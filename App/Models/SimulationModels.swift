import Foundation

/// The shape of help requested in Compass. Raw values are persisted in drafts,
/// so additions must be backward compatible.
nonisolated enum CompassIntent: String, Codable, CaseIterable, Identifiable, Sendable {
    case general
    case conversation
    case compareOptions = "compare_options"
    case timing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Ask"
        case .conversation: "Conversation"
        case .compareOptions: "Compare options"
        case .timing: "Timing"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Get a clear next step"
        case .conversation: "Understand a thread"
        case .compareOptions: "Weigh two or three paths"
        case .timing: "Use calculated sky context"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "questionmark.bubble"
        case .conversation: "text.bubble"
        case .compareOptions: "arrow.triangle.branch"
        case .timing: "clock"
        }
    }
}

nonisolated enum CompassTopic: String, Codable, CaseIterable, Identifiable, Sendable {
    case relationships, work, money, family, personal

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .relationships: "heart"
        case .work: "briefcase"
        case .money: "banknote"
        case .family: "house"
        case .personal: "person"
        }
    }
}

/// A value draft makes navigation/deep-link handoff explicit without requiring
/// birth data. Legacy `PredictionDraft` remains supported below.
nonisolated struct CompassDraft: Codable, Equatable, Sendable {
    var intent: CompassIntent
    var question: String
    var topic: CompassTopic?
    var conversationText: String
    var options: [String]
    var additionalContext: String

    init(
        intent: CompassIntent = .general,
        question: String = "",
        topic: CompassTopic? = nil,
        conversationText: String = "",
        options: [String] = ["", ""],
        additionalContext: String = ""
    ) {
        self.intent = intent
        self.question = question
        self.topic = topic
        self.conversationText = conversationText
        self.options = Array(options.prefix(3))
        self.additionalContext = additionalContext
    }
}

nonisolated enum ReadingEvidenceBasis: String, Codable, CaseIterable, Sendable {
    case calculated
    case userConfirmed = "user_confirmed"
    case generalLens = "general_lens"

    var title: String {
        switch self {
        case .calculated: "Calculated"
        case .userConfirmed: "User-confirmed"
        case .generalLens: "General lens"
        }
    }
}

/// A fact the reading is allowed to rely on. `supportsTiming` is deliberately
/// explicit so a sign or freeform statement cannot silently become a forecast.
nonisolated struct ReadingEvidence: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let basis: ReadingEvidenceBasis
    let label: String
    let detail: String
    let supportsTiming: Bool

    init(
        id: UUID = UUID(),
        basis: ReadingEvidenceBasis,
        label: String,
        detail: String,
        supportsTiming: Bool = false
    ) {
        self.id = id
        self.basis = basis
        self.label = label
        self.detail = detail
        self.supportsTiming = supportsTiming
    }
}

nonisolated enum ContextQuality: String, Codable, CaseIterable, Sendable {
    case questionOnly = "question_only"
    case someContext = "some_context"
    case detailed

    var title: String {
        switch self {
        case .questionOnly: "Question only"
        case .someContext: "Some context"
        case .detailed: "Detailed context"
        }
    }
}

nonisolated enum ReadingHelpfulness: String, Codable, CaseIterable, Sendable {
    case helpful
    case notHelpful = "not_helpful"

    var title: String {
        switch self {
        case .helpful: "Helpful"
        case .notHelpful: "Not helpful"
        }
    }
}

nonisolated enum ReplyToneSimilarity: String, Codable, CaseIterable, Sendable {
    case similar, different, unsure

    var title: String { rawValue.capitalized }
}

