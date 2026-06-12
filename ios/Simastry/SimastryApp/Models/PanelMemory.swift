import Foundation

/// A lightweight thing the panel remembers — v1: which person from the
/// user's People the conversation touched, and when. The LLM channel gets
/// these as context lines; templates use the most recent one for follow-ups.
nonisolated struct MemoryNote: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let personName: String
    let personId: UUID?
    let createdAt: Date

    init(id: UUID = UUID(), personName: String, personId: UUID?, createdAt: Date = Date()) {
        self.id = id
        self.personName = personName
        self.personId = personId
        self.createdAt = createdAt
    }
}

nonisolated enum PanelMemoryMatcher {
    /// People whose name (or private label) appears as a whole word in the
    /// text. Case-insensitive; names under 3 characters are skipped so short
    /// fragments can't false-match.
    static func mentions(in text: String, people: [RelationshipPerson]) -> [RelationshipPerson] {
        let lowered = text.lowercased()
        return people.filter { person in
            let candidates = [person.name, person.privateLabel ?? ""]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { $0.count >= 3 }

            return candidates.contains { candidate in
                containsWholeWord(candidate, in: lowered)
            }
        }
    }

    private static func containsWholeWord(_ word: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = "\\b\(escaped)\\b"
        return text.range(of: pattern, options: [.regularExpression]) != nil
    }
}
