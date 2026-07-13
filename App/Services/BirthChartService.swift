import Foundation
import SwissEphemeris

/// Calculates tropical natal placements with explicit birth-time uncertainty.
/// The service never substitutes a made-up birth time for an unknown one.
///
/// The facade stays `@MainActor`, but every raw ephemeris touch
/// (`Coordinate`/`HouseCusps` sampling) hops onto `EphemerisActor` — the
/// app's single ephemeris serialization domain — so chart calculation can
/// never race the day-windows engine or the transit readers
/// (see EphemerisActor.swift). `calculate` is therefore async.
@MainActor
final class BirthChartService {
    struct BirthChart: Sendable {
        let sun: PlacementEstimate
        let moon: PlacementEstimate
        let rising: PlacementEstimate?
        let houseCusps: [Double]?

        var sunSign: ZodiacSign? { sun.resolvedSign }
        var moonSign: ZodiacSign? { moon.resolvedSign }
        var risingSign: ZodiacSign? { rising?.resolvedSign }
        var sunDegree: Double? { sun.representativeLongitude }
        var moonDegree: Double? { moon.representativeLongitude }
        var risingDegree: Double? { rising?.representativeLongitude }

        var isPartial: Bool {
            sunSign == nil || moonSign == nil || risingSign == nil || houseCusps == nil
        }
    }

    /// Initialize the ephemeris file path. Call once at app startup.
    static func setup() {
        JPLFileManager.setEphemerisPath()
    }

    /// Compatibility overload. Existing callers with a time are exact; a nil
    /// time is unknown and therefore cannot produce Rising or houses.
    func calculate(
        birthday: Date,
        birthTime: Date?,
        latitude: Double?,
        longitude: Double?,
        timeZone: TimeZone?
    ) async -> BirthChart {
        await calculate(
            birthday: birthday,
            birthTime: birthTime,
            precision: birthTime == nil ? .unknown : .exact,
            uncertaintyMinutes: nil,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone
        )
    }

    /// Calculates placements across the complete interval implied by the
    /// user's answer. Unknown time samples the full local birth date;
    /// approximate time samples `time ± uncertaintyMinutes`.
    func calculate(
        birthday: Date,
        birthTime: Date?,
        precision: BirthTimePrecision,
        uncertaintyMinutes: Int?,
        latitude: Double?,
        longitude: Double?,
        timeZone: TimeZone?
    ) async -> BirthChart {
        let effectivePrecision: BirthTimePrecision = birthTime == nil ? .unknown : precision
        let birthPlaceTimeZone = timeZone ?? .current
        let calculation = calculationSamples(
            birthday: birthday,
            birthTime: birthTime,
            precision: effectivePrecision,
            uncertaintyMinutes: uncertaintyMinutes,
            birthPlaceTimeZone: birthPlaceTimeZone
        )
        let interval = calculation.interval
        let sampleDates = calculation.dates

        let sun = await placementEstimate(body: .sun, dates: sampleDates, interval: interval)
        let moon = await placementEstimate(body: .moon, dates: sampleDates, interval: interval)

        guard effectivePrecision != .unknown,
              birthTime != nil,
              let latitude,
              let longitude else {
            return BirthChart(sun: sun, moon: moon, rising: nil, houseCusps: nil)
        }

        let risingSamples = await Self.ascendantLongitudes(
            dates: sampleDates,
            latitude: latitude,
            longitude: longitude
        )
        let rising = estimate(
            longitudes: risingSamples,
            interval: interval,
            representativeLongitude: risingSamples[safe: risingSamples.count / 2]
        )

        // A single exact wall-clock time can support a house calculation.
        // Approximate and unknown times intentionally do not persist houses.
        let cusps: [Double]?
        if effectivePrecision == .exact, sampleDates.count == 1, let date = sampleDates.first {
            cusps = await Self.houseCuspLongitudes(date: date, latitude: latitude, longitude: longitude)
        } else {
            cusps = nil
        }

        return BirthChart(sun: sun, moon: moon, rising: rising, houseCusps: cusps)
    }

