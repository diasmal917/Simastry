import Foundation

nonisolated struct AstrologySpecialist: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let characterName: String
    let publicTitle: String
    let displayName: String
    let emoji: String
    let publicDescription: String
    let shortDescription: String
    let longDescription: String
    let tradition: String
    let internalTradition: String
    let focusAreas: [String]
    let personalityTraits: [String]
    let symbol: String
    let placeholderAvatar: String
    let harnessFileName: String
    let legacyCharacterId: String
    let forbiddenConcepts: [String]
    let allowedTechniques: [String]
}

nonisolated enum ExpertAstrologerMode: String, Codable, Sendable {
    case individual
    case everyone
}

nonisolated enum SpecialistMessageRole: String, Codable, Sendable {
    case user
    case specialist
}

nonisolated struct SpecialistMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let conversationId: UUID
    let specialistId: String
    let role: SpecialistMessageRole
    var content: String
    let timestamp: Date
    let mode: ExpertAstrologerMode
    let multiConsultationId: UUID?
    let profileContextSummary: String?

    init(
        id: UUID = UUID(),
        conversationId: UUID,
        specialistId: String,
        role: SpecialistMessageRole,
        content: String,
        timestamp: Date = Date(),
        mode: ExpertAstrologerMode,
        multiConsultationId: UUID? = nil,
        profileContextSummary: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.specialistId = specialistId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.mode = mode
        self.multiConsultationId = multiConsultationId
        self.profileContextSummary = profileContextSummary
    }
}

nonisolated struct SpecialistConsultationResponse: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let multiConsultationId: UUID
    let specialistId: String
    let userQuestion: String
    var specialistResponse: String?
    var errorMessage: String?
    let timestamp: Date
    let mode: ExpertAstrologerMode
    let profileContextSummary: String?

    init(
        id: UUID = UUID(),
        multiConsultationId: UUID,
        specialistId: String,
        userQuestion: String,
        specialistResponse: String? = nil,
        errorMessage: String? = nil,
        timestamp: Date = Date(),
        mode: ExpertAstrologerMode = .everyone,
        profileContextSummary: String? = nil
    ) {
        self.id = id
        self.multiConsultationId = multiConsultationId
        self.specialistId = specialistId
        self.userQuestion = userQuestion
        self.specialistResponse = specialistResponse
        self.errorMessage = errorMessage
        self.timestamp = timestamp
        self.mode = mode
        self.profileContextSummary = profileContextSummary
    }
}

nonisolated struct ExpertAstrologerConversationRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var userId: UUID
    var specialistId: String
    var createdAt: Date
    var updatedAt: Date
    var lastMessageAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case specialistId = "specialist_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMessageAt = "last_message_at"
    }

    init(
        id: UUID,
        userId: UUID,
        specialistId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastMessageAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.specialistId = specialistId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessageAt = lastMessageAt
    }
}

nonisolated struct ExpertAstrologerMessageRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var conversationId: UUID
    var userId: UUID
    var specialistId: String
    var role: String
    var content: String
    var mode: String
    var multiConsultationId: UUID?
    var profileContextSummary: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case specialistId = "specialist_id"
        case role
        case content
        case mode
        case multiConsultationId = "multi_consultation_id"
        case profileContextSummary = "profile_context_summary"
        case createdAt = "created_at"
    }

    init(userId: UUID, message: SpecialistMessage) {
        self.id = message.id
        self.conversationId = message.conversationId
        self.userId = userId
        self.specialistId = message.specialistId
        self.role = message.role.rawValue
        self.content = message.content
        self.mode = message.mode.rawValue
        self.multiConsultationId = message.multiConsultationId
        self.profileContextSummary = message.profileContextSummary
        self.createdAt = message.timestamp
    }

    var localMessage: SpecialistMessage? {
        guard let role = SpecialistMessageRole(rawValue: role),
              let mode = ExpertAstrologerMode(rawValue: mode) else {
            return nil
        }
        return SpecialistMessage(
            id: id,
            conversationId: conversationId,
            specialistId: specialistId,
            role: role,
            content: content,
            timestamp: createdAt,
            mode: mode,
            multiConsultationId: multiConsultationId,
            profileContextSummary: profileContextSummary
        )
    }
}

nonisolated struct ExpertAstrologerConsultationRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var userId: UUID
    var mode: String
    var userQuestion: String
    var profileContextSummary: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mode
        case userQuestion = "user_question"
        case profileContextSummary = "profile_context_summary"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        userId: UUID,
        userQuestion: String,
        profileContextSummary: String?,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.mode = ExpertAstrologerMode.everyone.rawValue
        self.userQuestion = userQuestion
        self.profileContextSummary = profileContextSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

