import XCTest
@testable import Simastry

/// The landing screen's current-window line must be the real engine output
/// in the dial's own format — and honestly absent (nil) whenever there is
/// nothing computed to show, because the landing never falls back to canned
/// data.
@MainActor
final class LandingNowLineTests: XCTestCase {
    private let bangkok = TimeZone(identifier: "Asia/Bangkok")!

    override func setUp() {
        super.setUp()
        BirthChartService.setup()
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = bangkok
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func guestResult(for date: Date) async -> DayWindowsResult {
        let inputs = DayWindowsEngine.Inputs(
            date: date,
            timeZone: bangkok,
            natalSun: nil,
            natalMoon: nil,
            natalRising: nil,
            style: .practical
        )
        return await DayWindowsEngine.windows(for: inputs)
    }

    func testComposeMatchesTheDialFormatForTheActiveWindow() async {
        let now = makeDate(2026, 3, 14, hour: 10)
        let result = await guestResult(for: now)

        guard let line = LandingNowLine.compose(result: result, now: now) else {
            return XCTFail("An in-day moment must always compose a line — the engine tiles the whole day")
        }

        let expectedWindow = result.window(at: now)
        XCTAssertEqual(line.window, expectedWindow, "The line must be the engine's own active window")

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        XCTAssertEqual(
            line.untilText,
            "until \(formatter.string(from: line.window.interval.end))",
            "The until text must match the dial's format exactly"
        )
    }

    func testComposeIsNilWithoutAResult() {
        XCTAssertNil(LandingNowLine.compose(result: nil, now: makeDate(2026, 3, 14, hour: 10)))
    }

    func testComposeIsNilOutsideTheComputedDay() async {
        let computedFor = makeDate(2026, 3, 14, hour: 10)
        let result = await guestResult(for: computedFor)

        let tomorrow = makeDate(2026, 3, 15, hour: 10)
        XCTAssertNil(
            LandingNowLine.compose(result: result, now: tomorrow),
            "A stale result must hide the line, never show yesterday's window"
        )
    }
}
