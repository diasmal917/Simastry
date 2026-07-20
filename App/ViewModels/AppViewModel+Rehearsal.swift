import Foundation

/// Rehearsal Room turns. Sessions themselves live in the presenting view and
/// persist via `RehearsalSessionStore`; the view model only runs the
/// generation turns and applies the same daily-message gating as
/// consultations.
extension AppViewModel {
    /// The practice partner's next reply.
    func rehearsalPartnerReply(for session: RehearsalSession) async throws -> String {
        try await runRehearsalTurn(session: session, mode: "partner")
    }

    /// The primary companion's note on the user's latest draft.
    func rehearsalCoachNote(for session: RehearsalSession) async throws -> String {
        try await runRehearsalTurn(session: session, mode: "coach")
    }

    private func runRehearsalTurn(session: RehearsalSession, mode: String) async throws -> String {
        #if DEBUG
        if isDebugPreviewStateActive {
            try? await Task.sleep(for: .milliseconds(400))
            return mode == "coach"
                ? "Your ask is buried under the apology — lead with the one sentence you need them to hear, then give the reason."
                : "Okay… what's going on?"
        }
        #endif

        guard isAuthenticated, supabase.canInvokeCompanionReply else {
            throw RehearsalError.signedOut
        }
        guard companionPivotState.syncConsent else {
            throw RehearsalError.privateSyncRequired
        }
        if let blocked = session.messages
            .filter({ $0.role == .user })
            .map({ ConversationPrivacyService().prepare($0.content) })
            .first(where: { !$0.canProceed }) {
            throw RehearsalError.safety(
                blocked.blockingMessage ?? "This rehearsal cannot be processed safely."
            )
        }
        try await syncCompanionPilotDataNow(includePrivateRecords: true)
        if !experienceMode.isCompanionExperience {
            guard canSendMessage() else {
                showUpsell = true
                throw RehearsalError.messageLimit(dailyMessageLimit)
            }
        }

        let body = RehearsalRequestBody(
            session: session,
            mode: mode,
            userSunSign: userSunSign,
            userMoonSign: userMoonSign,
            userRisingSign: userRisingSign,
            guidanceStyle: .stored
        )
        let text = try await supabase.invokeConversationRehearsal(request: body)
        if !experienceMode.isCompanionExperience {
            await consumeMessage()
        }
        analytics.track(.rehearsalTurnCompleted, params: ["mode": mode])
        return text
    }
}

nonisolated enum RehearsalError: LocalizedError {
    case signedOut
    case messageLimit(Int)
    case privateSyncRequired
    case safety(String)

    var errorDescription: String? {
        switch self {
        case .signedOut:
            "Sign in to use Practice."
        case .messageLimit(let limit):
            "You've used all \(limit) messages today. Upgrade for unlimited rehearsals."
        case .privateSyncRequired:
            "Turn on private sync in Companion memory before rehearsing with a saved person."
        case .safety(let message):
            message
        }
    }
}
