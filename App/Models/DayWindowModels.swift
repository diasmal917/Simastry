import Foundation

/// The kinds of honest, time-bounded windows the day-windows engine can emit.
/// `planetaryHour` is engine-complete but UI-dormant in v1 (no location
/// permission exists); `dailyTransit` is the all-day natal context line and is
/// never a strip segment.
nonisolated enum DayWindowKind: String, Codable, Sendable {
    case moonSign, voidOfCourse, moonAspect, dailyTransit, planetaryHour, quiet
}

/// The ten modern bodies the engine reads. Raw values are stable and the
/// engine maps them onto SwissEphemeris `Planet` cases by name.
nonisolated enum DayPlanet: String, CaseIterable, Codable, Sendable {
    case sun, moon, mercury, venus, mars, jupiter, saturn, uranus, neptune, pluto

    var displayName: String { rawValue.capitalized }

    /// Shared category-token raw values (`SimastryCategoryToken.rawValue`).
    /// The engine never imports SwiftUI, so the mapping stays string-typed and
    /// views resolve color/icon from the token id.
    var tokenID: String {
        switch self {
        case .sun: "personal"
        case .moon: "family"
        case .mercury: "career"
        case .venus: "love"
        case .mars: "career"
        case .jupiter: "money"
        case .saturn: "career"
        case .uranus, .neptune, .pluto: "personal"
        }
    }
}

/// Degree-exact Ptolemaic aspect names for transiting-Moon-to-transiting-planet
/// contacts. Distinct from `WholeSignAspect` on purpose: whole-sign contacts
/// deliberately use sign-level phrasing, while these are exact to the minute,
/// so degree-precision names ("conjunct", "opposite") are honest here.
nonisolated enum MoonAspectKind: String, CaseIterable, Codable, Sendable {
    case conjunction, sextile, square, trine, opposition

    var angle: Double {
        switch self {
        case .conjunction: 0
        case .sextile: 60
        case .square: 90
        case .trine: 120
        case .opposition: 180
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

    /// flow / friction / emphasis — the same copy-family convention
    /// `WholeSignAspect` uses.
    var family: String {
        switch self {
        case .trine, .sextile: "flow"
        case .square, .opposition: "friction"
        case .conjunction: "emphasis"
        }
    }

    /// Strip keep-priority (plan: conjunction/opposition > square > trine > sextile).
    var keepScore: Int {
        switch self {
        case .conjunction: 80
        case .opposition: 78
        case .square: 70
        case .trine: 60
        case .sextile: 50
        }
    }
}

/// One honest, time-bounded window in the day strip.
nonisolated struct DayWindow: Identifiable, Equatable, Sendable {
    let kind: DayWindowKind
    /// Clamped to the local day. When the underlying sky event spills past the
    /// day edge (for example a void Moon that began yesterday evening), the
    /// interval is clamped but `derivation` keeps the true instants.
    let interval: DateInterval
    /// `SimastryCategoryToken.rawValue`; views resolve color/icon.
    let tokenID: String
    /// "Favors hard conversations" — never an outcome claim.
    let title: String
    /// Style-aware one-liner (why, honestly).
    let rationale: String
    /// The sky fact: "Moon 14° Scorpio at 12:00 AM; enters Sagittarius 2:40 PM".
    let derivation: String
    /// Basis `.calculated`, `supportsTiming: true`, "today only" scope in detail.
    let evidence: ReadingEvidence

    var id: String { "\(kind.rawValue)-\(Int(interval.start.timeIntervalSinceReferenceDate))" }
}

/// The computed day: 3–5 sorted, non-overlapping windows that tile the local
/// day, plus the optional all-day natal whole-sign context line.
nonisolated struct DayWindowsResult: Equatable, Sendable {
    let dayInterval: DateInterval
    /// Sorted by start, non-overlapping; together with the (normally empty)
    /// gaps they cover `dayInterval` exactly.
    let windows: [DayWindow]
    /// Natal whole-sign daily transit — a context line, never a strip segment.
    let allDayContext: DayWindow?

    func window(at date: Date) -> DayWindow? {
        guard dayInterval.contains(date) else { return nil }
        return windows.first { $0.interval.contains(date) }
    }

    /// The next instant at which the current window changes — window starts
    /// and ends plus the day edges. `nil` once `date` is past everything.
    func nextBoundary(after date: Date) -> Date? {
        var boundaries: [Date] = [dayInterval.start, dayInterval.end]
        for window in windows {
            boundaries.append(window.interval.start)
            boundaries.append(window.interval.end)
        }
        return boundaries.filter { $0 > date }.min()
    }
}

extension DayWindow {
    /// The evidence row a Compass reading may cite for the current sky
    /// window (D4): an honest, clock-bounded, transiting-only fact — never
    /// natal, always scoped to today, same as every other window. Callers
    /// (`SimulateView.readingEvidence`) attach this only when a window
    /// actually covers "now"; `timingIsAvailable` (the natal-gated composer
    /// chip) is a separate, untouched concern.
    var readingEvidenceRow: ReadingEvidence {
        ReadingEvidence(
            basis: .calculated,
            label: "Current sky window",
            detail: "\(title) — \(derivation). Scope: today only.",
            supportsTiming: true
        )
    }
}
