import Foundation
import SwiftUI

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
    case onboardingInsight
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
    case conversationGuide = "conversation_guide"
}

// MARK: - Deep Linking

nonisolated enum DeepLink: Equatable, Sendable {
    case compatibility(userSign: String, companionSign: String)
    case guide(sign: String)
    case home

    /// Attempts to parse a `DeepLink` from either a custom-scheme URL
    /// (`simastry://compatibility/aries/leo`) or a universal link
    /// (`https://simastry.app/share/compatibility/aries/leo`).
    static func from(url: URL) -> DeepLink? {
        let pathComponents: [String]

        if url.scheme == "simastry" {
            // simastry://compatibility/aries/leo  ->  host = "compatibility", path = "/aries/leo"
            guard let host = url.host else { return nil }
            let trailing = url.pathComponents.filter { $0 != "/" }
            pathComponents = [host] + trailing
        } else if url.host == "simastry.app" || url.host == "www.simastry.app" {
            // https://simastry.app/share/compatibility/aries/leo
            var raw = url.pathComponents.filter { $0 != "/" }
            // Strip the leading "share" segment used in universal links
            if raw.first == "share" { raw.removeFirst() }
            pathComponents = raw
        } else {
            return nil
        }

        guard let action = pathComponents.first else { return nil }

        switch action {
        case "compatibility":
            guard pathComponents.count >= 3 else { return nil }
            let userSign = pathComponents[1].lowercased()
            let companionSign = pathComponents[2].lowercased()
            guard ZodiacSign(rawValue: userSign) != nil,
                  ZodiacSign(rawValue: companionSign) != nil else { return nil }
            return .compatibility(userSign: userSign, companionSign: companionSign)

        case "guide":
            guard pathComponents.count >= 2 else { return nil }
            let sign = pathComponents[1].lowercased()
            guard ZodiacSign(rawValue: sign) != nil else { return nil }
            return .guide(sign: sign)

        default:
            return nil
        }
    }

    /// Builds the custom-scheme URL for this deep link.
    var customSchemeURL: URL {
        switch self {
        case .compatibility(let userSign, let companionSign):
            return URL(string: "simastry://compatibility/\(userSign)/\(companionSign)")!
        case .guide(let sign):
            return URL(string: "simastry://guide/\(sign)")!
        case .home:
            return URL(string: "simastry://home")!
        }
    }

    /// Builds the universal-link URL for this deep link (for sharing).
    var universalLinkURL: URL {
        switch self {
        case .compatibility(let userSign, let companionSign):
            return URL(string: "https://simastry.app/share/compatibility/\(userSign)/\(companionSign)")!
        case .guide(let sign):
            return URL(string: "https://simastry.app/share/guide/\(sign)")!
        case .home:
            return URL(string: "https://simastry.app")!
        }
    }

    /// Human-readable share text that accompanies the link.
    var shareText: String {
        switch self {
        case .compatibility(let userSign, let companionSign):
            let u = userSign.capitalized
            let c = companionSign.capitalized
            return "See the full \(u) & \(c) cosmic compatibility reading on Simastry \u{2728}"
        case .guide(let sign):
            return "Discover how to talk to a \(sign.capitalized) \u{2014} full communication guide on Simastry \u{2728}"
        case .home:
            return "Explore your cosmic connections on Simastry \u{2728}"
        }
    }
}

// MARK: - Saved Communication Guides

nonisolated struct SavedGuide: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var sunSign: ZodiacSign
    var category: GuideCategory
    var createdAt: Date
    var notes: String?

    init(id: UUID = UUID(), name: String, sunSign: ZodiacSign, category: GuideCategory, createdAt: Date = Date(), notes: String? = nil) {
        self.id = id
        self.name = name
        self.sunSign = sunSign
        self.category = category
        self.createdAt = createdAt
        self.notes = notes
    }
}

nonisolated enum GuideCategory: String, Codable, CaseIterable, Sendable {
    case family = "Family"
    case work = "Work"
    case friends = "Friends"
    case romantic = "Romantic"
    case other = "Other"

    var icon: String {
        switch self {
        case .family: return "house.fill"
        case .work: return "briefcase.fill"
        case .friends: return "person.2.fill"
        case .romantic: return "heart.fill"
        case .other: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .family: return Color(red: 194/255, green: 224/255, blue: 168/255)
        case .work: return Color(red: 74/255, green: 144/255, blue: 217/255)
        case .friends: return Color(red: 192/255, green: 132/255, blue: 216/255)
        case .romantic: return Color(red: 232/255, green: 132/255, blue: 90/255)
        case .other: return Color(red: 212/255, green: 175/255, blue: 55/255)
        }
    }
}
