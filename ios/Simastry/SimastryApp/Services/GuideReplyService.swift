import Foundation

extension ZodiacSign {
    /// Zodiac-lens specialization in Simastry Method language — shared by the
    /// directory cards and the LLM persona prompts.
    var methodLine: String {
        switch self {
        case .aries: "bold openings · momentum · directness"
        case .taurus: "grounding · trust-building · pacing"
        case .gemini: "banter craft · reframes · timing"
        case .cancer: "emotional safety · soft repair"
        case .leo: "confidence · warmth · presence"
        case .virgo: "precision edits · pattern naming"
        case .libra: "tone balance · graceful boundaries"
        case .scorpio: "motive reads · intensity · repair"
        case .sagittarius: "honesty · space · timing"
        case .capricorn: "restraint · standards · strategy"
        case .aquarius: "autonomy · perspective · distance"
        case .pisces: "empathy · feeling translation"
        }
    }
}

/// Builds the prompts for LLM-generated guide replies (panel and 1:1 chats)
/// sent through the companion-reply edge function. Static and deterministic
/// so prompt content is unit-testable.
nonisolated enum GuideReplyService {
    struct UserContext: Sendable {
        let name: String?
        let sun: ZodiacSign?
        let moon: ZodiacSign?
        let rising: ZodiacSign?
        let communicationType: String?
    }

    struct TranscriptEntry: Sendable {
        let senderName: String
        let content: String
    }

    static func personaSystemPrompt(
        profile: FactoryCompanionProfile,
        role: CelestialRole?,
        user: UserContext,
        isPanel: Bool,
        previousGuideName: String? = nil
    ) -> String {
        var lines: [String] = []

        lines.append("You are \(profile.name), a fictional AI astrologer guide inside the Simastry app.")
        lines.append("Your lens: \(profile.sign.displayName) — Simastry Method specialization: \(profile.sign.methodLine).")
        lines.append("Your persona: \(profile.headline) \(profile.personalityBio)")

        if let role {
            lines.append("On the user's advisory panel you hold their \(role.displayName) lens.")
        }

        var chartParts: [String] = []
        if let sun = user.sun { chartParts.append("Sun in \(sun.displayName)") }
        if let moon = user.moon { chartParts.append("Moon in \(moon.displayName)") }
        if let rising = user.rising { chartParts.append("Rising in \(rising.displayName)") }
        if !chartParts.isEmpty {
            lines.append("The user\(user.name.map { ", \($0)," } ?? "") has \(chartParts.joined(separator: ", ")).")
        }
        if let type = user.communicationType {
            lines.append("Their Simastry communication type is \(type).")
        }

        if isPanel {
            lines.append("You are one of three guides in a group thread; speak only as yourself.")
            if let previousGuideName {
                lines.append("\(previousGuideName) replied just before you — you may briefly build on or differ from their take, in one clause.")
            }
        }

        lines.append("""
        Rules: reply in 1-3 short sentences in a warm text-message register, in character. \
        Read the conversation through your sign lens and the user's chart. Be specific to what they wrote. \
        Never claim to be human or professionally certified; you are an in-app AI guide. \
        No medical, legal, or financial advice. If the user mentions self-harm or abuse, gently suggest real-world support. \
        Plain text only — no markdown, no emoji unless the user uses them first.
        """)

        return lines.joined(separator: "\n")
    }

    static func threadUserPrompt(
        transcript: [TranscriptEntry],
        replyingAs guideName: String,
        maxMessages: Int = 10
    ) -> String {
        let recent = transcript.suffix(maxMessages)
        let lines = recent
            .map { "\($0.senderName): \($0.content)" }
            .joined(separator: "\n")

        return """
        Conversation so far:
        \(lines)

        Reply as \(guideName).
        """
    }

    /// Races an async operation against a timeout; nil on timeout or error.
    static func withTimeout(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> String
    ) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                try? await operation()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
