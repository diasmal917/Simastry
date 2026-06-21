import Foundation

nonisolated enum DailyDecisionCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case wear
    case eat
    case focus
    case social
    case textVibe = "text_vibe"
    case dateVibe = "date_vibe"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wear: "Wear"
        case .eat: "Eat"
        case .focus: "Focus"
        case .social: "Social"
        case .textVibe: "Text vibe"
        case .dateVibe: "Date vibe"
        }
    }

    var question: String {
        switch self {
        case .wear: "What should I wear today?"
        case .eat: "What should I eat today?"
        case .focus: "What should I focus on today?"
        case .social: "What social move should I make today?"
        case .textVibe: "What should my texting vibe be today?"
        case .dateVibe: "What should my date vibe be today?"
        }
    }

    var systemImage: String {
        switch self {
        case .wear: "tshirt.fill"
        case .eat: "fork.knife"
        case .focus: "scope"
        case .social: "person.2.fill"
        case .textVibe: "bubble.left.and.bubble.right.fill"
        case .dateVibe: "heart.fill"
        }
    }
}

nonisolated struct DailyDecisionContext: Equatable, Sendable {
    let userSunSign: ZodiacSign?
    let userMoonSign: ZodiacSign?
    let userRisingSign: ZodiacSign?
    let communicationTypeTitle: String?
    let transitHeadline: String?
    let transitGuidance: String?

    init(
        userSunSign: ZodiacSign?,
        userMoonSign: ZodiacSign?,
        userRisingSign: ZodiacSign?,
        communicationTypeTitle: String? = nil,
        transitHeadline: String? = nil,
        transitGuidance: String? = nil
    ) {
        self.userSunSign = userSunSign
        self.userMoonSign = userMoonSign
        self.userRisingSign = userRisingSign
        self.communicationTypeTitle = communicationTypeTitle
        self.transitHeadline = transitHeadline
        self.transitGuidance = transitGuidance
    }
}

nonisolated struct DailyDecision: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let category: DailyDecisionCategory
    let pick: String
    let whyToday: String
    let tinyNextMove: String
    let safetyNote: String?
    let createdAt: Date
    let isFallback: Bool

    init(
        id: UUID = UUID(),
        category: DailyDecisionCategory,
        pick: String,
        whyToday: String,
        tinyNextMove: String,
        safetyNote: String? = nil,
        createdAt: Date = Date(),
        isFallback: Bool = false
    ) {
        self.id = id
        self.category = category
        self.pick = pick
        self.whyToday = whyToday
        self.tinyNextMove = tinyNextMove
        self.safetyNote = safetyNote
        self.createdAt = createdAt
        self.isFallback = isFallback
    }
}
