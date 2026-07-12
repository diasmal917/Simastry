import XCTest
@testable import Simastry

@MainActor
final class BirthChartTrustTests: XCTestCase {
    private let service = BirthChartService()
    private let bangkokLatitude = 13.7563
    private let bangkokLongitude = 100.5018
    private let bangkokTimeZone = TimeZone(identifier: "Asia/Bangkok")!

    override func setUp() {
        super.setUp()
        BirthChartService.setup()
    }

    func testUnknownTimeNeverCalculatesRisingOrHouses() {
        let chart = service.calculate(
            birthday: makeDate(year: 1995, month: 8, day: 12),
            birthTime: nil,
            precision: .unknown,
            uncertaintyMinutes: nil,
            latitude: bangkokLatitude,
            longitude: bangkokLongitude,
            timeZone: bangkokTimeZone
        )

        XCTAssertNil(chart.rising)
        XCTAssertNil(chart.risingSign)
        XCTAssertNil(chart.houseCusps)
        XCTAssertFalse(chart.sun.possibleSigns.isEmpty)
        XCTAssertFalse(chart.moon.possibleSigns.isEmpty)
    }

    func testNilTimeOverridesAnIncorrectExactFlag() {
        let birthday = makeDate(year: 1995, month: 8, day: 12)
        let chart = service.calculate(
            birthday: birthday,
            birthTime: nil,
            precision: .exact,
            uncertaintyMinutes: nil,
            latitude: bangkokLatitude,
            longitude: bangkokLongitude,
            timeZone: bangkokTimeZone
        )
        let record = service.makeNatalChartRecord(
            from: chart,
            birthday: birthday,
            birthTime: nil,
            precision: .exact,
            uncertaintyMinutes: nil,
            birthplace: "Bangkok, Thailand",
            location: ResolvedBirthplace(
                latitude: bangkokLatitude,
                longitude: bangkokLongitude,
                timeZone: bangkokTimeZone
            )
        )

        XCTAssertEqual(record.birthTimePrecision, .unknown)
        XCTAssertNil(record.birthTime)
        XCTAssertNil(record.risingEstimate)
        XCTAssertNil(record.houseCusps)
    }

    func testExactTimeCalculatesOneRisingSignAndTwelveHouses() {
        let date = makeDate(year: 1995, month: 8, day: 12)
        let time = makeDate(year: 2026, month: 1, day: 1, hour: 9, minute: 42)
        let chart = service.calculate(
            birthday: date,
            birthTime: time,
            precision: .exact,
            uncertaintyMinutes: nil,
            latitude: bangkokLatitude,
            longitude: bangkokLongitude,
            timeZone: bangkokTimeZone
        )

        XCTAssertEqual(chart.rising?.possibleSigns.count, 1)
        XCTAssertNotNil(chart.risingSign)
        XCTAssertEqual(chart.houseCusps?.count, 12)
    }

    func testApproximateTimeDoesNotPersistHouses() {
        let date = makeDate(year: 1995, month: 8, day: 12)
        let time = makeDate(year: 2026, month: 1, day: 1, hour: 9, minute: 42)
        let chart = service.calculate(
            birthday: date,
            birthTime: time,
            precision: .approximate,
            uncertaintyMinutes: 30,
            latitude: bangkokLatitude,
            longitude: bangkokLongitude,
            timeZone: bangkokTimeZone
        )

        XCTAssertNotNil(chart.rising)
        XCTAssertNil(chart.houseCusps)
        XCTAssertEqual(chart.risingSign == nil, (chart.rising?.possibleSigns.count ?? 0) != 1)
    }

    func testApproximateRisingShowsPossibilitiesAcrossARealSignBoundary() throws {
        let birthday = makeDate(year: 1995, month: 8, day: 12)
        let candidates = stride(from: 0, to: 24 * 60, by: 20).map { [self] in
            self.makeDate(year: 2026, month: 1, day: 1, hour: $0 / 60, minute: $0 % 60)
        }
        let transitionIndex = zip(candidates, candidates.dropFirst()).enumerated().first { [self] entry in
            let pair = entry.element
            let first = self.service.calculate(
                birthday: birthday,
                birthTime: pair.0,
                precision: .exact,
                uncertaintyMinutes: nil,
                latitude: self.bangkokLatitude,
                longitude: self.bangkokLongitude,
                timeZone: self.bangkokTimeZone
            ).risingSign
            let second = self.service.calculate(
                birthday: birthday,
                birthTime: pair.1,
                precision: .exact,
                uncertaintyMinutes: nil,
                latitude: self.bangkokLatitude,
                longitude: self.bangkokLongitude,
                timeZone: self.bangkokTimeZone
            ).risingSign
            return first != second
        }?.offset

        let index = try XCTUnwrap(transitionIndex)
        let approximate = service.calculate(
            birthday: birthday,
            birthTime: candidates[index + 1],
            precision: .approximate,
            uncertaintyMinutes: 20,
            latitude: bangkokLatitude,
            longitude: bangkokLongitude,
            timeZone: bangkokTimeZone
        )

        XCTAssertGreaterThanOrEqual(approximate.rising?.possibleSigns.count ?? 0, 2)
        XCTAssertNil(approximate.risingSign)
        XCTAssertNotNil(approximate.rising?.disclosure)
    }

