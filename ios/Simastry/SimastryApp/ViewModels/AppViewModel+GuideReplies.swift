import Foundation

// MARK: - LLM Guide Replies
// Optional Claude-generated replies for the panel and 1:1 chats, routed
// through the companion-reply edge function. Gated by AppConfig.llmChatEnabled
// (off until the function is deployed); every path falls back to the template
// composer on error or timeout, so chats never stall.

extension AppViewModel {
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
    ) async -> String? {
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
            memoryLines: llmMemoryLines
        )
        let user = GuideReplyService.threadUserPrompt(
            transcript: Array(transcript),
            replyingAs: entry.profile.name
        )

        return await GuideReplyService.withTimeout(seconds: GuideReplyService.chatReplyTimeout) { [supabase] in
            try await supabase.invokeCompanionReply(kind: .chat, system: system, user: user, maxTokens: 300)
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
            memoryLines: llmMemoryLines
        )
        let user = GuideReplyService.threadUserPrompt(
            transcript: Array(transcript),
            replyingAs: companionName
        )

        return await GuideReplyService.withTimeout(seconds: GuideReplyService.chatReplyTimeout) { [supabase] in
            try await supabase.invokeCompanionReply(kind: .chat, system: system, user: user, maxTokens: 300)
        }
    }
}
