import Foundation

final class FeatureTipManager {
    enum Tip: String, CaseIterable {
        case companionDetail
        case communicationGuide
        case savedGuides
        case shareCard
    }

    static let shared = FeatureTipManager()
    private let prefix = "simastry_feature_tip_dismissed_"
    private init() {}

    func shouldShow(_ tip: Tip) -> Bool {
        !UserDefaults.standard.bool(forKey: prefix + tip.rawValue)
    }

    func dismiss(_ tip: Tip) {
        UserDefaults.standard.set(true, forKey: prefix + tip.rawValue)
    }
}
