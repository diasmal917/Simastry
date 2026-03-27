import WidgetKit

struct SimastryWidgetEntry: TimelineEntry {
    let date: Date
    let companionName: String
    let companionGlyph: String
    let userGlyph: String
    let score: Int
    let dailyInsight: String
    let isEmpty: Bool
}