    func makeNatalChartRecord(
        from chart: BirthChart,
        birthday: Date,
        birthTime: Date?,
        precision: BirthTimePrecision,
        uncertaintyMinutes: Int?,
        birthplace: String,
        location: ResolvedBirthplace
    ) -> NatalChartRecord {
        let effectivePrecision: BirthTimePrecision = birthTime == nil ? .unknown : precision
        return NatalChartRecord(
            userId: nil,
            birthDate: Self.wallClockDateString(birthday, timeZone: .current),
            birthTime: effectivePrecision.requiresBirthTime
                ? birthTime.map { Self.wallClockTimeString($0, timeZone: .current) }
                : nil,
            birthTimePrecision: effectivePrecision,
            birthTimeUncertaintyMinutes: effectivePrecision == .approximate
                ? min(max(1, uncertaintyMinutes ?? 60), 720)
                : nil,
            birthPlace: birthplace,
            timeZoneIdentifier: location.timeZone.identifier,
            latitude: location.latitude,
            longitude: location.longitude,
            sunEstimate: chart.sun,
            moonEstimate: chart.moon,
            risingEstimate: effectivePrecision == .unknown ? nil : chart.rising,
            houseCusps: effectivePrecision == .exact ? chart.houseCusps : nil,
            calculationVersion: NatalChartRecord.currentCalculationVersion,
            provenance: .calculated,
            confirmedAt: Date(),
            createdAt: nil,
            updatedAt: nil
        )
    }

    // MARK: - Time ranges

    nonisolated static func combinedDate(
        birthday: Date,
        birthTime: Date?,
        selectionTimeZone: TimeZone = .current,
        birthPlaceTimeZone: TimeZone?
    ) -> Date {
        combinedDateCandidates(
            birthday: birthday,
            birthTime: birthTime,
            selectionTimeZone: selectionTimeZone,
            birthPlaceTimeZone: birthPlaceTimeZone
        ).first ?? birthday
    }

    /// Returns both real instants when a local wall time repeats at a daylight
    /// saving transition. A clock time alone cannot distinguish those instants,
    /// so both must remain possible even when the user entered it exactly.
    nonisolated static func combinedDateCandidates(
        birthday: Date,
        birthTime: Date?,
        selectionTimeZone: TimeZone = .current,
        birthPlaceTimeZone: TimeZone?
    ) -> [Date] {
        var selectionCalendar = Calendar(identifier: .gregorian)
        selectionCalendar.timeZone = selectionTimeZone
        let dateComponents = selectionCalendar.dateComponents([.year, .month, .day], from: birthday)

        guard let birthTime else {
            var birthCalendar = Calendar(identifier: .gregorian)
            birthCalendar.timeZone = birthPlaceTimeZone ?? selectionTimeZone
            var components = dateComponents
            components.hour = 12
            components.minute = 0
            components.second = 0
            return [birthCalendar.date(from: components) ?? birthday]
        }

        let timeComponents = selectionCalendar.dateComponents([.hour, .minute, .second], from: birthTime)
        var combined = dateComponents
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second

        var birthCalendar = Calendar(identifier: .gregorian)
        birthCalendar.timeZone = birthPlaceTimeZone ?? selectionTimeZone
        var midnightComponents = dateComponents
        midnightComponents.hour = 0
        midnightComponents.minute = 0
        midnightComponents.second = 0
        guard let midnight = birthCalendar.date(from: midnightComponents) else {
            return [birthCalendar.date(from: combined) ?? birthday]
        }

        var clock = DateComponents()
        clock.hour = timeComponents.hour
        clock.minute = timeComponents.minute
        clock.second = timeComponents.second
        let searchStart = midnight.addingTimeInterval(-1)
        let first = birthCalendar.nextDate(
            after: searchStart,
            matching: clock,
            matchingPolicy: .strict,
            repeatedTimePolicy: .first,
            direction: .forward
        )
        let last = birthCalendar.nextDate(
            after: searchStart,
            matching: clock,
            matchingPolicy: .strict,
            repeatedTimePolicy: .last,
            direction: .forward
        )

        let expectedDate = (dateComponents.year, dateComponents.month, dateComponents.day)
        let candidates = [first, last].compactMap { candidate -> Date? in
            guard let candidate else { return nil }
            let components = birthCalendar.dateComponents([.year, .month, .day], from: candidate)
            guard (components.year, components.month, components.day) == expectedDate else { return nil }
            return candidate
        }
        let unique = Array(Set(candidates)).sorted()
        return unique.isEmpty ? [birthCalendar.date(from: combined) ?? birthday] : unique
    }

    nonisolated static func localBirthDateInterval(
        birthday: Date,
        selectionTimeZone: TimeZone = .current,
        birthPlaceTimeZone: TimeZone
    ) -> DateInterval {
        var selectionCalendar = Calendar(identifier: .gregorian)
        selectionCalendar.timeZone = selectionTimeZone
        let components = selectionCalendar.dateComponents([.year, .month, .day], from: birthday)

        var birthCalendar = Calendar(identifier: .gregorian)
        birthCalendar.timeZone = birthPlaceTimeZone
        let start = birthCalendar.date(from: components) ?? birthday
        let end = birthCalendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(24 * 60 * 60)
        return DateInterval(start: start, end: end.addingTimeInterval(-1))
    }

