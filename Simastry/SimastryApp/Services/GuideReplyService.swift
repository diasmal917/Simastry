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
    static let chatReplyMaxTokens: Int = 140
    static let panelReplyMaxTokens: Int = 160
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

    struct TranscriptEntry: Equatable, Sendable {
        let senderName: String
        let content: String
        var isUser: Bool = false
    }

    struct OutgoingMessageSafetyResult: Equatable, Sendable {
        let redactedText: String
        let privacySummary: String?
        let blockingMessage: String?

        var canProceed: Bool {
            blockingMessage == nil
        }
    }

    struct RemoteTranscriptPreparation: Equatable, Sendable {
        let transcript: [TranscriptEntry]
        let privacySummary: String?
        let blockingMessage: String?

        var canProceed: Bool {
            blockingMessage == nil
        }
    }

    enum ChatIntent: String, Equatable, Sendable {
        case greeting
        case readMe
        case chartToday
        case comeAcross
        case notSeeing
        case chartGeneral
        case shortCheckIn
        case other
    }

    static func personaSystemPrompt(
        profile: FactoryCompanionProfile,
        role: CelestialRole?,
        user: UserContext,
        isPanel: Bool,
        previousGuideName: String? = nil,
        memoryLines: [String] = [],
        mode: GuideChatMode = .bestFriend,
        calibration: GuideCalibration? = nil,
        feedbackSummary: String? = nil
    ) -> String {
        var lines: [String] = []

        lines.append("You are \(profile.name), a fictional AI astrologer guide inside the Simastry app.")
        lines.append("Your private lens: \(profile.sign.displayName) — \(profile.sign.methodLine). Do not say 'Simastry Method' in chat replies.")
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
            if let calibrationBlock = calibration?.promptBlock {
                lines.append(calibrationBlock)
            }
        }

        if !memoryLines.isEmpty {
            lines.append("Recent context you remember: " + memoryLines.joined(separator: "; ") + ".")
        }

        if let feedbackSummary, !feedbackSummary.isEmpty {
            lines.append(feedbackSummary)
        }

        lines.append(SimastryVoice.promptBlock)

        lines.append("""
        Rules: reply like a real text from a sharp friend: 1-2 short sentences, usually under 28 words total. \
        If the latest user message is just a greeting, answer tiny and ask what is up. \
        If they ask about their signs, chart, today, how they come across, "read me", or what they are not seeing, briefly say you are looking at their chart, name the relevant Sun/Moon/Rising you have, and answer the exact question before giving advice. \
        For chart questions, use this flow: "let me look..." then placements, then one direct read, then one practical move. \
        Do not dodge a direct chart question with generic texting coaching. \
        No lecture voice, no slogan, no "for a second", no "let's separate", no "one beat", no method language. \
        Read the conversation through your sign lens and the user's chart, but keep the astrology mostly invisible unless they ask. \
        Never claim to be human or professionally certified; you are an in-app AI guide. \
        No medical, legal, or financial advice. If the user mentions self-harm or abuse, gently suggest real-world support. \
        Plain text only — no markdown, no emoji unless the user uses them first.
        """)

        return lines.joined(separator: "\n")
    }

    static func humanChatFallback(
        latestUserText: String,
        sign: ZodiacSign,
        threadCount: Int,
        mode: GuideChatMode,
        user: UserContext? = nil,
        allowChartFallback: Bool = true
    ) -> String? {
        let normalized = latestUserText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!? "))
        guard !normalized.isEmpty else { return nil }

        let intent = chatIntent(for: normalized)
        let greetingWords: Set<String> = ["hey", "hi", "hello", "yo", "sup", "hiya", "heyy"]
        let words = normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if intent == .greeting || (words.count <= 3 && words.contains(where: greetingWords.contains)) {
            let replies = [
                "hey. i'm here. what's up?",
                "hey - tell me what happened.",
                "hi. what's going on?",
                "hey. what are we reading?"
            ]
            return replies[threadCount % replies.count]
        }

        if normalized.count <= 24 {
            switch mode {
            case .mentor:
                return "got it. what outcome do you want here?"
            case .teacher:
                return "i'm here. say the part you're not saying yet."
            case .checkIn:
                return "i'm here. what are you feeling right now?"
            case .bestFriend:
                let replies = [
                    "i'm here. give me the messy version.",
                    "okay. what happened right before this?",
                    "tell me the part that feels weird."
                ]
                return replies[(threadCount + sign.rawValue.count) % replies.count]
            }
        }

        if allowChartFallback,
           let user,
           [.chartToday, .comeAcross, .notSeeing, .readMe, .chartGeneral].contains(intent) {
            return chartQuestionFallback(user: user, intent: intent)
        }

        return nil
    }

    static func chatIntent(for text: String) -> ChatIntent {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!? "))
        guard !normalized.isEmpty else { return .other }

        let words = normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let greetingWords: Set<String> = ["hey", "hi", "hello", "yo", "sup", "hiya", "heyy"]
        if words.count <= 3, words.contains(where: greetingWords.contains) {
            return .greeting
        }
        if normalized.contains("what am i not seeing") || normalized.contains("not seeing") {
            return .notSeeing
        }
        if normalized.contains("read me") {
            return .readMe
        }
        if (normalized.contains("chart") || normalized.contains("sign")) && normalized.contains("today") {
            return .chartToday
        }
        if normalized.contains("come across") || normalized.contains("come off") {
            return .comeAcross
        }
        if isChartQuestion(normalized) {
            return .chartGeneral
        }
        if normalized.count <= 24 {
            return .shortCheckIn
        }
        return .other
    }

    private static func isChartQuestion(_ normalized: String) -> Bool {
        let chartWords = ["sign", "signs", "chart", "birth chart", "placement", "placements", "aura"]
        return chartWords.contains { normalized.contains($0) }
    }

    private static func chartQuestionFallback(user: UserContext, intent: ChatIntent) -> String? {
        let placements = [
            user.sun.map { "Sun in \($0.displayName)" },
            user.moon.map { "Moon in \($0.displayName)" },
            user.rising.map { "Rising in \($0.displayName)" }
        ].compactMap { $0 }
        guard !placements.isEmpty else {
            return "let me look at what you've added so far. i need your signs before i can read this cleanly."
        }

        let chartLine = placements.joined(separator: ", ")
        let typeLine = user.communicationType.map { " Your \($0) pattern" } ?? " That mix"
        switch intent {
        case .chartToday:
            return "let me look at your chart. i see \(chartLine).\(typeLine) says today goes better when you lead with the honest first sentence, then soften the delivery. one clear text, no pile-on."
        case .comeAcross:
            return "let me look at your signs. i see \(chartLine).\(typeLine) can come across warm and easy to trust, but also a little indirect when you are trying to keep the peace. say the real point earlier."
        case .notSeeing, .readMe:
            return "let me look at your chart. i see \(chartLine). what you may be missing: you are trying to make the tone perfect before the truth is clear. name the truth first, then make it kind."
        case .chartGeneral:
            return "let me look at your chart. i see \(chartLine).\(typeLine) reads best when you are direct, warm, and brief. the move is not more explaining; it is one sentence that is actually yours."
        default:
            return "let me look at your chart. i see \(chartLine). answer me with the real question underneath this, and i'll read that directly."
        }
    }

    static func threadUserPrompt(
        transcript: [TranscriptEntry],
        replyingAs guideName: String,
        maxMessages: Int = 10,
        privacySummary: String? = nil
    ) -> String {
        let recent = transcript.suffix(maxMessages)
        let lines = recent
            .map { "\($0.senderName): \($0.content)" }
            .joined(separator: "\n")

        let privacyBlock = privacySummary.map {
            """
            Privacy handling:
            \($0)

            """
        } ?? ""

        return """
        \(privacyBlock)\
        Conversation so far:
        \(lines)

        Reply as \(guideName).
        """
    }

    static func prepareOutgoingUserMessage(
        _ content: String,
        privacyService: ConversationPrivacyService = ConversationPrivacyService()
    ) -> OutgoingMessageSafetyResult {
        let moderation = ContentModerationService.moderateGuideMessage(content)
        let prepared = privacyService.prepare(content)
        if !moderation.isAllowed {
            return OutgoingMessageSafetyResult(
                redactedText: prepared.redactedText,
                privacySummary: prepared.privacySummary,
                blockingMessage: moderation.reason
            )
        }
        if !prepared.canProceed {
            return OutgoingMessageSafetyResult(
                redactedText: prepared.redactedText,
                privacySummary: prepared.privacySummary,
                blockingMessage: prepared.blockingMessage
            )
        }
        return OutgoingMessageSafetyResult(
            redactedText: prepared.redactedText,
            privacySummary: prepared.privacySummary,
            blockingMessage: nil
        )
    }

    static func prepareRemoteTranscript(
        _ transcript: [TranscriptEntry],
        privacyService: ConversationPrivacyService = ConversationPrivacyService()
    ) -> RemoteTranscriptPreparation {
        var summaries: [String] = []
        var sanitized: [TranscriptEntry] = []

        for entry in transcript {
            let prepared = privacyService.prepare(entry.content)
            if let summary = prepared.privacySummary {
                summaries.append(summary)
            }

            if entry.isUser {
                let moderation = ContentModerationService.moderateGuideMessage(entry.content)
                if !moderation.isAllowed {
                    return RemoteTranscriptPreparation(
                        transcript: sanitized,
                        privacySummary: combinedPrivacySummary(summaries),
                        blockingMessage: moderation.reason
                    )
                }
                if !prepared.canProceed {
                    return RemoteTranscriptPreparation(
                        transcript: sanitized,
                        privacySummary: combinedPrivacySummary(summaries),
                        blockingMessage: prepared.blockingMessage
                    )
                }
            }

            sanitized.append(
                TranscriptEntry(
                    senderName: entry.senderName,
                    content: prepared.redactedText,
                    isUser: entry.isUser
                )
            )
        }

        return RemoteTranscriptPreparation(
            transcript: sanitized,
            privacySummary: combinedPrivacySummary(summaries),
            blockingMessage: nil
        )
    }

    private static func combinedPrivacySummary(_ summaries: [String]) -> String? {
        var seen: Set<String> = []
        let uniqueSummaries = summaries.filter { seen.insert($0).inserted }
        guard !uniqueSummaries.isEmpty else { return nil }
        return uniqueSummaries.joined(separator: " ")
    }

    /// Prompt pair for a situation playbook script (2-3 sendable lines for
    /// messaging a specific person, voiced by the user's Sun-lens guide).
    static func playbookPrompt(
        situation: String,
        personName: String,
        personSigns: String,
        relationshipType: String,
        personalityType: MBTIPersonalityType? = nil,
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
        if let personalityType {
            userLines.append("Optional personality type shared by the user: \(personalityType.rawValue). Use this lightly as context, not as a fixed judgment.")
        }
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
        personalityType: MBTIPersonalityType?,
        textingStyles: [String],
        situationLine: String?,
        contextNotes: String?,
        user: UserContext,
        transcript: [TranscriptEntry],
        privacySummary: String? = nil
    ) -> (system: String, user: String) {
        var systemLines: [String] = []
        systemLines.append("You are a practice simulation inside the Simastry app: a rehearsal stand-in for \(personName), a real person in the user's life. The user wants to practice a conversation before having it for real.")
        systemLines.append("Simulate how \(personName) might plausibly respond, based ONLY on: chart placements (\(personSigns)), relationship to the user (\(relationshipType)), and the user's own description below.")

        var descriptors: [String] = []
        if let pronouns { descriptors.append("pronouns: \(pronouns)") }
        if let ageBand { descriptors.append("age: \(ageBand)") }
        if let personalityType { descriptors.append("personality type: \(personalityType.rawValue)") }
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

        let userPrompt = threadUserPrompt(
            transcript: transcript,
            replyingAs: personName,
            privacySummary: privacySummary
        )
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
    static func withTimeout<Output: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> Output
    ) async -> Output? {
        await withTaskGroup(of: Output?.self) { group in
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
