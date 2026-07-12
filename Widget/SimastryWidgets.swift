import WidgetKit
import SwiftUI

@main
struct SimastryWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyNoteWidget()
    }
}

// MARK: - Timeline

struct DailyNoteEntry: TimelineEntry {
    let date: Date
    let sourceName: String
    let notice: String
    let action: String
    let isPlaceholder: Bool

    static let sample = DailyNoteEntry(
        date: .now,
        sourceName: "Simastry",
        notice: "Notice where tone matters more than perfect words today.",
        action: "Choose the first line carefully.",
        isPlaceholder: false
    )

    static let empty = DailyNoteEntry(
        date: .now,
        sourceName: "Simastry",
        notice: "Open Simastry to start your daily guidance.",
        action: "Choose one small action for today.",
        isPlaceholder: true
    )
}

/// Renders the notes the app pre-composed into the shared app group —
/// the widget itself never computes astrology, so it always matches the
/// Today card and the morning notification word for word.
struct DailyNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyNoteEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyNoteEntry) -> Void) {
        completion(currentEntries().first ?? .sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyNoteEntry>) -> Void) {
        var entries = currentEntries()
        if entries.isEmpty {
            entries = [.empty]
        }
        // Flip at the next local midnight (plus a small grace window); the app
        // republishes today+tomorrow whenever it runs.
        let calendar = Calendar.current
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        completion(Timeline(entries: entries, policy: .after(nextMidnight.addingTimeInterval(300))))
    }

    private func currentEntries() -> [DailyNoteEntry] {
        let calendar = Calendar.current
        let now = Date()
        return SharedDefaults.readDailyGuidance()
            .compactMap { guidance -> DailyNoteEntry? in
                guard let day = guidance.date() else { return nil }
                let start = calendar.startOfDay(for: day)
                // Keep today's note (already started) and future days.
                guard let end = calendar.date(byAdding: .day, value: 1, to: start), end > now else { return nil }
                return DailyNoteEntry(
                    date: max(start, calendar.startOfDay(for: now)) == start ? start : start,
                    sourceName: guidance.sourceName,
                    notice: guidance.notice,
                    action: guidance.action,
                    isPlaceholder: false
                )
            }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Widget

struct DailyNoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SimastryDailyNote", provider: DailyNoteProvider()) { entry in
            DailyNoteWidgetView(entry: entry)
                .widgetURL(URL(string: "simastry://home"))
        }
        .configurationDisplayName("Daily guidance")
        .description("One thing to notice and one practical action for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private enum WidgetPalette {
    static let gold = Color(red: 0.85, green: 0.72, blue: 0.45)
    static let goldSoft = Color(red: 0.85, green: 0.72, blue: 0.45).opacity(0.85)
    static let offWhite = Color(red: 0.95, green: 0.94, blue: 0.92)
    static let muted = Color(red: 0.62, green: 0.62, blue: 0.66)
    static let background = Color(red: 0.04, green: 0.04, blue: 0.06)
}

struct DailyNoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyNoteEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.sourceName): \(entry.notice)")
                .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.sourceName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.75)
                Text(entry.notice)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.clear, for: .widget)
        case .systemMedium:
            HStack(spacing: 12) {
                ringBadge(size: 92)

                VStack(alignment: .leading, spacing: 5) {
                    overline
                    Text(entry.notice)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WidgetPalette.offWhite)
                        .lineLimit(3)
                    Text(entry.action)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WidgetPalette.goldSoft)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .containerBackground(WidgetPalette.background, for: .widget)
        default:
            VStack(alignment: .leading, spacing: 6) {
                overline
                Text(entry.notice)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetPalette.offWhite)
                    .lineLimit(4)
                    .minimumScaleFactor(0.9)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) {
                ZStack(alignment: .bottomTrailing) {
                    WidgetPalette.background
                    Image("WidgetRing")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .opacity(0.55)
                        .offset(x: 34, y: 38)
                }
            }
        }
    }

    private var overline: some View {
        Text("TODAY · \(entry.sourceName.uppercased())")
            .font(.system(size: 10, weight: .bold))
            .kerning(1.1)
            .foregroundStyle(WidgetPalette.gold)
            .lineLimit(1)
    }

    private func ringBadge(size: CGFloat) -> some View {
        Image("WidgetRing")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}