nonisolated struct ExpertAstrologerConsultationResponseRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var multiConsultationId: UUID
    var userId: UUID
    var specialistId: String
    var userQuestion: String
    var specialistResponse: String?
    var errorMessage: String?
    var mode: String
    var profileContextSummary: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case multiConsultationId = "multi_consultation_id"
        case userId = "user_id"
        case specialistId = "specialist_id"
        case userQuestion = "user_question"
        case specialistResponse = "specialist_response"
        case errorMessage = "error_message"
        case mode
        case profileContextSummary = "profile_context_summary"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(userId: UUID, response: SpecialistConsultationResponse) {
        self.id = response.id
        self.multiConsultationId = response.multiConsultationId
        self.userId = userId
        self.specialistId = response.specialistId
        self.userQuestion = response.userQuestion
        self.specialistResponse = response.specialistResponse
        self.errorMessage = response.errorMessage
        self.mode = response.mode.rawValue
        self.profileContextSummary = response.profileContextSummary
        self.createdAt = response.timestamp
        self.updatedAt = Date()
    }

    var localResponse: SpecialistConsultationResponse? {
        guard let mode = ExpertAstrologerMode(rawValue: mode) else {
            return nil
        }
        return SpecialistConsultationResponse(
            id: id,
            multiConsultationId: multiConsultationId,
            specialistId: specialistId,
            userQuestion: userQuestion,
            specialistResponse: specialistResponse,
            errorMessage: errorMessage,
            timestamp: createdAt,
            mode: mode,
            profileContextSummary: profileContextSummary
        )
    }
}

/// One row of `public.expert_astrology_intake`. Birth date/time are stored as
/// wall-clock strings (`yyyy-MM-dd` / `HH:mm:ss`) and the tradition data holds
/// only the whitelisted, user-supplied fields — never app-calculated values.
/// Encoding always emits every column so an upsert is a full snapshot (clearing
/// a field writes SQL null rather than silently preserving the old value).
nonisolated struct ExpertAstrologyIntakeRecord: Codable, Equatable, Sendable {
    var userId: UUID
    var birthDate: String?
    var birthTime: String?
    var birthTimeUnknown: Bool
    var birthPlace: String?
    var partnerBirthDate: String?
    var partnerBirthTime: String?
    var partnerBirthTimeUnknown: Bool
    var partnerBirthPlace: String?
    var userSuppliedTraditionData: [String: String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case birthDate = "birth_date"
        case birthTime = "birth_time"
        case birthTimeUnknown = "birth_time_unknown"
        case birthPlace = "birth_place"
        case partnerBirthDate = "partner_birth_date"
        case partnerBirthTime = "partner_birth_time"
        case partnerBirthTimeUnknown = "partner_birth_time_unknown"
        case partnerBirthPlace = "partner_birth_place"
        case userSuppliedTraditionData = "user_supplied_tradition_data"
    }

    init(
        userId: UUID,
        birthDate: String?,
        birthTime: String?,
        birthTimeUnknown: Bool,
        birthPlace: String?,
        partnerBirthDate: String?,
        partnerBirthTime: String?,
        partnerBirthTimeUnknown: Bool,
        partnerBirthPlace: String?,
        userSuppliedTraditionData: [String: String]
    ) {
        self.userId = userId
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.birthTimeUnknown = birthTimeUnknown
        self.birthPlace = birthPlace
        self.partnerBirthDate = partnerBirthDate
        self.partnerBirthTime = partnerBirthTime
        self.partnerBirthTimeUnknown = partnerBirthTimeUnknown
        self.partnerBirthPlace = partnerBirthPlace
        self.userSuppliedTraditionData = userSuppliedTraditionData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        birthDate = try container.decodeIfPresent(String.self, forKey: .birthDate)
        birthTime = try container.decodeIfPresent(String.self, forKey: .birthTime)
        birthTimeUnknown = try container.decodeIfPresent(Bool.self, forKey: .birthTimeUnknown) ?? false
        birthPlace = try container.decodeIfPresent(String.self, forKey: .birthPlace)
        partnerBirthDate = try container.decodeIfPresent(String.self, forKey: .partnerBirthDate)
        partnerBirthTime = try container.decodeIfPresent(String.self, forKey: .partnerBirthTime)
        partnerBirthTimeUnknown = try container.decodeIfPresent(Bool.self, forKey: .partnerBirthTimeUnknown) ?? false
        partnerBirthPlace = try container.decodeIfPresent(String.self, forKey: .partnerBirthPlace)
        userSuppliedTraditionData = try container.decodeIfPresent([String: String].self, forKey: .userSuppliedTraditionData) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(birthDate, forKey: .birthDate)
        try container.encode(birthTime, forKey: .birthTime)
        try container.encode(birthTimeUnknown, forKey: .birthTimeUnknown)
        try container.encode(birthPlace, forKey: .birthPlace)
        try container.encode(partnerBirthDate, forKey: .partnerBirthDate)
        try container.encode(partnerBirthTime, forKey: .partnerBirthTime)
        try container.encode(partnerBirthTimeUnknown, forKey: .partnerBirthTimeUnknown)
        try container.encode(partnerBirthPlace, forKey: .partnerBirthPlace)
        try container.encode(userSuppliedTraditionData, forKey: .userSuppliedTraditionData)
    }
}

