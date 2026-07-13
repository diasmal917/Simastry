import XCTest
import SwissEphemeris
@testable import Simastry

/// Trust-grade tests for the deterministic day-windows engine. Fixed dates,
/// fixed time zones — the engine must produce identical output for identical
/// inputs, honest clock-bounded intervals, and language that never claims
/// outcomes. The raw `Coordinate`/`Aspect` probes below run from this
/// `@MainActor` class, which shares the executor with `EphemerisActor` — the
/// app's single ephemeris serialization domain.
@MainActor
final class DayWindowsEngineTests: XCTestCase {
    private let bangkok = TimeZone(identifier: "Asia/Bangkok")!
    private let newYork = TimeZone(identifier: "America/New_York")!
    private let longyearbyen = TimeZone(identifier: "Arctic/Longyearbyen")!
    private let bangkokLocation = DayWindowsEngine.GeoLocation(latitude: 13.7563, longitude: 100.5018)
    private let longyearbyenLocation = DayWindowsEngine.GeoLocation(latitude: 78.22, longitude: 15.63)

    override func setUp() {
        super.setUp()
        BirthChartService.setup()
    }

    // MARK: - 1. Stability

    func testFixedDateProducesStableWindows() async throws {
        let anchor = makeDate(2026, 3, 14, 9, 30, in: bangkok)
        let first = await DayWindowsEngine.windows(for: makeInputs(anchor, timeZone: bangkok))
        let second = await DayWindowsEngine.windows(for: makeInputs(anchor, timeZone: bangkok))

        XCTAssertEqual(first, second)
        XCTAssertTrue((3...5).contains(first.windows.count), "expected 3–5 windows, got \(first.windows.count)")
        assertStripIsSortedNonOverlappingAndTilesTheDay(first)

        let midday = first.dayInterval.start.addingTimeInterval(first.dayInterval.duration / 2)
        XCTAssertNotNil(first.window(at: midday))
        let boundary = try XCTUnwrap(first.nextBoundary(after: first.dayInterval.start))
        XCTAssertGreaterThan(boundary, first.dayInterval.start)
        XCTAssertLessThanOrEqual(boundary, first.dayInterval.end)
        XCTAssertNil(first.nextBoundary(after: first.dayInterval.end))
    }

    // MARK: - 2. Time-of-day invariance

    func testDeterministicAcrossTimeOfDaySameDay() async {
        let morning = await DayWindowsEngine.windows(
            for: makeInputs(makeDate(2026, 3, 14, 9, 0, in: bangkok), timeZone: bangkok)
        )
        let evening = await DayWindowsEngine.windows(
            for: makeInputs(makeDate(2026, 3, 14, 21, 0, in: bangkok), timeZone: bangkok)
        )
        XCTAssertEqual(morning, evening)
    }

    // MARK: - 3. Ingress accuracy

    func testMoonIngressAccurateToOneMinute() async throws {
        // 2026-03-14 has a Moon ingress inside the Bangkok local day
        // (verified against the ephemeris: 22:13 local).
        let maybeIngress = await DayWindowsEngine.moonIngress(
            dayContaining: makeDate(2026, 3, 14, in: bangkok),
            timeZone: bangkok
        )
        let ingress = try XCTUnwrap(maybeIngress)
        let boundary = Double(ZodiacSign.allCases.firstIndex(of: ingress.toSign)!) * 30
        let before = Coordinate<Planet>(body: .moon, date: ingress.date.addingTimeInterval(-60))
        let after = Coordinate<Planet>(body: .moon, date: ingress.date.addingTimeInterval(60))
        XCTAssertLessThan(
            DayWindowsEngine.signedDelta(before.longitude, boundary), 0,
            "60 s before the ingress the Moon must still be short of the sign boundary"
        )
        XCTAssertGreaterThan(
            DayWindowsEngine.signedDelta(after.longitude, boundary), 0,
            "60 s after the ingress the Moon must be past the sign boundary"
        )
    }

    // MARK: - 4. Void of course is anchored to a real exact aspect

