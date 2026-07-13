import WidgetKit
import SwiftUI

@main
struct SimastryWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyNoteWidget()
        CurrentWindowWidget()
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

    // MARK: - Category token colors
    //
    // The widget target compiles only Widget/ + SharedDefaults.swift (see
    // Project.json's SimastryWidgets sources), so it cannot import
    // `SimastryCategoryToken` or `SimastryColor` from the App module. These
    // six values are hand-copied from their source of truth:
    //   - token → color mapping: App/Views/Components/CategoryToken.swift
    //     (`SimastryCategoryToken.color`)
    //   - RGB values: App/Utilities/SimastryDesign.swift (`SimastryColor`)
    // Keep in sync by hand if either changes.
    static let tokenLove = Color(red: 255 / 255, green: 138 / 255, blue: 101 / 255)      // SimastryColor.sunCoral
    static let tokenMarriage = Color(red: 214 / 255, green: 130 / 255, blue: 172 / 255)  // SimastryColor.orchidPink
    static let tokenFamily = Color(red: 126 / 255, green: 168 / 255, blue: 120 / 255)    // SimastryColor.sageGreen
    static let tokenCareer = Color(red: 96 / 255, green: 156 / 255, blue: 245 / 255)     // SimastryColor.celestialBlue
    static let tokenMoney = Color(red: 224 / 255, green: 186 / 255, blue: 98 / 255)      // SimastryColor.gold
    static let tokenPersonal = Color(red: 178 / 255, green: 140 / 255, blue: 255 / 255)  // SimastryColor.risingViolet

    /// Resolves a `SimastryCategoryToken.rawValue` string to its color.
    /// Unknown ids (there shouldn't be any — the engine only emits the six
    /// known tokens) fall back to `tokenPersonal`, the engine's own default
    /// for ungrouped sky facts (VoC, quiet, outer planets).
    static func tokenColor(forTokenID tokenID: String) -> Color {
        switch tokenID {
        case "love": tokenLove
        case "marriage": tokenMarriage
        case "family": tokenFamily
        case "career": tokenCareer
        case "money": tokenMoney
        case "personal": tokenPersonal
        default: tokenPersonal
        }
    }
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

// MARK: - Current window

struct CurrentWindowEntry: TimelineEntry {
    let date: Date
    let title: String
    let tokenID: String
    /// `nil` only for `.empty` — the fallback entry never claims a real window.
    let until: Date?
    let isPlaceholder: Bool

    static let sample = CurrentWindowEntry(
        date: .now,
        title: "Favors focused, heads-down work",
        tokenID: "career",
        until: Date().addingTimeInterval(2 * 3600),
        isPlaceholder: false
    )

    static func empty(at date: Date = .now) -> CurrentWindowEntry {
        CurrentWindowEntry(
            date: date,
            title: "Open Simastry to compute today's windows.",
            tokenID: "personal",
            until: nil,
            isPlaceholder: true
        )
    }
}

/// Renders the windows the app pre-composed into the shared app group — the
/// widget itself never touches the ephemeris, so its "now" always agrees
/// with Compass's Now dial. One timeline entry per window boundary
/// (`startsAt`); WidgetKit always displays whichever entry's date is the
/// latest one at or before the real time, so a flat per-boundary list is
/// enough to track "now" across a reload without any duration math here.
struct CurrentWindowProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrentWindowEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentWindowEntry) -> Void) {
        completion(context.isPreview ? .sample : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrentWindowEntry>) -> Void) {
        let now = Date()
        let windows = SharedDefaults.readUnexpiredDayWindows(at: now)
        guard !windows.isEmpty else {
            // Nothing usable is published yet (or the cached payload has
            // expired). Show the honest fallback and request a future reload.
            let calendar = Calendar.current
            let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
                ?? now.addingTimeInterval(3600)
            let reloadDate = max(nextMidnight.addingTimeInterval(300), now.addingTimeInterval(60))
            completion(Timeline(entries: [.empty(at: now)], policy: .after(reloadDate)))
            return
        }

        var entries: [CurrentWindowEntry] = []
        if let active = windows.first(where: { $0.startsAt <= now && now < $0.endsAt }) {
            entries.append(CurrentWindowEntry(
                date: now,
                title: active.title,
                tokenID: active.tokenID,
                until: active.endsAt,
                isPlaceholder: false
            ))
        } else {
            entries.append(.empty(at: now))
        }

        entries.append(contentsOf: windows.filter { $0.startsAt > now }.map { window in
            CurrentWindowEntry(
                date: window.startsAt,
                title: window.title,
                tokenID: window.tokenID,
                until: window.endsAt,
                isPlaceholder: false
            )
        })
        let lastBoundary = windows.map(\.endsAt).max() ?? now.addingTimeInterval(60)
        completion(Timeline(entries: entries, policy: .after(max(lastBoundary, now.addingTimeInterval(60)))))
    }

    private func currentEntry() -> CurrentWindowEntry {
        let now = Date()
        guard let window = SharedDefaults.readDayWindows().first(where: { $0.startsAt <= now && now < $0.endsAt }) else {
            return .empty(at: now)
        }
        return CurrentWindowEntry(date: now, title: window.title, tokenID: window.tokenID, until: window.endsAt, isPlaceholder: false)
    }
}

// MARK: - Widget

struct CurrentWindowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SimastryCurrentWindow", provider: CurrentWindowProvider()) { entry in
            CurrentWindowEntryView(entry: entry)
                .widgetURL(URL(string: "simastry://predict"))
        }
        .configurationDisplayName("Current window")
        .description("The honest, time-bounded window Compass says favors right now.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct CurrentWindowEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CurrentWindowEntry

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private var untilText: String? {
        guard let until = entry.until else { return nil }
        return "until \(Self.timeFormatter.string(from: until))"
    }

    private var tokenColor: Color {
        WidgetPalette.tokenColor(forTokenID: entry.tokenID)
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
                .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                if let untilText {
                    Text(untilText)
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.75)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.clear, for: .widget)
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(tokenColor)
                        .frame(width: 18, height: 5)
                    Text(entry.isPlaceholder ? "COMPASS" : "NOW")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1.1)
                        .foregroundStyle(tokenColor)
                }
                Text(entry.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetPalette.offWhite)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
                if let untilText {
                    Text(untilText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WidgetPalette.muted)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(WidgetPalette.background, for: .widget)
        }
    }

    private var inlineText: String {
        if let untilText {
            return "\(entry.title) · \(untilText)"
        }
        return entry.title
    }
}
