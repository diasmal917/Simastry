import Foundation

/// Sunday "week in review" posted into the panel by a guide — the ritual
/// layer of the meaning loop.
nonisolated struct WeeklyRecapStats: Equatable, Sendable {
    let predictionsMade: Int
    let predictionsRated: Int
    let predictionsLanded: Int
    let panelMessagesSent: Int
    let momentsPosted: Int
    let streak: Int
    let topGuideName: String?

    var isQuietWeek: Bool {
        predictionsMade == 0 && panelMessagesSent == 0 && momentsPosted == 0
    }
}

nonisolated enum WeeklyRecapComposer {
    /// Aggregates the trailing 7 days ending at `weekEnding`.
    static func stats(
        history: [PredictionResult],
        panelMessages: [PanelMessage],
        moments: [Moment],
        streak: Int,
        guideName: (String) -> String?,
        weekEnding: Date,
        calendar: Calendar = .current
    ) -> WeeklyRecapStats {
        let weekStart = calendar.date(byAdding: .day, value: -7, to: weekEnding) ?? weekEnding
        let window = weekStart...weekEnding

        let weekPredictions = history.filter { window.contains($0.createdAt) }
        let weekUserMessages = panelMessages.filter {
            $0.senderId == PanelParticipant.localUserId && window.contains($0.timestamp)
        }
        let weekMoments = moments.filter { window.contains($0.createdAt) }

        let weekGuideMessages = panelMessages.filter {
            $0.senderId != PanelParticipant.localUserId && window.contains($0.timestamp)
        }
        let topGuide = Dictionary(grouping: weekGuideMessages, by: \.senderId)
            .max { $0.value.count < $1.value.count }
            .flatMap { guideName($0.key) }

        return WeeklyRecapStats(
            predictionsMade: weekPredictions.count,
            predictionsRated: weekPredictions.compactMap(\.outcome).count,
            predictionsLanded: weekPredictions.filter { $0.outcome == .landed }.count,
            panelMessagesSent: weekUserMessages.count,
            momentsPosted: weekMoments.count,
            streak: streak,
            topGuideName: topGuide
        )
    }

    /// Guide-voiced recap — always ends with something usable.
    static func recapMessage(stats: WeeklyRecapStats, guideName: String, userFirstName: String?) -> String {
        let name = userFirstName ?? "you"

        if stats.isQuietWeek {
            return "Quiet week, \(name) — those count too. One small read on Monday restarts the rhythm. Anyone you want us to look at first?"
        }

        var parts: [String] = []
        parts.append("Week in review, \(name):")

        if stats.predictionsMade > 0 {
            if stats.predictionsRated > 0 {
                parts.append("\(stats.predictionsMade) prediction\(stats.predictionsMade == 1 ? "" : "s") run — \(stats.predictionsLanded) landed of the \(stats.predictionsRated) you rated.")
            } else {
                parts.append("\(stats.predictionsMade) prediction\(stats.predictionsMade == 1 ? "" : "s") run, none rated yet.")
            }
        }

        var rhythm: [String] = []
        if stats.panelMessagesSent > 0 {
            rhythm.append("\(stats.panelMessagesSent) panel message\(stats.panelMessagesSent == 1 ? "" : "s")")
        }
        if stats.momentsPosted > 0 {
            rhythm.append("\(stats.momentsPosted) moment\(stats.momentsPosted == 1 ? "" : "s")")
        }
        if stats.streak > 1 {
            rhythm.append("a \(stats.streak)-day streak")
        }
        if !rhythm.isEmpty {
            parts.append(rhythm.joined(separator: ", ") + ".")
        }

        if stats.predictionsMade > 0 && stats.predictionsRated < stats.predictionsMade {
            parts.append("Next week's edge: rate the ones you skipped — it sharpens every read we give you.")
        } else {
            parts.append("Next week's edge: bring us the conversation you're most unsure about first.")
        }

        return parts.joined(separator: " ")
    }

    /// "2026-W24" — stable within an ISO week, distinct across weeks.
    static func weekStamp(for date: Date, calendar: Calendar = .current) -> String {
        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.timeZone = calendar.timeZone
        let components = isoCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-W\(components.weekOfYear ?? 0)"
    }
}
