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
    case ageGate
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

nonisolated enum DiscoveryReportReason: String, CaseIterable, Identifiable, Codable, Sendable {
    case spam
    case harassment
    case impersonation = "impersonation"
    case inappropriateContent = "inappropriate_content"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam: "Spam"
        case .harassment: "Harassment"
        case .impersonation: "Impersonation"
        case .inappropriateContent: "Inappropriate Content"
        }
    }
}

// MARK: - Referral Info

nonisolated struct ReferralInfo: Codable, Equatable, Sendable {
    var referralCode: String?
    var referredBy: String? // astrologer name or code
    var referralDate: Date?
}

// MARK: - Deep Linking

nonisolated enum DeepLink: Equatable, Sendable {
    case compatibility(userSign: String, companionSign: String)
    case guide(sign: String)
    case home

    /// Attempts to parse a `DeepLink` from either a custom-scheme URL
    /// (`simastry://compatibility/aries/leo`) or a universal link
    /// (`https://simastry.com/share/compatibility/aries/leo`).
    static func from(url: URL) -> DeepLink? {
        let pathComponents: [String]

        if url.scheme == "simastry" {
            // simastry://compatibility/aries/leo  ->  host = "compatibility", path = "/aries/leo"
            guard let host = url.host else { return nil }
            let trailing = url.pathComponents.filter { $0 != "/" }
            pathComponents = [host] + trailing
        } else if let host = url.host,
                  [
                    AppConfig.universalLinkHost,
                    "www.\(AppConfig.universalLinkHost)",
                    "simastry.app",
                    "www.simastry.app"
                  ].contains(host) {
            // https://simastry.com/share/compatibility/aries/leo
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
            return URL(string: "https://\(AppConfig.universalLinkHost)/share/compatibility/\(userSign)/\(companionSign)")!
        case .guide(let sign):
            return URL(string: "https://\(AppConfig.universalLinkHost)/share/guide/\(sign)")!
        case .home:
            return AppConfig.websiteURL
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

// MARK: - Companion Messages (Inbox)

nonisolated enum InboxMessageSource: String, Codable, Equatable, Sendable {
    case companion
    case discovery
}

nonisolated enum InboxMessageDirection: String, Codable, Equatable, Sendable {
    case incoming
    case outgoing
}

nonisolated struct CompanionMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let companionId: UUID
    let companionName: String
    let companionSign: String
    let content: String
    let timestamp: Date
    var isRead: Bool
    var source: InboxMessageSource
    var direction: InboxMessageDirection

    enum CodingKeys: String, CodingKey {
        case id, companionId, companionName, companionSign, content, timestamp, isRead, source, direction
    }

    init(
        id: UUID = UUID(),
        companionId: UUID,
        companionName: String,
        companionSign: String,
        content: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        source: InboxMessageSource = .companion,
        direction: InboxMessageDirection = .incoming
    ) {
        self.id = id
        self.companionId = companionId
        self.companionName = companionName
        self.companionSign = companionSign
        self.content = content
        self.timestamp = timestamp
        self.isRead = isRead
        self.source = source
        self.direction = direction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companionId = try container.decode(UUID.self, forKey: .companionId)
        companionName = try container.decode(String.self, forKey: .companionName)
        companionSign = try container.decode(String.self, forKey: .companionSign)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        source = try container.decodeIfPresent(InboxMessageSource.self, forKey: .source) ?? .companion
        direction = try container.decodeIfPresent(InboxMessageDirection.self, forKey: .direction) ?? .incoming
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(companionId, forKey: .companionId)
        try container.encode(companionName, forKey: .companionName)
        try container.encode(companionSign, forKey: .companionSign)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(source, forKey: .source)
        try container.encode(direction, forKey: .direction)
    }
}

// MARK: - Social Links

nonisolated struct SocialLinks: Codable, Equatable, Sendable {
    var instagram: String?  // just the username, not full URL
    var tiktok: String?
    var twitter: String?

    var isEmpty: Bool {
        (instagram ?? "").isEmpty && (tiktok ?? "").isEmpty && (twitter ?? "").isEmpty
    }
}

// MARK: - Social Discovery Profile

nonisolated struct SocialProfile: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var displayName: String
    var sunSign: String
    var moonSign: String?
    var risingSign: String?
    var bio: String?
    var socialLinks: SocialLinks?
    var isVisible: Bool // opt-in to discovery
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case sunSign = "sun_sign"
        case moonSign = "moon_sign"
        case risingSign = "rising_sign"
        case bio
        case socialLinks = "social_links"
        case isVisible = "is_visible"
        case createdAt = "created_at"
    }

    // Computed
    var signSummary: String {
        var parts = ["\u{2600}\u{FE0F} \(sunSign.capitalized)"]
        if let moon = moonSign { parts.append("\u{1F319} \(moon.capitalized)") }
        if let rising = risingSign { parts.append("\u{2B06}\u{FE0F} \(rising.capitalized)") }
        return parts.joined(separator: " \u{00B7} ")
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        sunSign: String,
        moonSign: String? = nil,
        risingSign: String? = nil,
        bio: String? = nil,
        socialLinks: SocialLinks? = nil,
        isVisible: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.sunSign = sunSign
        self.moonSign = moonSign
        self.risingSign = risingSign
        self.bio = bio
        self.socialLinks = socialLinks
        self.isVisible = isVisible
        self.createdAt = createdAt
    }
}

nonisolated struct DiscoveryMessageData: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var senderId: UUID
    var recipientId: UUID
    var senderDisplayName: String
    var senderSunSign: String
    var senderMoonSign: String?
    var senderRisingSign: String?
    var recipientDisplayName: String
    var recipientSunSign: String
    var recipientMoonSign: String?
    var recipientRisingSign: String?
    var content: String
    var isRead: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case senderDisplayName = "sender_display_name"
        case senderSunSign = "sender_sun_sign"
        case senderMoonSign = "sender_moon_sign"
        case senderRisingSign = "sender_rising_sign"
        case recipientDisplayName = "recipient_display_name"
        case recipientSunSign = "recipient_sun_sign"
        case recipientMoonSign = "recipient_moon_sign"
        case recipientRisingSign = "recipient_rising_sign"
        case content
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    func inboxMessage(for viewerId: UUID) -> CompanionMessage {
        let outgoing = senderId == viewerId
        let counterpartId = outgoing ? recipientId : senderId
        let counterpartName = outgoing ? recipientDisplayName : senderDisplayName
        let counterpartSunSign = outgoing ? recipientSunSign : senderSunSign

        return CompanionMessage(
            id: id,
            companionId: counterpartId,
            companionName: counterpartName,
            companionSign: ZodiacSign(rawValue: counterpartSunSign)?.displayName ?? counterpartSunSign.capitalized,
            content: content,
            timestamp: createdAt ?? Date(),
            isRead: outgoing ? true : isRead,
            source: .discovery,
            direction: outgoing ? .outgoing : .incoming
        )
    }
}

nonisolated struct DiscoveryBlockData: Codable, Equatable, Sendable {
    var blockerId: UUID
    var blockedId: UUID
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
        case createdAt = "created_at"
    }
}

nonisolated struct DiscoveryReportData: Codable, Equatable, Sendable {
    var id: UUID
    var reporterId: UUID
    var reportedId: UUID
    var reason: String
    var details: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case reporterId = "reporter_id"
        case reportedId = "reported_id"
        case reason
        case details
        case createdAt = "created_at"
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
