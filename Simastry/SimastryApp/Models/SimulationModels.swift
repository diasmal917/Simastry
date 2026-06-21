import Foundation

nonisolated enum SimulationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case whatWillTheySay = "what_will_they_say"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whatWillTheySay:
            "Ask the Future"
        }
    }

    var systemImage: String {
        switch self {
        case .whatWillTheySay:
            "sparkles"
        }
    }

    var actionTitle: String {
        switch self {
        case .whatWillTheySay:
            "Ask the Future"
        }
    }
}

nonisolated enum FutureQuestionCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case loveTiming = "love_timing"
    case commitment = "commitment"
    case familyPath = "family_path"
    case careerSuccess = "career_success"
    case moneyDirection = "money_direction"
    case messageOutcome = "message_outcome"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loveTiming: "Love timing"
        case .commitment: "Commitment"
        case .familyPath: "Family path"
        case .careerSuccess: "Career success"
        case .moneyDirection: "Money direction"
        case .messageOutcome: "Message outcome"
        }
    }

    var shortTitle: String {
        switch self {
        case .loveTiming: "Love"
        case .commitment: "Marriage"
        case .familyPath: "Family"
        case .careerSuccess: "Career"
        case .moneyDirection: "Money"
        case .messageOutcome: "Replies"
        }
    }

    var subtitle: String {
        switch self {
        case .loveTiming: "Meetings, openings, and romantic momentum."
        case .commitment: "Marriage, seriousness, and long-game timing."
        case .familyPath: "Children, home, care, and family chapters."
        case .careerSuccess: "Visibility, purpose, and success windows."
        case .moneyDirection: "Prosperity patterns without financial advice."
        case .messageOutcome: "Texts, replies, interest, and timing."
        }
    }

    var defaultQuestion: String {
        switch self {
        case .loveTiming: "When will I meet someone?"
        case .commitment: "When will I get married?"
        case .familyPath: "Will I have kids?"
        case .careerSuccess: "Will I be successful?"
        case .moneyDirection: "Will I be rich?"
        case .messageOutcome: "Will they text back?"
        }
    }

    var suggestedQuestions: [String] {
        switch self {
        case .loveTiming:
            ["When will I meet someone?", "Is love opening soon?", "What kind of person is next?", "Should I put myself out there?"]
        case .commitment:
            ["When will I get married?", "Is this relationship serious?", "Are they long-term?", "What is blocking commitment?"]
        case .familyPath:
            ["Will I have kids?", "What family chapter is ahead?", "Am I building a home soon?", "What should I prepare for?"]
        case .careerSuccess:
            ["Will I be successful?", "What career window is opening?", "Should I take the risk?", "Where should I focus?"]
        case .moneyDirection:
            ["Will I be rich?", "How does money grow for me?", "What is my prosperity pattern?", "What should I stop leaking energy on?"]
        case .messageOutcome:
            ["Will they reply?", "What are they feeling?", "Should I double text?", "Are they interested?"]
        }
    }

    var systemImage: String {
        switch self {
        case .loveTiming: "heart.circle.fill"
        case .commitment: "sparkle.magnifyingglass"
        case .familyPath: "house.and.flag.fill"
        case .careerSuccess: "chart.line.uptrend.xyaxis.circle.fill"
        case .moneyDirection: "dollarsign.circle.fill"
        case .messageOutcome: "message.circle.fill"
        }
    }

    var requiresConversation: Bool {
        self == .messageOutcome
    }

    var requiresTargetSign: Bool {
        self == .messageOutcome
    }

    var allowsTargetSign: Bool {
        switch self {
        case .loveTiming, .commitment, .familyPath, .messageOutcome:
            true
        case .careerSuccess, .moneyDirection:
            false
        }
    }

    var resultTitle: String {
        switch self {
        case .messageOutcome: "Likely next text"
        default: "Short answer"
        }
    }

    var reasoningTitle: String {
        switch self {
        case .messageOutcome: "Why they'd say this"
        default: "Why this shows up"
        }
    }

    var actionTitle: String {
        switch self {
        case .messageOutcome: "Predict the reply"
        default: "Ask the future"
        }
    }
}

nonisolated enum SimulationTone: String, Codable, CaseIterable, Sendable {
    case playful
    case guarded
    case warm
    case cold
    case anxious
    case confident
    case flirty
    case distant

    var displayName: String {
        rawValue.capitalized
    }
}

