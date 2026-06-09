import SwiftUI

nonisolated struct CommunicationTypeProfile: Identifiable, Equatable, Sendable {
    let title: String
    let summary: String
    let sunSignal: String
    let moonSignal: String
    let risingSignal: String
    let keywords: [String]
    let accent: Color

    var id: String { title }

    static func make(sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) -> CommunicationTypeProfile? {
        guard let sun else { return nil }
        let adjective = rising.map(risingAdjective) ?? elementAdjective(for: sun.element)
        let archetype = sunArchetype(for: sun)
        let moonText = moon.map(moonPattern) ?? "Your Moon refines emotional reaction once it is known."
        let risingText = rising.map(risingPattern) ?? "Your Rising refines first response once it is known."

        return CommunicationTypeProfile(
            title: "\(adjective) \(archetype)",
            summary: "\(sun.displayName) Sun gives the core communication drive. \(moonText) \(risingText)",
            sunSignal: sunDrive(for: sun),
            moonSignal: moonText,
            risingSignal: risingText,
            keywords: Array([elementKeyword(for: sun.element), moon.map(elementKeywordForMoon), rising.map(risingKeyword)].compactMap { $0 }.prefix(3)),
            accent: rising?.color ?? sun.color
        )
    }

    static func methodSignal(sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) -> MethodSignal? {
        guard let profile = make(sun: sun, moon: moon, rising: rising) else { return nil }
        return MethodSignal(
            label: "Communication type",
            detail: profile.title,
            systemImage: "bubble.left.and.text.bubble.right.fill",
            tint: profile.accent
        )
    }

    private static func sunArchetype(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "Initiator"
        case .taurus: "Anchor"
        case .gemini: "Translator"
        case .cancer: "Protector"
        case .leo: "Performer"
        case .virgo: "Analyst"
        case .libra: "Diplomat"
        case .scorpio: "Truth-Seeker"
        case .sagittarius: "Explorer"
        case .capricorn: "Strategist"
        case .aquarius: "Signal"
        case .pisces: "Dreamer"
        }
    }

    private static func risingAdjective(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "Direct"
        case .taurus: "Steady"
        case .gemini: "Curious"
        case .cancer: "Careful"
        case .leo: "Radiant"
        case .virgo: "Precise"
        case .libra: "Diplomatic"
        case .scorpio: "Intense"
        case .sagittarius: "Open"
        case .capricorn: "Measured"
        case .aquarius: "Original"
        case .pisces: "Soft"
        }
    }

    private static func elementAdjective(for element: ZodiacElement) -> String {
        switch element {
        case .fire: "Direct"
        case .earth: "Grounded"
        case .air: "Social"
        case .water: "Soft"
        }
    }

    private static func sunDrive(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "Moves fast, names the point, and prefers momentum over overthinking."
        case .taurus: "Builds trust through consistency, calm pacing, and concrete reassurance."
        case .gemini: "Processes through language, options, questions, and quick reframes."
        case .cancer: "Communicates through emotional safety, memory, and protective subtext."
        case .leo: "Needs warmth, recognition, and a tone that feels generous."
        case .virgo: "Looks for precision, usefulness, and small details that prove care."
        case .libra: "Reads tone, fairness, timing, and social balance before responding."
        case .scorpio: "Tracks depth, honesty, control, and what is not being said."
        case .sagittarius: "Needs honesty, space, humor, and room for the conversation to breathe."
        case .capricorn: "Trusts maturity, restraint, reliability, and messages with structure."
        case .aquarius: "Responds to originality, autonomy, and ideas that leave room to think."
        case .pisces: "Reads feeling, atmosphere, longing, and the emotional music beneath words."
        }
    }

    private static func moonPattern(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "Your \(sign.displayName) Moon reacts quickly and cools down when action is possible."
        case .taurus: "Your \(sign.displayName) Moon wants steadiness before it opens."
        case .gemini: "Your \(sign.displayName) Moon metabolizes emotion by talking it through."
        case .cancer: "Your \(sign.displayName) Moon may read silence as emotional distance."
        case .leo: "Your \(sign.displayName) Moon needs warmth to feel safe enough to soften."
        case .virgo: "Your \(sign.displayName) Moon looks for details it can repair or improve."
        case .libra: "Your \(sign.displayName) Moon wants emotional balance and clean tone."
        case .scorpio: "Your \(sign.displayName) Moon tracks intensity and hidden motives."
        case .sagittarius: "Your \(sign.displayName) Moon needs emotional room and honesty."
        case .capricorn: "Your \(sign.displayName) Moon protects itself through composure."
        case .aquarius: "Your \(sign.displayName) Moon needs space before naming feelings."
        case .pisces: "Your \(sign.displayName) Moon absorbs atmosphere before facts."
        }
    }

    private static func risingPattern(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "Your \(sign.displayName) Rising answers first with immediacy."
        case .taurus: "Your \(sign.displayName) Rising answers first by stabilizing the room."
        case .gemini: "Your \(sign.displayName) Rising answers first with questions."
        case .cancer: "Your \(sign.displayName) Rising answers first by checking safety."
        case .leo: "Your \(sign.displayName) Rising answers first with warmth and presence."
        case .virgo: "Your \(sign.displayName) Rising answers first by sorting the details."
        case .libra: "Your \(sign.displayName) Rising answers first through tone and diplomacy."
        case .scorpio: "Your \(sign.displayName) Rising answers first by scanning for truth."
        case .sagittarius: "Your \(sign.displayName) Rising answers first with candor."
        case .capricorn: "Your \(sign.displayName) Rising answers first with restraint."
        case .aquarius: "Your \(sign.displayName) Rising answers first from distance and perspective."
        case .pisces: "Your \(sign.displayName) Rising answers first through feeling."
        }
    }

    private static func elementKeyword(for element: ZodiacElement) -> String {
        switch element {
        case .fire: "direct"
        case .earth: "steady"
        case .air: "social"
        case .water: "sensitive"
        }
    }

    private static func elementKeywordForMoon(_ sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire: "reactive"
        case .earth: "grounded"
        case .air: "processing"
        case .water: "protective"
        }
    }

    private static func risingKeyword(_ sign: ZodiacSign) -> String {
        switch sign.modality {
        case "cardinal": "initiating"
        case "fixed": "steady"
        default: "adaptive"
        }
    }
}
