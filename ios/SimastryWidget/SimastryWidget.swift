import WidgetKit
import SwiftUI

struct SimastryWidget: Widget {
    let kind: String = "SimastryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimastryTimelineProvider()) { entry in
            SimastryWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 10/255, green: 14/255, blue: 26/255)
                }
        }
        .configurationDisplayName("Daily Compatibility")
        .description("Your daily compatibility score with your top companion")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

#if DEBUG
#Preview("Small", as: .systemSmall) {
    SimastryWidget()
} timeline: {
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

#Preview("Medium", as: .systemMedium) {
    SimastryWidget()
} timeline: {
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

#Preview("Small Empty", as: .systemSmall) {
    SimastryWidget()
} timeline: {
    SimastryWidgetEntry(
        date: Date(),
        companionName: "",
        companionGlyph: "✦",
        userGlyph: "✦",
        score: 0,
        dailyInsight: "",
        isEmpty: true
    )
}
#endif
