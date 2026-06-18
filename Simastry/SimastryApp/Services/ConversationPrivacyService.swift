import Foundation

nonisolated enum ConversationSafetyIssue: String, Codable, Equatable, Sendable {
    case selfHarm
    case directThreat
    case sexualMinor
    case coerciveRelationshipBehavior

    var userMessage: String {
        switch self {
        case .selfHarm:
            return "This looks like it may involve self-harm. Simastry is not the right tool for urgent safety support."
        case .directThreat:
            return "This looks like it may involve a direct threat. Simastry will not generate a reply prediction for it."
        case .sexualMinor:
            return "This looks like it may involve sexual content with a minor. Simastry cannot process it."
        case .coerciveRelationshipBehavior:
            return "Simastry cannot help with stalking, spying, threats, revenge, or manipulation. Try a clean boundary instead."
        }
    }
}

nonisolated struct ConversationPrivacyResult: Codable, Equatable, Sendable {
    let redactedText: String
    let redactedEmails: Int
    let redactedPhoneNumbers: Int
    let redactedLinks: Int
    let redactedHandles: Int
    let safetyIssues: [ConversationSafetyIssue]

    var didRedact: Bool {
        redactedEmails + redactedPhoneNumbers + redactedLinks + redactedHandles > 0
    }

    var canProceed: Bool {
        safetyIssues.isEmpty
    }

    var privacySummary: String? {
        guard didRedact else { return nil }

        var parts: [String] = []
        if redactedEmails > 0 { parts.append("\(redactedEmails) email\(redactedEmails == 1 ? "" : "s")") }
        if redactedPhoneNumbers > 0 { parts.append("\(redactedPhoneNumbers) phone number\(redactedPhoneNumbers == 1 ? "" : "s")") }
        if redactedLinks > 0 { parts.append("\(redactedLinks) link\(redactedLinks == 1 ? "" : "s")") }
        if redactedHandles > 0 { parts.append("\(redactedHandles) handle\(redactedHandles == 1 ? "" : "s")") }

        return "Redacted \(parts.joined(separator: ", ")) before analysis."
    }

    var blockingMessage: String? {
        safetyIssues.first?.userMessage
    }
}

nonisolated final class ConversationPrivacyService {
    func prepare(_ text: String) -> ConversationPrivacyResult {
        var working = text
        var emailCount = 0
        var phoneCount = 0
        var linkCount = 0
        var handleCount = 0

        (working, linkCount) = redact(
            working,
            pattern: #"(?i)\b(?:https?://|www\.)\S+"#,
            replacement: "[link redacted]"
        )
        (working, emailCount) = redact(
            working,
            pattern: #"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            replacement: "[email redacted]"
        )
        (working, phoneCount) = redact(
            working,
            pattern: #"(?<!\w)(?:\+?\d[\d\s().-]{7,}\d)(?!\w)"#,
            replacement: "[phone redacted]"
        )
        (working, handleCount) = redact(
            working,
            pattern: #"(?<![\w.])@[A-Za-z0-9_]{2,32}\b"#,
            replacement: "[handle redacted]"
        )

        return ConversationPrivacyResult(
            redactedText: working,
            redactedEmails: emailCount,
            redactedPhoneNumbers: phoneCount,
            redactedLinks: linkCount,
            redactedHandles: handleCount,
            safetyIssues: safetyIssues(in: text)
        )
    }

    private func redact(_ text: String, pattern: String, replacement: String) -> (String, Int) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (text, 0)
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else { return (text, 0) }

        let mutable = NSMutableString(string: text)
        regex.replaceMatches(
            in: mutable,
            options: [],
            range: NSRange(location: 0, length: mutable.length),
            withTemplate: replacement
        )
        return (String(mutable), matches.count)
    }

    private func safetyIssues(in text: String) -> [ConversationSafetyIssue] {
        let normalized = text.lowercased()
        var issues: [ConversationSafetyIssue] = []

        if matches(normalized, pattern: #"\b(kill myself|end my life|suicide|self[- ]?harm)\b"#) {
            issues.append(.selfHarm)
        }

        if matches(normalized, pattern: #"\b(kill you|hurt you|shoot you|stab you)\b"#) {
            issues.append(.directThreat)
        }

        if matches(normalized, pattern: #"\b(underage|minor|child|kid)\b.{0,48}\b(sex|nude|nudes|hook up)\b"#) {
            issues.append(.sexualMinor)
        }

        if matches(normalized, pattern: #"\b(stalk|track them|spy on|hack|blackmail|dox|threaten|make them jealous|manipulate|revenge)\b"#) {
            issues.append(.coerciveRelationshipBehavior)
        }

        return issues
    }

    private func matches(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
