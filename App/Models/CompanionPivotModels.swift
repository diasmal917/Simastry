import Foundation

// MARK: - Experience contract

/// The three deliberately separate product surfaces. Companion data never
/// shares persistence with the expert archive.
nonisolated enum ExperienceMode: String, CaseIterable, Codable, Sendable {
    case companionPilot = "companion_pilot"
    case companionFull = "companion_full"
    case expertArchive = "expert_archive"

    var isCompanionExperience: Bool {
        self == .companionPilot || self == .companionFull
    }
}

/// A Factory slug is the only canonical identity accepted by companion APIs.
/// Display names, signs, and portraits are metadata and are never used to
/// merge or infer identities.
nonisolated struct CompanionPersonaID: RawRepresentable, Codable, Hashable, Identifiable, Sendable {
    let rawValue: String

    var id: String { rawValue }

    init(rawValue: String) {
        // Identity is deliberately exact. Callers may validate a Factory slug,
        // but must never normalize, infer, or merge one by case/name/sign.
        self.rawValue = rawValue
    }

    static let amara = Self(rawValue: "aries-amara")
    static let theo = Self(rawValue: "taurus-theo")
    static let isolde = Self(rawValue: "libra-isolde")
    static let zev = Self(rawValue: "pisces-zev")
}

nonisolated enum CompanionCertificationStatus: String, Codable, Sendable {
    case pilotCertified = "pilot_certified"
    case pendingCertification = "pending_certification"
    case archived
}

nonisolated struct CompanionPersona: Identifiable, Codable, Hashable, Sendable {
    let id: CompanionPersonaID
    let displayName: String
    let sign: ZodiacSign
    let headline: String
    let supportPromise: String
    let profileImageName: String
    let cardImageName: String
    let assetVersion: Int
    let personaVersion: Int
    let certificationStatus: CompanionCertificationStatus

    var isPilotCertified: Bool { certificationStatus == .pilotCertified }
}

/// The approved pilot registry is mirrored on the server. This client copy is
/// presentation metadata only; it is never sent as a system prompt.
nonisolated enum CompanionPersonaRegistry {
    static let pilot: [CompanionPersona] = [
        CompanionPersona(
            id: .amara,
            displayName: "Amara",
            sign: .aries,
            headline: "Courage with a clean next move.",
            supportPromise: "Fast, direct courage without recklessness.",
            profileImageName: "Factory_aries-amara_profile",
            cardImageName: "Factory_aries-amara_card",
            assetVersion: 1,
            personaVersion: 1,
            certificationStatus: .pilotCertified
        ),
        CompanionPersona(
            id: .theo,
            displayName: "Theo",
            sign: .taurus,
            headline: "Ground the noise. Keep what is true.",
            supportPromise: "Calm, grounded clarity without passivity.",
            profileImageName: "Factory_taurus-theo_profile",
            cardImageName: "Factory_taurus-theo_card",
            assetVersion: 1,
            personaVersion: 1,
            certificationStatus: .pilotCertified
        ),
        CompanionPersona(
            id: .isolde,
            displayName: "Isolde",
            sign: .libra,
            headline: "Fair words with a real boundary.",
            supportPromise: "Tactful fairness and firm boundaries.",
            profileImageName: "Factory_libra-isolde_profile",
            cardImageName: "Factory_libra-isolde_card",
            assetVersion: 1,
            personaVersion: 1,
            certificationStatus: .pilotCertified
        ),
        CompanionPersona(
            id: .zev,
            displayName: "Zev",
            sign: .pisces,
            headline: "Translate the feeling without inventing a story.",
            supportPromise: "Emotionally perceptive translation without mind-reading or rescuing.",
            profileImageName: "Factory_pisces-zev_profile",
            cardImageName: "Factory_pisces-zev_card",
            assetVersion: 1,
            personaVersion: 1,
            certificationStatus: .pilotCertified
        ),
    ]

    static let pilotIDs = Set(pilot.map(\.id))

    static func persona(id: CompanionPersonaID) -> CompanionPersona? {
        pilot.first { $0.id == id }
    }

    /// Recommends three certified companions using chart context and the user's
    /// preferred guidance style. The fourth remains available, and the user
    /// must still choose explicitly.
    static func recommendations(
        sun: ZodiacSign?,
        moon: ZodiacSign?,
        rising: ZodiacSign?,
        guidanceStyle: GuidanceStyle
    ) -> [CompanionPersona] {
        let boosted: Set<CompanionPersonaID> = switch guidanceStyle {
        case .practical: [.theo, .amara]
        case .balanced: [.isolde, .theo]
        case .astrologyRich: [.zev, .isolde]
        }
        return recommendations(sun: sun, moon: moon, rising: rising, boosting: boosted)
    }

    /// Onboarding variant: the support style chosen during setup carries the
    /// bias instead of the account-level guidance style. Same scoring, same
    /// explicit-choice rule.
    static func recommendations(
        sun: ZodiacSign?,
        moon: ZodiacSign?,
        rising: ZodiacSign?,
        supportStyle: OnboardingSupportStyle
    ) -> [CompanionPersona] {
        let boosted: Set<CompanionPersonaID> = switch supportStyle {
        case .tellMeStraight: [.amara, .theo]
        case .thinkItThrough: [.theo, .isolde]
        case .findTheWords: [.isolde, .zev]
        }
        return recommendations(sun: sun, moon: moon, rising: rising, boosting: boosted)
    }

    private static func recommendations(
        sun: ZodiacSign?,
        moon: ZodiacSign?,
        rising: ZodiacSign?,
        boosting boosted: Set<CompanionPersonaID>
    ) -> [CompanionPersona] {
        let placements = [sun, moon, rising].compactMap { $0 }
        let scored = pilot.map { persona -> (CompanionPersona, Int) in
            var score = 0
            for (index, placement) in placements.enumerated() {
                if persona.sign == placement { score += 10 - index }
                if persona.sign.element == placement.element { score += 4 - min(index, 2) }
                if complementaryElements.contains([persona.sign.element, placement.element]) { score += 2 }
            }
            if boosted.contains(persona.id) { score += 3 }
            return (persona, score)
        }
        return scored
            .sorted {
                if $0.1 == $1.1 { return $0.0.id.rawValue < $1.0.id.rawValue }
                return $0.1 > $1.1
            }
            .prefix(3)
            .map(\.0)
    }

    private static let complementaryElements: Set<Set<ZodiacElement>> = [
        [.fire, .air],
        [.earth, .water],
    ]
}

