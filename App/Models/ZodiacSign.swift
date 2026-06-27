import SwiftUI

/// The twelve zodiac signs. Stable, string-backed so it can be persisted and
/// mapped 1:1 to the official Zodiac SDK icon set (see `ZodiacIconView`).
enum ZodiacSign: String, CaseIterable, Identifiable, Codable {
  case aries, taurus, gemini, cancer, leo, virgo
  case libra, scorpio, sagittarius, capricorn, aquarius, pisces

  var id: String { rawValue }

  var displayName: String {
    rawValue.prefix(1).uppercased() + rawValue.dropFirst()
  }

  /// Unicode astrological glyph — used only by the fallback renderer when the
  /// official SDK icon is unavailable. UI should never render this directly.
  var glyph: String {
    switch self {
    case .aries: "♈"
    case .taurus: "♉"
    case .gemini: "♊"
    case .cancer: "♋"
    case .leo: "♌"
    case .virgo: "♍"
    case .libra: "♎"
    case .scorpio: "♏"
    case .sagittarius: "♐"
    case .capricorn: "♑"
    case .aquarius: "♒"
    case .pisces: "♓"
    }
  }

  /// Soft pastel accent per sign (calm, not candy/neon).
  var pastel: Color {
    switch self {
    case .aries: Color(red: 0.95, green: 0.62, blue: 0.58)
    case .taurus: Color(red: 0.66, green: 0.82, blue: 0.65)
    case .gemini: Color(red: 0.95, green: 0.86, blue: 0.62)
    case .cancer: Color(red: 0.74, green: 0.83, blue: 0.95)
    case .leo: Color(red: 0.96, green: 0.74, blue: 0.50)
    case .virgo: Color(red: 0.70, green: 0.79, blue: 0.66)
    case .libra: Color(red: 0.85, green: 0.76, blue: 0.95)
    case .scorpio: Color(red: 0.80, green: 0.55, blue: 0.62)
    case .sagittarius: Color(red: 0.74, green: 0.70, blue: 0.95)
    case .capricorn: Color(red: 0.66, green: 0.72, blue: 0.78)
    case .aquarius: Color(red: 0.62, green: 0.84, blue: 0.90)
    case .pisces: Color(red: 0.72, green: 0.78, blue: 0.95)
    }
  }

  var dateRange: String {
    switch self {
    case .aries: "Mar 21 – Apr 19"
    case .taurus: "Apr 20 – May 20"
    case .gemini: "May 21 – Jun 20"
    case .cancer: "Jun 21 – Jul 22"
    case .leo: "Jul 23 – Aug 22"
    case .virgo: "Aug 23 – Sep 22"
    case .libra: "Sep 23 – Oct 22"
    case .scorpio: "Oct 23 – Nov 21"
    case .sagittarius: "Nov 22 – Dec 21"
    case .capricorn: "Dec 22 – Jan 19"
    case .aquarius: "Jan 20 – Feb 18"
    case .pisces: "Feb 19 – Mar 20"
    }
  }
}
