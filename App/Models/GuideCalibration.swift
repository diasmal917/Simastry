import Foundation

nonisolated enum GuideCalibrationRole: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case astrologer
    case bestFriend
    case soulmate
    case mentor
    case teacher
    case coach

    var id: String { rawValue }

    var title: String {
        switch self {
        case .astrologer: "Astrologer"
        case .bestFriend: "Best friend"
        case .soulmate: "Soulmate"
        case .mentor: "Mentor"
        case .teacher: "Teacher"
        case .coach: "Coach"
        }
    }

    var promptLine: String {
        switch self {
        case .astrologer:
            "Keep the relationship feeling like a warm astrologer guide: symbolic, grounded, and clear."
        case .bestFriend:
            "Lean slightly closer, like a trusted best friend: warm, direct, playful, and still boundaried."
        case .soulmate:
            "Use a tender, intimate register, but never claim a real romantic bond or destiny."
        case .mentor:
            "Use a mentor register: wise, practical, steady, and focused on the next useful step."
        case .teacher:
            "Use a teaching register: explain the pattern clearly and make the lesson easy to apply."
        case .coach:
            "Use a coach register: encouraging, specific, and action-oriented without pressure."
        }
    }
}

nonisolated enum MBTIPersonalityType: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case intj = "INTJ"
    case intp = "INTP"
    case entj = "ENTJ"
    case entp = "ENTP"
    case infj = "INFJ"
    case infp = "INFP"
    case enfj = "ENFJ"
    case enfp = "ENFP"
    case istj = "ISTJ"
    case isfj = "ISFJ"
    case estj = "ESTJ"
    case esfj = "ESFJ"
    case istp = "ISTP"
    case isfp = "ISFP"
    case estp = "ESTP"
    case esfp = "ESFP"
    case notSure = "Not sure"

    var id: String { rawValue }
}

nonisolated enum GuideCalibrationStyleBalance: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case practical
    case balanced
    case mystical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .practical: "Practical"
        case .balanced: "Balanced"
        case .mystical: "Mystical"
        }
    }

    var promptLine: String {
        switch self {
        case .practical: "Prefer practical, concrete advice over symbolic framing."
        case .balanced: "Balance astrology language with concrete next steps."
        case .mystical: "Use a little more astrology language while staying practical."
        }
    }
}

nonisolated enum GuideCalibrationDirectness: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case gentle
    case balanced
    case direct

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: "Gentle"
        case .balanced: "Balanced"
        case .direct: "Direct"
        }
    }

    var promptLine: String {
        switch self {
        case .gentle: "Use a softer tone before giving the direct read."
        case .balanced: "Be warm and clear in equal measure."
        case .direct: "Be more direct, concise, and action-oriented."
        }
    }
}

nonisolated enum GuideCalibrationDetailLevel: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case short
    case balanced
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .short: "Short"
        case .balanced: "Balanced"
        case .detailed: "Detailed"
        }
    }

    var promptLine: String {
        switch self {
        case .short: "Keep guide replies short and immediately usable."
        case .balanced: "Use normal concise Simastry reply length."
        case .detailed: "Add a little more reasoning when it helps the user choose."
        }
    }
}

nonisolated struct GuideCalibration: Codable, Equatable, Sendable {
    static let availableTopics: [String] = [
        "relationships",
        "texting",
        "timing",
        "conflict",
        "compatibility",
        "career",
        "self-reflection",
        "family",
        "friendships",
        "creativity",
        "boundaries"
    ]

    var role: GuideCalibrationRole = .astrologer
    var personalityType: MBTIPersonalityType?
    var topics: [String] = []
    var updatedAt: Date?
    var styleBalance: GuideCalibrationStyleBalance?
    var directness: GuideCalibrationDirectness?
    var detailLevel: GuideCalibrationDetailLevel?

    var isDefault: Bool {
        role == .astrologer
            && personalityType == nil
            && topics.isEmpty
            && (styleBalance == nil || styleBalance == .balanced)
            && (directness == nil || directness == .balanced)
            && (detailLevel == nil || detailLevel == .balanced)
    }

    var displaySummary: String {
        var parts: [String] = []
        if role != .astrologer {
            parts.append(role.title)
        }
        if let personalityType {
            parts.append(personalityType.rawValue)
        }
        if !topics.isEmpty {
            parts.append(topics.prefix(2).joined(separator: ", "))
        }
        if let styleBalance, styleBalance != .balanced {
            parts.append(styleBalance.title)
        }
        if let directness, directness != .balanced {
            parts.append(directness.title)
        }
        if let detailLevel, detailLevel != .balanced {
            parts.append(detailLevel.title)
        }
        return parts.isEmpty ? "Default guide voice" : parts.joined(separator: " • ")
    }

    var promptBlock: String? {
        guard !isDefault else { return nil }

        var lines: [String] = [
            "User calibration for this one-on-one guide relationship:",
            "- Relationship role: \(role.title). \(role.promptLine)"
        ]

        if let personalityType {
            lines.append("- Optional personality lens: \(personalityType.rawValue). Treat this as user-provided context, not a diagnosis.")
        }

        if !topics.isEmpty {
            lines.append("- Preferred discussion topics: \(topics.joined(separator: ", ")).")
        }
        if let styleBalance {
            lines.append("- Astrology/practical balance: \(styleBalance.title). \(styleBalance.promptLine)")
        }
        if let directness {
            lines.append("- Directness preference: \(directness.title). \(directness.promptLine)")
        }
        if let detailLevel {
            lines.append("- Detail preference: \(detailLevel.title). \(detailLevel.promptLine)")
        }

        lines.append("Use calibration only for tone and context. Do not change the guide's zodiac lens, core identity, or safety boundaries.")
        return lines.joined(separator: "\n")
    }
}

final class GuideCalibrationStore {
    static let shared = GuideCalibrationStore()

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

    func calibration(for guideId: String) -> GuideCalibration {
        guard let data = defaults.data(forKey: storageKey(for: guideId)),
              let decoded = try? decoder.decode(GuideCalibration.self, from: data) else {
            return GuideCalibration()
        }
        return decoded
    }

    func calibratedGuideIds(in guideIds: some Sequence<String>) -> Set<String> {
        Set(guideIds.filter { !calibration(for: $0).isDefault })
    }

    func save(_ calibration: GuideCalibration, for guideId: String) {
        guard let data = try? encoder.encode(calibration) else { return }
        defaults.set(data, forKey: storageKey(for: guideId))
    }

    func clear(for guideId: String) {
        defaults.removeObject(forKey: storageKey(for: guideId))
    }

    private func storageKey(for guideId: String) -> String {
        "simastry_guide_calibration_\(guideId)"
    }
}
