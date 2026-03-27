import StoreKit
import SwiftUI

/// Prompts for App Store review at optimal moments.
/// Only prompts after positive experiences, max 3 times per year (Apple limit).
@MainActor
final class ReviewPromptService {
    static let shared = ReviewPromptService()

    private let positiveActionsKey = "positiveActionCount"
    private let lastPromptDateKey = "lastReviewPromptDate"
    private let promptCountKey = "reviewPromptCount"

    private init() {}

    /// Call after positive user experiences:
    /// - Viewing a prediction they found insightful
    /// - Saving their 3rd guide
    /// - Creating their 2nd companion
    /// - Sharing a result card
    /// - Completing onboarding
    func recordPositiveAction() {
        let count = UserDefaults.standard.integer(forKey: positiveActionsKey) + 1
        UserDefaults.standard.set(count, forKey: positiveActionsKey)

        // Prompt after 5 positive actions, and not more than once per 60 days
        if count >= 5 && shouldPrompt() {
            requestReview()
        }
    }

    private func shouldPrompt() -> Bool {
        let promptCount = UserDefaults.standard.integer(forKey: promptCountKey)
        if promptCount >= 3 { return false } // Apple's yearly limit

        if let lastPrompt = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            return daysSince >= 60
        }

        return true
    }

    private func requestReview() {
        // Get the current window scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        SKStoreReviewController.requestReview(in: windowScene)

        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)
        let count = UserDefaults.standard.integer(forKey: promptCountKey)
        UserDefaults.standard.set(count + 1, forKey: promptCountKey)

        // Reset positive action count after prompting
        UserDefaults.standard.set(0, forKey: positiveActionsKey)
    }
}