    func testVoidOfCourseEndsAtIngressAndStartsAtAnExactAspect() async throws {
        let maybeIngress = await DayWindowsEngine.nextMoonIngress(after: makeDate(2026, 3, 14, 0, 0, in: bangkok))
        let ingress = try XCTUnwrap(maybeIngress)
        let maybeVoc = await DayWindowsEngine.voidOfCourse(before: ingress)
        let voc = try XCTUnwrap(maybeVoc)

        XCTAssertEqual(voc.end, ingress.date)
        XCTAssertLessThan(voc.start, voc.end)

        let moon = Coordinate<Planet>(body: .moon, date: voc.start)
        let planet = Coordinate<Planet>(body: voc.lastAspect.planet.planet, date: voc.start)
        XCTAssertNotNil(
            Aspect(a: moon.longitude, b: planet.longitude, orb: 0.05),
            "the void start must be an exact Ptolemaic aspect within 0.05°"
        )

        let laterAspects = await DayWindowsEngine.moonExactAspects(
            in: DateInterval(start: voc.start.addingTimeInterval(120), end: ingress.date.addingTimeInterval(-1))
        )
        XCTAssertTrue(laterAspects.isEmpty, "no exact aspect may exist between the void start and the ingress")
    }

    // MARK: - 5. Midnight-spanning void clamps the interval, keeps the true start

    func testVoidOfCourseSpanningLocalMidnightClampsIntervalButDerivationKeepsTrueStart() async throws {
        // 2026-03-12 Bangkok begins void: the Moon's last exact aspect lands
        // 2026-03-11 16:38 local and the ingress follows 2026-03-12 11:06
        // local (verified against the ephemeris).
        let anchor = makeDate(2026, 3, 12, in: bangkok)
        let result = await DayWindowsEngine.windows(for: makeInputs(anchor, timeZone: bangkok))

        let maybeIngress = await DayWindowsEngine.nextMoonIngress(after: result.dayInterval.start)
        let ingress = try XCTUnwrap(maybeIngress)
        let maybeVoc = await DayWindowsEngine.voidOfCourse(before: ingress)
        let voc = try XCTUnwrap(maybeVoc)
        XCTAssertLessThan(voc.start, result.dayInterval.start, "premise: the void must begin before local midnight")

        let vocWindow = try XCTUnwrap(result.windows.first { $0.kind == .voidOfCourse })
        XCTAssertEqual(vocWindow.interval.start, result.dayInterval.start, "the strip interval clamps to the day")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = bangkok
        formatter.dateFormat = "h:mm a"
        let trueStart = "yesterday \(formatter.string(from: voc.start))"
        XCTAssertTrue(
            vocWindow.derivation.contains(trueStart),
            "derivation must keep the true start (\(trueStart)); got: \(vocWindow.derivation)"
        )
    }

    // MARK: - 6/7. DST days are fully covered

    func testSpringForwardDayIsFullyCovered() async {
        let result = await DayWindowsEngine.windows(
            for: makeInputs(makeDate(2026, 3, 8, 12, 0, in: newYork), timeZone: newYork)
        )
        XCTAssertEqual(result.dayInterval.duration, 23 * 3600, accuracy: 1)
        assertStripIsSortedNonOverlappingAndTilesTheDay(result)
    }

    func testFallBackDayIsFullyCovered() async {
        let result = await DayWindowsEngine.windows(
            for: makeInputs(makeDate(2026, 11, 1, 12, 0, in: newYork), timeZone: newYork)
        )
        XCTAssertEqual(result.dayInterval.duration, 25 * 3600, accuracy: 1)
        assertStripIsSortedNonOverlappingAndTilesTheDay(result)
    }

    // MARK: - 8. Polar days: no planetary hours, moon windows intact

    func testPolarSummerAndWinterSkipPlanetaryHoursButKeepMoonWindows() async {
        let anchors = [
            makeDate(2026, 6, 20, in: longyearbyen),
            makeDate(2026, 12, 21, in: longyearbyen)
        ]
        for anchor in anchors {
            let hours = await DayWindowsEngine.planetaryHours(
                dayContaining: anchor,
                timeZone: longyearbyen,
                location: longyearbyenLocation
            )
            XCTAssertNil(hours, "circumpolar rise/set must clamp to nil")
            let result = await DayWindowsEngine.windows(
                for: makeInputs(anchor, timeZone: longyearbyen, location: longyearbyenLocation)
            )
            XCTAssertTrue(
                (3...5).contains(result.windows.count),
                "moon-derived strip must survive polar days, got \(result.windows.count)"
            )
            assertStripIsSortedNonOverlappingAndTilesTheDay(result)
        }
    }

    // MARK: - 9. Planetary hours structure

