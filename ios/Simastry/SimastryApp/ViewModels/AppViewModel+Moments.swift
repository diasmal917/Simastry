import Foundation

// MARK: - Moments
// Private, on-device photo posts. The user's panel guides drip persona-voiced
// template comments after a post — riffing on the caption and the user's
// chart, never claiming to see the image (there is no vision model).

extension AppViewModel {
    func loadMoments() {
        moments = momentsStore.load()
    }

    func saveMoments() {
        momentsStore.save(moments)
    }

    @discardableResult
    func addMoment(imageData: Data, caption: String?) -> Moment? {
        guard let prepared = MomentPhoto.prepared(imageData) else {
            showToast("Couldn't read that photo", subtitle: "Try a different image.", isError: true)
            return nil
        }

        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let moment = Moment(
            caption: (trimmedCaption?.isEmpty ?? true) ? nil : trimmedCaption,
            imageFileName: "\(UUID().uuidString).jpg"
        )

        guard momentsStore.writeImage(prepared, fileName: moment.imageFileName) else {
            showToast("Couldn't save that photo", subtitle: "Check your device storage and try again.", isError: true)
            return nil
        }

        moments.insert(moment, at: 0)
        saveMoments()
        scheduleGuideEngagement(for: moment)
        return moment
    }

    func deleteMoment(_ moment: Moment) {
        momentsStore.deleteImage(fileName: moment.imageFileName)
        moments.removeAll { $0.id == moment.id }
        momentTypingKeys = momentTypingKeys.filter { !$0.hasPrefix("\(moment.id.uuidString):") }
        saveMoments()
    }

    func momentImageURL(for moment: Moment) -> URL {
        momentsStore.imageURL(for: moment.imageFileName)
    }

    func addUserComment(_ text: String, to momentId: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = moments.firstIndex(where: { $0.id == momentId }) else { return }

        let comment = MomentComment(
            authorKind: .user,
            authorName: profile?.displayName ?? "You",
            content: trimmed
        )
        moments[index].comments.append(comment)
        saveMoments()

        // Sometimes one guide answers the user's comment.
        if moments[index].comments.count % 2 == 0 {
            scheduleSingleGuideReply(momentId: momentId)
        }
    }

    /// 1–3 guides comment over roughly a minute, with typing indicators and a
    /// couple of reactions arriving alongside.
    private func scheduleGuideEngagement(for moment: Moment) {
        let guides = panelGuideEntries
        guard !guides.isEmpty else { return }

        let seed = abs(moment.id.uuidString.hashValue)
        let commenterCount = min(1 + seed % 3, guides.count)
        let start = seed % guides.count
        let commenters = Array((guides[start...] + guides[..<start]).prefix(commenterCount))
        let delays: [Int] = [8_000, 25_000, 50_000]

        for (index, entry) in commenters.enumerated() {
            scheduleGuideComment(
                momentId: moment.id,
                entry: entry,
                beatIndex: seed + index,
                landDelayMilliseconds: delays[min(index, delays.count - 1)]
            )
        }
    }

    private func scheduleSingleGuideReply(momentId: UUID) {
        guard let moment = moments.first(where: { $0.id == momentId }),
              let entry = panelGuideEntries.randomElement() else { return }
        scheduleGuideComment(
            momentId: momentId,
            entry: entry,
            beatIndex: abs(moment.id.uuidString.hashValue) + moment.comments.count,
            landDelayMilliseconds: 5_000
        )
    }

    private func scheduleGuideComment(
        momentId: UUID,
        entry: PanelMatcher.Entry,
        beatIndex: Int,
        landDelayMilliseconds: Int
    ) {
        let typingKey = "\(momentId.uuidString):\(entry.profile.id)"
        guard !momentTypingKeys.contains(typingKey) else { return }

        let typingLeadIn = 1_500

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(max(landDelayMilliseconds - typingLeadIn, 300)))
            guard moments.contains(where: { $0.id == momentId }) else { return }
            momentTypingKeys.insert(typingKey)

            // LLM comment when the edge channel is live (caption + chart only,
            // never the image); template fallback keeps the typing feel.
            var content = await generateMomentCommentViaLLM(momentId: momentId, entry: entry)
            if content == nil {
                try? await Task.sleep(for: .milliseconds(typingLeadIn))
            }
            momentTypingKeys.remove(typingKey)

            guard let index = moments.firstIndex(where: { $0.id == momentId }) else { return }

            if content == nil {
                content = Self.composeMomentComment(
                    profile: entry.profile,
                    role: entry.role,
                    caption: moments[index].caption,
                    userName: (profile?.displayName ?? "").components(separatedBy: " ").first,
                    userSun: userSunSign,
                    userRising: userRisingSign,
                    beatIndex: beatIndex
                )
            }

            guard let content, !content.isEmpty else { return }
            let comment = MomentComment(
                authorKind: .guide(profileId: entry.profile.id),
                authorName: entry.profile.name,
                content: content
            )
            moments[index].comments.append(comment)
            moments[index].reactionCount += 1 + beatIndex % 2
            saveMoments()
        }
    }

    /// LLM comment for a moment, or nil (caller falls back to templates).
    private func generateMomentCommentViaLLM(
        momentId: UUID,
        entry: PanelMatcher.Entry
    ) async -> String? {
        guard AppConfig.llmChatEnabled, supabase.canInvokeCompanionReply,
              let moment = moments.first(where: { $0.id == momentId }) else { return nil }

        let userContext = GuideReplyService.UserContext(
            name: (profile?.displayName ?? "").components(separatedBy: " ").first,
            sun: userSunSign,
            moon: userMoonSign,
            rising: userRisingSign,
            communicationType: nil
        )

        let prompts = GuideReplyService.momentCommentPrompt(
            caption: moment.caption,
            guideProfile: entry.profile,
            role: entry.role,
            user: userContext
        )

        return await GuideReplyService.withTimeout(seconds: 8) { [supabase] in
            try await supabase.invokeCompanionReply(
                kind: .chat,
                system: prompts.system,
                user: prompts.user,
                maxTokens: 120
            )
        }
    }

    /// Static and deterministic for unit testing. Comments riff on the caption
    /// (when present) or the user's chart — never on image content.
    nonisolated static func composeMomentComment(
        profile: FactoryCompanionProfile,
        role: CelestialRole,
        caption: String?,
        userName: String?,
        userSun: ZodiacSign?,
        userRising: ZodiacSign?,
        beatIndex: Int
    ) -> String {
        if let caption = caption?.trimmingCharacters(in: .whitespacesAndNewlines),
           !caption.isEmpty,
           beatIndex % 5 < 3 {
            let echoes = AstrologyTemplates.momentCaptionEchoTemplates
            if !echoes.isEmpty {
                let snippet = String(caption.prefix(40))
                return echoes[beatIndex % echoes.count]
                    .replacingOccurrences(of: "{caption}", with: snippet)
            }
        }

        let templates = AstrologyTemplates.momentCommentTemplates[profile.sign.element.rawValue] ?? []
        guard !templates.isEmpty else {
            return "This one belongs in the keep pile."
        }
        return templates[beatIndex % templates.count]
            .replacingOccurrences(of: "{name}", with: userName ?? "you")
            .replacingOccurrences(of: "{sun}", with: userSun?.displayName ?? "Sun-sign")
            .replacingOccurrences(of: "{rising}", with: userRising?.displayName ?? "Rising")
            .replacingOccurrences(of: "{role}", with: role.displayName)
    }
}
