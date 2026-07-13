import Foundation

enum SharedDefaults {
    static let suiteName = "group.com.simastry.shared"

    enum Key {
        static let companionName = "widgetCompanionName"
        static let companionSunSign = "widgetCompanionSunSign"
        static let companionGlyph = "widgetCompanionGlyph"
        static let userSunSign = "widgetUserSunSign"
        static let userGlyph = "widgetUserGlyph"
        static let compatibilityScore = "widgetCompatibilityScore"
        static let companionId = "widgetCompanionId"
    }

    static var shared: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Write (called from main app)

    static func writeCompanionData(
        companionName: String,
        companionSunSign: String,
        companionGlyph: String,
        userSunSign: String,
        userGlyph: String,
        compatibilityScore: Int,
        companionId: String
    ) {
        guard let defaults = shared else { return }
        defaults.set(companionName, forKey: Key.companionName)
        defaults.set(companionSunSign, forKey: Key.companionSunSign)
        defaults.set(companionGlyph, forKey: Key.companionGlyph)
        defaults.set(userSunSign, forKey: Key.userSunSign)
        defaults.set(userGlyph, forKey: Key.userGlyph)
        defaults.set(compatibilityScore, forKey: Key.compatibilityScore)
        defaults.set(companionId, forKey: Key.companionId)
    }

    // MARK: - Read (called from widget)

    static func readCompanionName() -> String? {
        shared?.string(forKey: Key.companionName)
    }

    static func readCompanionGlyph() -> String {
        shared?.string(forKey: Key.companionGlyph) ?? "SIM"
    }

    static func readUserGlyph() -> String {
        shared?.string(forKey: Key.userGlyph) ?? "YOU"
    }

    static func readCompatibilityScore() -> Int {
        shared?.integer(forKey: Key.compatibilityScore) ?? 0
    }

    static func readCompanionId() -> String? {
        shared?.string(forKey: Key.companionId)
    }

    static func hasCompanionData() -> Bool {
        readCompanionName() != nil
    }

    // MARK: - Daily expert note (widget)

    static let dailyNotesKey = "widgetDailyNotes"
    static let dailyGuidanceKey = "widgetDailyGuidance"

    /// Publishes the canonical daily guidance used by Home, Compass, the
    /// widget, and notifications. Keeping one encoded record prevents those
    /// surfaces from quietly giving different advice for the same day.
    static func writeDailyGuidance(_ guidance: [DailyGuidance]) {
        guard let defaults = shared, let data = try? JSONEncoder().encode(guidance) else { return }
        defaults.set(data, forKey: dailyGuidanceKey)
    }

    static func readDailyGuidance() -> [DailyGuidance] {
        guard let defaults = shared else { return [] }

        if let data = defaults.data(forKey: dailyGuidanceKey),
           let guidance = try? JSONDecoder().decode([DailyGuidance].self, from: data) {
            return guidance
        }

        // Build 1 compatibility: retain the note when upgrading instead of
        // leaving the widget blank before the app republishes.
        return readDailyNotes().map(DailyGuidance.init(legacyNote:))
    }

