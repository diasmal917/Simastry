import Foundation
import SwissEphemeris

/// The transiting bodies Simastry reads for daily communication timing.
nonisolated enum TransitBody: String, CaseIterable, Sendable {
    case mercury, venus, mars, sun, moon

    var planet: Planet {
        switch self {
        case .mercury: .mercury
        case .venus: .venus
        case .mars: .mars
        case .sun: .sun
        case .moon: .moon
        }
    }

    var displayName: String {
        switch self {
        case .mercury: "Mercury"
        case .venus: "Venus"
        case .mars: "Mars"
        case .sun: "The Sun"
        case .moon: "The Moon"
        }
    }

    var glyph: String {
        switch self {
        case .mercury: "☿"
        case .venus: "♀"
        case .mars: "♂"
        case .sun: "☉"
        case .moon: "☽"
        }
    }

    /// How loudly this body speaks in a communication-timing read.
    var significance: Int {
        switch self {
        case .mercury: 3   // wording, replies — the messaging planet
        case .venus: 2     // affection, tone
        case .mars: 2      // initiative, friction
        case .sun: 1
        case .moon: 1
        }
    }
}

/// Sign-to-sign (whole-sign) aspects — honest with the data the app stores,
/// which is placements as signs, not degrees.
nonisolated enum WholeSignAspect: String, Sendable, CaseIterable {
    case conjunction, sextile, square, trine, opposition

    static func between(_ a: ZodiacSign, _ b: ZodiacSign) -> WholeSignAspect? {
        guard let indexA = ZodiacSign.allCases.firstIndex(of: a),
              let indexB = ZodiacSign.allCases.firstIndex(of: b) else { return nil }
        let raw = abs(indexA - indexB)
        switch min(raw, 12 - raw) {
        case 0: return .conjunction
        case 2: return .sextile
        case 3: return .square
        case 4: return .trine
        case 6: return .opposition
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .conjunction: "conjunct"
        case .sextile: "sextile"
        case .square: "square"
        case .trine: "trine"
        case .opposition: "opposite"
        }
    }

    /// flow / friction / emphasis — drives the copy family.
    var family: String {
        switch self {
        case .trine, .sextile: "flow"
        case .square, .opposition: "friction"
        case .conjunction: "emphasis"
        }
    }

    var isSupportive: Bool {
        self == .trine || self == .sextile
    }

    var significance: Int {
        switch self {
        case .conjunction: 5
        case .opposition: 4
        case .square: 4
        case .trine: 3
        case .sextile: 2
        }
    }
}

nonisolated struct DailyTransitReading: Sendable, Equatable {
    let body: TransitBody
    let transitSign: ZodiacSign
    let natalRole: CelestialRole
    let natalSign: ZodiacSign
    let aspect: WholeSignAspect
    let guidance: String

    var headline: String {
        "\(body.displayName) \(aspect.displayName) your \(natalRole.displayName)"
    }

    var detailLine: String {
        "\(body.displayName) is moving through \(transitSign.displayName) — \(aspect.displayName) your \(natalSign.displayName) \(natalRole.displayName)."
    }

    var isSupportive: Bool {
        aspect.isSupportive
    }
}

/// Computes real current planetary positions (Swiss Ephemeris) and reads them
/// against the user's natal signs as whole-sign aspects.
nonisolated enum TransitEngine {
    static func transitingSign(of body: TransitBody, on date: Date) -> ZodiacSign {
        let coordinate = Coordinate<Planet>(body: body.planet, date: date)
        return signFromLongitude(coordinate.longitude)
    }

    /// The most significant transit-to-natal contact of the day, or nil when
    /// nothing aspects (or no natal signs exist). Deterministic per day.
    static func dailyReading(
        sun: ZodiacSign?,
        moon: ZodiacSign?,
        rising: ZodiacSign?,
        on date: Date = Date()
    ) -> DailyTransitReading? {
        let natalPlacements: [(CelestialRole, ZodiacSign)] = [
            (.sun, sun), (.moon, moon), (.rising, rising)
        ].compactMap { role, sign in sign.map { (role, $0) } }

        guard !natalPlacements.isEmpty else { return nil }

        let roleWeight: [CelestialRole: Int] = [.sun: 3, .moon: 2, .rising: 1]
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1

        var best: (score: Int, reading: DailyTransitReading)? = nil

        for body in TransitBody.allCases {
            let transitSign = transitingSign(of: body, on: date)
            for (role, natalSign) in natalPlacements {
                guard let aspect = WholeSignAspect.between(transitSign, natalSign) else { continue }
                let score = aspect.significance * 3 + body.significance * 2 + (roleWeight[role] ?? 0)
                guard score > (best?.score ?? Int.min) else { continue }

                let reading = DailyTransitReading(
                    body: body,
                    transitSign: transitSign,
                    natalRole: role,
                    natalSign: natalSign,
                    aspect: aspect,
                    guidance: guidance(for: body, aspect: aspect, dayOfYear: dayOfYear)
                )
                best = (score, reading)
            }
        }

        return best?.reading
    }

    private static func guidance(for body: TransitBody, aspect: WholeSignAspect, dayOfYear: Int) -> String {
        let key = "\(body.rawValue).\(aspect.family)"
        let lines = AstrologyTemplates.transitGuidance[key] ?? []
        guard !lines.isEmpty else {
            return aspect.isSupportive
                ? "The sky leans with you today — say the clear thing."
                : "The sky adds friction today — draft now, send when it reads calm."
        }
        return lines[dayOfYear % lines.count]
    }

    private static func signFromLongitude(_ longitude: Double) -> ZodiacSign {
        let normalized = ((longitude.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int(normalized / 30.0) % 12
        return ZodiacSign.allCases[index]
    }
}
