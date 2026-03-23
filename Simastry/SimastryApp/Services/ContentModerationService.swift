import Foundation

struct ContentModerationService {

    struct ModerationResult {
        let isAllowed: Bool
        let reason: String?
    }

    // Keywords/patterns that indicate harmful content
    private static let harmfulPatterns: [String] = [
        "kill myself", "kill themselves", "suicide", "self-harm", "self harm",
        "want to die", "end my life", "end it all",
        "abuse", "assault", "violence against",
        "child abuse", "underage", "minor"
    ]

    // Patterns indicating the conversation contains sensitive personal data of others
    private static let sensitiveDataPatterns: [String] = [
        "social security", "ssn", "credit card", "bank account",
        "passport number", "driver's license"
    ]

    static func moderateConversation(_ text: String) -> ModerationResult {
        let lowered = text.lowercased()

        // Check for self-harm/crisis content
        for pattern in harmfulPatterns {
            if lowered.contains(pattern) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "This conversation contains sensitive content that we can't process. If you or someone you know is in crisis, please contact the 988 Suicide & Crisis Lifeline (call or text 988)."
                )
            }
        }

        // Check for sensitive personal data
        for pattern in sensitiveDataPatterns {
            if lowered.contains(pattern) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "This conversation appears to contain sensitive personal information. Please remove any financial or identity data before pasting."
                )
            }
        }

        // Check minimum length
        if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
            return ModerationResult(
                isAllowed: false,
                reason: "Please paste a longer conversation for a meaningful prediction."
            )
        }

        return ModerationResult(isAllowed: true, reason: nil)
    }
}
