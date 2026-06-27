import Foundation

nonisolated enum FirstReadBestNextMoveType: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case wait
    case replyNow
    case replyLater
    case clarify
    case setBoundary
    case letItRest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wait: "Wait"
        case .replyNow: "Reply now"
        case .replyLater: "Reply later"
        case .clarify: "Clarify"
        case .setBoundary: "Set a boundary"
        case .letItRest: "Let it rest"
        }
    }

    var systemImage: String {
        switch self {
        case .wait: "clock.fill"
        case .replyNow: "arrow.up.message.fill"
        case .replyLater: "calendar.badge.clock"
        case .clarify: "questionmark.bubble.fill"
        case .setBoundary: "hand.raised.fill"
        case .letItRest: "moon.zzz.fill"
        }
    }
}

nonisolated struct FirstReadBestNextMove: Codable, Equatable, Sendable {
    var type: FirstReadBestNextMoveType
    var summary: String
    var timingNote: String?
}

nonisolated enum FirstReadSafetyLevel: String, Codable, Hashable, Sendable {
    case ok
    case softBoundary
    case manipulationRisk
    case abuseOrCoercion
    case selfHarmOrCrisis
    case minorSensitive
    case unsupported
}

nonisolated struct FirstReadReplyOption: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var text: String
    var tone: String
    var rationale: String?
}

/// Tomorrow's remote AI contract. The UI should render this shape whether the
/// values come from OpenAI, Claude, or the deterministic local fallback.
nonisolated struct FirstReadAIResult: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var toneRead: String
    var likelyMeaning: String
    var dontAssume: [String]
    var bestNextMove: FirstReadBestNextMove
    var timingNote: String?
    var replyOptions: [FirstReadReplyOption]
    var guideContinuationSeed: String
    var safetyLevel: FirstReadSafetyLevel
    var confidence: Int
    var followUpPrompt: String?
}

nonisolated enum FeedbackSurface: String, Codable, Hashable, Sendable {
    case firstRead
    case panelChat
    case guideCard
    case replyOption
}

nonisolated enum HelpfulnessRating: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case helpful
    case partlyHelpful
    case notHelpful

    var id: String { rawValue }

    var title: String {
        switch self {
        case .helpful: "Yes"
        case .partlyHelpful: "Kind of"
        case .notHelpful: "No"
        }
    }
}

nonisolated enum GuideFeedbackReason: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case tooVague
    case tooIntense
    case tooMystical
    case notPractical
    case wrongTone
    case missedContext
    case replyDidntSoundLikeMe
    case tooLong
    case tooSoft
    case tooHarsh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tooVague: "Too vague"
        case .tooIntense: "Too intense"
        case .tooMystical: "Too mystical"
        case .notPractical: "Not practical"
        case .wrongTone: "Wrong tone"
        case .missedContext: "Missed context"
        case .replyDidntSoundLikeMe: "Did not sound like me"
        case .tooLong: "Too long"
        case .tooSoft: "Too soft"
        case .tooHarsh: "Too harsh"
        }
    }

    var promptHint: String {
        switch self {
        case .tooVague: "be more specific"
        case .tooIntense: "lower the intensity"
        case .tooMystical: "use less astrology jargon"
        case .notPractical: "make the next step more practical"
        case .wrongTone: "better match the user's tone"
        case .missedContext: "reference the user's actual context more carefully"
        case .replyDidntSoundLikeMe: "make reply drafts sound more natural for the user"
        case .tooLong: "keep replies shorter"
        case .tooSoft: "be clearer and less cushioning"
        case .tooHarsh: "soften the delivery"
        }
    }
}

nonisolated enum ReplyTuneAction: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case warmer
    case moreDirect
    case shorter
    case lessIntense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warmer: "Warmer"
        case .moreDirect: "Direct"
        case .shorter: "Shorter"
        case .lessIntense: "Less intense"
        }
    }

    var systemImage: String {
        switch self {
        case .warmer: "heart.fill"
        case .moreDirect: "arrow.right.circle.fill"
        case .shorter: "scissors"
        case .lessIntense: "leaf.fill"
        }
    }
}

nonisolated enum GuideFeedbackTuneOption: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case warmer
    case moreDirect
    case shorter
    case lessMystical
    case morePractical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warmer: "Warmer"
        case .moreDirect: "More direct"
        case .shorter: "Shorter"
        case .lessMystical: "Less mystical"
        case .morePractical: "More practical"
        }
    }

    var systemImage: String {
        switch self {
        case .warmer: "heart.fill"
        case .moreDirect: "arrow.right.circle.fill"
        case .shorter: "scissors"
        case .lessMystical: "sparkles"
        case .morePractical: "checklist"
        }
    }

    var feedbackReason: GuideFeedbackReason {
        switch self {
        case .warmer: .tooHarsh
        case .moreDirect: .tooSoft
        case .shorter: .tooLong
        case .lessMystical: .tooMystical
        case .morePractical: .notPractical
        }
    }
}

