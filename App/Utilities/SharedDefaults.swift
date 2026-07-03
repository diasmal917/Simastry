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

    // MARK: - Clear

    static func clearAll() {
        guard let defaults = shared else { return }
        for key in [Key.companionName, Key.companionSunSign, Key.companionGlyph,
                    Key.userSunSign, Key.userGlyph, Key.compatibilityScore, Key.companionId,
                    dailyNotesKey] {
            defaults.removeObject(forKey: key)
        }
    }
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
