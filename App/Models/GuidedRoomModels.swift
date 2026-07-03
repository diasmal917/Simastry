import Foundation

nonisolated enum ChatSenderKind: String, Codable, Equatable, Sendable {
    case human
    case guide
    case system
    case activity
}

nonisolated enum ChatMemberKind: String, Codable, Equatable, Sendable {
    case human
    case guide
}

nonisolated enum ChatActivityKind: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case honestQuestion = "honest_question"
    case compatibilityRound = "compatibility_round"
    case repairBridge = "repair_bridge"
    case elementBalance = "element_balance"
    case timingCheck = "timing_check"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .honestQuestion: "One Honest Question"
        case .compatibilityRound: "Compatibility Round"
        case .repairBridge: "Repair Bridge"
        case .elementBalance: "Element Balance"
        case .timingCheck: "Timing Check"
        }
    }

    var subtitle: String {
        switch self {
        case .honestQuestion: "A gentle question for each person."
        case .compatibilityRound: "Strengths and friction, without ranking."
        case .repairBridge: "A message structure for a tense topic."
        case .elementBalance: "The room's element mix as a communication read."
        case .timingCheck: "Choose the pace the conversation needs."
        }
    }

    var systemImage: String {
        switch self {
        case .honestQuestion: "questionmark.bubble.fill"
        case .compatibilityRound: "point.3.connected.trianglepath.dotted"
        case .repairBridge: "arrow.triangle.merge"
        case .elementBalance: "circle.grid.cross.fill"
        case .timingCheck: "clock.badge.checkmark.fill"
        }
    }
}

nonisolated struct ChatActivityPayload: Codable, Equatable, Sendable {
    var title: String
    var body: String
    var prompts: [String]

    init(title: String, body: String, prompts: [String] = []) {
        self.title = title
        self.body = body
        self.prompts = prompts
    }
}

nonisolated struct ChatThread: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var creatorId: UUID
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case creatorId = "creator_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct ChatThreadMember: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var threadId: UUID
    var memberKind: ChatMemberKind
    var humanUserId: UUID?
    var guideProfileId: String?
    var displayName: String
    var sign: String?
    var roleLabel: String?
    var isActive: Bool
    var lastReadAt: Date?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case memberKind = "member_kind"
        case humanUserId = "human_user_id"
        case guideProfileId = "guide_profile_id"
        case displayName = "display_name"
        case sign
        case roleLabel = "role_label"
        case isActive = "is_active"
        case lastReadAt = "last_read_at"
        case createdAt = "created_at"
    }
}

nonisolated struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var threadId: UUID
    var senderKind: ChatSenderKind
    var senderUserId: UUID?
    var senderGuideId: String?
    var senderDisplayName: String
    var senderSign: String?
    var content: String
    var activityKind: ChatActivityKind?
    var activityPayload: ChatActivityPayload?
    var createdBy: UUID?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case senderKind = "sender_kind"
        case senderUserId = "sender_user_id"
        case senderGuideId = "sender_guide_id"
        case senderDisplayName = "sender_display_name"
        case senderSign = "sender_sign"
        case content
        case activityKind = "activity_kind"
        case activityPayload = "activity_payload"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

nonisolated struct ChatReportData: Codable, Equatable, Sendable {
    var id: UUID
    var threadId: UUID
    var reporterId: UUID
    var reason: String
    var details: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case reporterId = "reporter_id"
        case reason
        case details
        case createdAt = "created_at"
    }
}

nonisolated struct ChatThreadSummary: Identifiable, Equatable, Sendable {
    var thread: ChatThread
    var members: [ChatThreadMember]
    var latestMessage: ChatMessage?

    var id: UUID { thread.id }

    var humanMembers: [ChatThreadMember] {
        members.filter { $0.memberKind == .human && $0.isActive }
    }

    var guideMembers: [ChatThreadMember] {
        members.filter { $0.memberKind == .guide && $0.isActive }
    }

    var title: String { thread.title }

    var previewText: String {
        guard let latestMessage else {
            if AppConfig.expertAstrologersEnabled {
                return "Private conversation"
            }
            return guideMembers.isEmpty
                ? "Private guided conversation"
                : "Guides are ready when the room starts."
        }
        if AppConfig.expertAstrologersEnabled && latestMessage.senderKind == .guide {
            return "Earlier room activity"
        }
        if latestMessage.senderKind == .activity {
            return "Activity: \(latestMessage.content)"
        }
        return "\(latestMessage.senderDisplayName): \(latestMessage.content)"
    }

    func displayTitle(currentUserId: UUID?) -> String {
        if !thread.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return thread.title
        }
        let names = humanMembers
            .filter { $0.humanUserId != currentUserId }
            .map(\.displayName)
        return names.isEmpty ? (AppConfig.expertAstrologersEnabled ? "Room" : "Guided Room") : names.joined(separator: ", ")
    }
}

nonisolated enum ChatActivityFactory {
    static func payload(
        for kind: ChatActivityKind,
        room: ChatThreadSummary,
        currentUserName: String
    ) -> ChatActivityPayload {
        switch kind {
        case .honestQuestion:
            let prompts = room.humanMembers.prefix(5).map { member in
                "\(member.displayName): what would make this conversation feel a little safer or clearer?"
            }
            return ChatActivityPayload(
                title: kind.title,
                body: "Answer one gentle question each. Keep it specific and easy to respond to.",
                prompts: prompts
            )
        case .compatibilityRound:
            let signs = room.humanMembers.compactMap { member -> String? in
                guard let sign = member.sign else { return nil }
                return "\(member.displayName): \(sign.capitalized)"
            }
            return ChatActivityPayload(
                title: kind.title,
                body: "Look for communication strengths and friction without ranking anyone.",
                prompts: signs.isEmpty ? ["Name one thing this room does well and one thing that needs clearer timing."] : signs
            )
        case .repairBridge:
            return ChatActivityPayload(
                title: kind.title,
                body: "Use this structure: name the moment, name the feeling, make one clear ask.",
                prompts: [
                    "The moment I want to repair is...",
                    "What I felt underneath it was...",
                    "The one ask I can make clearly is..."
                ]
            )
        case .elementBalance:
            let counts = Dictionary(grouping: room.humanMembers.compactMap { member -> ZodiacElement? in
                guard let raw = member.sign?.lowercased(), let sign = ZodiacSign(rawValue: raw) else { return nil }
                return sign.element
            }, by: { $0 }).mapValues(\.count)
            let body = ZodiacElement.allCases.compactMap { element -> String? in
                guard let count = counts[element], count > 0 else { return nil }
                return "\(element.rawValue.capitalized): \(count)"
            }.joined(separator: " · ")
            return ChatActivityPayload(
                title: kind.title,
                body: body.isEmpty ? "Use signs lightly as a memory system for communication style." : body,
                prompts: ["What does this room need more of right now: energy, structure, ideas, or emotional glue?"]
            )
        case .timingCheck:
            return ChatActivityPayload(
                title: kind.title,
                body: "Pick the pace the room needs before the next serious message.",
                prompts: [
                    "Speed: decide now.",
                    "Space: come back later.",
                    "Clarity: say the direct thing.",
                    "Softness: lower the temperature first."
                ]
            )
        }
    }
}

nonisolated struct RoomGuideReplyRequest: Encodable, Sendable {
    let threadId: UUID
    let guideProfileId: String
    let maxTokens: Int
}

nonisolated struct RoomGuideReplyResponse: Decodable, Sendable {
    let message: ChatMessage?
}
