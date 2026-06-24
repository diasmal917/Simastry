import Foundation

nonisolated struct ContentModerationService {

    struct ModerationResult: Equatable, Sendable {
        let isAllowed: Bool
        let reason: String?
    }

    private static let selfHarmPhrases: [String] = [
        "kill myself", "kill themselves", "suicide", "self-harm", "self harm",
        "want to die", "end my life", "end it all"
    ]

    private static let directThreatPatterns: [String] = [
        #"\b(i\s*(will|'ll|am going to)|i['’]?m going to|i['’]?m gonna|gonna|going to)\s+(kill|hurt|shoot|stab|assault)\s+(you|them|him|her|someone)\b"#,
        #"\b(kill|hurt|shoot|stab)\s+(you|them|him|her|someone)\b"#,
        #"\bviolence against\b"#
    ]

    private static let sexualMinorPatterns: [String] = [
        #"\b(underage|minor|child|kid|teen)\b.{0,64}\b(sex|sexual|nude|nudes|explicit|hook\s*up)\b"#,
        #"\b(sex|sexual|nude|nudes|explicit|hook\s*up)\b.{0,64}\b(underage|minor|child|kid|teen)\b"#
    ]

    private static let coercionPatterns: [String] = [
        #"\b(blackmail|dox|doxx|doxxing)\b"#,
        #"\b(stalk|track|spy on)\s+(them|him|her|my ex|my partner)\b"#,
        #"\bhack\s+(their|his|her)\s+(account|phone|messages|email|icloud|instagram)\b"#,
        #"\b(threaten|manipulate)\s+(them|him|her|my ex|my partner)\b"#,
        #"\bmake\s+(them|him|her|my ex|my partner)\s+jealous\b"#,
        #"\b(get|take)\s+revenge\b|\brevenge\s+on\b"#
    ]

    // Patterns indicating the conversation contains sensitive personal data of others
    private static let sensitiveDataPatterns: [String] = [
        "social security", "ssn", "credit card", "bank account",
        "passport number", "driver's license"
    ]

    static func moderateConversation(_ text: String) -> ModerationResult {
        let lowered = text.lowercased()

        // Check for self-harm/crisis content
        if containsUnsafeContent(lowered) {
            return ModerationResult(
                isAllowed: false,
                reason: "This conversation contains sensitive content that we can't process. If you or someone you know is in crisis, please contact the 988 Suicide & Crisis Lifeline (call or text 988)."
            )
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

        if containsUnsafeContent(lowered) {
            return ModerationResult(
                isAllowed: false,
                reason: "That profile text contains content we can't publish."
            )
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

    static func moderateCalibrationTopic(_ text: String) -> ModerationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ModerationResult(
                isAllowed: false,
                reason: "Add a topic first."
            )
        }

        guard trimmed.count <= 40 else {
            return ModerationResult(
                isAllowed: false,
                reason: "Keep custom topics under 40 characters."
            )
        }

        let profileResult = moderatePublicProfileText(trimmed)
        guard profileResult.isAllowed else {
            return ModerationResult(
                isAllowed: false,
                reason: "That topic contains content we can't save."
            )
        }

        return ModerationResult(isAllowed: true, reason: nil)
    }

    static func moderateGuideMessage(_ text: String) -> ModerationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ModerationResult(
                isAllowed: false,
                reason: "Write a message before sending."
            )
        }

        if trimmed.count > 1_500 {
            return ModerationResult(
                isAllowed: false,
                reason: "Keep guide messages under 1,500 characters."
            )
        }

        let lowered = trimmed.lowercased()
        if containsUnsafeContent(lowered) {
            return ModerationResult(
                isAllowed: false,
                reason: "That message contains content Simastry cannot safely process in AI guide chat."
            )
        }

        for pattern in sensitiveDataPatterns {
            if lowered.contains(pattern) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "Please remove private financial or identity details before sending."
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

        if trimmed.count > 500 {
            return ModerationResult(
                isAllowed: false,
                reason: "Keep discovery messages under 500 characters."
            )
        }

        let lowered = trimmed.lowercased()

        if containsUnsafeContent(lowered) {
            return ModerationResult(
                isAllowed: false,
                reason: "That message contains content we can't send in discovery."
            )
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

    private static func containsUnsafeContent(_ lowered: String) -> Bool {
        containsAnyPhrase(lowered, phrases: selfHarmPhrases)
            || matchesAny(lowered, patterns: directThreatPatterns)
            || matchesAny(lowered, patterns: sexualMinorPatterns)
            || matchesAny(lowered, patterns: coercionPatterns)
    }

    private static func containsAnyPhrase(_ lowered: String, phrases: [String]) -> Bool {
        phrases.contains { lowered.contains($0) }
    }

    private static func matchesAny(_ lowered: String, patterns: [String]) -> Bool {
        patterns.contains { matches(lowered, pattern: $0) }
    }

    private static func matches(_ lowered: String, pattern: String) -> Bool {
        lowered.range(of: pattern, options: .regularExpression) != nil
    }
}
