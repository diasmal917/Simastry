import Foundation

final class ReviewPromptService {
    static let shared = ReviewPromptService()
    private init() {}

    func recordPositiveAction() {
        let key = "positiveActionCount"
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }
}
