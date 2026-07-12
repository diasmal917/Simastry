import Foundation

/// Controls how much astrological language Simastry uses without asking
/// people to label themselves as believers or skeptics.
nonisolated enum GuidanceStyle: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case practical
    case balanced
    case astrologyRich = "astrology_rich"

    static let storageKey = "simastry_guidance_style"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .practical:
            "Practical"
        case .balanced:
            "Balanced"
        case .astrologyRich:
            "Astrology-rich"
        }
    }

    var summary: String {
        switch self {
        case .practical:
            "Clear takeaways and next steps. Astrology stays in the background."
        case .balanced:
            "Practical guidance with a brief explanation of the astrological lens."
        case .astrologyRich:
            "More chart language and a fuller explanation of the astrological lens."
        }
    }

    static var stored: GuidanceStyle {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
              let style = GuidanceStyle(rawValue: rawValue) else {
            return .practical
        }
        return style
    }
}