// MARK: - User-owned companion data

nonisolated enum CompanionSupportTone: String, CaseIterable, Codable, Identifiable, Sendable {
    case warm, steady, candid
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

nonisolated enum CompanionSupportDirectness: String, CaseIterable, Codable, Identifiable, Sendable {
    case gentle, balanced, direct
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

nonisolated enum CompanionSupportLength: String, CaseIterable, Codable, Identifiable, Sendable {
    case concise, medium, detailed
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

nonisolated struct CompanionSupportPreferences: Codable, Hashable, Sendable {
    var tone: CompanionSupportTone = .warm
    var directness: CompanionSupportDirectness = .balanced
    var length: CompanionSupportLength = .medium
    var topics: [String] = []
}

nonisolated struct CompanionRelationship: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var userId: UUID?
    let companionId: CompanionPersonaID
    var isPrimary: Bool
    var preferences: CompanionSupportPreferences
    let personaVersion: Int
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        companionId: CompanionPersonaID,
        isPrimary: Bool,
        preferences: CompanionSupportPreferences = .init(),
        personaVersion: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.companionId = companionId
        self.isPrimary = isPrimary
        self.preferences = preferences
        self.personaVersion = personaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

nonisolated enum CompanionMemoryScope: String, Codable, CaseIterable, Sendable {
    case sharedUserFact = "shared_user_fact"
    case personaRelationship = "persona_relationship"
}

nonisolated enum CompanionMemorySource: String, Codable, Sendable {
    case userRecorded = "user_recorded"
    case recordedOutcome = "recorded_outcome"
    case consentedMigration = "consented_migration"
}

nonisolated struct CompanionMemoryItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var userId: UUID?
    let companionId: CompanionPersonaID?
    let scope: CompanionMemoryScope
    let source: CompanionMemorySource
    var content: String
    var relatedPersonId: UUID?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        companionId: CompanionPersonaID?,
        scope: CompanionMemoryScope,
        source: CompanionMemorySource,
        content: String,
        relatedPersonId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.companionId = companionId
        self.scope = scope
        self.source = source
        self.content = content
        self.relatedPersonId = relatedPersonId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

nonisolated struct CompanionConversation: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var userId: UUID?
    let companionId: CompanionPersonaID
    let createdAt: Date
    var updatedAt: Date
}

nonisolated enum CompanionChatRole: String, Codable, Sendable {
    case user
    case assistant
}

nonisolated struct CompanionChatMessage: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let conversationId: UUID
    let clientMessageId: UUID?
    let role: CompanionChatRole
    var content: String
    let personaVersion: Int
    let modelVersion: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        conversationId: UUID,
        clientMessageId: UUID? = nil,
        role: CompanionChatRole,
        content: String,
        personaVersion: Int = 1,
        modelVersion: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.conversationId = conversationId
        self.clientMessageId = clientMessageId
        self.role = role
        self.content = content
        self.personaVersion = personaVersion
        self.modelVersion = modelVersion
        self.createdAt = createdAt
    }
}

