import Foundation

/// Aggregates rated prediction outcomes into a trust-building accuracy line.
nonisolated struct PredictionScorecard: Equatable, Sendable {
    let rated: Int
    let landed: Int

    static func from(_ history: [PredictionResult]) -> PredictionScorecard {
        let outcomes = history.compactMap(\.outcome)
        return PredictionScorecard(
            rated: outcomes.count,
            landed: outcomes.filter { $0 == .landed }.count
        )
    }

    /// "Called it 7 of 10" — nil until three outcomes are rated, so the stat
    /// never shows on a sample too small to mean anything.
    var line: String? {
        guard rated >= 3 else { return nil }
        return "Called it \(landed) of \(rated)"
    }

    /// Compact Home-metric variant.
    var captionLine: String? {
        guard rated >= 3 else { return nil }
        return "called it \(landed)/\(rated)"
    }
}
