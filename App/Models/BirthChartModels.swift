import Foundation

/// How trustworthy the wall-clock birth time is. Unknown time is represented
/// by `nil` everywhere it is persisted; noon is never substituted as fact.
nonisolated enum BirthTimePrecision: String, CaseIterable, Codable, Identifiable, Sendable {
    case exact
    case approximate
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exact: "Exact"
        case .approximate: "Approximate"
        case .unknown: "I don't know"
        }
    }

    var detail: String {
        switch self {
        case .exact: "From a birth record or someone who remembers"
        case .approximate: "A remembered time with a margin of uncertainty"
        case .unknown: "No Rising sign or houses will be calculated"
        }
    }

    var requiresBirthTime: Bool { self != .unknown }
}

/// Consumer-facing source labels that distinguish facts from interpretation.
nonisolated enum AstrologyCapabilityLabel: String, Codable, CaseIterable, Sendable {
    case calculated
    case userConfirmed = "user_confirmed"
    case generalLens = "general_lens"

    var title: String {
        switch self {
        case .calculated: "Calculated"
        case .userConfirmed: "User-confirmed"
        case .generalLens: "General lens"
        }
    }
}

/// Provenance of the compatibility sign cache shown around the existing app.
/// Legacy profile signs stay available, but are never presented as newly
/// calculated until the user confirms the underlying birth details.
nonisolated enum BirthChartProvenance: String, Codable, Sendable {
    case calculated
    case userConfirmed = "user_confirmed"
    case previouslySaved = "previously_saved"
    case generalLens = "general_lens"

    var title: String {
        switch self {
        case .calculated: "Calculated"
        case .userConfirmed: "User-confirmed"
        case .previouslySaved: "Previously saved"
        case .generalLens: "General lens"
        }
    }

    var capabilityLabel: AstrologyCapabilityLabel {
        switch self {
        case .calculated: .calculated
        case .userConfirmed: .userConfirmed
        case .previouslySaved, .generalLens: .generalLens
        }
    }
}

/// A placement sampled across the time range the user actually supplied.
/// One sign means the placement remained stable throughout the range. Two or
/// more signs are intentionally retained instead of manufacturing certainty.
nonisolated struct PlacementEstimate: Codable, Equatable, Sendable {
    let possibleSigns: [ZodiacSign]
    let representativeLongitude: Double?
    let sampledLongitudes: [Double]
    let rangeStart: Date
    let rangeEnd: Date
    let capability: AstrologyCapabilityLabel

    var resolvedSign: ZodiacSign? {
        possibleSigns.count == 1 ? possibleSigns[0] : nil
    }

    var isResolved: Bool { resolvedSign != nil }

    var displayValue: String {
        if let resolvedSign {
            return resolvedSign.displayName
        }
        return possibleSigns.map(\.displayName).joined(separator: " or ")
    }

    var disclosure: String? {
        guard possibleSigns.count > 1 else { return nil }
        return "This placement changes during the time range you provided, so both possibilities are shown."
    }
}

/// Private, owner-scoped record stored in `public.user_birth_charts`.
/// Date and time are wall-clock strings so a profile never changes birthday
/// when decoded in a different device timezone.
nonisolated struct NatalChartRecord: Codable, Equatable, Sendable {
    static let currentCalculationVersion = "swiss-ephemeris-tropical-1"

    var userId: UUID?
    var birthDate: String
    var birthTime: String?
    var birthTimePrecision: BirthTimePrecision
    var birthTimeUncertaintyMinutes: Int?
    var birthPlace: String
    var timeZoneIdentifier: String
    var latitude: Double
    var longitude: Double
    var sunEstimate: PlacementEstimate
    var moonEstimate: PlacementEstimate
    var risingEstimate: PlacementEstimate?
    var houseCusps: [Double]?
    var calculationVersion: String
    var provenance: BirthChartProvenance
    var confirmedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case birthDate = "birth_date"
        case birthTime = "birth_time"
        case birthTimePrecision = "birth_time_precision"
        case birthTimeUncertaintyMinutes = "birth_time_uncertainty_minutes"
        case birthPlace = "birth_place"
        case timeZoneIdentifier = "time_zone_identifier"
        case latitude
        case longitude
        case sunEstimate = "sun_estimate"
        case moonEstimate = "moon_estimate"
        case risingEstimate = "rising_estimate"
        case houseCusps = "house_cusps"
        case calculationVersion = "calculation_version"
        case provenance
        case confirmedAt = "confirmed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var hasPartialChart: Bool {
        risingEstimate?.resolvedSign == nil || sunEstimate.resolvedSign == nil || moonEstimate.resolvedSign == nil
    }

    var contextQualitySummary: String {
        switch birthTimePrecision {
        case .exact where !hasPartialChart:
            "Full chart · exact birth time"
        case .exact:
            "Partial chart · local birth time has more than one possible instant"
        case .approximate where risingEstimate?.isResolved == true:
            "Full placements · approximate time stayed in one Rising sign"
        case .approximate:
            "Partial chart · possible Rising signs shown"
        case .unknown:
            "Partial chart · Rising sign and houses unavailable"
        }
    }

    func decodedBirthDate(in timeZone: TimeZone = .current) -> Date? {
        Self.wallClockFormatter(format: "yyyy-MM-dd", timeZone: timeZone).date(from: birthDate)
    }

    func decodedBirthTime(in timeZone: TimeZone = .current) -> Date? {
        guard let birthTime, birthTimePrecision.requiresBirthTime else { return nil }
        for format in ["HH:mm:ss", "HH:mm"] {
            if let date = Self.wallClockFormatter(format: format, timeZone: timeZone).date(from: birthTime) {
                return date
            }
        }
        return nil
    }

    private static func wallClockFormatter(format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}