nonisolated struct GuideFeedback: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var readId: UUID
    var aiUsageEventId: UUID?
    var guideId: String?
    var surface: FeedbackSurface
    var helpfulness: HelpfulnessRating
    var reasons: [GuideFeedbackReason]
    var freeformNote: String?
    var createdAt: Date
    var syncedAt: Date?

    func matches(readId: UUID, guideId: String?, surface: FeedbackSurface) -> Bool {
        self.readId == readId && self.guideId == guideId && self.surface == surface
    }
}

nonisolated struct GuideFeedbackSyncPayload: Encodable, Equatable, Sendable {
    var id: UUID
    var aiUsageEventId: UUID?
    var readId: UUID
    var guideId: String?
    var surface: String
    var helpfulness: String
    var reasons: [String]
    var freeformNote: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case aiUsageEventId = "p_ai_usage_event_id"
        case readId = "p_read_id"
        case guideId = "p_guide_id"
        case surface = "p_surface"
        case helpfulness = "p_helpfulness"
        case reasons = "p_reasons"
        case freeformNote = "p_freeform_note"
        case createdAt = "p_created_at"
    }

    init(feedback: GuideFeedback) {
        id = feedback.id
        aiUsageEventId = feedback.aiUsageEventId
        readId = feedback.readId
        guideId = feedback.guideId
        surface = feedback.surface.rawValue
        helpfulness = feedback.helpfulness.rawValue
        reasons = feedback.reasons.map(\.rawValue)
        freeformNote = feedback.freeformNote
        createdAt = ISO8601DateFormatter().string(from: feedback.createdAt)
    }
}

nonisolated struct GuideFeedbackEventData: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var userId: UUID
    var aiUsageEventId: UUID?
    var readId: UUID
    var guideId: String?
    var surface: String
    var helpfulness: String
    var reasons: [String]
    var freeformNote: String?
    var createdAt: Date
    var syncedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case aiUsageEventId = "ai_usage_event_id"
        case readId = "read_id"
        case guideId = "guide_id"
        case surface
        case helpfulness
        case reasons
        case freeformNote = "freeform_note"
        case createdAt = "created_at"
        case syncedAt = "synced_at"
    }

    init(userId: UUID, feedback: GuideFeedback) {
        self.id = feedback.id
        self.userId = userId
        self.aiUsageEventId = feedback.aiUsageEventId
        self.readId = feedback.readId
        self.guideId = feedback.guideId
        self.surface = feedback.surface.rawValue
        self.helpfulness = feedback.helpfulness.rawValue
        self.reasons = feedback.reasons.map(\.rawValue)
        self.freeformNote = feedback.freeformNote
        self.createdAt = feedback.createdAt
        self.syncedAt = feedback.syncedAt
    }

    var localFeedback: GuideFeedback? {
        guard let surface = FeedbackSurface(rawValue: surface),
              let helpfulness = HelpfulnessRating(rawValue: helpfulness) else {
            return nil
        }

        return GuideFeedback(
            id: id,
            readId: readId,
            aiUsageEventId: aiUsageEventId,
            guideId: guideId,
            surface: surface,
            helpfulness: helpfulness,
            reasons: reasons.compactMap(GuideFeedbackReason.init(rawValue:)),
            freeformNote: freeformNote,
            createdAt: createdAt,
            syncedAt: syncedAt
        )
    }
}

nonisolated final class GuideFeedbackStore {
    static let defaultsKey = "simastry_guide_feedback_events"

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [GuideFeedback] {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let events = try? decoder.decode([GuideFeedback].self, from: data) else {
            return []
        }
        return events
    }

    func save(_ events: [GuideFeedback]) {
        guard let data = try? encoder.encode(events) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}

nonisolated enum GuideFeedbackPromptBuilder {
    static func promptSummary(from events: [GuideFeedback], guideId: String?, limit: Int = 12) -> String? {
        let relevant = events
            .filter { event in
                event.guideId == nil || guideId == nil || event.guideId == guideId
            }
            .suffix(limit)
        guard !relevant.isEmpty else { return nil }

        let reasons = relevant.flatMap(\.reasons)
        let reasonCounts = Dictionary(grouping: reasons, by: { $0 })
            .mapValues(\.count)
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.rawValue < rhs.key.rawValue
                }
                return lhs.value > rhs.value
            }
            .prefix(4)
            .map { $0.key.promptHint }

        let helpfulCount = relevant.filter { $0.helpfulness == .helpful }.count
        let notHelpfulCount = relevant.filter { $0.helpfulness == .notHelpful }.count

        var lines: [String] = ["Recent user feedback for guide output:"]
        if !reasonCounts.isEmpty {
            lines.append("- Adjust toward: \(reasonCounts.joined(separator: ", ")).")
        }
        if helpfulCount > notHelpfulCount {
            lines.append("- The user has recently marked this style as useful. Keep the practical, specific register.")
        } else if notHelpfulCount > helpfulCount {
            lines.append("- The user has recently rejected some guide output. Prioritize specificity and lower confidence claims.")
        }
        lines.append("Use this only for tone and usefulness. Do not weaken safety boundaries.")
        return lines.joined(separator: "\n")
    }
}