nonisolated struct UserAstrologyContext: Codable, Equatable, Sendable {
    let userName: String?
    let sunSign: String?
    let moonSign: String?
    let risingSign: String?
    let birthDateAvailable: Bool
    let birthTimeAvailable: Bool
    let birthPlaceAvailable: Bool
    let partnerName: String?
    let partnerSunSign: String?
    let partnerMoonSign: String?
    let partnerRisingSign: String?
    let partnerBirthDateAvailable: Bool
    let partnerBirthTimeAvailable: Bool
    let partnerBirthPlaceAvailable: Bool

    var summary: String {
        var parts: [String] = []
        if let userName, !userName.isEmpty {
            parts.append("User: \(userName)")
        }
        let placements = [
            sunSign.map { "Sun \($0)" },
            moonSign.map { "Moon \($0)" },
            risingSign.map { "Rising \($0)" }
        ].compactMap { $0 }
        if !placements.isEmpty {
            parts.append("User placements: \(placements.joined(separator: ", "))")
        }
        if let partnerName, !partnerName.isEmpty {
            parts.append("Partner/person: \(partnerName)")
        }
        let partnerPlacements = [
            partnerSunSign.map { "Sun \($0)" },
            partnerMoonSign.map { "Moon \($0)" },
            partnerRisingSign.map { "Rising \($0)" }
        ].compactMap { $0 }
        if !partnerPlacements.isEmpty {
            parts.append("Partner/person placements: \(partnerPlacements.joined(separator: ", "))")
        }
        parts.append("Birth data: user date \(birthDateAvailable ? "available" : "missing"), time \(birthTimeAvailable ? "available" : "missing"), place \(birthPlaceAvailable ? "available" : "missing")")
        if partnerName != nil {
            parts.append("Partner birth data: date \(partnerBirthDateAvailable ? "available" : "missing"), time \(partnerBirthTimeAvailable ? "available" : "missing"), place \(partnerBirthPlaceAvailable ? "available" : "missing")")
        }
        parts.append("Unavailable unless explicitly listed above: calculated dasha sequences, nakshatras, BaZi pillars, Day Masters, Luck Pillars, sect, Lots, profections, Zodiacal Releasing periods, exact aspects, transits, composite charts, and detailed synastry.")
        return parts.joined(separator: "\n")
    }

    var analyticsParams: [String: String] {
        [
            "hasBirthData": birthDateAvailable && birthTimeAvailable && birthPlaceAvailable ? "true" : "false",
            "hasPartnerData": partnerBirthDateAvailable ? "true" : "false",
            "missingBirthData": missingBirthDataLabels.joined(separator: ",")
        ]
    }

    var missingBirthDataLabels: [String] {
        var labels: [String] = []
        if !birthDateAvailable { labels.append("user_date") }
        if !birthTimeAvailable { labels.append("user_time") }
        if !birthPlaceAvailable { labels.append("user_place") }
        if partnerName != nil {
            if !partnerBirthDateAvailable { labels.append("partner_date") }
            if !partnerBirthTimeAvailable { labels.append("partner_time") }
            if !partnerBirthPlaceAvailable { labels.append("partner_place") }
        }
        return labels.isEmpty ? ["none"] : labels
    }
}