    func testPlanetaryHoursTwelveDayTwelveNightContiguous() async throws {
        let anchor = makeDate(2026, 3, 14, in: bangkok)
        let maybeHours = await DayWindowsEngine.planetaryHours(
            dayContaining: anchor,
            timeZone: bangkok,
            location: bangkokLocation
        )
        let hours = try XCTUnwrap(maybeHours)

        XCTAssertEqual(hours.count, 24)
        XCTAssertEqual(hours.filter(\.isDaytime).count, 12)
        XCTAssertEqual(hours.prefix(12).filter(\.isDaytime).count, 12, "the twelve day-hours come first")
        for (current, next) in zip(hours, hours.dropFirst()) {
            XCTAssertEqual(
                current.interval.end.timeIntervalSince1970,
                next.interval.start.timeIntervalSince1970,
                accuracy: 1,
                "hours must be contiguous"
            )
        }

        let day = DayWindowsEngine.localDayInterval(containing: anchor, timeZone: bangkok)
        XCTAssertTrue(day.contains(hours[0].interval.start), "sunrise anchors the first hour inside the local day")
        let span = hours[23].interval.end.timeIntervalSince(hours[0].interval.start)
        XCTAssertEqual(span, 24 * 3600, accuracy: 20 * 60, "sunrise to next sunrise spans roughly one day")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = bangkok
        let weekday = calendar.component(.weekday, from: day.start)
        XCTAssertEqual(hours[0].ruler, DayWindowsEngine.weekdayRulers[weekday - 1])
        XCTAssertEqual(hours[0].ruler, .saturn, "2026-03-14 is a Saturday, so the first hour belongs to Saturn")
    }

    // MARK: - 10. Provenance gating of the all-day context

    func testProvenanceGatingOfDailyTransitContext() async {
        let anchor = makeDate(2026, 3, 14, in: bangkok)
        let without = await DayWindowsEngine.windows(for: makeInputs(anchor, timeZone: bangkok))
        XCTAssertNil(without.allDayContext, "no natal signs ⇒ no natal context line")

        let with = await DayWindowsEngine.windows(
            for: makeInputs(anchor, timeZone: bangkok, sun: .leo, moon: .scorpio, rising: .virgo)
        )
        XCTAssertNotNil(with.allDayContext)
        XCTAssertEqual(with.allDayContext?.kind, .dailyTransit)
        XCTAssertEqual(with.allDayContext?.interval, with.dayInterval)
        XCTAssertFalse(
            with.windows.contains { $0.kind == .dailyTransit },
            "the natal context is a context line, never a strip segment"
        )
        XCTAssertEqual(without.windows, with.windows, "natal data must not change the sky strip")
    }

    // MARK: - 11. Language lint: 366 days × 3 styles × every kind

    func testWindowLanguageNeverClaimsOutcomes() {
        let allowedPrefixes = ["Favors", "Leans", "Good window for", "Quiet"]
        let richLeads = [" — favors", " — leans", " — quiet", " — good window"]
        let forbidden = ["will happen", "guaranteed", "bad", "avoid", "unlucky", "you will"]

        for dayOfYear in 1...366 {
            for style in GuidanceStyle.allCases {
                for entry in DayWindowCopy.lintCorpus(dayOfYear: dayOfYear, style: style) {
                    let title = entry.title
                    let startsAllowed = allowedPrefixes.contains { title.hasPrefix($0) }
                    if style == .astrologyRich {
                        let leadsWithFact = richLeads.contains { title.contains($0) }
                        XCTAssertTrue(
                            startsAllowed || leadsWithFact,
                            "day \(dayOfYear) \(style) \(entry.kind): bad lead-in: \(title)"
                        )
                    } else {
                        XCTAssertTrue(
                            startsAllowed,
                            "day \(dayOfYear) \(style) \(entry.kind): title must start with Favors/Leans/Good window for/Quiet: \(title)"
                        )
                    }
                    let haystack = "\(title) \(entry.rationale)".lowercased()
                    for phrase in forbidden {
                        XCTAssertFalse(
                            haystack.contains(phrase),
                            "day \(dayOfYear) \(style) \(entry.kind): forbidden phrase '\(phrase)' in: \(haystack)"
                        )
                    }
                    XCTAssertFalse(title.contains("°"), "degree language never belongs in titles: \(title)")
                    XCTAssertFalse(entry.rationale.contains("°"), "degree language never belongs in rationales: \(entry.rationale)")
                }
            }
        }
    }

    // MARK: - 12. Evidence shape

    func testEveryWindowEvidenceIsCalculatedAndSupportsTiming() async {
        let anchor = makeDate(2026, 3, 14, in: bangkok)
        let result = await DayWindowsEngine.windows(
            for: makeInputs(anchor, timeZone: bangkok, sun: .leo, moon: .scorpio, rising: .virgo)
        )
        var allWindows = result.windows
        if let context = result.allDayContext { allWindows.append(context) }
        XCTAssertFalse(allWindows.isEmpty)
        for window in allWindows {
            XCTAssertEqual(window.evidence.basis, .calculated, "\(window.kind) evidence must be calculated")
            XCTAssertTrue(window.evidence.supportsTiming, "\(window.kind) evidence must support timing")
            XCTAssertTrue(
                window.evidence.detail.localizedCaseInsensitiveContains("today only"),
                "\(window.kind) evidence detail needs the today-only scope: \(window.evidence.detail)"
            )
        }
    }

