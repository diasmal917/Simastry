import Foundation

nonisolated enum ExpertAstrologerReplyService {
    static let replyTimeout: Double = 8
    static let replyMaxTokens: Int = 520

    struct Request: Encodable, Sendable {
        let specialistId: String
        let mode: ExpertAstrologerMode
        let userQuestion: String
        let conversationId: UUID?
        let multiConsultationId: UUID?
        let profileContext: UserAstrologyContext
        let transcript: [SpecialistMessage]
    }

    static func localFallback(for request: Request) -> String {
        guard let specialist = ExpertAstrologerRegistry.specialist(id: request.specialistId) else {
            return "I could not load that specialist right now. Please try again."
        }

        let lowercasedQuestion = request.userQuestion.lowercased()
        if specialist.id == "leyla-western",
           lowercasedQuestion.contains("rising"),
           !request.profileContext.birthTimeAvailable || !request.profileContext.birthPlaceAvailable {
            return "Leyla - Western Astrologer\n\nI cannot name your Rising sign without birth time and birth location. From my Western lens, the Rising depends on the exact horizon at the moment and place of birth, so guessing would be misleading.\n\nPractical reflection: if you can add the time and place, I can speak about your Ascendant, chart ruler, and house pattern much more cleanly."
        }
        if specialist.id == "mateo-vedic", lowercasedQuestion.contains("mercury retrograde") {
            return "Mateo - Vedic Astrologer\n\nFrom Jyotish, I would not treat Mercury retrograde as a generic pop-astrology lesson. Budha relates to speech, intellect, trade, discernment, and how the mind organizes information. A true reading would need the sidereal placement, house, dignity, and dasha context.\n\nPractical reflection: treat this as a time to refine speech and decisions rather than assume every delay has one fixed meaning."
        }
        if specialist.id == "naomi-chinese", lowercasedQuestion.contains("scorpio") {
            return "Naomi - Chinese Astrologer\n\nI would not interpret Scorpio, because that belongs to Western astrology. From Chinese astrology, compatibility is better judged through BaZi: Day Masters, element balance, spouse palace interactions, branch combinations, and useful elements. With only a Western sign, I can only redirect the frame.\n\nPractical reflection: bring birth year, month, day, and hour for both people, and I can read the energetic balance more usefully."
        }
        if specialist.id == "elias-ancient", lowercasedQuestion.contains("pluto") {
            return "Elias - Ancient Astrologer\n\nBy the ancient method, Pluto is not a core traditional planet. I would judge partnership through the 7th place, its ruler, Venus, Mars, sect, and the condition of the planets involved. If timing is the question, I would also look for the active time lord, if supplied.\n\nPractical reflection: ask what condition surrounds the 7th place before giving Pluto the whole judgment."
        }
        if specialist.id == "nadia-evolutionary",
           lowercasedQuestion.contains("trauma") || lowercasedQuestion.contains("traumatized") {
            return "Nadia - Evolutionary Astrologer\n\nI cannot diagnose trauma from a chart. What I can do is read the symbolism as a reflective map: where emotional defenses, repeated patterns, sensitivity, and growth invitations may appear. If this question feels heavy or immediate, real support from a qualified professional matters.\n\nPractical reflection: ask gently, \"What pattern keeps asking for care?\" rather than using the chart to label yourself."
        }

        let dataNote: String
        switch specialist.id {
        case "naomi-chinese":
            dataNote = request.profileContext.birthDateAvailable
                ? "For a precise BaZi reading, birth time would sharpen the hour pillar."
                : "With birth date and time, I could make this more specific through the Four Pillars."
        case "mateo-vedic":
            dataNote = request.profileContext.birthTimeAvailable && request.profileContext.birthPlaceAvailable
                ? "Your available birth context helps with timing and chart emphasis."
                : "Birth time and place would make the Jyotish timing more precise."
        default:
            dataNote = request.profileContext.birthTimeAvailable && request.profileContext.birthPlaceAvailable
                ? "Your available chart context helps refine the interpretation."
                : "Birth time and place would make this more precise."
        }

        let frame = switch specialist.id {
        case "leyla-western":
            "Leyla - Western Astrologer\n\nFrom a Western tropical lens, I would look at love, identity, compatibility, and the current symbolic timing around this question."
        case "mateo-vedic":
            "Mateo - Vedic Astrologer\n\nFrom a Jyotish lens, I would read this through karma, dharma, graha condition, nakshatra emphasis, and timing cycles."
        case "naomi-chinese":
            "Naomi - Chinese Astrologer\n\nFrom a Chinese astrology lens, I would look for elemental balance, useful timing, and the pattern created by the year, month, day, and hour pillars."
        case "elias-ancient":
            "Elias - Ancient Astrologer\n\nFrom an ancient lens, I would judge planetary condition, sect, whole sign topics, and timing methods before giving a conclusion."
        case "nadia-evolutionary":
            "Nadia - Evolutionary Astrologer\n\nFrom an evolutionary lens, I would ask what growth pattern, emotional repetition, or soul lesson this situation is inviting you to work with."
        default:
            "From this specialist's tradition, I would approach the question through its own methods."
        }

        return """
        \(frame)

        For “\(request.userQuestion)”, the cleanest first insight is to treat the question as a pattern rather than a verdict. Notice what keeps repeating, what timing is asking from you, and where a more conscious choice is available.

        \(dataNote)
        """
    }

}