    /// The app pre-composes today's and tomorrow's notes; the widget only
    /// renders them, so it always matches the Today card and the push.
    static func writeDailyNotes(_ notes: [SharedDailyNote]) {
        guard let defaults = shared, let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: dailyNotesKey)
    }

    static func readDailyNotes() -> [SharedDailyNote] {
        guard let defaults = shared,
              let data = defaults.data(forKey: dailyNotesKey),
              let notes = try? JSONDecoder().decode([SharedDailyNote].self, from: data) else {
            return []
        }
        return notes
    }

    // MARK: - Day windows (widget)

    static let dayWindowsKey = "widgetDayWindows"

    /// The app pre-composes today's and tomorrow's honest, time-bounded
    /// windows (style-resolved, final strings); the widget only ever renders
    /// them, never computing astrology itself — same contract as
    /// `writeDailyNotes`/`readDailyNotes`.
    static func writeDayWindows(_ windows: [SharedDayWindow]) {
        guard let defaults = shared, let data = try? JSONEncoder().encode(windows) else { return }
        defaults.set(data, forKey: dayWindowsKey)
    }

    static func readDayWindows() -> [SharedDayWindow] {
        guard let defaults = shared,
              let data = defaults.data(forKey: dayWindowsKey),
              let windows = try? JSONDecoder().decode([SharedDayWindow].self, from: data) else {
            return []
        }
        return windows
    }

    static func readUnexpiredDayWindows(at date: Date = Date()) -> [SharedDayWindow] {
        readDayWindows()
            .filter { $0.endsAt > date }
            .sorted { $0.startsAt < $1.startsAt }
    }

    // MARK: - Clear

    /// Removes only the legacy companion widget payload. Daily guidance and
    /// Compass windows belong to separate widgets and must survive mode
    /// changes or an empty companion list.
    static func clearCompanionData() {
        guard let defaults = shared else { return }
        for key in [Key.companionName, Key.companionSunSign, Key.companionGlyph,
                    Key.userSunSign, Key.userGlyph, Key.compatibilityScore, Key.companionId] {
            defaults.removeObject(forKey: key)
        }
    }

    static func clearAll() {
        guard let defaults = shared else { return }
        clearCompanionData()
        for key in [dailyNotesKey, dailyGuidanceKey, dayWindowsKey] {
            defaults.removeObject(forKey: key)
        }
    }
}

/// One trustworthy record for every daily surface.
///
/// `notice` and `action` are useful without astrology. The rationale is
/// optional and stays visibly separate so interpreted material never looks
/// like an observed fact.
nonisolated struct DailyGuidance: Codable, Equatable, Identifiable, Sendable {
    let dateKey: String
    let sourceName: String
    let sourceId: String
    let notice: String
    let action: String
    let astrologicalRationale: String?
    let eveningCheckIn: String?

    var id: String { dateKey }

    init(
        dateKey: String,
        sourceName: String,
        sourceId: String,
        notice: String,
        action: String,
        astrologicalRationale: String? = nil,
        eveningCheckIn: String? = nil
    ) {
        self.dateKey = dateKey
        self.sourceName = sourceName
        self.sourceId = sourceId
        self.notice = notice
        self.action = action
        self.astrologicalRationale = astrologicalRationale
        self.eveningCheckIn = eveningCheckIn
    }

    init(legacyNote: SharedDailyNote) {
        self.init(
            dateKey: legacyNote.dateKey,
            sourceName: legacyNote.expertName,
            sourceId: "legacy-daily-note",
            notice: legacyNote.headline,
            action: legacyNote.move,
            eveningCheckIn: "Tonight, note what changed after you tried this."
        )
    }

    static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func date(calendar: Calendar = .current) -> Date? {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// One honest, time-bounded Compass window as shared with the widget
/// extension. A flattened, pre-composed mirror of `DayWindow` — the widget
/// target compiles only `Widget/` + this file (see Project.json), so it
/// never sees `DayWindow`, `ReadingEvidence`, or any other App model; the
/// app resolves the final style-aware strings once and writes them here.
struct SharedDayWindow: Codable, Equatable {
    /// Local-calendar day the window belongs to, "yyyy-MM-dd".
    let dateKey: String
    /// `SimastryCategoryToken.rawValue`; the widget resolves its own color.
    let tokenID: String
    /// "Favors hard conversations" — never an outcome claim.
    let title: String
    let startsAt: Date
    let endsAt: Date
    /// Style-aware one-liner (why, honestly).
    let rationale: String
}

/// One day's expert note as shared with the widget extension.
struct SharedDailyNote: Codable, Equatable {
    /// Local-calendar day, "yyyy-MM-dd".
    let dateKey: String
    let expertName: String
    let headline: String
    let move: String

    static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func date(calendar: Calendar = .current) -> Date? {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
