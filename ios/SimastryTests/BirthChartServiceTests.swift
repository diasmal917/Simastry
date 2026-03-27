import Foundation
import Testing
@testable import Simastry

struct BirthChartServiceTests {
    @Test func combinedDateUsesBirthplaceTimezoneWithoutChangingSelectedBirthdayOrTime() {
        let selectionTimeZone = try! #require(TimeZone(identifier: "Asia/Bangkok"))
        let newYorkTimeZone = try! #require(TimeZone(identifier: "America/New_York"))
        let tokyoTimeZone = try! #require(TimeZone(identifier: "Asia/Tokyo"))

        let birthday = makeSelectionDate(
            year: 1990,
            month: 1,
            day: 15,
            hour: 0,
            minute: 0,
            timeZone: selectionTimeZone
        )
        let birthTime = makeSelectionDate(
            year: 2001,
            month: 1,
            day: 1,
            hour: 8,
            minute: 30,
            timeZone: selectionTimeZone
        )

        let newYorkCombined = BirthChartService.combinedDate(
            birthday: birthday,
            birthTime: birthTime,
            selectionTimeZone: selectionTimeZone,
            birthPlaceTimeZone: newYorkTimeZone
        )
        let tokyoCombined = BirthChartService.combinedDate(
            birthday: birthday,
            birthTime: birthTime,
            selectionTimeZone: selectionTimeZone,
            birthPlaceTimeZone: tokyoTimeZone
        )

        #expect(components(of: newYorkCombined, in: newYorkTimeZone).year == 1990)
        #expect(components(of: newYorkCombined, in: newYorkTimeZone).month == 1)
        #expect(components(of: newYorkCombined, in: newYorkTimeZone).day == 15)
        #expect(components(of: newYorkCombined, in: newYorkTimeZone).hour == 8)
        #expect(components(of: newYorkCombined, in: newYorkTimeZone).minute == 30)
        #expect(newYorkCombined != tokyoCombined)
    }
}

private func makeSelectionDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int,
    timeZone: TimeZone
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone

    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.timeZone = timeZone

    return calendar.date(from: components)!
}

private func components(of date: Date, in timeZone: TimeZone) -> DateComponents {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
}