nonisolated enum CommunicationOutcomeResult: String, CaseIterable, Codable, Identifiable, Sendable {
    case betterThanExpected = "better_than_expected"
    case asExpected = "as_expected"
    case harderThanExpected = "harder_than_expected"
    case noResponse = "no_response"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .betterThanExpected: "Better than expected"
        case .asExpected: "About as expected"
        case .harderThanExpected: "Harder than expected"
        case .noResponse: "No response yet"
        }
    }
}

nonisolated enum CommunicationFollowUpState: String, Codable, Sendable {
    case pending
    case acknowledged
    case dismissed
}

nonisolated struct CommunicationOutcome: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var userId: UUID?
    let personId: UUID
    let companionId: CompanionPersonaID
    var intendedAction: String
    var result: CommunicationOutcomeResult
    var userNotes: String?
    var followUpState: CommunicationFollowUpState
    let occurredAt: Date
    let createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        personId: UUID,
        companionId: CompanionPersonaID,
        intendedAction: String,
        result: CommunicationOutcomeResult,
        userNotes: String? = nil,
        followUpState: CommunicationFollowUpState = .pending,
        occurredAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.personId = personId
        self.companionId = companionId
        self.intendedAction = intendedAction
        self.result = result
        self.userNotes = userNotes
        self.followUpState = followUpState
        self.occurredAt = occurredAt
        self.createdAt = createdAt
    }
}

nonisolated struct LegacyCompanionRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let originalName: String
    let originalSign: String
    let importedAt: Date
    let isReadOnly: Bool
}

/// Authenticated server snapshot used to restore the primary relationship and
/// separate histories on a new device. Private People/memory/outcome arrays are
/// populated only when this device has explicit sync consent.
nonisolated struct CompanionServerSnapshot: Sendable {
    var relationships: [CompanionRelationship] = []
    var conversations: [CompanionConversation] = []
    var messages: [CompanionChatMessage] = []
    var people: [RelationshipPerson] = []
    var memories: [CompanionMemoryItem] = []
    var outcomes: [CommunicationOutcome] = []
}

nonisolated struct CompanionLegacyMessageMigration: Encodable, Sendable {
    let legacyMessageId: UUID
    let role: String
    let content: String
    let createdAt: String
}

nonisolated struct CompanionLegacyConversationMigration: Encodable, Sendable {
    let legacyConversationId: UUID
    let title: String?
    let messages: [CompanionLegacyMessageMigration]
}

nonisolated struct CompanionLegacyThreadMigration: Sendable {
    let companionId: CompanionPersonaID
    let conversations: [CompanionLegacyConversationMigration]
}

// MARK: - Local-first, consent-aware cache

nonisolated struct CompanionPivotState: Codable, Sendable {
    static let currentMigrationVersion = 1

    var relationships: [CompanionRelationship] = []
    var conversations: [CompanionConversation] = []
    var messages: [CompanionChatMessage] = []
    var memories: [CompanionMemoryItem] = []
    var outcomes: [CommunicationOutcome] = []
    var legacyRecords: [LegacyCompanionRecord] = []
    var syncConsent = false
    var migrationVersion = 0

    /// The local mirror of the database's partial unique index. Selection is
    /// exact-slug-only and never infers identity from a display name or sign.
    @discardableResult
    mutating func selectPrimary(
        _ companionId: CompanionPersonaID,
        userId: UUID?,
        now: Date = Date()
    ) -> CompanionRelationship? {
        guard CompanionPersonaRegistry.pilotIDs.contains(companionId),
              let persona = CompanionPersonaRegistry.persona(id: companionId) else {
            return nil
        }

        for index in relationships.indices {
            relationships[index].isPrimary = false
            relationships[index].updatedAt = now
        }

        if let index = relationships.firstIndex(where: { $0.companionId == companionId }) {
            relationships[index].isPrimary = true
            relationships[index].updatedAt = now
            return relationships[index]
        }

        let relationship = CompanionRelationship(
            userId: userId,
            companionId: companionId,
            isPrimary: true,
            personaVersion: persona.personaVersion,
            createdAt: now,
            updatedAt: now
        )
        relationships.append(relationship)
        return relationship
    }
}

nonisolated final class CompanionPivotStore: @unchecked Sendable {
    static let shared = CompanionPivotStore()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileURL: URL
    private let lock = NSLock()

    init(fileURL: URL? = nil) {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = fileURL ?? base
            .appendingPathComponent("SimastryCompanions", isDirectory: true)
            .appendingPathComponent("companion_pivot_state.json")
    }

    func load() -> CompanionPivotState {
        lock.withLock {
            guard let data = try? Data(contentsOf: fileURL),
                  let state = try? decoder.decode(CompanionPivotState.self, from: data) else {
                return CompanionPivotState()
            }
            return state
        }
    }

    func save(_ state: CompanionPivotState) {
        lock.withLock {
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try encoder.encode(state).write(to: fileURL, options: .atomic)
            } catch {
                CrashReporter.log(error, context: "companionPivotStoreWrite")
            }
        }
    }

    func clear() {
        lock.withLock {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
