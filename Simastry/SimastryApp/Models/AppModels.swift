import Foundation

nonisolated enum AppTab: Int, CaseIterable, Identifiable, Sendable {
    case home = 0
    case companions = 1
    case predict = 2
    case guides = 3
    case aboutMe = 4
    case messages = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .companions: "Companions"
        case .predict: "Predict"
        case .guides: "Guides"
        case .messages: "Messages"
        case .aboutMe: "About Me"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .companions: "circle.hexagongrid.fill"
        case .predict: "wand.and.stars"
        case .guides: "bubble.left.and.bubble.right.fill"
        case .messages: "message.fill"
        case .aboutMe: "person.crop.circle.fill"
        }
    }
}

nonisolated enum CompanionMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case simulateAnyone = "simulate_anyone"
    case soulmate
    case bestie

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simulateAnyone: "Simulate Anyone"
        case .soulmate: "Soulmate"
        case .bestie: "Bestie"
        }
    }

    var subtitle: String {
        switch self {
        case .simulateAnyone: "Practice a real conversation"
        case .soulmate: "The Perfect Love"
        case .bestie: "The Perfect Friend"
        }
    }
}

nonisolated enum AppearanceStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case ethereal, warm, bold, serene, mysterious, playful

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var primaryColor: (r: Double, g: Double, b: Double) {
        switch self {
        case .ethereal: (184/255, 169/255, 232/255)
        case .warm: (212/255, 149/255, 107/255)
        case .bold: (196/255, 64/255, 64/255)
        case .serene: (124/255, 174/255, 122/255)
        case .mysterious: (74/255, 80/255, 128/255)
        case .playful: (232/255, 112/255, 96/255)
        }
    }

    var secondaryColor: (r: Double, g: Double, b: Double) {
        switch self {
        case .ethereal: (232/255, 223/255, 240/255)
        case .warm: (232/255, 160/255, 176/255)
        case .bold: (212/255, 175/255, 55/255)
        case .serene: (109/255, 191/255, 184/255)
        case .mysterious: (168/255, 176/255, 200/255)
        case .playful: (96/255, 184/255, 232/255)
        }
    }
}

nonisolated enum CelestialRole: String, Codable, Sendable, CaseIterable {
    case sun, moon, rising

    var displayName: String {
        switch self {
        case .sun: "Sun"
        case .moon: "Moon"
        case .rising: "Rising"
        }
    }

    var subtitle: String {
        switch self {
        case .sun: "Your core personality"
        case .moon: "Your emotional world"
        case .rising: "How the world sees you"
        }
    }

    var iconName: String {
        switch self {
        case .sun: "sun.max.fill"
        case .moon: "moon.stars.fill"
        case .rising: "sparkles"
        }
    }

    var accentRed: Double {
        switch self {
        case .sun: 232/255
        case .moon: 74/255
        case .rising: 192/255
        }
    }

    var accentGreen: Double {
        switch self {
        case .sun: 132/255
        case .moon: 144/255
        case .rising: 132/255
        }
    }

    var accentBlue: Double {
        switch self {
        case .sun: 90/255
        case .moon: 217/255
        case .rising: 216/255
        }
    }
}

nonisolated struct UserProfile: Codable, Sendable {
    var id: UUID
    var displayName: String?
    var sunSign: String?
    var moonSign: String?
    var risingSign: String?
    var theme: String
    var tier: String
    var dailyMessagesUsed: Int
    var dailyMessagesResetDate: Date?
    var weeklyPredictionsUsed: Int
    var weeklyPredictionsResetDate: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case sunSign = "sun_sign"
        case moonSign = "moon_sign"
        case risingSign = "rising_sign"
        case theme, tier
        case dailyMessagesUsed = "daily_messages_used"
        case dailyMessagesResetDate = "daily_messages_reset_date"
        case weeklyPredictionsUsed = "weekly_predictions_used"
        case weeklyPredictionsResetDate = "weekly_predictions_reset_date"
        case createdAt = "created_at"
    }

    static func createDefault(id: UUID) -> UserProfile {
        UserProfile(
            id: id, displayName: nil,
            sunSign: nil, moonSign: nil, risingSign: nil,
            theme: "dark", tier: "free",
            dailyMessagesUsed: 0, dailyMessagesResetDate: nil,
            weeklyPredictionsUsed: 0, weeklyPredictionsResetDate: nil,
            createdAt: Date()
        )
    }
}

nonisolated struct CompanionData: Codable, Identifiable, Sendable {
    var id: UUID
    var userId: UUID
    var name: String
    var mode: String
    var sunSign: String
    var moonSign: String
    var risingSign: String
    var appearanceStyle: String?
    var conversationCount: Int
    var firstConversationAt: Date?
    var compatibilityScore: Int
    var companionMemory: String?
    var relationshipLevel: Int
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, mode
        case sunSign = "sun_sign"
        case moonSign = "moon_sign"
        case risingSign = "rising_sign"
        case appearanceStyle = "appearance_style"
        case conversationCount = "conversation_count"
        case firstConversationAt = "first_conversation_at"
        case compatibilityScore = "compatibility_score"
        case companionMemory = "companion_memory"
        case relationshipLevel = "relationship_level"
        case createdAt = "created_at"
    }
}

nonisolated struct MessageData: Codable, Identifiable, Sendable {
    var id: UUID
    var companionId: UUID
    var role: String
    var content: String
    var moodContext: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case companionId = "companion_id"
        case role, content
        case moodContext = "mood_context"
        case createdAt = "created_at"
    }
}

nonisolated enum AppScreen: Sendable {
    case landing
    case birthDetails
    case signUp
    case signIn
    case loading
    case home
}

nonisolated enum HomeSetupPhase: Sendable {
    case modeSelection
    case signSelection
    case companionSetup
    case soulCreation
    case complete
}

nonisolated enum RelationshipLevel: Int, Sendable {
    case stranger = 1
    case acquaintance = 2
    case familiar = 3
    case close = 4
    case bonded = 5
    case soulbound = 6

    var name: String {
        switch self {
        case .stranger: "Stranger"
        case .acquaintance: "Acquaintance"
        case .familiar: "Familiar"
        case .close: "Close"
        case .bonded: "Bonded"
        case .soulbound: "Soulbound"
        }
    }

    var threshold: Int {
        switch self {
        case .stranger: 0
        case .acquaintance: 15
        case .familiar: 50
        case .close: 150
        case .bonded: 400
        case .soulbound: 800
        }
    }

    var nextThreshold: Int? {
        switch self {
        case .stranger: 15
        case .acquaintance: 50
        case .familiar: 150
        case .close: 400
        case .bonded: 800
        case .soulbound: nil
        }
    }

    static func from(messageCount: Int) -> RelationshipLevel {
        if messageCount >= 800 { return .soulbound }
        if messageCount >= 400 { return .bonded }
        if messageCount >= 150 { return .close }
        if messageCount >= 50 { return .familiar }
        if messageCount >= 15 { return .acquaintance }
        return .stranger
    }
}

nonisolated enum ShareableCardType: String, Sendable {
    case cosmicDNA = "cosmic_dna"
    case compatibility
    case reading
}