nonisolated enum ExpertAstrologerRegistry {
    static let specialists: [AstrologySpecialist] = [
        .leylaWestern,
        .mateoVedic,
        .naomiChinese,
        .sorenAncient,
        .nadiaEvolutionary
    ]

    static var archivedProfiles: [FactoryCompanionProfile] {
        specialists.compactMap(\.archivedProfile)
    }

    static func specialist(id: String) -> AstrologySpecialist? {
        if let direct = specialists.first(where: { $0.id == id }) {
            return direct
        }
        let legacyAliases = [
            "western": "leyla-western",
            "vedic": "mateo-vedic",
            "chinese": "naomi-chinese",
            "ancient": "elias-ancient",
            "soren": "elias-ancient",
            "soren-ancient": "elias-ancient",
            "evolutionary": "nadia-evolutionary"
        ]
        guard let mappedId = legacyAliases[id] else { return nil }
        return specialists.first { $0.id == mappedId }
    }

    static func specialist(forLegacyCharacterId legacyCharacterId: String) -> AstrologySpecialist? {
        specialists.first { $0.legacyCharacterId == legacyCharacterId }
    }

    static func specialist(for profile: FactoryCompanionProfile) -> AstrologySpecialist? {
        specialist(forLegacyCharacterId: profile.id)
    }
}

extension AstrologySpecialist {
    var archivedProfile: FactoryCompanionProfile? {
        LegacyGuideRegistry.guide(id: legacyCharacterId)
    }

    var profileImageName: String? {
        archivedProfile?.profileImageName
    }

    var cardImageName: String? {
        archivedProfile?.cardImageName
    }
}

private extension AstrologySpecialist {
    static let leylaWestern = AstrologySpecialist(
        id: "leyla-western",
        characterName: "Leyla",
        publicTitle: "Western Astrologer",
        displayName: "Leyla - Western Astrologer",
        emoji: "🌞",
        publicDescription: "Relationships, identity, compatibility, and life direction.",
        shortDescription: "Love, identity, compatibility, and transits.",
        longDescription: "Leyla reads the modern birth chart through personality, love, timing, and compatibility. She is best for relationship questions, identity, emotional needs, attraction, and life direction.",
        tradition: "Western tropical astrology",
        internalTradition: "Western tropical astrology",
        focusAreas: ["Relationships", "Identity", "Compatibility", "Life direction", "Transits", "Natal chart patterns"],
        personalityTraits: ["Warm", "Emotionally intelligent", "Modern", "Relationship-aware"],
        symbol: "sun.max.fill",
        placeholderAvatar: "L",
        harnessFileName: "leyla-western",
        legacyCharacterId: "virgo-mara",
        forbiddenConcepts: ["Vedic sidereal zodiac", "Nakshatras", "Dashas", "BaZi", "Chinese zodiac animals", "Hellenistic Lots", "Annual Profections", "Zodiacal Releasing"],
        allowedTechniques: ["Tropical zodiac", "Natal chart", "Sun/Moon/Rising", "Planets", "Houses", "Aspects", "Transits", "Synastry"]
    )

    static let mateoVedic = AstrologySpecialist(
        id: "mateo-vedic",
        characterName: "Mateo",
        publicTitle: "Vedic Astrologer",
        displayName: "Mateo - Vedic Astrologer",
        emoji: "🌙",
        publicDescription: "Karma, timing, dharma, destiny, and spiritual patterns.",
        shortDescription: "Karma, timing, dharma, and spiritual patterns.",
        longDescription: "Mateo reads through the ancient Jyotish lens of karma, dharma, nakshatras, and planetary periods. He is best for spiritual lessons, destiny patterns, timing, and karmic relationships.",
        tradition: "Vedic astrology / Jyotish",
        internalTradition: "Jyotish / Vedic astrology",
        focusAreas: ["Karma", "Dharma", "Timing", "Destiny patterns", "Spiritual lessons", "Karmic relationships"],
        personalityTraits: ["Calm", "Wise", "Grounded", "Spiritually serious", "Direct"],
        symbol: "moon.stars.fill",
        placeholderAvatar: "M",
        harnessFileName: "mateo-vedic",
        legacyCharacterId: "libra-mateo",
        forbiddenConcepts: ["Western tropical zodiac as primary zodiac", "Western psychological framing", "Chinese zodiac", "BaZi", "Hellenistic Lots", "Annual Profections", "Evolutionary shadow-work language"],
        allowedTechniques: ["Sidereal zodiac", "Rāśis", "Grahas", "Bhavas", "Nakshatras", "Vimshottari dasha", "Gocharas", "Navamsa"]
    )

