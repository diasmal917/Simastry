import Foundation

// MARK: - Playbook LLM Hook
// Optional Claude-generated playbook scripts via the companion-reply edge
// function; the template composer remains the instant, permanent fallback.

extension AppViewModel {
    /// LLM script for a playbook, or nil (caller keeps the template script).
    func generatePlaybookViaLLM(
        person: RelationshipPerson,
        situation: PlaybookSituation
    ) async -> String? {
        guard AppConfig.llmChatEnabled, supabase.canInvokeCompanionReply else { return nil }
        guard let guideEntry = panelGuideEntries.first else { return nil }

        let userContext = GuideReplyService.UserContext(
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

        let prompts = GuideReplyService.playbookPrompt(
            situation: situation.title,
            personName: person.displayName,
            personSigns: person.signLine,
            relationshipType: person.relationshipType.rawValue,
            guideProfile: guideEntry.profile,
            user: userContext
        )

        return await GuideReplyService.withTimeout(seconds: 8) { [supabase] in
            try await supabase.invokeCompanionReply(
                kind: .chat,
                system: prompts.system,
                user: prompts.user,
                maxTokens: 200
            )
        }
    }
}