    private func calculationSamples(
        birthday: Date,
        birthTime: Date?,
        precision: BirthTimePrecision,
        uncertaintyMinutes: Int?,
        birthPlaceTimeZone: TimeZone
    ) -> (interval: DateInterval, dates: [Date]) {
        if precision == .unknown || birthTime == nil {
            let interval = Self.localBirthDateInterval(
                birthday: birthday,
                birthPlaceTimeZone: birthPlaceTimeZone
            )
            return (interval, datesToSample(in: interval, step: 60 * 60))
        }

        let centers = Self.combinedDateCandidates(
            birthday: birthday,
            birthTime: birthTime,
            birthPlaceTimeZone: birthPlaceTimeZone
        )
        guard precision == .approximate else {
            let start = centers.first ?? birthday
            let end = centers.last ?? start
            return (DateInterval(start: start, end: end), centers)
        }

        let normalizedMinutes = min(max(1, uncertaintyMinutes ?? 60), 720)
        let seconds = TimeInterval(normalizedMinutes * 60)
        let ranges = centers.map {
            DateInterval(
                start: $0.addingTimeInterval(-seconds),
                end: $0.addingTimeInterval(seconds)
            )
        }
        let dates = Array(Set(ranges.flatMap { datesToSample(in: $0, step: 10 * 60) })).sorted()
        let start = ranges.first?.start ?? birthday
        let end = ranges.last?.end ?? start
        return (DateInterval(start: start, end: end), dates)
    }

    private func datesToSample(in interval: DateInterval, step: TimeInterval) -> [Date] {
        guard interval.duration > 0 else { return [interval.start] }

        var dates: [Date] = [interval.start]
        var next = interval.start.addingTimeInterval(step)
        while next < interval.end {
            dates.append(next)
            next = next.addingTimeInterval(step)
        }
        dates.append(interval.end)
        return dates
    }

    // MARK: - Placements

    private func placementEstimate(
        body: Planet,
        dates: [Date],
        interval: DateInterval
    ) async -> PlacementEstimate {
        let longitudes = await Self.sampledLongitudes(body: body, dates: dates)
        return estimate(
            longitudes: longitudes,
            interval: interval,
            representativeLongitude: longitudes[safe: longitudes.count / 2]
        )
    }

    // MARK: - Raw ephemeris sampling (single serialization domain)

    @EphemerisActor
    private static func sampledLongitudes(body: Planet, dates: [Date]) -> [Double] {
        dates.map { Coordinate<Planet>(body: body, date: $0).longitude }
    }

    @EphemerisActor
    private static func ascendantLongitudes(dates: [Date], latitude: Double, longitude: Double) -> [Double] {
        dates.map { date in
            HouseCusps(
                date: date,
                latitude: latitude,
                longitude: longitude,
                houseSystem: .placidus
            ).ascendent.tropical.value
        }
    }

    @EphemerisActor
    private static func houseCuspLongitudes(date: Date, latitude: Double, longitude: Double) -> [Double] {
        let houses = HouseCusps(
            date: date,
            latitude: latitude,
            longitude: longitude,
            houseSystem: .placidus
        )
        return [
            houses.first, houses.second, houses.third, houses.fourth,
            houses.fifth, houses.sixth, houses.seventh, houses.eighth,
            houses.ninth, houses.tenth, houses.eleventh, houses.twelfth
        ].map { $0.tropical.value }
    }

    private func estimate(
        longitudes: [Double],
        interval: DateInterval,
        representativeLongitude: Double?
    ) -> PlacementEstimate {
        var seen: Set<ZodiacSign> = []
        let signs = longitudes.compactMap { longitude -> ZodiacSign? in
            let sign = signFromLongitude(longitude)
            return seen.insert(sign).inserted ? sign : nil
        }
        return PlacementEstimate(
            possibleSigns: signs,
            representativeLongitude: representativeLongitude,
            sampledLongitudes: longitudes,
            rangeStart: interval.start,
            rangeEnd: interval.end,
            capability: .calculated
        )
    }

    private func signFromLongitude(_ longitude: Double) -> ZodiacSign {
        let normalized = ((longitude.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int(normalized / 30.0) % 12
        return ZodiacSign.allCases[index]
    }

    nonisolated private static func wallClockDateString(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    nonisolated private static func wallClockTimeString(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return String(
            format: "%02d:%02d:%02d",
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