    static let naomiChinese = AstrologySpecialist(
        id: "naomi-chinese",
        characterName: "Naomi",
        publicTitle: "Chinese Astrologer",
        displayName: "Naomi - Chinese Astrologer",
        emoji: "🐉",
        publicDescription: "Five Elements, life cycles, compatibility, and practical strategy.",
        shortDescription: "Five Elements, life cycles, and strategy.",
        longDescription: "Naomi reads through BaZi, the Five Elements, and life cycles. She is best for practical strategy, compatibility, career timing, family patterns, and understanding your natural energetic balance.",
        tradition: "Chinese astrology / BaZi / Four Pillars",
        internalTradition: "BaZi / Four Pillars / Chinese astrology",
        focusAreas: ["Five Elements", "Life cycles", "Compatibility", "Practical strategy", "Career timing", "Family patterns"],
        personalityTraits: ["Practical", "Strategic", "Observant", "Future-oriented", "Composed"],
        symbol: "circle.hexagongrid.fill",
        placeholderAvatar: "N",
        harnessFileName: "naomi-chinese",
        legacyCharacterId: "capricorn-naomi",
        forbiddenConcepts: ["Western zodiac signs", "Planets", "Houses", "Aspects", "Western transits", "Vedic dashas", "Nakshatras", "Hellenistic Lots", "Annual Profections"],
        allowedTechniques: ["BaZi / Four Pillars", "Year Pillar", "Month Pillar", "Day Pillar", "Hour Pillar", "Heavenly Stems", "Earthly Branches", "Five Elements", "Luck Pillars"]
    )

    static let sorenAncient = AstrologySpecialist(
        id: "elias-ancient",
        characterName: "Soren",
        publicTitle: "Ancient Astrologer",
        displayName: "Soren - Ancient Astrologer",
        emoji: "🏛",
        publicDescription: "Ancient predictive methods, fate, timing, and classical technique.",
        shortDescription: "Classical prediction, fate, and timing.",
        longDescription: "Soren uses classical astrological techniques from antiquity. He is best for fate, timing, life chapters, predictive cycles, and clear traditional judgment.",
        tradition: "Ancient astrology",
        internalTradition: "Hellenistic astrology",
        focusAreas: ["Ancient predictive methods", "Fate", "Timing", "Classical technique", "Life chapters", "Traditional judgment"],
        personalityTraits: ["Scholarly", "Composed", "Precise", "Analytical", "Restrained"],
        symbol: "building.columns.fill",
        placeholderAvatar: "S",
        harnessFileName: "elias-ancient",
        legacyCharacterId: "aries-cassian",
        forbiddenConcepts: ["Vedic dashas", "Nakshatras", "Chinese zodiac", "BaZi", "Modern psychological astrology as main frame", "Evolutionary shadow-work language", "Outer planets as primary anchors"],
        allowedTechniques: ["Whole Sign Houses", "Seven traditional planets", "Sect", "Benefics and malefics", "Planetary condition", "Essential dignity", "Lots", "Annual Profections", "Zodiacal Releasing"]
    )

    static let nadiaEvolutionary = AstrologySpecialist(
        id: "nadia-evolutionary",
        characterName: "Nadia",
        publicTitle: "Evolutionary Astrologer",
        displayName: "Nadia - Evolutionary Astrologer",
        emoji: "🦋",
        publicDescription: "Healing, shadow work, emotional patterns, and personal growth.",
        shortDescription: "Healing, shadow work, and emotional growth.",
        longDescription: "Nadia reads the chart as a map of growth, healing, and emotional transformation. She is best for shadow work, relationship patterns, self-worth, attachment themes, and personal evolution.",
        tradition: "Evolutionary astrology",
        internalTradition: "Evolutionary astrology",
        focusAreas: ["Healing", "Shadow work", "Emotional patterns", "Personal growth", "Relationship patterns", "Self-worth", "Attachment themes"],
        personalityTraits: ["Compassionate", "Reflective", "Psychologically aware", "Gently direct", "Healing-oriented"],
        symbol: "sparkles",
        placeholderAvatar: "N",
        harnessFileName: "nadia-evolutionary",
        legacyCharacterId: "sagittarius-nadia",
        forbiddenConcepts: ["Vedic dashas", "Nakshatras", "Chinese astrology", "BaZi", "Hellenistic Lots", "Annual Profections", "Zodiacal Releasing", "Deterministic fate language", "Clinical diagnosis"],
        allowedTechniques: ["Natal chart as growth map", "Pluto", "Lunar Nodes", "Saturn", "Chiron", "Moon", "Venus", "Mars", "Relationship patterns", "Shadow work"]
    )
}
