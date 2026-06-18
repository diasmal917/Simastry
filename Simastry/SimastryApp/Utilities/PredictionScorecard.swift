import Foundation

struct PredictionScorecard {
    let line: String?

    static func from(_ history: [PredictionResult]) -> PredictionScorecard {
        let rated = history.compactMap(\.outcome)
        guard !rated.isEmpty else { return PredictionScorecard(line: nil) }
        let landed = rated.filter { $0 == .landed }.count
        return PredictionScorecard(line: "\(landed)/\(rated.count) landed")
    }
}