    // MARK: - 13. Style changes wording, never intervals

    func testGuidanceStyleChangesWordingNotIntervals() async {
        let anchor = makeDate(2026, 3, 14, in: bangkok)
        let practical = await DayWindowsEngine.windows(for: makeInputs(anchor, timeZone: bangkok, style: .practical))
        let balanced = await DayWindowsEngine.windows(for: makeInputs(anchor, timeZone: bangkok, style: .balanced))
        let rich = await DayWindowsEngine.windows(for: makeInputs(anchor, timeZone: bangkok, style: .astrologyRich))

        XCTAssertEqual(practical.windows.map(\.interval), rich.windows.map(\.interval))
        XCTAssertEqual(practical.windows.map(\.interval), balanced.windows.map(\.interval))
        XCTAssertEqual(practical.windows.map(\.kind), rich.windows.map(\.kind))
        XCTAssertEqual(practical.windows.map(\.derivation), rich.windows.map(\.derivation), "derivations are sky facts, not style copy")
        XCTAssertNotEqual(practical.windows.map(\.title), rich.windows.map(\.title), "styles must actually change wording")
    }

    // MARK: - 14. Performance budget

    // Synchronous on purpose: XCTest forbids `wait(for:)` inside async test
    // methods, and `measure {}` has no async variant, so the async engine is
    // driven through expectations; the work runs on the ephemeris actor's
    // own executor while the main run loop pumps the task resumption.
    func testPerformanceBudget() {
        let engineInputs = makeInputs(
            makeDate(2026, 3, 14, in: bangkok),
            timeZone: bangkok,
            sun: .leo, moon: .scorpio, rising: .virgo
        )

        func computeOnce() -> TimeInterval {
            let done = expectation(description: "windows computation")
            let start = CFAbsoluteTimeGetCurrent()
            Task {
                _ = await DayWindowsEngine.windows(for: engineInputs)
                done.fulfill()
            }
            wait(for: [done], timeout: 10)
            return CFAbsoluteTimeGetCurrent() - start
        }

        _ = computeOnce() // warm the ephemeris file cache
        let elapsed = computeOnce()
        XCTAssertLessThan(elapsed, 0.2, "one full windows(for:) computation must stay under 200 ms")

        measure {
            _ = computeOnce()
        }
    }

    // MARK: - 15. Concurrency: hammered engine + chart service match serial baselines

    /// Regression guard for the single ephemeris serialization domain. Runs
    /// sanitizer-free: it guards via determinism-equality (plus the executor
    /// identity assertion), not TSan. If the engine loses its actor
    /// isolation, or `EphemerisActor` gets rebound to the main executor and
    /// re-stalls first paint, this test goes red.
    func testConcurrentEngineAndChartAccessMatchesSerialBaselines() async {
        await Task.detached {
            await Self.assertEphemerisDomainRunsOffTheMainThread()
        }.value

        let cases: [DayWindowsEngine.Inputs] = [
            makeInputs(makeDate(2026, 3, 12, in: bangkok), timeZone: bangkok),
            makeInputs(makeDate(2026, 3, 14, in: bangkok), timeZone: bangkok, sun: .leo, moon: .scorpio, rising: .virgo),
            makeInputs(makeDate(2026, 3, 8, in: newYork), timeZone: newYork),
            makeInputs(makeDate(2026, 11, 1, in: newYork), timeZone: newYork),
            makeInputs(makeDate(2026, 12, 21, in: longyearbyen), timeZone: longyearbyen)
        ]

        var baselines: [DayWindowsResult] = []
        for engineInputs in cases {
            baselines.append(await DayWindowsEngine.windows(for: engineInputs))
        }
        let frozenBaselines = baselines

        let service = BirthChartService()
        let birthday = makeDate(1995, 8, 12, in: bangkok)
        let birthTime = makeDate(2026, 1, 1, 9, 42, in: bangkok)
        func computeChart() async -> BirthChartService.BirthChart {
            await service.calculate(
                birthday: birthday,
                birthTime: birthTime,
                precision: .exact,
                uncertaintyMinutes: nil,
                latitude: bangkokLocation.latitude,
                longitude: bangkokLocation.longitude,
                timeZone: bangkok
            )
        }
        let chartBaseline = await computeChart()

        await withTaskGroup(of: (Int, DayWindowsResult).self) { group in
            for _ in 0..<4 {
                for (index, engineInputs) in cases.enumerated() {
                    group.addTask {
                        (index, await DayWindowsEngine.windows(for: engineInputs))
                    }
                }
            }

            // Interleave chart computations with the hammering detached
            // tasks; both contend for the ephemeris actor and must serialize.
            for _ in 0..<3 {
                let chart = await computeChart()
                XCTAssertEqual(chart.sun, chartBaseline.sun)
                XCTAssertEqual(chart.moon, chartBaseline.moon)
                XCTAssertEqual(chart.rising, chartBaseline.rising)
                XCTAssertEqual(chart.houseCusps, chartBaseline.houseCusps)
                await Task.yield()
            }

            for await (index, result) in group {
                XCTAssertEqual(
                    result, frozenBaselines[index],
                    "concurrent invocation for case \(index) must equal the serial baseline"
                )
            }
        }
    }

