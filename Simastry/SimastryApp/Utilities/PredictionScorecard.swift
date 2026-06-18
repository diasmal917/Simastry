import Foundation

struct PredictionScorecard {
    let rated: Int
    let landed: Int
    let line: String?
    let captionLine: String?

    static func from(_ history: [PredictionResult]) -> PredictionScorecard {
        let rated = history.compactMap(\.outcome)
        guard rated.count >= 3 else {
            return PredictionScorecard(rated: rated.count, landed: rated.filter { $0 == .landed }.count, line: nil, captionLine: nil)
        }
        let landed = rated.filter { $0 == .landed }.count
        return PredictionScorecard(
            rated: rated.count,
            landed: landed,
            line: "Called it \(landed) of \(rated.count)",
            captionLine: "called it \(landed)/\(rated.count)"
        )
    }
}
