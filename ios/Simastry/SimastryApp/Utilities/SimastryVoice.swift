import Foundation

/// The tone constitution — one source of truth for how every guide speaks,
/// in templates and in LLM prompts. The anti-Co-Star position: warm, never
/// deflating, always actionable.
nonisolated enum SimastryVoice {
    static let rules: [String] = [
        "Warm beats blunt; blunt beats vague.",
        "Never deflate: no verdicts on the user or the other person — describe behavior, not worth.",
        "Always end with something usable: a line to send, a move to make, or a question to answer.",
        "Name the user sparingly but deliberately — once at most per message.",
        "No doom language: no 'never', no 'they've already decided', no 'red flag' framing."
    ]

    static var promptBlock: String {
        "Voice rules: " + rules.joined(separator: " ")
    }
}
