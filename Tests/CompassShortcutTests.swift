import XCTest
@testable import Simastry

/// Stage 6 trust tests: the Shortcuts surface must stay as honest as the
/// dial it mirrors. `CurrentWindowIntent` only ever re-reads the published
/// widget payload (no ephemeris, no network, no credits), scoped to today;
/// `QuickBearingIntent`'s options arm exactly the drafts the in-app bearing
/// cards arm, through raw values that are a persisted contract.
@MainActor
final class CompassShortcutTests: XCTestCase {
    private let calendar = Calendar.current
    /// Fixed local day (house pattern: fixed dates, deterministic output).
    /// `dialLine` takes `now` explicitly, so nothing here depends on the
    /// wall clock — the assertions cannot drift across a midnight run.
    private lazy var baseDay: Date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!

    private lazy var clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private func date(atHour hour: Int, dayOffset: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: baseDay)!
        return calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    private func window(title: String, fromHour: Int, toHour: Int, dayOffset: Int = 0) -> SharedDayWindow {
        let start = date(atHour: fromHour, dayOffset: dayOffset)
        return SharedDayWindow(
            dateKey: DailyGuidance.dateKey(for: start),
            tokenID: "career",
            title: title,
            startsAt: start,
            endsAt: date(atHour: toHour, dayOffset: dayOffset),
            rationale: "Test rationale"
        )
    }

    // MARK: - Current window line

    func testDialLineForActiveWindowMatchesTheDial() {
        let active = window(title: "Favors focused work", fromHour: 9, toHour: 11)
        let later = window(title: "Favors honest conversations", fromHour: 13, toHour: 15)
        let line = CurrentWindowIntent.dialLine(
            windows: [active, later],
            now: date(atHour: 10),
            calendar: calendar
        )
        XCTAssertEqual(line, "Favors focused work — until \(clockFormatter.string(from: active.endsAt)).")
    }

    func testDialLineBetweenWindowsPointsToTodaysNext() {
        let earlier = window(title: "Favors steady focus", fromHour: 7, toHour: 9)
        let next = window(title: "Favors honest conversations", fromHour: 13, toHour: 15)
        let line = CurrentWindowIntent.dialLine(
            windows: [earlier, next],
            now: date(atHour: 10),
            calendar: calendar
        )
        XCTAssertEqual(
            line,
            "Between windows right now. Next: Favors honest conversations, from \(clockFormatter.string(from: next.startsAt))."
        )
    }

    func testDialLineNeverReachesIntoTomorrow() {
        // Scope is "today only": with nothing left today, tomorrow's windows
        // must not be offered as the next thing — the honest fallback wins.
        let expired = window(title: "Favors steady focus", fromHour: 7, toHour: 9)
        let tomorrow = window(title: "Favors fresh starts", fromHour: 9, toHour: 11, dayOffset: 1)
        let line = CurrentWindowIntent.dialLine(
            windows: [expired, tomorrow],
            now: date(atHour: 22),
            calendar: calendar
        )
        XCTAssertEqual(line, "Open Simastry to compute today's windows.")
    }

    func testDialLineFallsBackWhenPayloadIsEmpty() {
        let line = CurrentWindowIntent.dialLine(windows: [], now: date(atHour: 10), calendar: calendar)
        XCTAssertEqual(line, "Open Simastry to compute today's windows.")
    }

    // MARK: - Quick bearing contract

    func testBearingOptionsArmExactlyTheInAppBearingDrafts() {
        // Must stay in lockstep with `SimulateView.compassBearingItems`:
        // same intent/topic, same deterministic question salts, and the same
        // love-specific preview bank — a Siri-armed read shows the question
        // the on-screen card shows that day.
        XCTAssertEqual(CompassBearingShortcutOption.work.draftIntent, .general)
        XCTAssertEqual(CompassBearingShortcutOption.work.draftTopic, .work)
        XCTAssertEqual(CompassBearingShortcutOption.work.questionSalt, 0)
        XCTAssertNil(CompassBearingShortcutOption.work.questionBank)

        XCTAssertEqual(CompassBearingShortcutOption.love.draftIntent, .general)
        XCTAssertEqual(CompassBearingShortcutOption.love.draftTopic, .relationships)
        XCTAssertEqual(CompassBearingShortcutOption.love.questionSalt, 1)
        XCTAssertEqual(CompassBearingShortcutOption.love.questionBank, .loveTiming)

        XCTAssertEqual(CompassBearingShortcutOption.money.draftIntent, .general)
        XCTAssertEqual(CompassBearingShortcutOption.money.draftTopic, .money)
        XCTAssertEqual(CompassBearingShortcutOption.money.questionSalt, 2)
        XCTAssertNil(CompassBearingShortcutOption.money.questionBank)

        XCTAssertEqual(CompassBearingShortcutOption.timing.draftIntent, .timing)
        XCTAssertNil(CompassBearingShortcutOption.timing.draftTopic)
        XCTAssertEqual(CompassBearingShortcutOption.timing.questionSalt, 3)
        XCTAssertNil(CompassBearingShortcutOption.timing.questionBank)
    }

    func testBearingRawValuesAreAStableContract() {
        // Written to UserDefaults by a donated Shortcuts intent and read
        // back after the next app launch — renaming a case breaks every
        // shortcut a user has already saved.
        XCTAssertEqual(
            CompassBearingShortcutOption.allCases.map(\.rawValue),
            ["work", "love", "money", "timing"]
        )
    }
}
