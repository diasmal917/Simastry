import SwiftUI

nonisolated enum ZodiacElement: String, CaseIterable, Codable, Sendable {
    case fire, earth, air, water
}

nonisolated enum ZodiacSign: String, CaseIterable, Codable, Identifiable, Sendable {
    case aries, taurus, gemini, cancer, leo, virgo
    case libra, scorpio, sagittarius, capricorn, aquarius, pisces

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var compactCode: String {
        switch self {
        case .aries: "ARI"
        case .taurus: "TAU"
        case .gemini: "GEM"
        case .cancer: "CAN"
        case .leo: "LEO"
        case .virgo: "VIR"
        case .libra: "LIB"
        case .scorpio: "SCO"
        case .sagittarius: "SAG"
        case .capricorn: "CAP"
        case .aquarius: "AQU"
        case .pisces: "PIS"
        }
    }

    var iconAssetName: String {
        "Zodiacs_\(rawValue)"
    }

    var glyph: String {
        switch self {
        case .aries: "♈︎"
        case .taurus: "♉︎"
        case .gemini: "♊︎"
        case .cancer: "♋︎"
        case .leo: "♌︎"
        case .virgo: "♍︎"
        case .libra: "♎︎"
        case .scorpio: "♏︎"
        case .sagittarius: "♐︎"
        case .capricorn: "♑︎"
        case .aquarius: "♒︎"
        case .pisces: "♓︎"
        }
    }

    var color: Color {
        switch self {
        case .aries: Color(red: 232/255, green: 160/255, blue: 154/255)
        case .taurus: Color(red: 194/255, green: 224/255, blue: 168/255)
        case .gemini: Color(red: 192/255, green: 168/255, blue: 212/255)
        case .cancer: Color(red: 160/255, green: 196/255, blue: 220/255)
        case .leo: Color(red: 224/255, green: 160/255, blue: 184/255)
        case .virgo: Color(red: 152/255, green: 212/255, blue: 184/255)
        case .libra: Color(red: 216/255, green: 176/255, blue: 208/255)
        case .scorpio: Color(red: 136/255, green: 184/255, blue: 216/255)
        case .sagittarius: Color(red: 216/255, green: 184/255, blue: 152/255)
        case .capricorn: Color(red: 144/255, green: 208/255, blue: 168/255)
        case .aquarius: Color(red: 192/255, green: 168/255, blue: 216/255)
        case .pisces: Color(red: 152/255, green: 212/255, blue: 200/255)
        }
    }

    var element: ZodiacElement {
        switch self {
        case .aries, .leo, .sagittarius: .fire
        case .taurus, .virgo, .capricorn: .earth
        case .gemini, .libra, .aquarius: .air
        case .cancer, .scorpio, .pisces: .water
        }
    }

    var modality: String {
        switch self {
        case .aries, .cancer, .libra, .capricorn: return "cardinal"
        case .taurus, .leo, .scorpio, .aquarius: return "fixed"
        case .gemini, .virgo, .sagittarius, .pisces: return "mutable"
        }
    }

    /// Element-based compatibility: same element = high, compatible elements = medium, others = lower
    static func compatibilityScore(
        userSun: ZodiacSign, userMoon: ZodiacSign, userRising: ZodiacSign,
        companionSun: ZodiacSign, companionMoon: ZodiacSign, companionRising: ZodiacSign
    ) -> Int {
        var score = 50 // base

        // Element compatibility (fire-air and earth-water are compatible)
        let compatibleElements: Set<Set<ZodiacElement>> = [[.fire, .air], [.earth, .water]]

        // Sun-Sun (most important, weighted 3x)
        if userSun.element == companionSun.element {
            score += 15
        } else if compatibleElements.contains([userSun.element, companionSun.element]) {
            score += 9
        }

        // Moon-Moon (emotional compatibility, weighted 2x)
        if userMoon.element == companionMoon.element {
            score += 12
        } else if compatibleElements.contains([userMoon.element, companionMoon.element]) {
            score += 7
        }

        // Rising-Rising
        if userRising.element == companionRising.element {
            score += 8
        } else if compatibleElements.contains([userRising.element, companionRising.element]) {
            score += 5
        }

        // Same sign bonus
        if userSun == companionSun { score += 5 }
        if userMoon == companionMoon { score += 5 }

        // Modality harmony (same modality can be challenging)
        if userSun.modality == companionSun.modality && userSun != companionSun {
            score -= 3
        }

        return min(max(score, 30), 98)
    }

    static func fromDate(_ date: Date) -> ZodiacSign {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        switch (month, day) {
        case (3, 21...31), (4, 1...19): return .aries
        case (4, 20...30), (5, 1...20): return .taurus
        case (5, 21...31), (6, 1...20): return .gemini
        case (6, 21...30), (7, 1...22): return .cancer
        case (7, 23...31), (8, 1...22): return .leo
        case (8, 23...31), (9, 1...22): return .virgo
        case (9, 23...30), (10, 1...22): return .libra
        case (10, 23...31), (11, 1...21): return .scorpio
        case (11, 22...30), (12, 1...21): return .sagittarius
        case (12, 22...31), (1, 1...19): return .capricorn
        case (1, 20...31), (2, 1...18): return .aquarius
        case (2, 19...29), (3, 1...20): return .pisces
        default: return .capricorn
        }
    }
}
