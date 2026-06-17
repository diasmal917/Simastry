import Foundation
import SwissEphemeris

/// Calculates accurate Sun, Moon, and Rising (Ascendant) signs using the Swiss Ephemeris.
@MainActor
final class BirthChartService {

    /// Result of a birth chart calculation.
    struct BirthChart: Sendable {
        let sunSign: ZodiacSign
        let moonSign: ZodiacSign
        let risingSign: ZodiacSign?
        let sunDegree: Double
        let moonDegree: Double
        let risingDegree: Double?
    }

    /// Initialize the ephemeris file path. Call once at app startup.
    static func setup() {
        JPLFileManager.setEphemerisPath()
    }

    /// Calculate a birth chart from birth details.
    /// - Parameters:
    ///   - birthday: The date of birth.
    ///   - birthTime: The time of birth (optional — needed for Rising sign).
    ///   - latitude: Birth location latitude (optional — needed for Rising sign).
    ///   - longitude: Birth location longitude (optional — needed for Rising sign).
    /// - Returns: A `BirthChart` with accurate sign placements.
    func calculate(
        birthday: Date,
        birthTime: Date?,
        latitude: Double?,
        longitude: Double?
    ) -> BirthChart {
        // Combine birthday date with birth time
        let chartDate = combinedDate(birthday: birthday, birthTime: birthTime)

        // Sun position
        let sunCoord = Coordinate<Planet>(body: .sun, date: chartDate)
        let sunLongitude = sunCoord.longitude
        let sunSign = signFromLongitude(sunLongitude)

        // Moon position
        let moonCoord = Coordinate<Planet>(body: .moon, date: chartDate)
        let moonLongitude = moonCoord.longitude
        let moonSign = signFromLongitude(moonLongitude)

        // Rising sign (Ascendant) — requires birth time and location
        var risingSign: ZodiacSign? = nil
        var risingDegree: Double? = nil

        if birthTime != nil, let lat = latitude, let lon = longitude {
            let houses = HouseCusps(
                date: chartDate,
                latitude: lat,
                longitude: lon,
                houseSystem: .placidus
            )
            let ascLongitude = houses.ascendent.tropical.value
            risingSign = signFromLongitude(ascLongitude)
            risingDegree = ascLongitude
        }

        return BirthChart(
            sunSign: sunSign,
            moonSign: moonSign,
            risingSign: risingSign,
            sunDegree: sunLongitude,
            moonDegree: moonLongitude,
            risingDegree: risingDegree
        )
    }

    // MARK: - Private

    /// Combine a birthday (date only) with a birth time into a single Date.
    private func combinedDate(birthday: Date, birthTime: Date?) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: birthday)

        guard let birthTime else {
            // Default to noon if no birth time
            var components = dateComponents
            components.hour = 12
            components.minute = 0
            return calendar.date(from: components) ?? birthday
        }

        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: birthTime)
        var combined = dateComponents
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second
        return calendar.date(from: combined) ?? birthday
    }

    /// Convert ecliptic longitude (0–360°) to a zodiac sign.
    private func signFromLongitude(_ longitude: Double) -> ZodiacSign {
        let normalized = ((longitude.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int(normalized / 30.0) % 12
        return ZodiacSign.allCases[index]
    }
}
