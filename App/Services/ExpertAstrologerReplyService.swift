import Foundation

nonisolated enum ExpertAstrologerReplyService {
    static let replyTimeout: Double = SupabaseService.companionReplyRequestTimeout
    static let replyMaxTokens: Int = 520

    struct Request: Encodable, Sendable {
        let specialistId: String
        let mode: ExpertAstrologerMode
        let userQuestion: String
        let conversationId: UUID?
        let multiConsultationId: UUID?
        /// Saved person the question is about. When present, the backend reads
        /// `expert_person_astrology_intake` + that person's latest chart import.
        let selectedPersonId: UUID?
        let profileContext: UserAstrologyContext
        let transcript: [SpecialistMessage]
        let knownDataPoints: [String]
        let missingDataPoints: [String]
        let userSuppliedTraditionData: [String: String]
        let calculatedTraditionData: [String: String]
        let readinessSummary: String
        let dataLimitations: [String]

        init(
            specialistId: String,
            mode: ExpertAstrologerMode,
            userQuestion: String,
            conversationId: UUID?,
            multiConsultationId: UUID?,
            selectedPersonId: UUID? = nil,
            profileContext: UserAstrologyContext,
            transcript: [SpecialistMessage],
            readiness: ExpertReadinessChecklist,
            manualData: ExpertManualAstrologyData
        ) {
            self.specialistId = specialistId
            self.mode = mode
            self.userQuestion = userQuestion
            self.conversationId = conversationId
            self.multiConsultationId = multiConsultationId
            self.selectedPersonId = selectedPersonId
            self.profileContext = profileContext
            self.transcript = transcript
            self.knownDataPoints = readiness.knownDataPoints
            self.missingDataPoints = readiness.missingDataPoints
            self.userSuppliedTraditionData = manualData.userSuppliedTraditionData
            self.calculatedTraditionData = [:]
            self.readinessSummary = readiness.readinessSummary
            self.dataLimitations = readiness.dataLimitations
        }
    }

    /// Offline/pre-auth reading. Each specialist has a fully distinct voice —
    /// no shared sentences — and no name prefix (every surface that renders
    /// these already shows the expert's name and title in its own header).
    static func localFallback(for request: Request) -> String {
        guard let specialist = ExpertAstrologerRegistry.specialist(id: request.specialistId) else {
            return "I could not load that specialist right now. Please try again."
        }

        let lowercasedQuestion = request.userQuestion.lowercased()
        if specialist.id == "leyla-western",
           lowercasedQuestion.contains("rising"),
           !request.profileContext.birthTimeAvailable || !request.profileContext.birthPlaceAvailable {
            return "I cannot name your Rising sign without birth time and birth location. The Rising depends on the exact horizon at the moment and place of birth, so guessing would be misleading.\n\nPractical reflection: if you can add the time and place, I can speak about your Ascendant, chart ruler, and house pattern much more cleanly."
        }
        if specialist.id == "mateo-vedic", lowercasedQuestion.contains("mercury retrograde") {
            return "From Jyotish, I would not treat Mercury retrograde as a generic pop-astrology lesson. Budha relates to speech, intellect, trade, discernment, and how the mind organizes information. A true reading would need the sidereal placement, house, dignity, and dasha context.\n\nPractical reflection: treat this as a time to refine speech and decisions rather than assume every delay has one fixed meaning."
        }
        if specialist.id == "naomi-chinese", lowercasedQuestion.contains("scorpio") {
            return "I would not interpret Scorpio, because that belongs to Western astrology. In Chinese astrology, compatibility is judged through BaZi: Day Masters, element balance, spouse palace interactions, branch combinations, and useful elements. With only a Western sign, I can only redirect the frame.\n\nPractical reflection: bring birth year, month, day, and hour for both people, and I can read the energetic balance more usefully."
        }
        if specialist.id == "elias-ancient", lowercasedQuestion.contains("pluto") {
            return "By the ancient method, Pluto is not a core traditional planet. I would judge partnership through the 7th place, its ruler, Venus, Mars, sect, and the condition of the planets involved. If timing is the question, I would also look for the active time lord, if supplied.\n\nPractical reflection: ask what condition surrounds the 7th place before giving Pluto the whole judgment."
        }
        if specialist.id == "nadia-evolutionary",
           lowercasedQuestion.contains("trauma") || lowercasedQuestion.contains("traumatized") {
            return "I cannot diagnose trauma from a chart. What I can do is read the symbolism as a reflective map: where emotional defenses, repeated patterns, sensitivity, and growth invitations may appear. If this question feels heavy or immediate, real support from a qualified professional matters.\n\nPractical reflection: ask gently, \"What pattern keeps asking for care?\" rather than using the chart to label yourself."
        }

        let context = request.profileContext
        switch specialist.id {
        case "leyla-western":
            let anchor = context.sunSign.map {
                "Your Sun in \($0) is already on file, so the identity side has an anchor; your Moon and Rising would tell me how you process and how you open."
            } ?? "I do not have your placements yet, so I will hold to the method rather than guess at your chart."
            let note = context.birthTimeAvailable && context.birthPlaceAvailable
                ? "With your birth details saved, the full reading can bring houses and real transit timing into this."
                : "Add your birth time and place, and I can bring your Rising, houses, and real transit timing into this."
            return """
            Reading this the Western way, I would start with the natal chart: what the Sun wants here, what the Moon needs, and whether the current transits make this an opening or a waiting period. \(anchor)

            Practical reflection: before you act on this, say the want underneath it in one plain sentence. Western work lands better once the need is named instead of implied.

            \(note)
            """
        case "mateo-vedic":
            let note = context.birthDateAvailable && context.birthTimeAvailable
                ? "Your saved birth details are a good start; a calculated sidereal chart, or placements you already know, would let me speak to dashas and timing properly."
                : "Birth date, exact time, and place — or sidereal placements you already know — would let me speak to dashas and timing properly."
            return """
            In Jyotish, a question like this is weighed through karma and timing: which graha carries the theme, which bhava it falls in, and whether the running period supports it. None of that can be judged without a sidereal chart, and I will not invent one.

            What I can give you now is the frame: treat this as a dharma question first. Ask which duty you have been serving and which one you have been avoiding, and let the answer sit uncomfortably for a moment before you move.

            \(note)
            """
        case "naomi-chinese":
            let note = context.birthDateAvailable
                ? "Your birth date gives me the year, month, and day context; the birth hour would complete the fourth pillar."
                : "Bring the birth year, month, day, and hour — that is where every Four Pillars reading begins."
            return """
            From a BaZi standpoint, I would set this against your Four Pillars: the Day Master that describes how you move, and the element balance that says whether this is a season to push or to hold. Those are not calculated yet, so I will stay at the level of strategy.

            Strategy for now: choose the smallest version of this that can be tested within a week, run it, and read the result before you commit anything larger.

            \(note)
            """
        case "elias-ancient":
            let note = context.birthTimeAvailable && context.birthPlaceAvailable
                ? "Your saved birth details would support sect and house judgment in the full reading."
                : "An exact birth time and place would let me judge sect, houses, and the year's profection honestly."
            return """
            An ancient astrologer takes this in order: first the house the matter belongs to, then the condition of its ruler, then whether the time lords support action at all. Without chart data, none of that can be judged, so I will hold to the order itself.

            Classical counsel: decide what you would do if nothing about the situation changed, then let one night pass before you act on it. The old astrologers trusted judgment that survives a delay.

            \(note)
            """
        case "nadia-evolutionary":
            let note = context.sunSign != nil || context.birthDateAvailable
                ? "I have your basic chart anchors saved; your own pattern notes would take this deeper."
                : "A birth date gives me your growth map's anchors; your own pattern notes make it personal."
            return """
            Evolutionary work starts a step before the answer: where has this exact question shown up in your life before, and what does keeping it unresolved protect you from feeling? The chart is a map of that pattern, not a verdict on it.

            Try this: write the situation as one sentence that begins with "I keep…". Once the pattern has a name, the chart work gets much more precise — and so do your choices.

            \(note)
            """
        default:
            return "From this specialist's tradition, I would approach the question through its own methods, using only the data you have actually supplied."
        }
    }

}
