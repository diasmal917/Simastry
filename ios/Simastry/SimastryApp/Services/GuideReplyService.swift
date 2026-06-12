import Foundation

nonisolated extension ZodiacSign {
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
    /// Chat surfaces hold a typing indicator while the LLM races the
    /// template fallback — keep that race short so chats never feel stuck.
    static let chatReplyTimeout: Double = 2.5
    /// Deliberate flows (Predict, Playbooks) show their own progress UI and
    /// can afford a fuller generation window.
    static let deliberateReplyTimeout: Double = 8

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
        previousGuideName: String? = nil,
        memoryLines: [String] = [],
        mode: GuideChatMode = .bestFriend
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
        } else {
            // 1:1 threads carry the user's chosen register for this guide.
            lines.append(mode.promptBlock)
        }

        if !memoryLines.isEmpty {
            lines.append("Recent context you remember: " + memoryLines.joined(separator: "; ") + ".")
        }

        lines.append(SimastryVoice.promptBlock)

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

    /// Prompt pair for a situation playbook script (2-3 sendable lines for
    /// messaging a specific person, voiced by the user's Sun-lens guide).
    static func playbookPrompt(
        situation: String,
        personName: String,
        personSigns: String,
        relationshipType: String,
        guideProfile: FactoryCompanionProfile,
        user: UserContext
    ) -> (system: String, user: String) {
        var systemLines: [String] = []
        systemLines.append("You are \(guideProfile.name), a fictional AI astrologer guide inside the Simastry app.")
        systemLines.append("Your lens: \(guideProfile.sign.displayName) — Simastry Method specialization: \(guideProfile.sign.methodLine).")
        systemLines.append(SimastryVoice.promptBlock)
        systemLines.append("""
        Task: write a short message script the user could actually send — 2 to 3 sentences, \
        natural text-message register, no greeting filler, no emoji. Plain text only. \
        Read the target person through their placements and the relationship type. \
        Output ONLY the script itself, nothing else.
        """)

        var userLines: [String] = []
        userLines.append("Situation: \(situation).")
        userLines.append("The person: \(personName) — \(personSigns). Relationship: \(relationshipType).")
        var chartParts: [String] = []
        if let sun = user.sun { chartParts.append("Sun in \(sun.displayName)") }
        if let moon = user.moon { chartParts.append("Moon in \(moon.displayName)") }
        if let rising = user.rising { chartParts.append("Rising in \(rising.displayName)") }
        if !chartParts.isEmpty {
            userLines.append("The sender\(user.name.map { " (\($0))" } ?? "") has \(chartParts.joined(separator: ", ")).")
        }
        userLines.append("Write the script.")

        return (systemLines.joined(separator: "\n"), userLines.joined(separator: "\n"))
    }

    /// Prompt pair for a practice conversation with a simulated persona of
    /// someone in the user's life — a REHEARSAL, never the real person.
    /// Built from chart placements and user-described behavior; the hard
    /// rules ban identity claims, stereotyping, and unhandled crisis talk.
    static func practicePersonaPrompt(
        personName: String,
        personSigns: String,
        relationshipType: String,
        pronouns: String?,
        ageBand: String?,
        textingStyles: [String],
        situationLine: String?,
        contextNotes: String?,
        user: UserContext,
        transcript: [TranscriptEntry]
    ) -> (system: String, user: String) {
        var systemLines: [String] = []
        systemLines.append("You are a practice simulation inside the Simastry app: a rehearsal stand-in for \(personName), a real person in the user's life. The user wants to practice a conversation before having it for real.")
        systemLines.append("Simulate how \(personName) might plausibly respond, based ONLY on: chart placements (\(personSigns)), relationship to the user (\(relationshipType)), and the user's own description below.")

        var descriptors: [String] = []
        if let pronouns { descriptors.append("pronouns: \(pronouns)") }
        if let ageBand { descriptors.append("age: \(ageBand)") }
        if !textingStyles.isEmpty { descriptors.append("texting style: \(textingStyles.joined(separator: ", "))") }
        if !descriptors.isEmpty {
            systemLines.append("Described behavior — \(descriptors.joined(separator: "; ")).")
        }
        if let situationLine {
            systemLines.append("Current situation: \(situationLine).")
        }
        if let contextNotes = contextNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !contextNotes.isEmpty {
            systemLines.append("The user's own notes about \(personName), verbatim: \u{201C}\(contextNotes)\u{201D}")
        }

        var chartParts: [String] = []
        if let sun = user.sun { chartParts.append("Sun in \(sun.displayName)") }
        if let moon = user.moon { chartParts.append("Moon in \(moon.displayName)") }
        if !chartParts.isEmpty {
            systemLines.append("The user\(user.name.map { " (\($0))" } ?? "") has \(chartParts.joined(separator: ", ")).")
        }

        systemLines.append(SimastryVoice.promptBlock)

        systemLines.append("""
        Hard rules: you are a rehearsal simulation, NOT the real \(personName) — never claim to be them, \
        never invent facts about their life beyond what the user described. \
        Derive behavior from described patterns only; never stereotype from any demographic detail. \
        Reply in 1-2 short sentences in their plausible texting register. \
        Stay realistic — include the friction the user describes; a rehearsal that only flatters is useless. \
        If the conversation turns to crisis, self-harm, or abuse, break character and gently point the user to real-world support. \
        Plain text only, no emoji unless their texting style says otherwise.
        """)

        let userPrompt = threadUserPrompt(transcript: transcript, replyingAs: personName)
        return (systemLines.joined(separator: "\n"), userPrompt)
    }

    /// Prompt pair for a guide's comment on a user's Moment. The model never
    /// sees the photo — the hard no-vision rule is part of the system prompt.
    static func momentCommentPrompt(
        caption: String?,
        guideProfile: FactoryCompanionProfile,
        role: CelestialRole?,
        user: UserContext
    ) -> (system: String, user: String) {
        var systemLines: [String] = []
        systemLines.append("You are \(guideProfile.name), a fictional AI astrologer guide inside the Simastry app, commenting on a photo the user posted to their private Moments wall.")
        systemLines.append("Your lens: \(guideProfile.sign.displayName) — Simastry Method specialization: \(guideProfile.sign.methodLine).")
        if let role {
            systemLines.append("On the user's advisory panel you hold their \(role.displayName) lens.")
        }
        systemLines.append(SimastryVoice.promptBlock)
        systemLines.append("""
        Hard rule: you CANNOT see the photo. Never describe, guess, or imply anything about \
        the image content. Respond only to the user's caption and their chart energy. \
        One warm sentence, in character, plain text only — no emoji, no hashtags.
        """)

        var userLines: [String] = []
        if let caption = caption?.trimmingCharacters(in: .whitespacesAndNewlines), !caption.isEmpty {
            userLines.append("Their caption: \u{201C}\(caption)\u{201D}")
        } else {
            userLines.append("They posted with no caption.")
        }
        var chartParts: [String] = []
        if let sun = user.sun { chartParts.append("Sun in \(sun.displayName)") }
        if let rising = user.rising { chartParts.append("Rising in \(rising.displayName)") }
        if !chartParts.isEmpty {
            userLines.append("The user\(user.name.map { " (\($0))" } ?? "") has \(chartParts.joined(separator: ", ")).")
        }
        userLines.append("Write your one-sentence comment.")

        return (systemLines.joined(separator: "\n"), userLines.joined(separator: "\n"))
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