    func testUnknownTimeFindsMoonIngressInsteadOfChoosingNoon() throws {
        let ingressChart = try XCTUnwrap((1...31).lazy.compactMap { [self] day -> BirthChartService.BirthChart? in
            let chart = self.service.calculate(
                birthday: self.makeDate(year: 2024, month: 3, day: day),
                birthTime: nil,
                precision: .unknown,
                uncertaintyMinutes: nil,
                latitude: self.bangkokLatitude,
                longitude: self.bangkokLongitude,
                timeZone: self.bangkokTimeZone
            )
            return chart.moon.possibleSigns.count > 1 ? chart : nil
        }.first)

        XCTAssertGreaterThanOrEqual(ingressChart.moon.possibleSigns.count, 2)
        XCTAssertNil(ingressChart.moonSign)
        XCTAssertNotNil(ingressChart.moon.disclosure)
    }

    func testLocalBirthDayUsesDSTLength() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let spring = BirthChartService.localBirthDateInterval(
            birthday: makeDate(year: 2024, month: 3, day: 10),
            selectionTimeZone: .current,
            birthPlaceTimeZone: newYork
        )
        let fall = BirthChartService.localBirthDateInterval(
            birthday: makeDate(year: 2024, month: 11, day: 3),
            selectionTimeZone: .current,
            birthPlaceTimeZone: newYork
        )

        XCTAssertEqual(spring.duration, 23 * 60 * 60 - 1, accuracy: 0.1)
        XCTAssertEqual(fall.duration, 25 * 60 * 60 - 1, accuracy: 0.1)
    }

    func testRepeatedDSTWallTimeRetainsBothPossibleInstants() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let birthday = makeDate(year: 2024, month: 11, day: 3)
        let wallTime = makeDate(year: 2026, month: 1, day: 1, hour: 1, minute: 30)
        let candidates = BirthChartService.combinedDateCandidates(
            birthday: birthday,
            birthTime: wallTime,
            selectionTimeZone: .current,
            birthPlaceTimeZone: newYork
        )

        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(candidates[1].timeIntervalSince(candidates[0]), 60 * 60, accuracy: 0.1)

        let chart = service.calculate(
            birthday: birthday,
            birthTime: wallTime,
            precision: .exact,
            uncertaintyMinutes: nil,
            latitude: 40.7128,
            longitude: -74.0060,
            timeZone: newYork
        )
        XCTAssertEqual(chart.rising?.sampledLongitudes.count, 2)
        XCTAssertNil(chart.houseCusps)
    }

    func testUnknownRecordPersistsNilTimeRisingAndHouses() {
        let birthday = makeDate(year: 1995, month: 8, day: 12)
        let chart = service.calculate(
            birthday: birthday,
            birthTime: nil,
            precision: .unknown,
            uncertaintyMinutes: nil,
            latitude: bangkokLatitude,
            longitude: bangkokLongitude,
            timeZone: bangkokTimeZone
        )
        let record = service.makeNatalChartRecord(
            from: chart,
            birthday: birthday,
            birthTime: nil,
            precision: .unknown,
            uncertaintyMinutes: nil,
            birthplace: "Bangkok, Thailand",
            location: ResolvedBirthplace(
                latitude: bangkokLatitude,
                longitude: bangkokLongitude,
                timeZone: bangkokTimeZone
            )
        )

        XCTAssertNil(record.birthTime)
        XCTAssertNil(record.birthTimeUncertaintyMinutes)
        XCTAssertNil(record.risingEstimate)
        XCTAssertNil(record.houseCusps)
        XCTAssertEqual(record.contextQualitySummary, "Partial chart · Rising sign and houses unavailable")
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
