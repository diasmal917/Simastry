import Foundation
import SwissEphemeris

/// Computes today's honest, time-bounded astrological windows from the real
/// sky (Swiss Ephemeris) — deterministic, on-device, and free of natal claims.
///
/// Trust contract:
/// - Degree/clock phrasing appears only in `derivation` strings and only for
///   transiting-to-transiting sky facts (Moon ingress, void-of-course, exact
///   Moon aspects). The natal all-day context stays whole-sign.
/// - Deterministic: no `Date()`, `Calendar.current`, or `TimeZone.current`
///   anywhere in the engine. Identical `Inputs` produce identical output;
///   copy picks are keyed by day-of-year.
/// - Serialized: every function that touches the ephemeris is isolated to
///   `EphemerisActor`, because the underlying C library mutates
///   process-global state on every call (see EphemerisActor.swift).
/// - Void-of-course uses the modern planet set (Moon aspects to Sun through
///   Pluto), the common contemporary convention: the Moon is void from its
///   last exact Ptolemaic aspect (0/60/90/120/180°) to any of the nine other
///   modern bodies until it enters the next sign. Purely classical VoC
///   (Sun–Saturn only) yields longer voids; we document rather than mix.
/// - Planetary hours are engine-complete but UI-dormant in v1 (no location
///   permission exists in the app). The SwissEphemeris rise/set wrapper
///   ignores the C failure code, so on circumpolar days the returned date is
///   garbage — every rise/set result is clamped to ±48 h of its query and to
///   sane ordering; any violation means "no rise/set today" and the function
///   returns nil.
nonisolated enum DayWindowsEngine {
    struct GeoLocation: Equatable, Sendable {
        var latitude: Double
        var longitude: Double
    }

    struct Inputs: Sendable {
        /// Any instant in the target local day.
        var date: Date
        /// Explicit — the engine never reads `TimeZone.current`.
        var timeZone: TimeZone
        /// nil ⇒ no planetary hours (v1 UI passes nil).
        var location: GeoLocation?
        /// Callers pass natal signs only when chart provenance is
        /// calculated/user-confirmed; nil suppresses the all-day context line.
        var natalSun: ZodiacSign?
        var natalMoon: ZodiacSign?
        var natalRising: ZodiacSign?
        var style: GuidanceStyle

        init(
            date: Date,
            timeZone: TimeZone,
            location: GeoLocation? = nil,
            natalSun: ZodiacSign? = nil,
            natalMoon: ZodiacSign? = nil,
            natalRising: ZodiacSign? = nil,
            style: GuidanceStyle
        ) {
            self.date = date
            self.timeZone = timeZone
            self.location = location
            self.natalSun = natalSun
            self.natalMoon = natalMoon
            self.natalRising = natalRising
            self.style = style
        }
    }

    // MARK: - Internal sky-fact types (internal, individually testable)

    struct MoonIngress: Equatable, Sendable {
        let date: Date
        let fromSign: ZodiacSign
        let toSign: ZodiacSign
    }

    struct MoonAspectEvent: Equatable, Sendable {
        let date: Date
        let planet: DayPlanet
        let kind: MoonAspectKind
        let moonLongitude: Double
        let planetLongitude: Double
    }

    struct VoidOfCourse: Equatable, Sendable {
        /// The exact time of the Moon's last Ptolemaic aspect before the ingress.
        let start: Date
        let ingress: MoonIngress
        let lastAspect: MoonAspectEvent

        var end: Date { ingress.date }
        var sign: ZodiacSign { ingress.fromSign }
    }

    struct PlanetaryHour: Equatable, Sendable {
        let index: Int
        let ruler: DayPlanet
        let interval: DateInterval
        let isDaytime: Bool
    }

    // MARK: - Tuning constants

    /// Exact-aspect windows span ±90 minutes around exactness (clipped).
    private static let aspectHalfWindow: TimeInterval = 90 * 60
    /// An aspect window that clips below 30 minutes is dropped.
    private static let minimumAspectDuration: TimeInterval = 30 * 60
    /// Sub-minute slivers are absorbed so the strip tiles the day exactly.
    private static let minimumPieceDuration: TimeInterval = 60
    /// Quiet edge windows require at least two hours.
    private static let minimumQuietDuration: TimeInterval = 2 * 3600
    private static let maximumWindowCount = 5
    /// Presentation-only day-edge boundaries for quiet windows (8 AM / 9 PM
    /// local). The copy never claims a sky boundary at these times — the
    /// quiet window's sky fact is the absence of exact contacts in its span.
    private static let quietMorningHour = 8
    private static let quietEveningHour = 21

    /// Moon-aspect scan targets: separations (Moon − planet, mod 360) that
    /// realize the Ptolemaic angles {0, 60, 90, 120, 180}.
    private static let separationTargets: [Double] = [0, 60, 90, 120, 180, 240, 270, 300]

    /// The modern void-of-course planet set: every body the Moon can aspect.
    static let aspectScanPlanets: [DayPlanet] = [
        .sun, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto
    ]

    /// Chaldean order, slowest to fastest.
    static let chaldeanOrder: [DayPlanet] = [.saturn, .jupiter, .mars, .sun, .venus, .mercury, .moon]
    /// Weekday rulers indexed by (gregorian weekday − 1): Sunday → Sun … Saturday → Saturn.
    static let weekdayRulers: [DayPlanet] = [.sun, .moon, .mars, .mercury, .jupiter, .venus, .saturn]

    // MARK: - Public entry point

    /// Computes the day strip: 3–5 sorted, non-overlapping windows that tile
    /// the local day (degenerate all-void days can drop below 3 rather than
    /// fabricate boundaries), plus the provenance-gated all-day natal context.
    /// `inputs.location` is accepted for API completeness; planetary hours do
    /// not join the strip in v1 (UI-dormant until location permission ships).
    @EphemerisActor
    static func windows(for inputs: Inputs) async -> DayWindowsResult {
        let timeZone = inputs.timeZone
        let day = localDayInterval(containing: inputs.date, timeZone: timeZone)
        let dayOfYear = dayOfYear(for: day.start, timeZone: timeZone)

        // --- Sky facts ----------------------------------------------------
        let ingressNext = nextMoonIngress(after: day.start)
        let ingressInDay: MoonIngress? = {
            guard let ingressNext, ingressNext.date < day.end else { return nil }
            return ingressNext
        }()

        var vocs: [VoidOfCourse] = []
        if let ingressNext {
            if let voc = voidOfCourse(before: ingressNext), voc.start < day.end {
                vocs.append(voc)
            }
            if let inDay = ingressInDay,
               let followUp = nextMoonIngress(after: inDay.date.addingTimeInterval(120)),
               let laterVoc = voidOfCourse(before: followUp), laterVoc.start < day.end {
                vocs.append(laterVoc)
            }
        }

        let allAspects = moonExactAspects(in: day)
        // Aspects strictly inside a void period cannot exist for the same
        // planet set by definition; drop defensively anyway (VoC wins).
        let aspects = allAspects.filter { event in
            !vocs.contains { $0.start < event.date && event.date < $0.end }
        }

        // --- Base tiling: sign segments carved by void periods -------------
        var pieces: [StripPiece] = []
        if let inDay = ingressInDay {
            pieces = [
                StripPiece(
                    interval: DateInterval(start: day.start, end: inDay.date),
                    payload: .moonSign(sign: inDay.fromSign, endingIngress: inDay)
                ),
                StripPiece(
                    interval: DateInterval(start: inDay.date, end: day.end),
                    payload: .moonSign(sign: inDay.toSign, endingIngress: nil)
                )
            ]
        } else {
            guard let sign = ingressNext?.fromSign ?? moonSign(at: day.start) else {
                // Non-finite ephemeris output (corrupt or missing data files):
                // emit an honest empty day rather than fabricate a sign.
                return DayWindowsResult(dayInterval: day, windows: [], allDayContext: nil)
            }
            pieces = [StripPiece(interval: day, payload: .moonSign(sign: sign, endingIngress: nil))]
        }
        pieces = pieces.filter { $0.interval.duration >= minimumPieceDuration }

        for voc in vocs {
            let clipStart = max(voc.start, day.start)
            let clipEnd = min(voc.end, day.end)
            guard clipEnd.timeIntervalSince(clipStart) >= minimumPieceDuration else { continue }
            let cut = StripPiece(
                interval: DateInterval(start: clipStart, end: clipEnd),
                payload: .voidOfCourse(voc)
            )
            pieces = carve(cut: cut, into: pieces)
        }

        // --- Aspect windows: ±90 min, clipped, VoC wins ---------------------
        let prioritized = aspects.sorted { a, b in
            if a.kind.keepScore != b.kind.keepScore { return a.kind.keepScore > b.kind.keepScore }
            if a.date != b.date { return a.date < b.date }
            return a.planet.rawValue < b.planet.rawValue
        }
        var keptAspects: [StripPiece] = []
        for event in prioritized {
            // Host: the sign piece containing the exact moment. Clipping to
            // the host keeps aspect windows inside their own sign segment —
            // they never cross an ingress, a void period, or the day edges.
            guard let host = pieces.first(where: { piece in
                if case .moonSign = piece.payload { return piece.interval.contains(event.date) }
                return false
            }) else { continue }
            var start = max(event.date.addingTimeInterval(-aspectHalfWindow), host.interval.start)
            var end = min(event.date.addingTimeInterval(aspectHalfWindow), host.interval.end)
            var swallowed = false
            for kept in keptAspects where kept.interval.intersects(DateInterval(start: start, end: end)) {
                if kept.interval.contains(event.date) {
                    swallowed = true
                    break
                } else if kept.interval.end <= event.date {
                    start = max(start, kept.interval.end)
                } else {
                    end = min(end, kept.interval.start)
                }
            }
            guard !swallowed, end.timeIntervalSince(start) >= minimumAspectDuration else { continue }
            keptAspects.append(StripPiece(
                interval: DateInterval(start: start, end: end),
                payload: .moonAspect(event)
            ))
        }

        // --- Cap at 5 by score: drop the lowest-scored aspects first --------
        var tiled = pieces
        var keepCount = keptAspects.count
        repeat {
            tiled = pieces
            for aspect in keptAspects.prefix(keepCount) {
                tiled = carve(cut: aspect, into: tiled)
            }
            keepCount -= 1
        } while tiled.count > maximumWindowCount && keepCount >= 0

        // --- Quiet edges (only where the sky is genuinely event-free) -------
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let morning = calendar.date(bySettingHour: quietMorningHour, minute: 0, second: 0, of: day.start)
            ?? day.start.addingTimeInterval(TimeInterval(quietMorningHour) * 3600)
        let evening = calendar.date(bySettingHour: quietEveningHour, minute: 0, second: 0, of: day.start)
            ?? day.start.addingTimeInterval(TimeInterval(quietEveningHour) * 3600)
        let eventDates = allAspects.map(\.date)
            + vocs.map(\.start)
            + (ingressInDay.map { [$0.date] } ?? [])

        if tiled.count < maximumWindowCount,
           let first = tiled.first,
           case .moonSign = first.payload,
           first.interval.start == day.start,
           morning.timeIntervalSince(day.start) >= minimumQuietDuration,
           first.interval.end.timeIntervalSince(morning) >= 3600,
           !eventDates.contains(where: { $0 > day.start && $0 < morning }) {
            let quiet = StripPiece(interval: DateInterval(start: day.start, end: morning), payload: .quiet)
            tiled = carve(cut: quiet, into: tiled)
        }
        if tiled.count < maximumWindowCount,
           let last = tiled.max(by: { $0.interval.start < $1.interval.start }),
           case .moonSign = last.payload,
           last.interval.end == day.end,
           day.end.timeIntervalSince(evening) >= minimumQuietDuration,
           evening.timeIntervalSince(last.interval.start) >= 3600,
           !eventDates.contains(where: { $0 > evening && $0 < day.end }) {
            let quiet = StripPiece(interval: DateInterval(start: evening, end: day.end), payload: .quiet)
            tiled = carve(cut: quiet, into: tiled)
        }
        tiled.sort { $0.interval.start < $1.interval.start }

        let stripWindows = tiled.map { piece in
            makeWindow(for: piece, day: day, timeZone: timeZone, style: inputs.style, dayOfYear: dayOfYear)
        }

        // --- All-day natal whole-sign context (provenance-gated) ------------
        var allDayContext: DayWindow?
        if inputs.natalSun != nil || inputs.natalMoon != nil || inputs.natalRising != nil {
            // Read the transit at local midday so every instant of the same
            // local day produces the same context line.
            let midday = day.start.addingTimeInterval(day.duration / 2)
            if let reading = await TransitEngine.dailyReading(
                sun: inputs.natalSun,
                moon: inputs.natalMoon,
                rising: inputs.natalRising,
                on: midday
            ) {
                let lines = DayWindowCopy.dailyTransit(
                    fact: reading.headline,
                    family: reading.aspect.family,
                    style: inputs.style,
                    dayOfYear: dayOfYear
                )
                allDayContext = DayWindow(
                    kind: .dailyTransit,
                    interval: day,
                    tokenID: tokenID(for: reading.body),
                    title: lines.title,
                    rationale: lines.rationale,
                    derivation: reading.detailLine,
                    evidence: evidence(
                        kind: .dailyTransit,
                        derivation: reading.detailLine,
                        interval: day,
                        label: "Current whole-sign transit"
                    )
                )
            }
        }

        return DayWindowsResult(dayInterval: day, windows: stripWindows, allDayContext: allDayContext)
    }

    // MARK: - Moon ingress

    /// The Moon's ingress within the local day containing `date`, if any.
    /// Accurate to ≤60 s (predict on `speedLongitude`, then bisect).
    @EphemerisActor
    static func moonIngress(dayContaining date: Date, timeZone: TimeZone) -> MoonIngress? {
        let day = localDayInterval(containing: date, timeZone: timeZone)
        guard let ingress = nextMoonIngress(after: day.start), ingress.date < day.end else { return nil }
        return ingress
    }

    /// The first Moon ingress at or after `date`. The Moon needs ≥2.1 days
    /// per sign, so consecutive calls step through every ingress.
    @EphemerisActor
    static func nextMoonIngress(after date: Date) -> MoonIngress? {
        let start = Coordinate<Planet>(body: .moon, date: date)
        let startLongitude = normalizedDegrees(start.longitude)
        guard startLongitude.isFinite else { return nil }
        let fromIndex = min(Int(startLongitude / 30), 11)
        let boundary = normalizedDegrees(Double(fromIndex + 1) * 30)

        var ahead = boundary - startLongitude
        if ahead <= 0 { ahead += 360 }
        var speed = max(start.speedLongitude, 8)
        var candidate = date.addingTimeInterval(ahead / speed * 86_400)
        var converged = false
        for _ in 0..<6 {
            let moon = Coordinate<Planet>(body: .moon, date: candidate)
            let miss = signedDelta(boundary, moon.longitude)
            speed = max(moon.speedLongitude, 8)
            if abs(miss) < 0.02 {
                converged = true
                break
            }
            candidate = candidate.addingTimeInterval(miss / speed * 86_400)
        }
        guard converged else { return nil }

        func delta(_ instant: Date) -> Double {
            signedDelta(Coordinate<Planet>(body: .moon, date: instant).longitude, boundary)
        }
        guard let root = bisectRoot(around: candidate, delta: delta) else { return nil }
        guard root >= date.addingTimeInterval(-60) else { return nil }
        return MoonIngress(
            date: root,
            fromSign: ZodiacSign.allCases[fromIndex],
            toSign: ZodiacSign.allCases[(fromIndex + 1) % 12]
        )
    }

    // MARK: - Exact Moon aspects

    /// Every exact Ptolemaic aspect the transiting Moon makes to the modern
    /// planet set within `interval`, each verified with real coordinates and
    /// bisected to ≤60 s. Slow planets are sampled once at the interval
    /// midpoint (linear model; the Moon outruns them 6–14× so roots are
    /// bracketed reliably), then every root is polished against real
    /// positions for both bodies.
    @EphemerisActor
    static func moonExactAspects(in interval: DateInterval) -> [MoonAspectEvent] {
        guard interval.duration > 0 else { return [] }
        var events: [MoonAspectEvent] = []
        let midpoint = interval.start.addingTimeInterval(interval.duration / 2)
        let moonStart = Coordinate<Planet>(body: .moon, date: interval.start)

        for dayPlanet in aspectScanPlanets {
            let sample = Coordinate<Planet>(body: dayPlanet.planet, date: midpoint)
            let startSeparation = normalizedDegrees(
                moonStart.longitude - linearLongitude(sample: sample, sampleDate: midpoint, at: interval.start)
            )
            let relativeSpeed = moonStart.speedLongitude - sample.speedLongitude
            guard relativeSpeed > 1 else { continue }

            let maxTravel = relativeSpeed * (interval.duration / 86_400) * 1.3 + 0.6
            var targets: [Double] = []
            var base = floor(startSeparation / 360) * 360
            while base < startSeparation + maxTravel {
                for target in separationTargets {
                    let unwrapped = base + target
                    if unwrapped > startSeparation + 1e-6, unwrapped <= startSeparation + maxTravel {
                        targets.append(unwrapped)
                    }
                }
                base += 360
            }

            for target in targets.sorted() {
                if let event = solveAspect(
                    dayPlanet: dayPlanet,
                    targetUnwrapped: target,
                    startSeparation: startSeparation,
                    relativeSpeedEstimate: relativeSpeed,
                    planetSample: sample,
                    planetSampleDate: midpoint,
                    window: interval
                ) {
                    events.append(event)
                }
            }
        }
        return events.sorted { $0.date < $1.date }
    }

    // MARK: - Void of course

    /// The void period ending at `ingress`: from the Moon's last exact
    /// Ptolemaic aspect (modern Sun–Pluto set) to the ingress itself. The
    /// search walks backward from the ingress in 12 h chunks up to 60 h; if
    /// no aspect exists in that span (vanishingly rare) we return nil rather
    /// than claim a void we did not compute.
    @EphemerisActor
    static func voidOfCourse(before ingress: MoonIngress) -> VoidOfCourse? {
        let chunk: TimeInterval = 12 * 3600
        for step in 0..<5 {
            let end = ingress.date.addingTimeInterval(-chunk * Double(step) + (step == 0 ? 0 : 600))
            let start = ingress.date.addingTimeInterval(-chunk * Double(step + 1) - 600)
            let events = moonExactAspects(in: DateInterval(start: start, end: end))
                .filter { $0.date <= ingress.date }
            if let last = events.max(by: { $0.date < $1.date }) {
                return VoidOfCourse(start: last.date, ingress: ingress, lastAspect: last)
            }
        }
        return nil
    }

    // MARK: - Planetary hours

    /// Twelve equal sunrise→sunset hours plus twelve sunset→next-sunrise
    /// hours, rulers in Chaldean sequence starting from the weekday ruler
    /// (gregorian weekday in the explicit time zone, Sunday = 1). Returns nil
    /// whenever a rise/set result fails the ±48 h clamp or sane ordering —
    /// the SwissEphemeris wrapper ignores swe_rise_trans failures, so polar
    /// days produce garbage dates that must never become windows.
    @EphemerisActor
    static func planetaryHours(
        dayContaining date: Date,
        timeZone: TimeZone,
        location: GeoLocation
    ) -> [PlanetaryHour]? {
        let day = localDayInterval(containing: date, timeZone: timeZone)

        let sunriseResult = RiseTime<Planet>(
            date: day.start,
            body: .sun,
            longitude: location.longitude,
            latitude: location.latitude
        ).date
        guard let sunrise = clampedEventDate(sunriseResult, query: day.start),
              day.contains(sunrise) else { return nil }

        let sunsetResult = SetTime<Planet>(
            date: sunrise.addingTimeInterval(60),
            body: .sun,
            longitude: location.longitude,
            latitude: location.latitude
        ).date
        guard let sunset = clampedEventDate(sunsetResult, query: sunrise),
              sunset > sunrise else { return nil }

        let nextSunriseResult = RiseTime<Planet>(
            date: sunset.addingTimeInterval(60),
            body: .sun,
            longitude: location.longitude,
            latitude: location.latitude
        ).date
        guard let nextSunrise = clampedEventDate(nextSunriseResult, query: sunset),
              nextSunrise > sunset else { return nil }

        let dayHourLength = sunset.timeIntervalSince(sunrise) / 12
        let nightHourLength = nextSunrise.timeIntervalSince(sunset) / 12
        guard dayHourLength > 0, nightHourLength > 0 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: day.start)
        guard (1...7).contains(weekday),
              let startIndex = chaldeanOrder.firstIndex(of: weekdayRulers[weekday - 1]) else { return nil }

        var hours: [PlanetaryHour] = []
        for index in 0..<24 {
            let isDaytime = index < 12
            let start = isDaytime
                ? sunrise.addingTimeInterval(Double(index) * dayHourLength)
                : sunset.addingTimeInterval(Double(index - 12) * nightHourLength)
            let end = isDaytime
                ? sunrise.addingTimeInterval(Double(index + 1) * dayHourLength)
                : sunset.addingTimeInterval(Double(index - 11) * nightHourLength)
            hours.append(PlanetaryHour(
                index: index,
                ruler: chaldeanOrder[(startIndex + index) % 7],
                interval: DateInterval(start: start, end: end),
                isDaytime: isDaytime
            ))
        }
        return hours
    }

    // MARK: - Calendar helpers (explicit time zone only)

    static func localDayInterval(containing date: Date, timeZone: TimeZone) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    private static func dayOfYear(for date: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    // MARK: - Strip assembly

    private struct StripPiece {
        enum Payload {
            case moonSign(sign: ZodiacSign, endingIngress: MoonIngress?)
            case voidOfCourse(VoidOfCourse)
            case moonAspect(MoonAspectEvent)
            case quiet
        }

        var interval: DateInterval
        var payload: Payload
    }

    /// Replaces the overlapping portions of moon-sign pieces with `cut`.
    /// Sub-minute sign slivers are absorbed into the cut so the strip keeps
    /// tiling the day exactly. Non-sign pieces are never carved.
    private static func carve(cut: StripPiece, into pieces: [StripPiece]) -> [StripPiece] {
        var adjusted = cut
        for piece in pieces {
            guard case .moonSign = piece.payload,
                  let overlap = piece.interval.intersection(with: adjusted.interval),
                  overlap.duration > 0 else { continue }
            var start = adjusted.interval.start
            var end = adjusted.interval.end
            let leftSliver = overlap.start.timeIntervalSince(piece.interval.start)
            if leftSliver > 0, leftSliver < minimumPieceDuration {
                start = min(start, piece.interval.start)
            }
            let rightSliver = piece.interval.end.timeIntervalSince(overlap.end)
            if rightSliver > 0, rightSliver < minimumPieceDuration {
                end = max(end, piece.interval.end)
            }
            adjusted.interval = DateInterval(start: start, end: end)
        }

        var result: [StripPiece] = []
        for piece in pieces {
            guard case .moonSign = piece.payload,
                  let overlap = piece.interval.intersection(with: adjusted.interval),
                  overlap.duration > 0 else {
                result.append(piece)
                continue
            }
            if overlap.start > piece.interval.start {
                var left = piece
                left.interval = DateInterval(start: piece.interval.start, end: overlap.start)
                result.append(left)
            }
            if overlap.end < piece.interval.end {
                var right = piece
                right.interval = DateInterval(start: overlap.end, end: piece.interval.end)
                result.append(right)
            }
        }
        result.append(adjusted)
        return result.sorted { $0.interval.start < $1.interval.start }
    }

    @EphemerisActor
    private static func makeWindow(
        for piece: StripPiece,
        day: DateInterval,
        timeZone: TimeZone,
        style: GuidanceStyle,
        dayOfYear: Int
    ) -> DayWindow {
        switch piece.payload {
        case .moonSign(let sign, let endingIngress):
            let probe = piece.interval.start.addingTimeInterval(min(30, piece.interval.duration / 2))
            let moon = Coordinate<Planet>(body: .moon, date: probe)
            var derivation = "Moon \(degreeInSign(moon.longitude))° \(sign.displayName) at \(timeString(piece.interval.start, timeZone: timeZone, day: day))"
            if let endingIngress {
                derivation += "; enters \(endingIngress.toSign.displayName) \(timeString(endingIngress.date, timeZone: timeZone, day: day))"
            }
            let lines = DayWindowCopy.moonSign(sign: sign, style: style, dayOfYear: dayOfYear)
            return DayWindow(
                kind: .moonSign,
                interval: piece.interval,
                tokenID: DayPlanet.moon.tokenID,
                title: lines.title,
                rationale: lines.rationale,
                derivation: derivation,
                evidence: evidence(kind: .moonSign, derivation: derivation, interval: piece.interval, label: "Transiting Moon sign")
            )

        case .voidOfCourse(let voc):
            let aspectText = "Moon \(voc.lastAspect.kind.displayName) \(voc.lastAspect.planet.displayName) \(timeString(voc.start, timeZone: timeZone, day: day))"
            let derivation = "Moon void in \(voc.sign.displayName) since its last exact aspect — \(aspectText); enters \(voc.ingress.toSign.displayName) \(timeString(voc.end, timeZone: timeZone, day: day))"
            let lines = DayWindowCopy.voidOfCourse(sign: voc.sign, nextSign: voc.ingress.toSign, style: style, dayOfYear: dayOfYear)
            return DayWindow(
                kind: .voidOfCourse,
                interval: piece.interval,
                tokenID: "personal",
                title: lines.title,
                rationale: lines.rationale,
                derivation: derivation,
                evidence: evidence(kind: .voidOfCourse, derivation: derivation, interval: piece.interval, label: "Void-of-course Moon")
            )

        case .moonAspect(let event):
            let sign = ZodiacSign.allCases[min(Int(normalizedDegrees(event.moonLongitude) / 30), 11)]
            let derivation = "Moon \(event.kind.displayName) \(event.planet.displayName) exact \(timeString(event.date, timeZone: timeZone, day: day)); Moon \(degreeInSign(event.moonLongitude))° \(sign.displayName)"
            let lines = DayWindowCopy.moonAspect(planet: event.planet, kind: event.kind, style: style, dayOfYear: dayOfYear)
            return DayWindow(
                kind: .moonAspect,
                interval: piece.interval,
                tokenID: event.planet.tokenID,
                title: lines.title,
                rationale: lines.rationale,
                derivation: derivation,
                evidence: evidence(kind: .moonAspect, derivation: derivation, interval: piece.interval, label: "Exact Moon aspect")
            )

        case .quiet:
            let derivation = "No exact Moon contacts between \(timeString(piece.interval.start, timeZone: timeZone, day: day)) and \(timeString(piece.interval.end, timeZone: timeZone, day: day))"
            let lines = DayWindowCopy.quiet(style: style, dayOfYear: dayOfYear)
            return DayWindow(
                kind: .quiet,
                interval: piece.interval,
                tokenID: "personal",
                title: lines.title,
                rationale: lines.rationale,
                derivation: derivation,
                evidence: evidence(kind: .quiet, derivation: derivation, interval: piece.interval, label: "Quiet sky stretch")
            )
        }
    }

    // MARK: - Evidence

    private static func evidence(
        kind: DayWindowKind,
        derivation: String,
        interval: DateInterval,
        label: String
    ) -> ReadingEvidence {
        let detail = derivation.hasSuffix(".")
            ? "\(derivation) Scope: today only."
            : "\(derivation). Scope: today only."
        return ReadingEvidence(
            id: deterministicUUID(seed: "\(kind.rawValue)|\(Int(interval.start.timeIntervalSinceReferenceDate))|\(Int(interval.end.timeIntervalSinceReferenceDate))|\(label)"),
            basis: .calculated,
            label: label,
            detail: detail,
            supportsTiming: true
        )
    }

    private static func tokenID(for body: TransitBody) -> String {
        switch body {
        case .sun: "personal"
        case .moon: "family"
        case .mercury: "career"
        case .venus: "love"
        case .mars: "career"
        }
    }

    // MARK: - Aspect root solving

    private static func linearLongitude(sample: Coordinate<Planet>, sampleDate: Date, at date: Date) -> Double {
        sample.longitude + sample.speedLongitude * date.timeIntervalSince(sampleDate) / 86_400
    }

    @EphemerisActor
    private static func solveAspect(
        dayPlanet: DayPlanet,
        targetUnwrapped: Double,
        startSeparation: Double,
        relativeSpeedEstimate: Double,
        planetSample: Coordinate<Planet>,
        planetSampleDate: Date,
        window: DateInterval
    ) -> MoonAspectEvent? {
        let targetNormalized = normalizedDegrees(targetUnwrapped)
        let startNormalized = normalizedDegrees(startSeparation)

        // Newton phase: real Moon, linear planet — lands within minutes.
        var candidate = window.start.addingTimeInterval(
            (targetUnwrapped - startSeparation) / relativeSpeedEstimate * 86_400
        )
        var converged = false
        for _ in 0..<5 {
            let moon = Coordinate<Planet>(body: .moon, date: candidate)
            let planetLongitude = linearLongitude(sample: planetSample, sampleDate: planetSampleDate, at: candidate)
            let separation = normalizedDegrees(moon.longitude - planetLongitude)
            let unwrapped = startSeparation + signedDelta(separation, startNormalized)
            let miss = targetUnwrapped - unwrapped
            let relativeSpeed = max(moon.speedLongitude - planetSample.speedLongitude, 6)
            if abs(miss) < 0.02 {
                converged = true
                break
            }
            candidate = candidate.addingTimeInterval(miss / relativeSpeed * 86_400)
        }
        guard converged else { return nil }

        // Trust-grade polish: bisect on real coordinates for BOTH bodies.
        func delta(_ instant: Date) -> Double {
            let moon = Coordinate<Planet>(body: .moon, date: instant)
            let planet = Coordinate<Planet>(body: dayPlanet.planet, date: instant)
            return signedDelta(moon.longitude - planet.longitude, targetNormalized)
        }
        guard let root = bisectRoot(around: candidate, delta: delta) else { return nil }
        guard window.contains(root) else { return nil }

        let moon = Coordinate<Planet>(body: .moon, date: root)
        let planet = Coordinate<Planet>(body: dayPlanet.planet, date: root)
        guard abs(signedDelta(moon.longitude - planet.longitude, targetNormalized)) < 0.03 else { return nil }
        return MoonAspectEvent(
            date: root,
            planet: dayPlanet,
            kind: aspectKind(forSeparation: targetNormalized),
            moonLongitude: normalizedDegrees(moon.longitude),
            planetLongitude: normalizedDegrees(planet.longitude)
        )
    }

    /// Brackets a sign change of `delta` around `center` (widening ±10 min up
    /// to ±160 min), then bisects to ≤60 s. `delta` must be locally
    /// increasing through zero, which Moon-relative motion guarantees.
    @EphemerisActor
    private static func bisectRoot(around center: Date, delta: (Date) -> Double) -> Date? {
        var half: TimeInterval = 600
        var low = center.addingTimeInterval(-half)
        var high = center.addingTimeInterval(half)
        var lowDelta = delta(low)
        var highDelta = delta(high)
        var attempts = 0
        while (lowDelta > 0 || highDelta < 0), attempts < 4 {
            half *= 2
            low = center.addingTimeInterval(-half)
            high = center.addingTimeInterval(half)
            lowDelta = delta(low)
            highDelta = delta(high)
            attempts += 1
        }
        guard lowDelta <= 0, highDelta >= 0 else { return nil }
        while high.timeIntervalSince(low) > 30 {
            let middle = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if delta(middle) < 0 {
                low = middle
            } else {
                high = middle
            }
        }
        return low.addingTimeInterval(high.timeIntervalSince(low) / 2)
    }

    private static func aspectKind(forSeparation separation: Double) -> MoonAspectKind {
        let folded = separation > 180 ? 360 - separation : separation
        switch Int(folded.rounded()) {
        case 0: return .conjunction
        case 60: return .sextile
        case 90: return .square
        case 120: return .trine
        default: return .opposition
        }
    }

    // MARK: - Angle & misc helpers

    static func normalizedDegrees(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    /// (a − b) wrapped to (−180, 180].
    static func signedDelta(_ a: Double, _ b: Double) -> Double {
        var delta = (a - b).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta <= -180 { delta += 360 }
        return delta
    }

    private static func degreeInSign(_ longitude: Double) -> Int {
        let normalized = normalizedDegrees(longitude)
        guard normalized.isFinite else { return 0 }
        return Int(normalized.truncatingRemainder(dividingBy: 30))
    }

    @EphemerisActor
    private static func moonSign(at date: Date) -> ZodiacSign? {
        let longitude = normalizedDegrees(Coordinate<Planet>(body: .moon, date: date).longitude)
        guard longitude.isFinite else { return nil }
        return ZodiacSign.allCases[min(Int(longitude / 30), 11)]
    }

    private static func clampedEventDate(_ date: Date?, query: Date) -> Date? {
        guard let date, date.timeIntervalSince1970.isFinite else { return nil }
        guard abs(date.timeIntervalSince(query)) <= 48 * 3600 else { return nil }
        return date
    }

    /// Derivation clock strings: fixed en_US_POSIX + the explicit time zone
    /// so identical inputs render identical facts on every device. Times
    /// outside the local day carry a relative or weekday prefix — that is how
    /// a midnight-clamped window keeps its true start honest.
    private static func timeString(_ date: Date, timeZone: TimeZone, day: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a"
        let clock = formatter.string(from: date)
        if date >= day.start, date < day.end { return clock }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if let previousStart = calendar.date(byAdding: .day, value: -1, to: day.start),
           date >= previousStart, date < day.start {
            return "yesterday \(clock)"
        }
        if let nextEnd = calendar.date(byAdding: .day, value: 1, to: day.end),
           date >= day.end, date < nextEnd {
            return "tomorrow \(clock)"
        }
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }

    /// Stable UUID from a seed so evidence rows compare equal across
    /// invocations with identical inputs (FNV-1a, forward + reversed).
    private static func deterministicUUID(seed: String) -> UUID {
        func fnv1a<S: Sequence>(_ bytes: S, basis: UInt64) -> UInt64 where S.Element == UInt8 {
            var hash = basis
            for byte in bytes {
                hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
            }
            return hash
        }
        let forward = fnv1a(seed.utf8, basis: 0xCBF2_9CE4_8422_2325)
        let backward = fnv1a(Array(seed.utf8).reversed(), basis: 0x9E37_79B9_7F4A_7C15)
        func byte(_ value: UInt64, _ index: UInt64) -> UInt8 {
            UInt8((value >> (56 - index * 8)) & 0xFF)
        }
        return UUID(uuid: (
            byte(forward, 0), byte(forward, 1), byte(forward, 2), byte(forward, 3),
            byte(forward, 4), byte(forward, 5), byte(forward, 6), byte(forward, 7),
            byte(backward, 0), byte(backward, 1), byte(backward, 2), byte(backward, 3),
            byte(backward, 4), byte(backward, 5), byte(backward, 6), byte(backward, 7)
        ))
    }
}

// MARK: - DayPlanet ↔ SwissEphemeris

extension DayPlanet {
    var planet: Planet {
        switch self {
        case .sun: .sun
        case .moon: .moon
        case .mercury: .mercury
        case .venus: .venus
        case .mars: .mars
        case .jupiter: .jupiter
        case .saturn: .saturn
        case .uranus: .uranus
        case .neptune: .neptune
        case .pluto: .pluto
        }
    }
}