    @EphemerisActor
    private static func assertEphemerisDomainRunsOffTheMainThread() {
        XCTAssertFalse(
            Thread.isMainThread,
            "EphemerisActor must run on its own executor so ephemeris work stays off the main thread; if you rebind it to the main executor, migrate every ephemeris facade and this tripwire in the same change"
        )
    }

    // MARK: - 16. Reading evidence row (D4)

    /// Compass bearings attach the current window as reading evidence so a
    /// reply can echo real clock bounds honestly. This is a pure
    /// transformation (`DayWindow.readingEvidenceRow`) independent of the
    /// engine's own computation, so it is fixture-driven rather than
    /// engine-driven like the tests above.
    func testCurrentWindowEvidenceRowIsCalculatedAndSupportsTiming() {
        let window = DayWindow(
            kind: .moonAspect,
            interval: DateInterval(start: makeDate(2026, 3, 14, 9, 0, in: bangkok), duration: 3600),
            tokenID: "career",
            title: "Good window for a decisive push",
            rationale: "An easy stretch — momentum tends to work with you.",
            derivation: "Moon trine Mars at 9:00 AM; separates by 10:00 AM.",
            evidence: ReadingEvidence(
                basis: .calculated,
                label: "Moon trine Mars",
                detail: "Moon trine Mars at 9:00 AM. Scope: today only.",
                supportsTiming: true
            )
        )

        let row = window.readingEvidenceRow

        XCTAssertEqual(row.basis, .calculated)
        XCTAssertTrue(row.supportsTiming)
        XCTAssertTrue(
            row.detail.localizedCaseInsensitiveContains("today"),
            "evidence row must carry the today-only scope: \(row.detail)"
        )
        XCTAssertTrue(row.detail.contains(window.title), "evidence row should echo the window's title")
        XCTAssertTrue(row.detail.contains(window.derivation), "evidence row should echo the window's sky-fact derivation")
    }

    // MARK: - Shared assertions & helpers

    private func assertStripIsSortedNonOverlappingAndTilesTheDay(
        _ result: DayWindowsResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let windows = result.windows
        XCTAssertFalse(windows.isEmpty, "strip must never be empty", file: file, line: line)
        XCTAssertEqual(
            windows.first?.interval.start, result.dayInterval.start,
            "strip starts at the day start", file: file, line: line
        )
        XCTAssertEqual(
            windows.last?.interval.end, result.dayInterval.end,
            "strip ends at the day end", file: file, line: line
        )
        for window in windows {
            XCTAssertGreaterThanOrEqual(window.interval.start, result.dayInterval.start, file: file, line: line)
            XCTAssertLessThanOrEqual(window.interval.end, result.dayInterval.end, file: file, line: line)
        }
        for (current, next) in zip(windows, windows.dropFirst()) {
            XCTAssertEqual(
                current.interval.end.timeIntervalSince1970,
                next.interval.start.timeIntervalSince1970,
                accuracy: 0.5,
                "windows and gaps must union to the exact day (no overlap, no hole)",
                file: file,
                line: line
            )
        }
    }

    private func makeInputs(
        _ date: Date,
        timeZone: TimeZone,
        location: DayWindowsEngine.GeoLocation? = nil,
        sun: ZodiacSign? = nil,
        moon: ZodiacSign? = nil,
        rising: ZodiacSign? = nil,
        style: GuidanceStyle = .balanced
    ) -> DayWindowsEngine.Inputs {
        DayWindowsEngine.Inputs(
            date: date,
            timeZone: timeZone,
            location: location,
            natalSun: sun,
            natalMoon: moon,
            natalRising: rising,
            style: style
        )
    }

    private func makeDate(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0,
        in timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }
}
