import Foundation

// MARK: - Rehearsal Room models

/// Who the practice stand-in is shaped after. Signs and notes are always
/// user-supplied symbolism — mirrored into every backend request as such.
nonisolated struct RehearsalPersona: Codable, Equatable, Sendable {
    var name: String
    var relationship: String?
    var sunSign: String?
    var moonSign: String?
    var risingSign: String?
    var notes: String?
    /// Saved People link, when the rehearsal started from a person card.
    var personId: UUID?
}

nonisolated enum RehearsalRole: String, Codable, Sendable {
    case user
    case partner
    case coach
}

nonisolated struct RehearsalChatMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let role: RehearsalRole
    var content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: RehearsalRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// One practice conversation. Local-only; capped by the store.
nonisolated struct RehearsalSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var persona: RehearsalPersona
    var goal: String
    var coachSpecialistId: String
    var messages: [RehearsalChatMessage]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        persona: RehearsalPersona,
        goal: String,
        coachSpecialistId: String,
        messages: [RehearsalChatMessage] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.persona = persona
        self.goal = goal
        self.coachSpecialistId = coachSpecialistId
        self.messages = messages
        self.createdAt = createdAt
    }

    /// Matches the backend's 15-partner-turn session limit.
    static let partnerTurnLimit = 15

    var partnerTurnCount: Int {
        messages.filter { $0.role == .partner }.count
    }

    var isAtTurnLimit: Bool {
        partnerTurnCount >= Self.partnerTurnLimit
    }
}

// MARK: - Backend request body

/// Mirrors `ConversationRehearsalRequest` on the edge function. Coach notes
/// never travel in the transcript — the backend sees only user/partner turns.
nonisolated struct RehearsalRequestBody: Encodable, Sendable {
    struct Message: Encodable, Sendable {
        let role: String
        let content: String
    }

    let mode: String
    let personaName: String
    let relationship: String?
    let personaSunSign: String?
    let personaMoonSign: String?
    let personaRisingSign: String?
    let personaNotes: String?
    let goal: String
    let coachSpecialistId: String?
    let transcript: [Message]
    let sessionId: UUID?

    init(session: RehearsalSession, mode: String) {
        self.mode = mode
        self.personaName = session.persona.name
        self.relationship = session.persona.relationship
        self.personaSunSign = session.persona.sunSign
        self.personaMoonSign = session.persona.moonSign
        self.personaRisingSign = session.persona.risingSign
        self.personaNotes = session.persona.notes
        self.goal = session.goal
        self.coachSpecialistId = mode == "coach" ? session.coachSpecialistId : nil
        self.transcript = session.messages
            .filter { $0.role != .coach }
            .suffix(20)
            .map { Message(role: $0.role.rawValue, content: $0.content) }
        self.sessionId = session.id
    }
}

// MARK: - Local persistence

/// Rehearsals stay on this device: capped, atomically written JSON alongside
/// the expert chat store. Cleared with local data.
nonisolated enum RehearsalSessionStore {
    static let maxStoredSessions = 10

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("SimastryExpertChats", isDirectory: true)
            .appendingPathComponent("rehearsal_sessions.json")
    }

    static func load() -> [RehearsalSession] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([RehearsalSession].self, from: data)) ?? []
    }

    static func save(_ session: RehearsalSession) {
        var sessions = load().filter { $0.id != session.id }
        sessions.insert(session, at: 0)
        persist(Array(sessions.prefix(maxStoredSessions)))
    }

    static func remove(id: UUID) {
        persist(load().filter { $0.id != id })
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func persist(_ sessions: [RehearsalSession]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(sessions).write(to: fileURL, options: .atomic)
        } catch {
            CrashReporter.log(error, context: "rehearsalSessionStoreWrite")
        }
    }
}
