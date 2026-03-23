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

    static func moderatePublicProfileText(_ text: String) -> ModerationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ModerationResult(isAllowed: true, reason: nil)
        }

        let lowered = trimmed.lowercased()

        for pattern in harmfulPatterns {
            if lowered.contains(pattern) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "That profile text contains content we can't publish."
                )
            }
        }

        for pattern in sensitiveDataPatterns {
            if lowered.contains(pattern) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "Please remove private financial or identity details from your public profile."
                )
            }
        }

        return ModerationResult(isAllowed: true, reason: nil)
    }

    static func moderateDiscoveryMessage(_ text: String) -> ModerationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ModerationResult(
                isAllowed: false,
                reason: "Write a message before sending."
            )
        }

        if trimmed.count > 280 {
            return ModerationResult(
                isAllowed: false,
                reason: "Keep discovery messages under 280 characters."
            )
        }

        let lowered = trimmed.lowercased()

        for pattern in harmfulPatterns {
            if lowered.contains(pattern) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "That message contains content we can't send in discovery."
                )
            }
        }

        for pattern in sensitiveDataPatterns {
            if lowered.contains(pattern) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "Please remove financial or identity details before sending."
                )
            }
        }

        return ModerationResult(isAllowed: true, reason: nil)
    }
}
