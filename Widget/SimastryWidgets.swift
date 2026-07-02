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
    let expertName: String
    let headline: String
    let move: String
    let isPlaceholder: Bool

    static let sample = DailyNoteEntry(
        date: .now,
        expertName: "Leyla",
        headline: "Mercury is in the same sign as your Moon today.",
        move: "Choose the first line carefully.",
        isPlaceholder: false
    )

    static let empty = DailyNoteEntry(
        date: .now,
        expertName: "Simastry",
        headline: "Open Simastry to start your daily note.",
        move: "Your chosen expert writes one line each morning.",
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
        return SharedDefaults.readDailyNotes()
            .compactMap { note -> DailyNoteEntry? in
                guard let day = note.date() else { return nil }
                let start = calendar.startOfDay(for: day)
                // Keep today's note (already started) and future days.
                guard let end = calendar.date(byAdding: .day, value: 1, to: start), end > now else { return nil }
                return DailyNoteEntry(
                    date: max(start, calendar.startOfDay(for: now)) == start ? start : start,
                    expertName: note.expertName,
                    headline: note.headline,
                    move: note.move,
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
        .configurationDisplayName("Daily note")
        .description("One line from your chosen expert, composed from your saved chart and today's sky.")
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
            Text("\(entry.expertName): \(entry.headline)")
                .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.expertName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.75)
                Text(entry.headline)
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
                    Text(entry.headline)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WidgetPalette.offWhite)
                        .lineLimit(3)
                    Text(entry.move)
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
                Text(entry.headline)
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
        Text("TODAY · \(entry.expertName.uppercased())")
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
