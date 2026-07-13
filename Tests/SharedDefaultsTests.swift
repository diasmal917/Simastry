import XCTest
@testable import Simastry

@MainActor
final class SharedDefaultsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SharedDefaults.clearAll()
    }

    override func tearDown() {
        SharedDefaults.clearAll()
        super.tearDown()
    }

    func testClearingCompanionDataPreservesGuidanceAndDayWindows() {
        let anchor = Date(timeIntervalSince1970: 1_800_000_000)
        let guidance = DailyGuidance(
            dateKey: "2027-01-15",
            sourceName: "Nadia",
            sourceId: "nadia",
            notice: "Notice the useful opening.",
            action: "Take one clear step."
        )
        let window = makeWindow(
            title: "Favors focused work",
            start: anchor,
            end: anchor.addingTimeInterval(3600)
        )

        SharedDefaults.writeCompanionData(
            companionName: "Alex",
            companionSunSign: "Leo",
            companionGlyph: "LEO",
            userSunSign: "Virgo",
            userGlyph: "VIR",
            compatibilityScore: 84,
            companionId: UUID().uuidString
        )
        SharedDefaults.writeDailyGuidance([guidance])
        SharedDefaults.writeDayWindows([window])

        SharedDefaults.clearCompanionData()

        XCTAssertFalse(SharedDefaults.hasCompanionData())
        XCTAssertEqual(SharedDefaults.readDailyGuidance(), [guidance])
        XCTAssertEqual(SharedDefaults.readDayWindows(), [window])
    }

    func testUnexpiredDayWindowsDropsPastEntriesAndSortsTheRest() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expired = makeWindow(
            title: "Expired",
            start: now.addingTimeInterval(-7200),
            end: now.addingTimeInterval(-3600)
        )
        let active = makeWindow(
            title: "Active",
            start: now.addingTimeInterval(-600),
            end: now.addingTimeInterval(600)
        )
        let future = makeWindow(
            title: "Future",
            start: now.addingTimeInterval(600),
            end: now.addingTimeInterval(1200)
        )
        SharedDefaults.writeDayWindows([future, expired, active])

        XCTAssertEqual(SharedDefaults.readUnexpiredDayWindows(at: now), [active, future])
    }

    private func makeWindow(title: String, start: Date, end: Date) -> SharedDayWindow {
        SharedDayWindow(
            dateKey: "2027-01-15",
            tokenID: "career",
            title: title,
            startsAt: start,
            endsAt: end,
            rationale: "Test rationale"
        )
    }
}
