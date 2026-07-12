import Foundation

/// The deterministic copy bank for day windows. The engine emits sky facts;
/// this file turns them into short, honest lines.
///
/// Rules (lint-tested across 366 days × 3 styles):
/// - Titles lead with "Favors" / "Leans" / "Good window for" / "Quiet" —
///   except `astrologyRich`, which may lead with the sky fact and carry the
///   same verb after an em dash ("Moon trine Mars — favors …").
/// - Windows describe what an hour favors, never outcomes. No "will happen",
///   no "guaranteed", no "bad"/"avoid"/"unlucky" framing.
/// - Degree and clock phrasing never appears here; it lives only in the
///   engine's `derivation` strings (pure transiting-sky facts).
/// - Every pick is keyed by day-of-year so identical inputs give identical
///   copy, and wording varies day to day without randomness.
nonisolated enum DayWindowCopy {
    struct Lines: Equatable, Sendable {
        let title: String
        let rationale: String
    }

    // MARK: - Moon sign segments

    private static let signThemes: [ZodiacSign: [String]] = [
        .aries: ["starting the thing that needs a push", "direct asks and first moves"],
        .taurus: ["steady follow-through", "slow, tangible progress"],
        .gemini: ["quick errands and catch-ups", "conversations that need lightness"],
        .cancer: ["checking in on your people", "home matters and quiet care"],
        .leo: ["visible work and warm gestures", "saying the generous thing out loud"],
        .virgo: ["detail work and tidying loose ends", "fixing the small things properly"],
        .libra: ["smoothing things over", "meeting people halfway"],
        .scorpio: ["focused deep work", "the conversation that needs honesty"],
        .sagittarius: ["big-picture planning", "saying yes to the wider view"],
        .capricorn: ["structured work and long tasks", "doing the responsible thing first"],
        .aquarius: ["group plans and unconventional fixes", "the odd idea worth testing"],
        .pisces: ["rest, art, and low-stakes drifting", "soft starts and imagination"]
    ]

    static func moonSign(sign: ZodiacSign, style: GuidanceStyle, dayOfYear: Int) -> Lines {
        let theme = pick(dayOfYear, signThemes[sign] ?? ["steady, ordinary progress"])
        let title: String
        switch style {
        case .practical:
            title = "Good window for \(theme)"
        case .balanced:
            title = "Good window for \(theme) — Moon in \(sign.displayName)"
        case .astrologyRich:
            title = "Moon in \(sign.displayName) — favors \(theme)"
        }
        let rationale: String
        switch style {
        case .practical:
            rationale = pick(dayOfYear, [
                "A steady baseline for this stretch — \(theme) suits the mood.",
                "The day's undercurrent leans toward \(theme)."
            ])
        case .balanced:
            rationale = pick(dayOfYear, [
                "The Moon is moving through \(sign.displayName); stretches like this lean toward \(theme).",
                "With the Moon in \(sign.displayName), the tone leans toward \(theme)."
            ])
        case .astrologyRich:
            rationale = pick(dayOfYear, [
                "The transiting Moon in \(sign.displayName) colors the day's mood — it leans toward \(theme).",
                "Moon-in-\(sign.displayName) hours carry that sign's temperament; they lean toward \(theme)."
            ])
        }
        return Lines(title: title, rationale: rationale)
    }

    // MARK: - Void of course

    static func voidOfCourse(sign: ZodiacSign, nextSign: ZodiacSign, style: GuidanceStyle, dayOfYear: Int) -> Lines {
        let title: String
        switch style {
        case .practical:
            title = pick(dayOfYear, [
                "Leans quiet — favors finishing and rest, not launches",
                "Leans low-stakes — favors wrapping up, not starting"
            ])
        case .balanced:
            title = pick(dayOfYear, [
                "Leans quiet — favors finishing and rest — Moon void in \(sign.displayName)",
                "Leans low-stakes — favors wrapping up — Moon void in \(sign.displayName)"
            ])
        case .astrologyRich:
            title = pick(dayOfYear, [
                "Moon void in \(sign.displayName) — leans quiet, favors finishing and rest",
                "Moon void in \(sign.displayName) — leans low-stakes until \(nextSign.displayName)"
            ])
        }
        let rationale: String
        switch style {
        case .practical:
            rationale = pick(dayOfYear, [
                "A between-chapters stretch — momentum drifts, so finish rather than launch.",
                "Loose-ends time: wrap up, rest, and let new decisions wait a beat."
            ])
        case .balanced:
            rationale = pick(dayOfYear, [
                "The Moon makes no more exact contacts before changing signs — a natural wind-down.",
                "A void stretch: the Moon is between its last contact and the next sign, which leans quiet."
            ])
        case .astrologyRich:
            rationale = pick(dayOfYear, [
                "With no further applying aspects before \(nextSign.displayName), the void Moon traditionally favors finishing and rest over launches.",
                "The void-of-course Moon runs from its last exact aspect to the \(nextSign.displayName) ingress — kept for wrapping up, not starting."
            ])
        }
        return Lines(title: title, rationale: rationale)
    }

    // MARK: - Exact Moon aspects

    private static let flowThemes: [DayPlanet: [String]] = [
        .sun: ["putting your work where people can see it", "warm, direct appreciation"],
        .mercury: ["messages, asks, and quick errands", "saying the clear thing plainly"],
        .venus: ["warm asks and small repairs", "social plans and easy company"],
        .mars: ["a decisive push on the hard task", "starting what needs momentum"],
        .jupiter: ["the bigger ask", "planning past next week"],
        .saturn: ["patient, structured work", "finishing what you committed to"],
        .uranus: ["trying the unconventional fix", "breaking a stale routine on purpose"],
        .neptune: ["imaginative work and rest", "art, music, and soft focus"],
        .pluto: ["focused deep work", "the honest conversation under the surface"]
    ]

    private static let frictionThemes: [DayPlanet: [String]] = [
        .sun: ["keeping your ego out of the reply", "letting the work speak first"],
        .mercury: ["double-checking the wording", "drafting now and sending later"],
        .venus: ["keeping asks small and kind", "repair over point-scoring"],
        .mars: ["pacing the push", "spending the heat on a task, not a person"],
        .jupiter: ["right-sizing the promise", "checking the optimism against the calendar"],
        .saturn: ["trimming the plan to what fits", "doing the unglamorous step properly"],
        .uranus: ["leaving room for plans to change", "holding the impulse for an hour"],
        .neptune: ["naming what is actually known", "letting the fog pass before deciding"],
        .pluto: ["loosening your grip a notch", "noticing the power line under the topic"]
    ]

    private static let emphasisThemes: [DayPlanet: [String]] = [
        .sun: ["one clear priority", "leading with the main thing"],
        .mercury: ["one message that says it all", "putting the point in the first line"],
        .venus: ["one warm gesture made on purpose", "tending the relationship that matters most"],
        .mars: ["one committed start", "the first move you keep postponing"],
        .jupiter: ["one generous, concrete offer", "backing one plan fully"],
        .saturn: ["one responsibility done completely", "the long task, taken seriously"],
        .uranus: ["one deliberate experiment", "the odd idea worth an hour"],
        .neptune: ["one unhurried, imaginative hour", "listening more than steering"],
        .pluto: ["one thing examined honestly", "going deeper on a single question"]
    ]

    private static let planetDomains: [DayPlanet: String] = [
        .sun: "visibility", .moon: "mood", .mercury: "wording", .venus: "warmth",
        .mars: "momentum", .jupiter: "confidence", .saturn: "discipline",
        .uranus: "surprises", .neptune: "imagination", .pluto: "intensity"
    ]

    static func moonAspect(planet: DayPlanet, kind: MoonAspectKind, style: GuidanceStyle, dayOfYear: Int) -> Lines {
        let fact = "Moon \(kind.displayName) \(planet.displayName)"
        let domain = planetDomains[planet] ?? "the hour"
        let theme: String
        let practicalTitle: String
        switch kind.family {
        case "flow":
            theme = pick(dayOfYear, flowThemes[planet] ?? ["easy, direct progress"])
            practicalTitle = "Good window for \(theme)"
        case "friction":
            theme = pick(dayOfYear, frictionThemes[planet] ?? ["one extra pass before committing"])
            practicalTitle = "Favors \(theme)"
        default:
            theme = pick(dayOfYear, emphasisThemes[planet] ?? ["one thing at a time"])
            practicalTitle = "Favors \(theme)"
        }

        let title: String
        switch style {
        case .practical:
            title = practicalTitle
        case .balanced:
            title = "\(practicalTitle) — \(fact)"
        case .astrologyRich:
            title = "\(fact) — favors \(theme)"
        }

        let rationale: String
        switch (kind.family, style) {
        case ("flow", .practical):
            rationale = pick(dayOfYear, [
                "An easy stretch — \(domain) tends to work with you.",
                "A smooth patch for anything that needs \(domain)."
            ])
        case ("flow", .balanced):
            rationale = pick(dayOfYear, [
                "The Moon makes an easy angle to \(planet.displayName) — a supportive stretch for \(domain).",
                "Moon–\(planet.displayName) contacts like this lean smooth; \(domain) comes easier."
            ])
        case ("flow", .astrologyRich):
            rationale = pick(dayOfYear, [
                "The Moon's \(kind.rawValue) to \(planet.displayName) is a flowing contact — \(domain) runs with less resistance.",
                "A classic flowing Moon–\(planet.displayName) contact; the hour leans toward \(domain) that lands."
            ])
        case ("friction", .practical):
            rationale = pick(dayOfYear, [
                "A scratchier stretch — \(domain) rewards a second look.",
                "Expect a little static around \(domain) here."
            ])
        case ("friction", .balanced):
            rationale = pick(dayOfYear, [
                "The Moon meets \(planet.displayName) at a working angle — \(domain) reads louder than you mean it.",
                "A frictional Moon–\(planet.displayName) contact; give \(domain) one extra pass."
            ])
        case ("friction", .astrologyRich):
            rationale = pick(dayOfYear, [
                "The Moon's \(kind.rawValue) to \(planet.displayName) adds friction — \(domain) benefits from a pause before you commit.",
                "A hard Moon–\(planet.displayName) angle; the hour rewards care with \(domain)."
            ])
        case (_, .practical):
            rationale = pick(dayOfYear, [
                "A concentrated stretch — one thing at a time lands best.",
                "Emphasis hours reward leading with what matters."
            ])
        case (_, .balanced):
            rationale = pick(dayOfYear, [
                "The Moon joins \(planet.displayName) — \(domain) gets amplified for a stretch.",
                "A Moon–\(planet.displayName) conjunction concentrates the hour around \(domain)."
            ])
        case (_, .astrologyRich):
            rationale = pick(dayOfYear, [
                "The Moon's conjunction with \(planet.displayName) concentrates \(domain) — whatever you lead with gets louder.",
                "Moon conjunct \(planet.displayName): a compressed, single-topic stretch for \(domain)."
            ])
        }
        return Lines(title: title, rationale: rationale)
    }

    // MARK: - Quiet gaps

    static func quiet(style: GuidanceStyle, dayOfYear: Int) -> Lines {
        let title: String
        switch style {
        case .practical:
            title = pick(dayOfYear, [
                "Quiet hours — favors rest and routine",
                "Quiet stretch — favors steady, unhurried work"
            ])
        case .balanced:
            title = pick(dayOfYear, [
                "Quiet hours — no exact Moon contacts; favors rest and routine",
                "Quiet stretch — the sky is between events; favors steady focus"
            ])
        case .astrologyRich:
            title = pick(dayOfYear, [
                "Quiet sky — no exact Moon contacts in this stretch; favors rest and unhurried work",
                "Quiet interval between Moon contacts — favors routine, rest, and slow starts"
            ])
        }
        let rationale: String
        switch style {
        case .practical:
            rationale = pick(dayOfYear, [
                "Nothing is pulling at this stretch — good for routine and recovery.",
                "An unhurried patch; let it be simple."
            ])
        case .balanced:
            rationale = pick(dayOfYear, [
                "No exact Moon contacts land in this stretch, so it reads calm.",
                "The sky is between events here — a natural low-key patch."
            ])
        case .astrologyRich:
            rationale = pick(dayOfYear, [
                "With no exact lunar contacts in the span, the hours lean neutral — rest and routine fit them well.",
                "An aspect-free lunar stretch: quiet sky, which is its own kind of useful."
            ])
        }
        return Lines(title: title, rationale: rationale)
    }

    // MARK: - Planetary hours (engine-complete, UI-dormant in v1)

    private static let hourThemes: [DayPlanet: [String]] = [
        .sun: ["visible work", "leading with the main thing"],
        .moon: ["check-ins and care", "tending the routine"],
        .mercury: ["messages and errands", "sorting and writing"],
        .venus: ["warm asks and repair", "company and accord"],
        .mars: ["a focused push", "the effortful start"],
        .jupiter: ["the bigger ask", "generous planning"],
        .saturn: ["structured, patient work", "finishing what is owed"]
    ]

    static func planetaryHour(ruler: DayPlanet, style: GuidanceStyle, dayOfYear: Int) -> Lines {
        let theme = pick(dayOfYear, hourThemes[ruler] ?? ["steady, ordinary work"])
        let title: String
        switch style {
        case .practical:
            title = "Good window for \(theme)"
        case .balanced:
            title = "Good window for \(theme) — \(ruler.displayName) hour"
        case .astrologyRich:
            title = "\(ruler.displayName) hour — favors \(theme)"
        }
        let rationale: String
        switch style {
        case .practical:
            rationale = pick(dayOfYear, [
                "A short stretch that suits \(theme).",
                "An hour shaped for \(theme)."
            ])
        case .balanced:
            rationale = pick(dayOfYear, [
                "By the planetary-hours clock this hour belongs to \(ruler.displayName) — it leans toward \(theme).",
                "A \(ruler.displayName)-ruled hour; it suits \(theme)."
            ])
        case .astrologyRich:
            rationale = pick(dayOfYear, [
                "In the Chaldean order this hour is ruled by \(ruler.displayName), traditionally kept for \(theme).",
                "\(ruler.displayName)'s hour by the old planetary clock — kept for \(theme)."
            ])
        }
        return Lines(title: title, rationale: rationale)
    }

    // MARK: - All-day natal transit context (whole-sign only, no clock, no degrees)

    static func dailyTransit(fact: String, family: String, style: GuidanceStyle, dayOfYear: Int) -> Lines {
        let theme: String
        switch family {
        case "flow":
            theme = pick(dayOfYear, [
                "reaching out while the day leans with you",
                "the warm message you keep postponing"
            ])
        case "friction":
            theme = pick(dayOfYear, [
                "drafting first and sending second",
                "shorter, cooler replies"
            ])
        default:
            theme = pick(dayOfYear, [
                "saying the important thing once, well",
                "keeping the spotlight on one topic"
            ])
        }
        let title: String
        switch style {
        case .practical:
            title = "Favors \(theme)"
        case .balanced:
            title = "Favors \(theme) — \(fact)"
        case .astrologyRich:
            title = "\(fact) — favors \(theme)"
        }
        let rationale: String
        switch style {
        case .practical:
            rationale = pick(dayOfYear, [
                "Today's background contact colors interactions all day.",
                "An all-day tone, not a timed event."
            ])
        case .balanced:
            rationale = pick(dayOfYear, [
                "\(fact) is today's whole-sign contact — background weather, not a timed event.",
                "A sign-to-sign contact shapes the day's tone: \(fact)."
            ])
        case .astrologyRich:
            rationale = pick(dayOfYear, [
                "\(fact) is a whole-sign contact from the transiting sky to your chart — an all-day lean rather than a clocked window.",
                "Read sign-to-sign, \(fact) sets the day's undertone."
            ])
        }
        return Lines(title: title, rationale: rationale)
    }

    // MARK: - Lint corpus

    /// Every title/rationale combination the bank can produce for one day and
    /// style. The 366-day language-lint test walks this so no phrasing can
    /// drift into outcome claims unnoticed.
    static func lintCorpus(dayOfYear: Int, style: GuidanceStyle) -> [(kind: DayWindowKind, title: String, rationale: String)] {
        var corpus: [(DayWindowKind, String, String)] = []
        for sign in ZodiacSign.allCases {
            let lines = moonSign(sign: sign, style: style, dayOfYear: dayOfYear)
            corpus.append((.moonSign, lines.title, lines.rationale))
            let nextSign = ZodiacSign.allCases[(ZodiacSign.allCases.firstIndex(of: sign)! + 1) % 12]
            let voc = voidOfCourse(sign: sign, nextSign: nextSign, style: style, dayOfYear: dayOfYear)
            corpus.append((.voidOfCourse, voc.title, voc.rationale))
        }
        for planet in DayPlanet.allCases where planet != .moon {
            for kind in MoonAspectKind.allCases {
                let lines = moonAspect(planet: planet, kind: kind, style: style, dayOfYear: dayOfYear)
                corpus.append((.moonAspect, lines.title, lines.rationale))
            }
        }
        for ruler in [DayPlanet.saturn, .jupiter, .mars, .sun, .venus, .mercury, .moon] {
            let lines = planetaryHour(ruler: ruler, style: style, dayOfYear: dayOfYear)
            corpus.append((.planetaryHour, lines.title, lines.rationale))
        }
        for body in TransitBody.allCases {
            for family in ["flow", "friction", "emphasis"] {
                let fact = "\(body.displayName) trine your Sun"
                let lines = dailyTransit(fact: fact, family: family, style: style, dayOfYear: dayOfYear)
                corpus.append((.dailyTransit, lines.title, lines.rationale))
            }
        }
        let quietLines = quiet(style: style, dayOfYear: dayOfYear)
        corpus.append((.quiet, quietLines.title, quietLines.rationale))
        return corpus.map { (kind: $0.0, title: $0.1, rationale: $0.2) }
    }

    // MARK: - Helpers

    private static func pick(_ day: Int, _ options: [String]) -> String {
        guard !options.isEmpty else { return "" }
        return options[abs(day) % options.count]
    }
}
