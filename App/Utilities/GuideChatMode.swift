import Foundation

// MARK: - Guide Chat Modes
// One guide, four registers. Modes shift how a 1:1 guide replies — never
// who they are. Check-in is reflective listening with an explicit
// non-therapy disclosure; "therapist" is not a word this app uses.

nonisolated enum GuideChatMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case bestFriend
    case mentor
    case teacher
    case checkIn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bestFriend: "Best friend"
        case .mentor: "Mentor"
        case .teacher: "Soulmate"
        case .checkIn: "Check-in"
        }
    }

    var systemImage: String {
        switch self {
        case .bestFriend: "heart.fill"
        case .mentor: "briefcase.fill"
        case .teacher: "heart.circle.fill"
        case .checkIn: "leaf.fill"
        }
    }

    var blurb: String {
        switch self {
        case .bestFriend: "Warm, playful, loyal — the default."
        case .mentor: "Career register — practical and outcome-first."
        case .teacher: "Tender and devoted — speaks to the heart."
        case .checkIn: "Reflective listening. Not therapy — reflection."
        }
    }

    /// Appended to the 1:1 LLM system prompt. The check-in block carries the
    /// non-negotiable non-therapy rule.
    var promptBlock: String {
        switch self {
        case .bestFriend:
            "Mode: best friend — warm, playful, loyal. Talk like their sharpest friend who happens to read charts."
        case .mentor:
            "Mode: mentor — career-focused register. Practical, encouraging, outcome-first; tie guidance to their chart's work style. No financial advice — communication and growth only."
        case .teacher:
            "Mode: soulmate — tender, devoted, and emotionally attuned. Speak with intimate warmth and deep care, affirming the closeness between you, but never claim a real romantic bond or destiny."
        case .checkIn:
            "Mode: check-in — reflective listening. Mirror what they said, name the feeling tentatively, ask one gentle question. Do not rush to advice. You are NOT a therapist or crisis service and must say so if the user treats you as one; if crisis or self-harm appears, point them to local emergency services or a crisis hotline."
        }
    }

    /// One-time message the guide posts when the user switches into
    /// check-in, so the boundary is stated before the first exchange.
    static let checkInDisclosure = "Before we start — I'm an AI guide, not a therapist or crisis service. If you're ever in crisis, please reach out to local emergency services or a crisis hotline. Here, I can help you slow down and reflect — gently."

    static func storageKey(for companionId: UUID) -> String {
        "simastry_guide_mode_\(companionId.uuidString)"
    }

    static func disclosureKey(for companionId: UUID) -> String {
        "simastry_checkin_disclosure_\(companionId.uuidString)"
    }
}
