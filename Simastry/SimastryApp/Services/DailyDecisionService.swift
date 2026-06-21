import Foundation

nonisolated final class DailyDecisionService {
    private let decoder = JSONDecoder()

    var replyChannel: (@Sendable (_ system: String, _ user: String) async throws -> String)?
    var isRemoteChannelAvailable: (@Sendable () -> Bool)?

    var isConfigured: Bool {
        replyChannel != nil && (isRemoteChannelAvailable?() ?? false)
    }

    init() {}

    func generateDecision(
        category: DailyDecisionCategory,
        context: DailyDecisionContext,
        date: Date = Date()
    ) async -> DailyDecision {
        guard isConfigured, let replyChannel else {
            return Self.fallbackDecision(category: category, context: context, date: date)
        }

        do {
            let text = try await replyChannel(
                makeSystemPrompt(category: category),
                makeUserPrompt(category: category, context: context)
            )
            guard let parsed = parse(text), !parsed.pick.isEmpty, !parsed.whyToday.isEmpty else {
                return Self.fallbackDecision(category: category, context: context, date: date)
            }
            return DailyDecision(
                category: category,
                pick: parsed.pick,
                whyToday: parsed.whyToday,
                tinyNextMove: parsed.tinyNextMove,
                safetyNote: parsed.safetyNote,
                createdAt: date,
                isFallback: false
            )
        } catch {
            return Self.fallbackDecision(category: category, context: context, date: date)
        }
    }

    static func fallbackDecision(
        category: DailyDecisionCategory,
        context: DailyDecisionContext,
        date: Date = Date()
    ) -> DailyDecision {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let signOffset = context.userSunSign.flatMap { ZodiacSign.allCases.firstIndex(of: $0) } ?? 0
        let index = abs(dayOfYear + signOffset) % fallbackLines(for: category).count
        let line = fallbackLines(for: category)[index]

        return DailyDecision(
            category: category,
            pick: line.pick,
            whyToday: line.whyToday,
            tinyNextMove: line.tinyNextMove,
            safetyNote: line.safetyNote,
            createdAt: date,
            isFallback: true
        )
    }

    private func makeSystemPrompt(category: DailyDecisionCategory) -> String {
        """
        You are Simastry's Daily Decider. Help the user make one low-stakes everyday choice.

        \(SimastryVoice.promptBlock)

        Category: \(category.title)

        Rules:
        - Be decisive. Give one clear recommendation, not a menu.
        - Keep the answer short, practical, warm, and a little magical.
        - Do not reference private messages, names, secrets, or content the user did not provide.
        - For food: Do not give medical, diet, weight-loss, allergy, fertility, or nutrition advice.
        - For clothing: never body-shame or imply the user's body needs hiding or fixing.
        - For indecision: reduce overthinking with one tiny action.
        - Return valid JSON with exactly these fields:
          {"pick":"one clear recommendation","why_today":"why this fits today in 1-2 sentences","tiny_next_move":"one tiny action","safety_note":"short caution if needed, otherwise null"}
        - Return ONLY the JSON object, no markdown.
        """
    }

    private func makeUserPrompt(category: DailyDecisionCategory, context: DailyDecisionContext) -> String {
        var sections: [String] = [
            "Decision category:\n\(category.title)",
            "User question:\n\(category.question)",
            "Private message text:\nnot provided"
        ]

        let chartParts = [
            context.userSunSign.map { "Sun in \($0.displayName)" },
            context.userMoonSign.map { "Moon in \($0.displayName)" },
            context.userRisingSign.map { "Rising in \($0.displayName)" }
        ].compactMap { $0 }
        sections.append("User chart:\n\(chartParts.isEmpty ? "unknown" : chartParts.joined(separator: ", "))")

        if let communicationTypeTitle = clean(context.communicationTypeTitle) {
            sections.append("Communication type:\n\(communicationTypeTitle)")
        }

        if let transitHeadline = clean(context.transitHeadline) {
            let transitLine = [transitHeadline, clean(context.transitGuidance)]
                .compactMap { $0 }
                .joined(separator: " - ")
            sections.append("Today's sky:\n\(transitLine)")
        }

        sections.append("Answer with a clear pick, one reason, and one tiny next move.")
        return sections.joined(separator: "\n\n")
    }

    private struct ParsedDecision: Decodable {
        let pick: String
        let whyToday: String
        let tinyNextMove: String
        let safetyNote: String?

        enum CodingKeys: String, CodingKey {
            case pick
            case whyToday = "why_today"
            case tinyNextMove = "tiny_next_move"
            case safetyNote = "safety_note"
        }
    }

    private func parse(_ text: String) -> ParsedDecision? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let data = trimmed.data(using: .utf8),
           let parsed = try? decoder.decode(ParsedDecision.self, from: data) {
            return clean(parsed)
        }

        return ParsedDecision(
            pick: trimmed,
            whyToday: "This is the cleanest low-friction move for today.",
            tinyNextMove: "Choose it now, then stop reopening the decision.",
            safetyNote: nil
        )
    }

    private func clean(_ parsed: ParsedDecision) -> ParsedDecision? {
        guard let pick = clean(parsed.pick),
              let whyToday = clean(parsed.whyToday),
              let tinyNextMove = clean(parsed.tinyNextMove) else {
            return nil
        }
        return ParsedDecision(
            pick: pick,
            whyToday: whyToday,
            tinyNextMove: tinyNextMove,
            safetyNote: clean(parsed.safetyNote)
        )
    }

    private func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func fallbackLines(
        for category: DailyDecisionCategory
    ) -> [(pick: String, whyToday: String, tinyNextMove: String, safetyNote: String?)] {
        switch category {
        case .wear:
            return [
                (
                    "Wear a clean base, one soft layer, and comfortable shoes.",
                    "Simple beats fussy today — let the basics carry it.",
                    "Choose the shoes first, then build everything around them.",
                    nil
                ),
                (
                    "Pick one color that makes you feel awake and keep the rest simple.",
                    "One good accent does more than a busy outfit today.",
                    "Put on the accent piece before you can second-guess it.",
                    nil
                )
            ]
        case .eat:
            return [
                (
                    "Choose something warm, familiar, and grounding.",
                    "Steady beats new today — eat something you already trust.",
                    "Pick the easiest warm option available and add water before anything else.",
                    "Follow any allergies, medical guidance, or dietary needs first."
                ),
                (
                    "Go with a low-drama comfort meal.",
                    "Keep it easy — food doesn't need to be another decision today.",
                    "Choose the place or plate you would recommend to a tired friend.",
                    "This is a vibe suggestion, not medical or nutrition advice."
                )
            ]
        case .focus:
            return [
                (
                    "Do the thing with the clearest next step.",
                    "Momentum beats the perfect plan today — just start.",
                    "Set a 20-minute timer and start before you optimize.",
                    nil
                ),
                (
                    "Focus on the task that removes future noise.",
                    "Close one loop today instead of opening five.",
                    "Write the one sentence that defines done.",
                    nil
                )
            ]
        case .social:
            return [
                (
                    "Send one warm check-in with no hidden agenda.",
                    "Keep it light today — connection doesn't need a production.",
                    "Text the person whose reply would make you smile, then let it breathe.",
                    nil
                ),
                (
                    "Choose the plan that leaves you with energy afterward.",
                    "Pick the closeness that leaves you with energy.",
                    "Say yes to one thing and no to the extra add-on.",
                    nil
                )
            ]
        case .textVibe:
            return [
                (
                    "Keep it warm, short, and specific.",
                    "A little room lands better today — don't over-explain.",
                    "Send one clean sentence and skip the apology preamble.",
                    nil
                ),
                (
                    "Ask the direct question kindly.",
                    "A clear question beats a paragraph today.",
                    "Draft it once, remove one extra sentence, then send.",
                    nil
                )
            ]
        case .dateVibe:
            return [
                (
                    "Go relaxed, curious, and a little playful.",
                    "Be present, not impressive — let the chemistry do the work.",
                    "Pick one easy question you actually want to know.",
                    nil
                ),
                (
                    "Choose simple plans with good lighting and low pressure.",
                    "A calm setting tells you more than a big production.",
                    "Choose the place that makes conversation easiest.",
                    nil
                )
            ]
        }
    }
}
