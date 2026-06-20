import Foundation

// MARK: - LLM Guide Replies
// Optional Claude-generated replies for the panel and 1:1 chats, routed
// through the companion-reply edge function. Gated by AppConfig.llmChatEnabled
// (off until the function is deployed); every path falls back to the template
// composer on error or timeout, so chats never stall.

extension AppViewModel {
    // MARK: Guide DMs

    static let guideThreadIdsKey = "simastry_guide_thread_ids"

    /// Stable thread UUID per catalog guide, so a guide's DM thread survives
    /// app restarts and reopens to the same conversation.
    func guideThreadId(for profile: FactoryCompanionProfile) -> UUID {
        var map = (UserDefaults.standard.data(forKey: Self.guideThreadIdsKey))
            .flatMap { try? JSONDecoder().decode([String: UUID].self, from: $0) } ?? [:]
        if let existing = map[profile.id] {
            return existing
        }
        let id = UUID()
        map[profile.id] = id
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: Self.guideThreadIdsKey)
        }
        return id
    }

    func guideProfile(
        forThreadId companionId: UUID,
        companionName: String? = nil,
        companionSign: String? = nil
    ) -> FactoryCompanionProfile? {
        let map = (UserDefaults.standard.data(forKey: Self.guideThreadIdsKey))
            .flatMap { try? JSONDecoder().decode([String: UUID].self, from: $0) } ?? [:]

        if let guideId = map.first(where: { $0.value == companionId })?.key,
           let profile = FactoryCompanionCatalog.all.first(where: { $0.id == guideId }) {
            return profile
        }

        if let companionName {
            let normalizedName = companionName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let profile = FactoryCompanionCatalog.all.first(where: { $0.name.lowercased() == normalizedName }) {
                return profile
            }
        }

        if let companionSign,
           let sign = ZodiacSign(rawValue: companionSign.lowercased())
            ?? ZodiacSign.allCases.first(where: { $0.displayName.lowercased() == companionSign.lowercased() }) {
            return FactoryCompanionCatalog.all.first { $0.sign == sign }
        }

        return nil
    }

    /// The Instagram flow's last step: open a real 1:1 thread with any
    /// catalog guide. First open seeds the guide's greeting so the thread
    /// exists in the inbox; subsequent opens land in the same conversation.
    func startGuideChat(_ profile: FactoryCompanionProfile) {
        let threadId = guideThreadId(for: profile)

        if !companionMessages.contains(where: { $0.companionId == threadId }) {
            let greeting = "Hey — \(profile.name) here, your \(profile.sign.displayName) lens. \(profile.headline) What's the conversation on your mind?"
            companionMessages.insert(
                CompanionMessage(
                    companionId: threadId,
                    companionName: profile.name,
                    companionSign: profile.sign.rawValue,
                    content: greeting,
                    isRead: true,
                    source: .companion,
                    direction: .incoming
                ),
                at: 0
            )
            saveMessages()
        }

        selectedTab = .messages
        openThreadRequestCompanionId = threadId
    }

    // MARK: Guide Chat Modes

    /// The user's chosen register for a 1:1 guide thread (best friend by
    /// default). Per-companion, device-local.
    func guideChatMode(for companionId: UUID) -> GuideChatMode {
        UserDefaults.standard.string(forKey: GuideChatMode.storageKey(for: companionId))
            .flatMap(GuideChatMode.init(rawValue:)) ?? .bestFriend
    }

    /// Switches the register and, on the first ever switch into Check-in for
    /// this companion, posts the non-therapy disclosure as the guide's own
    /// message so the boundary is stated before the first exchange.
    func setGuideChatMode(
        _ mode: GuideChatMode,
        for companionId: UUID,
        companionName: String,
        companionSign: String
    ) {
        UserDefaults.standard.set(mode.rawValue, forKey: GuideChatMode.storageKey(for: companionId))

        guard mode == .checkIn else { return }
        let disclosureKey = GuideChatMode.disclosureKey(for: companionId)
        guard !UserDefaults.standard.bool(forKey: disclosureKey) else { return }
        UserDefaults.standard.set(true, forKey: disclosureKey)

        let disclosure = CompanionMessage(
            companionId: companionId,
            companionName: companionName,
            companionSign: companionSign,
            content: GuideChatMode.checkInDisclosure,
            timestamp: Date(),
            isRead: openCompanionThreadId == companionId,
            source: .companion,
            direction: .incoming
        )
        companionMessages.insert(disclosure, at: 0)
        saveMessages()
    }

    /// The two most recent memory notes as prompt context lines.
    private var llmMemoryLines: [String] {
        let now = Date()
        return panelMemoryNotes
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(2)
            .map { note in
                let days = max(0, Int(now.timeIntervalSince(note.createdAt) / 86_400))
                return "asked about \(note.personName) (\(days == 0 ? "today" : "\(days)d ago"))"
            }
    }

    private var llmUserContext: GuideReplyService.UserContext {
        GuideReplyService.UserContext(
            name: (profile?.displayName ?? "").components(separatedBy: " ").first,
            sun: userSunSign,
            moon: userMoonSign,
            rising: userRisingSign,
            communicationType: CommunicationTypeProfile.make(
                sun: userSunSign,
                moon: userMoonSign,
                rising: userRisingSign
            )?.title
        )
    }

    /// LLM reply for a panel guide, or nil (caller falls back to templates).
    func generatePanelReplyViaLLM(
        entry: PanelMatcher.Entry,
        previousGuideName: String?
    ) async -> CompanionReplyResult? {
        guard AppConfig.llmChatEnabled, supabase.canInvokeCompanionReply else { return nil }

        let transcript = sortedPanelMessages.suffix(10).map { message in
            GuideReplyService.TranscriptEntry(
                senderName: message.senderId == PanelParticipant.localUserId
                    ? (llmUserContext.name ?? "User")
                    : (panelGuideEntry(forParticipantId: message.senderId)?.profile.name ?? "Guide"),
                content: message.content
            )
        }

        let system = GuideReplyService.personaSystemPrompt(
            profile: entry.profile,
            role: entry.role,
            user: llmUserContext,
            isPanel: true,
            previousGuideName: previousGuideName,
            memoryLines: llmMemoryLines,
            feedbackSummary: guideFeedbackPromptSummary(for: entry.profile.id)
        )
        let user = GuideReplyService.threadUserPrompt(
            transcript: Array(transcript),
            replyingAs: entry.profile.name
        )

        return await GuideReplyService.withTimeout(seconds: GuideReplyService.chatReplyTimeout) { [supabase] in
            try await supabase.invokeCompanionReplyResult(
                kind: .chat,
                feature: .panelChat,
                system: system,
                user: user,
                maxTokens: 300
            )
        }
    }

    /// LLM reply for a 1:1 companion thread, or nil (caller falls back).
    func generateCompanionReplyViaLLM(
        companionId: UUID,
        companionName: String,
        companionSign: String
    ) async -> String? {
        guard AppConfig.llmChatEnabled, supabase.canInvokeCompanionReply else { return nil }

        let sign = ZodiacSign(rawValue: companionSign.lowercased())
            ?? ZodiacSign.allCases.first { $0.displayName.lowercased() == companionSign.lowercased() }
        let matched = FactoryCompanionCatalog.all.first { $0.name.lowercased() == companionName.lowercased() }
            ?? sign.flatMap { resolved in FactoryCompanionCatalog.all.first { $0.sign == resolved } }
        guard let matched else { return nil }

        let thread = companionConversation(with: companionId).suffix(10)
        let transcript = thread.map { message in
            GuideReplyService.TranscriptEntry(
                senderName: message.direction == .outgoing
                    ? (llmUserContext.name ?? "User")
                    : companionName,
                content: message.content
            )
        }

        let system = GuideReplyService.personaSystemPrompt(
            profile: matched,
            role: nil,
            user: llmUserContext,
            isPanel: false,
            memoryLines: llmMemoryLines,
            mode: guideChatMode(for: companionId),
            calibration: GuideCalibrationStore.shared.calibration(for: matched.id),
            feedbackSummary: guideFeedbackPromptSummary(for: matched.id)
        )
        let user = GuideReplyService.threadUserPrompt(
            transcript: Array(transcript),
            replyingAs: companionName
        )

        return await GuideReplyService.withTimeout(seconds: GuideReplyService.chatReplyTimeout) { [supabase] in
            try await supabase.invokeCompanionReply(
                kind: .chat,
                feature: .companionChat,
                system: system,
                user: user,
                maxTokens: 300
            )
        }
    }
}