nonisolated struct PredictionRequest: Sendable {
    let mode: SimulationMode
    let category: FutureQuestionCategory
    let conversationText: String
    let userSunSign: ZodiacSign?
    let userMoonSign: ZodiacSign?
    let userRisingSign: ZodiacSign?
    let targetSunSign: ZodiacSign?
    let targetMoonSign: ZodiacSign?
    let targetRisingSign: ZodiacSign?
    let question: String?
    let hypotheticalReply: String?

    init(
        mode: SimulationMode,
        category: FutureQuestionCategory = .messageOutcome,
        conversationText: String,
        userSunSign: ZodiacSign? = nil,
        userMoonSign: ZodiacSign? = nil,
        userRisingSign: ZodiacSign? = nil,
        targetSunSign: ZodiacSign?,
        targetMoonSign: ZodiacSign?,
        targetRisingSign: ZodiacSign?,
        question: String?,
        hypotheticalReply: String?
    ) {
        self.mode = mode
        self.category = category
        self.conversationText = conversationText
        self.userSunSign = userSunSign
        self.userMoonSign = userMoonSign
        self.userRisingSign = userRisingSign
        self.targetSunSign = targetSunSign
        self.targetMoonSign = targetMoonSign
        self.targetRisingSign = targetRisingSign
        self.question = question
        self.hypotheticalReply = hypotheticalReply
    }

    var trimmedConversationText: String {
        conversationText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedQuestion: String? {
        let trimmed = question?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedHypotheticalReply: String? {
        let trimmed = hypotheticalReply?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated enum PredictionOutcome: String, Codable, CaseIterable, Sendable {
    case landed
    case missed
    case feltAccurate = "felt_accurate"
    case tooVague = "too_vague"
    case morePractical = "more_practical"
    case timingOff = "timing_off"

    var title: String {
        switch self {
        case .landed: "Landed"
        case .missed: "Off"
        case .feltAccurate: "Felt accurate"
        case .tooVague: "Too vague"
        case .morePractical: "More practical"
        case .timingOff: "Timing off"
        }
    }

    var systemImage: String {
        switch self {
        case .landed: "hand.thumbsup.fill"
        case .missed: "hand.thumbsdown"
        case .feltAccurate: "checkmark.seal.fill"
        case .tooVague: "questionmark.bubble.fill"
        case .morePractical: "checklist"
        case .timingOff: "clock.badge.exclamationmark.fill"
        }
    }

    var countsAsAccurate: Bool {
        switch self {
        case .landed, .feltAccurate:
            true
        case .missed, .tooVague, .morePractical, .timingOff:
            false
        }
    }
}

nonisolated struct PredictionResult: Codable, Identifiable, Sendable {
    let id: UUID
    let mode: SimulationMode
    var category: FutureQuestionCategory?
    let question: String
    let conversationText: String?
    var userSunSign: ZodiacSign?
    var userMoonSign: ZodiacSign?
    var userRisingSign: ZodiacSign?
    let targetSunSign: ZodiacSign?
    let targetMoonSign: ZodiacSign?
    let targetRisingSign: ZodiacSign?
    let predictedMessage: String
    var directAnswer: String?
    var timingWindow: String?
    let astrologicalBreakdown: String
    var practicalNextMove: String?
    var safetyNote: String?
    let confidence: Int
    let tone: SimulationTone?
    let privacySummary: String?
    let createdAt: Date
    /// True when composed on-device from placement logic (no remote AI involved).
    /// Optional so previously saved history still decodes.
    var isLocalComposition: Bool?
    /// User-reported accuracy ("Did this land?"). Optional so old history decodes.
    var outcome: PredictionOutcome?

    var categoryOrDefault: FutureQuestionCategory {
        category ?? .messageOutcome
    }

    var isMessageOutcome: Bool {
        categoryOrDefault == .messageOutcome
    }

    var displayAnswer: String {
        if let directAnswer = directAnswer?.trimmingCharacters(in: .whitespacesAndNewlines),
           !directAnswer.isEmpty {
            return directAnswer
        }
        return predictedMessage
    }

    var historyTitle: String {
        if !question.isEmpty {
            return question
        }

        let preview = conversationText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !preview.isEmpty else {
            return predictedMessage
        }

        return String(preview.prefix(80))
    }

    init(
        id: UUID,
        mode: SimulationMode,
        category: FutureQuestionCategory? = nil,
        question: String,
        conversationText: String?,
        userSunSign: ZodiacSign? = nil,
        userMoonSign: ZodiacSign? = nil,
        userRisingSign: ZodiacSign? = nil,
        targetSunSign: ZodiacSign?,
        targetMoonSign: ZodiacSign?,
        targetRisingSign: ZodiacSign?,
        predictedMessage: String,
        directAnswer: String? = nil,
        timingWindow: String? = nil,
        astrologicalBreakdown: String,
        practicalNextMove: String? = nil,
        safetyNote: String? = nil,
        confidence: Int,
        tone: SimulationTone?,
        privacySummary: String?,
        createdAt: Date,
        isLocalComposition: Bool? = nil,
        outcome: PredictionOutcome? = nil
    ) {
        self.id = id
        self.mode = mode
        self.category = category
        self.question = question
        self.conversationText = conversationText
        self.userSunSign = userSunSign
        self.userMoonSign = userMoonSign
        self.userRisingSign = userRisingSign
        self.targetSunSign = targetSunSign
        self.targetMoonSign = targetMoonSign
        self.targetRisingSign = targetRisingSign
        self.predictedMessage = predictedMessage
        self.directAnswer = directAnswer
        self.timingWindow = timingWindow
        self.astrologicalBreakdown = astrologicalBreakdown
        self.practicalNextMove = practicalNextMove
        self.safetyNote = safetyNote
        self.confidence = confidence
        self.tone = tone
        self.privacySummary = privacySummary
        self.createdAt = createdAt
        self.isLocalComposition = isLocalComposition
        self.outcome = outcome
    }
}

nonisolated struct PredictionDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    let category: FutureQuestionCategory
    let targetName: String?
    let targetSunSign: ZodiacSign?
    let targetMoonSign: ZodiacSign?
    let targetRisingSign: ZodiacSign?
    let question: String?
    let conversationText: String?

    init(
        id: UUID = UUID(),
        category: FutureQuestionCategory = .messageOutcome,
        targetName: String? = nil,
        targetSunSign: ZodiacSign?,
        targetMoonSign: ZodiacSign? = nil,
        targetRisingSign: ZodiacSign? = nil,
        question: String? = nil,
        conversationText: String? = nil
    ) {
        self.id = id
        self.category = category
        self.targetName = targetName
        self.targetSunSign = targetSunSign
        self.targetMoonSign = targetMoonSign
        self.targetRisingSign = targetRisingSign
        self.question = question
        self.conversationText = conversationText
    }
}
