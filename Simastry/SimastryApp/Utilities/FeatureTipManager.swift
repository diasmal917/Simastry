import SwiftUI

/// Manages one-time feature tips/coach marks across the app.
/// Each tip is shown once and then dismissed permanently.
@MainActor
@Observable
final class FeatureTipManager {
    static let shared = FeatureTipManager()

    enum Tip: String, CaseIterable {
        case predictFeature = "tip_predict"
        case savedGuides = "tip_saved_guides"
        case companionDetail = "tip_companion_detail"
        case shareCard = "tip_share_card"
        case communicationGuide = "tip_communication_guide"
    }

    private(set) var dismissedTips: Set<String> = []

    private init() {
        // Load initial state from UserDefaults
        for tip in Tip.allCases {
            if UserDefaults.standard.bool(forKey: tip.rawValue) {
                dismissedTips.insert(tip.rawValue)
            }
        }
    }

    func shouldShow(_ tip: Tip) -> Bool {
        !dismissedTips.contains(tip.rawValue)
    }

    func dismiss(_ tip: Tip) {
        UserDefaults.standard.set(true, forKey: tip.rawValue)
        dismissedTips.insert(tip.rawValue)
    }

    func resetAll() {
        for tip in Tip.allCases {
            UserDefaults.standard.removeObject(forKey: tip.rawValue)
        }
        dismissedTips.removeAll()
    }
}
