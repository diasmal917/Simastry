import WidgetKit

struct SimastryTimelineProvider: TimelineProvider {

    // MARK: - Daily insight phrases

    private static let dailyInsights: [String] = [
        "Good energy today — lean in",
        "They might need space. Don't take it personally",
        "Great day for deep conversations",
        "Keep it light today",
        "Your vibes are magnetic right now",
        "A small gesture goes a long way today",
        "Trust your gut on this one",
        "Slow down — patience pays off",
        "Something unexpected could spark a connection",
        "Your empathy is your superpower today",
        "Don't overthink it — just show up",
        "Today's energy favors honesty",
        "A shared laugh will shift everything",
        "Emotional clarity is on your side",
        "Let them come to you today",
        "Adventure energy — say yes to plans",
        "Good day to revisit an old conversation",
        "Boundaries are acts of love too",
        "The stars say: send the first text",
        "Cozy night in beats going out tonight",
        "Creative energy is flowing between you two",
        "Check in on them — they'll appreciate it",
        "Today's cosmic weather: warm and open",
        "A vulnerability moment could deepen things",
        "Your energy is calm and grounding today",
        "Don't force it — let things unfold",
        "Shared silence can be powerful today",
        "Express gratitude — it'll come back tenfold",
        "A turning point may be closer than you think",
        "Today favors playfulness over seriousness",
        "Listen more than you speak today"
    ]

    // MARK: - Helpers

    private func dailyScore(baseScore: Int, for date: Date) -> Int {
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        // Deterministic daily variation seeded by date
        let seed = day &* 2654435761
        let variation = abs(seed % 21) - 10 // -10 to +10
        return max(30, min(98, baseScore + variation))
    }

    private func dailyInsight(for date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let index = day % Self.dailyInsights.count
        return Self.dailyInsights[index]
    }

    private func makeEntry(for date: Date) -> SimastryWidgetEntry {
        guard SharedDefaults.hasCompanionData(),
              let name = SharedDefaults.readCompanionName() else {
            return SimastryWidgetEntry(
                date: date,
                companionName: "",
                companionGlyph: "✦",
                userGlyph: "✦",
                score: 0,
                dailyInsight: "",
                isEmpty: true
            )
        }

        let baseScore = SharedDefaults.readCompatibilityScore()
        let score = dailyScore(baseScore: baseScore, for: date)
        let insight = dailyInsight(for: date)

        return SimastryWidgetEntry(
            date: date,
            companionName: name,
            companionGlyph: SharedDefaults.readCompanionGlyph(),
            userGlyph: SharedDefaults.readUserGlyph(),
            score: score,
            dailyInsight: insight,
            isEmpty: false
        )
    }

    // MARK: - TimelineProvider

    func placeholder(in context: Context) -> SimastryWidgetEntry {
        SimastryWidgetEntry(
            date: Date(),
            companionName: "Luna",
            companionGlyph: "♏︎",
            userGlyph: "♈︎",
            score: 87,
            dailyInsight: "Good energy today — lean in",
            isEmpty: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimastryWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(makeEntry(for: Date()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimastryWidgetEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(for: now)

        // Refresh at midnight for a new daily score and insight
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)

        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}
