import XCTest
@testable import Simastry

final class DailyGuidanceTests: XCTestCase {
    func testDailyGuidanceRoundTripsWithOptionalRationale() throws {
        let guidance = DailyGuidance(
            dateKey: "2026-07-10",
            sourceName: "Simastry",
            sourceId: "practical",
            notice: "Notice the conversation you keep rehearsing.",
            action: "Write one clear first line.",
            astrologicalRationale: nil,
            eveningCheckIn: "What changed after you tried it?"
        )

        let data = try JSONEncoder().encode(guidance)
        let decoded = try JSONDecoder().decode(DailyGuidance.self, from: data)

        XCTAssertEqual(decoded, guidance)
        XCTAssertNil(decoded.astrologicalRationale)
    }

    func testLegacyDailyNoteUpgradesWithoutInventingAstrology() {
        let legacy = SharedDailyNote(
            dateKey: "2026-07-10",
            expertName: "Leyla",
            headline: "A saved note",
            move: "Take one pause before replying."
        )

        let upgraded = DailyGuidance(legacyNote: legacy)

        XCTAssertEqual(upgraded.notice, legacy.headline)
        XCTAssertEqual(upgraded.action, legacy.move)
        XCTAssertNil(upgraded.astrologicalRationale)
    }
}

@MainActor
final class StreakManagerTests: XCTestCase {
    func testStreakAdvancesOnlyForCompletedMeaningfulActions() throws {
        let suiteName = "StreakManagerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let manager = StreakManager(defaults: defaults, calendar: calendar)
        let today = calendar.startOfDay(for: Date())

        XCTAssertEqual(manager.currentStreak, 0)
        manager.recordMeaningfulAction(.readingCompleted, at: today)
        XCTAssertEqual(manager.currentStreak, 1)

        manager.recordMeaningfulAction(.journalEntry, at: today.addingTimeInterval(60))
        XCTAssertEqual(manager.currentStreak, 1, "More actions on one day must not inflate a streak")
        XCTAssertEqual(manager.lastMeaningfulAction, .journalEntry)

        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))
        manager.recordMeaningfulAction(.outcomeCheckIn, at: tomorrow)
        XCTAssertEqual(manager.currentStreak, 2)
    }
}
