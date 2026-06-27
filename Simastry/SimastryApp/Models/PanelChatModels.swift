import Foundation

/// Who authored a panel message. Human friends become additional `.user`-like
/// kinds in the later backend phase — the chat renders off this enum, not off
/// guide-specific assumptions.
nonisolated enum PanelSenderKind: Codable, Hashable, Sendable {
    case user
    case guide(profileId: String)
}

nonisolated struct PanelParticipant: Identifiable, Codable, Hashable, Sendable {
    /// "user" for the local user; a FactoryCompanionProfile id for guides.
    /// The backend phase swaps in real account ids without changing callers.
    let id: String
    let kind: PanelSenderKind
    var displayName: String
    var signRawValue: String?

    var sign: ZodiacSign? {
        signRawValue.flatMap { ZodiacSign(rawValue: $0) }
    }

    static let localUserId = "user"
}

nonisolated struct PanelMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let threadId: String
    let senderId: String
    let content: String
    let timestamp: Date
    let aiUsageEventId: UUID?
    var isRead: Bool

    init(
        id: UUID = UUID(),
        threadId: String = PanelThread.defaultThreadId,
        senderId: String,
        content: String,
        timestamp: Date = Date(),
        aiUsageEventId: UUID? = nil,
        isRead: Bool
    ) {
        self.id = id
        self.threadId = threadId
        self.senderId = senderId
        self.content = content
        self.timestamp = timestamp
        self.aiUsageEventId = aiUsageEventId
        self.isRead = isRead
    }
}

/// The thread itself is rebuilt at runtime (participants derive from the
/// user's current placements via PanelMatcher); only messages persist, so a
/// sign change re-forms the panel while history stays attributable.
nonisolated struct PanelThread: Identifiable, Codable, Equatable, Sendable {
    static let defaultThreadId = "your-panel"

    let id: String
    var title: String
    var participants: [PanelParticipant]
}