/// Objective outcome data is intentionally separate from a user's opinion of
/// whether the guidance was useful.
nonisolated struct ReadingFollowUp: Codable, Equatable, Sendable {
    var replyReceived: Bool?
    var elapsedMinutes: Int?
    var toneSimilarity: ReplyToneSimilarity?
}

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
    case privateQuestion = "private_question"
    case messageOutcome = "message_outcome"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loveTiming: "Love timing"
        case .commitment: "Commitment"
        case .familyPath: "Family path"
        case .careerSuccess: "Career success"
        case .moneyDirection: "Money direction"
        case .privateQuestion: "Private question"
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
        case .privateQuestion: "Private"
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
        case .privateQuestion: "Sensitive questions, next moves, and what you are not saying out loud."
        case .messageOutcome: "Texts, replies, interest, and timing."
        }
    }

    var defaultQuestion: String {
        switch self {
        case .loveTiming: "Will I meet someone?"
        case .commitment: "Is this serious?"
        case .familyPath: "Where's home headed?"
        case .careerSuccess: "Where should I focus?"
        case .moneyDirection: "What should I watch for?"
        case .privateQuestion: "What's on my mind?"
        case .messageOutcome: "Will they text back?"
        }
    }

    var suggestedQuestions: [String] {
        switch self {
        case .loveTiming:
            ["When will I meet someone?", "Is love opening soon?", "What kind of person is next?", "Should I put myself out there?"]
        case .commitment:
            ["What pattern is opening around commitment?", "Is this relationship serious?", "Are they long-term?", "What is blocking commitment?"]
        case .familyPath:
            ["What should I understand about family timing?", "What family chapter is ahead?", "Am I building a home soon?", "What should I prepare for?"]
        case .careerSuccess:
            ["What career signal should I watch next?", "What career window is opening?", "Should I take the risk?", "Where should I focus?"]
        case .moneyDirection:
            ["What money pattern should I pay attention to?", "How does money grow for me?", "What is my prosperity pattern?", "What should I stop leaking energy on?"]
        case .privateQuestion:
            ["What happens next?", "Should I say it?", "What am I not seeing?", "What should I do next?"]
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
        case .privateQuestion: "lock.circle.fill"
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
        case .loveTiming, .commitment, .familyPath, .privateQuestion, .messageOutcome:
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
    let idempotencyKey: UUID
    let mode: SimulationMode
    let category: FutureQuestionCategory
    let intent: CompassIntent
    let topic: CompassTopic?
    let conversationText: String
    let comparisonOptions: [String]
    let additionalContext: String
    let evidence: [ReadingEvidence]
    let userSunSign: ZodiacSign?
    let userMoonSign: ZodiacSign?
    let userRisingSign: ZodiacSign?
    let targetSunSign: ZodiacSign?
    let targetMoonSign: ZodiacSign?
    let targetRisingSign: ZodiacSign?
    let question: String?
    let hypotheticalReply: String?
    let auraSnapshot: AuraSnapshotDescriptor?

    init(
        idempotencyKey: UUID = UUID(),
        mode: SimulationMode,
        category: FutureQuestionCategory = .messageOutcome,
        intent: CompassIntent = .general,
        topic: CompassTopic? = nil,
        conversationText: String,
        comparisonOptions: [String] = [],
        additionalContext: String = "",
        evidence: [ReadingEvidence] = [],
        userSunSign: ZodiacSign? = nil,
        userMoonSign: ZodiacSign? = nil,
        userRisingSign: ZodiacSign? = nil,
        targetSunSign: ZodiacSign?,
        targetMoonSign: ZodiacSign?,
        targetRisingSign: ZodiacSign?,
        question: String?,
        hypotheticalReply: String?,
        auraSnapshot: AuraSnapshotDescriptor? = nil
    ) {
        self.idempotencyKey = idempotencyKey
        self.mode = mode
        self.category = category
        self.intent = intent
        self.topic = topic
        self.conversationText = conversationText
        self.comparisonOptions = Array(comparisonOptions.prefix(3))
        self.additionalContext = additionalContext
        self.evidence = evidence
        self.userSunSign = userSunSign
        self.userMoonSign = userMoonSign
        self.userRisingSign = userRisingSign
        self.targetSunSign = targetSunSign
        self.targetMoonSign = targetMoonSign
        self.targetRisingSign = targetRisingSign
        self.question = question
        self.hypotheticalReply = hypotheticalReply
        self.auraSnapshot = auraSnapshot
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

    var hasTimingEvidence: Bool {
        evidence.contains { $0.basis == .calculated && $0.supportsTiming }
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

nonisolated enum PredictionConfidenceTier: String, Codable, CaseIterable, Sendable {
    case soft
    case moderate
    case strong

    var title: String {
        switch self {
        case .soft: "Soft"
        case .moderate: "Moderate"
        case .strong: "Strong"
        }
    }

    static func tier(for confidence: Int) -> PredictionConfidenceTier {
        switch confidence {
        case ..<60:
            return .soft
        case 60..<76:
            return .moderate
        default:
            return .strong
        }
    }
}

nonisolated struct PredictionResult: Codable, Identifiable, Sendable {
    let id: UUID
    let mode: SimulationMode
    var category: FutureQuestionCategory?
    var compassIntent: CompassIntent?
    var compassTopic: CompassTopic?
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
    /// A credible second interpretation, surfaced directly after the next move.
    var plausibleAlternative: String?
    /// A reply grounded in the supplied thread, when conversation context exists.
    var suggestedReply: String?
    /// Facts actually used by the reading. Nil keeps legacy history decodable.
    var evidence: [ReadingEvidence]?
    var contextQuality: ContextQuality?
    let confidence: Int
    let tone: SimulationTone?
    let privacySummary: String?
    let createdAt: Date
    /// True when composed on-device from placement logic (no remote AI involved).
    /// Optional so previously saved history still decodes.
    var isLocalComposition: Bool?
    /// User-reported accuracy ("Did this land?"). Optional so old history decodes.
    var outcome: PredictionOutcome?
    var followUp: ReadingFollowUp?
    var helpfulness: ReadingHelpfulness?

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

    var confidenceTier: PredictionConfidenceTier {
        PredictionConfidenceTier.tier(for: confidence)
    }

    var confidenceDisplayTier: String {
        confidenceTier.title
    }

    /// Safe, non-numeric confidence copy for the UI (e.g. "Signal strength: Moderate").
    /// Keeps the numeric `confidence` internal — we never surface a false-precision percentage.
    var confidenceSignalDisplay: String {
        "Signal strength: \(confidenceDisplayTier)"
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
        compassIntent: CompassIntent? = nil,
        compassTopic: CompassTopic? = nil,
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
        plausibleAlternative: String? = nil,
        suggestedReply: String? = nil,
        evidence: [ReadingEvidence]? = nil,
        contextQuality: ContextQuality? = nil,
        confidence: Int,
        tone: SimulationTone?,
        privacySummary: String?,
        createdAt: Date,
        isLocalComposition: Bool? = nil,
        outcome: PredictionOutcome? = nil,
        followUp: ReadingFollowUp? = nil,
        helpfulness: ReadingHelpfulness? = nil
    ) {
        self.id = id
        self.mode = mode
        self.category = category
        self.compassIntent = compassIntent
        self.compassTopic = compassTopic
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
        self.plausibleAlternative = plausibleAlternative
        self.suggestedReply = suggestedReply
        self.evidence = evidence
        self.contextQuality = contextQuality
        self.confidence = confidence
        self.tone = tone
        self.privacySummary = privacySummary
        self.createdAt = createdAt
        self.isLocalComposition = isLocalComposition
        self.outcome = outcome
        self.followUp = followUp
        self.helpfulness = helpfulness
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
