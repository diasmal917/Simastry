import Foundation

nonisolated enum SimulationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case whatWillTheySay = "what_will_they_say"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whatWillTheySay:
            "What Will They Say?"
        }
    }

    var systemImage: String {
        switch self {
        case .whatWillTheySay:
            "message.circle.fill"
        }
    }

    var actionTitle: String {
        switch self {
        case .whatWillTheySay:
            "Predict Their Response"
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
    let conversationText: String
    let targetSunSign: ZodiacSign
    let targetMoonSign: ZodiacSign?
    let targetRisingSign: ZodiacSign?
    let question: String?
    let hypotheticalReply: String?

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

nonisolated enum PredictionOutcome: String, Codable, Sendable {
    case landed
    case missed

    var title: String {
        switch self {
        case .landed: "Landed"
        case .missed: "Off"
        }
    }

    var systemImage: String {
        switch self {
        case .landed: "hand.thumbsup.fill"
        case .missed: "hand.thumbsdown"
        }
    }
}

nonisolated struct PredictionResult: Codable, Identifiable, Sendable {
    let id: UUID
    let mode: SimulationMode
    let question: String
    let conversationText: String?
    let targetSunSign: ZodiacSign?
    let targetMoonSign: ZodiacSign?
    let targetRisingSign: ZodiacSign?
    let predictedMessage: String
    let astrologicalBreakdown: String
    let confidence: Int
    let tone: SimulationTone?
    let privacySummary: String?
    let createdAt: Date
    /// True when composed on-device from placement logic (no remote AI involved).
    /// Optional so previously saved history still decodes.
    var isLocalComposition: Bool?
    /// User-reported accuracy ("Did this land?"). Optional so old history decodes.
    var outcome: PredictionOutcome?

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
}

nonisolated struct PredictionDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    let targetName: String?
    let targetSunSign: ZodiacSign
    let targetMoonSign: ZodiacSign?
    let targetRisingSign: ZodiacSign?
    let question: String?
    let conversationText: String?

    init(
        id: UUID = UUID(),
        targetName: String? = nil,
        targetSunSign: ZodiacSign,
        targetMoonSign: ZodiacSign? = nil,
        targetRisingSign: ZodiacSign? = nil,
        question: String? = nil,
        conversationText: String? = nil
    ) {
        self.id = id
        self.targetName = targetName
        self.targetSunSign = targetSunSign
        self.targetMoonSign = targetMoonSign
        self.targetRisingSign = targetRisingSign
        self.question = question
        self.conversationText = conversationText
    }
}
