import Foundation

/// One expert's short daily note: a lead line, one practical move, and the
/// question that seeds a consultation about it.
nonisolated struct DailyExpertNote: Equatable, Sendable {
    let specialistId: String
    let headline: String
    let move: String
    let askPrompt: String
}

/// Composes the daily note for the user's chosen expert. Every input is
/// honestly derivable — the real whole-sign transit sky (Swiss Ephemeris),
/// the weekday's planetary ruler (used in both Hellenistic planetary days and
/// the Jyotish vara), the traditional seasonal element, and which placements
/// the user has actually saved. No dashas, pillars, sect, houses, or aspects
/// are ever claimed. Deterministic per day so the Today card and the morning
/// notification always say the same thing.
nonisolated enum DailyExpertNoteComposer {
    static func note(
        for specialistId: String,
        on date: Date = Date(),
        sun: ZodiacSign?,
        moon: ZodiacSign?,
        rising: ZodiacSign?
    ) -> DailyExpertNote {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        switch specialistId {
        case "mateo-vedic":
            return mateo(day: day, date: date)
        case "naomi-chinese":
            return naomi(day: day, date: date)
        case "elias-ancient":
            return soren(day: day, date: date)
        case "nadia-evolutionary":
            return nadia(day: day, date: date, sun: sun, moon: moon, rising: rising)
        default:
            return leyla(day: day, date: date, sun: sun, moon: moon, rising: rising)
        }
    }

    /// The push body for the same note — headline plus move, matching the card.
    static func notificationBody(
        for specialistId: String,
        on date: Date,
        sun: ZodiacSign?,
        moon: ZodiacSign?,
        rising: ZodiacSign?
    ) -> String {
        let note = note(for: specialistId, on: date, sun: sun, moon: moon, rising: rising)
        return "\(note.headline) \(note.move)"
    }

    // MARK: - Leyla (Western tropical: real whole-sign transit)

    private static func leyla(day: Int, date: Date, sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) -> DailyExpertNote {
        let askPrompt = "How should I use today's sky in how I show up with people?"
        guard let reading = TransitEngine.dailyReading(sun: sun, moon: moon, rising: rising, on: date) else {
            return DailyExpertNote(
                specialistId: "leyla-western",
                headline: sun == nil
                    ? "No chart is on file yet, so today's note stays general: the Western day starts with naming what you actually want."
                    : "Nothing in today's sky makes a whole-sign contact with your saved placements — a quieter day by that measure.",
                move: pick(day, [
                    "Say one true thing plainly today; skip the softening clause.",
                    "Before any charged reply, name the need under it in one sentence.",
                    "Let one conversation be shorter and warmer than usual."
                ]),
                askPrompt: askPrompt
            )
        }

        let headline = "\(reading.body.displayName) is \(reading.aspect.displayName) your \(reading.natalRole.displayName) today."
        let move: String
        switch reading.aspect.family {
        case "flow":
            move = pick(day, [
                "The contact leans supportive — send the warm message you keep postponing.",
                "Openings like this reward plain language; ask directly for what you want.",
                "Use the ease: repair one small thing before it needs a bigger repair."
            ])
        case "friction":
            move = pick(day, [
                "Expect a little static in first drafts — write now, send after a pause.",
                "Friction days read tone as louder than you mean it; shorten the message.",
                "Disagree with the idea, not the person, and today stays workable."
            ])
        default:
            move = pick(day, [
                "Emphasis days amplify whatever you lead with — choose the first line carefully.",
                "What you repeat today gets remembered; say the important thing once, well.",
                "Keep the spotlight on one topic instead of three."
            ])
        }
        return DailyExpertNote(specialistId: "leyla-western", headline: headline, move: move, askPrompt: askPrompt)
    }

    // MARK: - Mateo (Jyotish: the vara — weekday ruler — needs no chart data)

    private static func mateo(day: Int, date: Date) -> DailyExpertNote {
        let (graha, theme, moves): (String, String, [String]) = switch weekday(of: date) {
        case 1: ("Surya, the Sun", "vitality and duty", [
            "Do the obligation you carry alone first; the rest of the day follows it.",
            "Lead one thing visibly today, without waiting to be asked."
        ])
        case 2: ("Chandra, the Moon", "care and nourishment", [
            "Feed something today — a person, a habit, a rest you keep skipping.",
            "Let one decision wait until you have eaten and slept on it."
        ])
        case 3: ("Mangala, Mars", "effort and courage", [
            "Pick the hard task, start it badly, and keep going — Mangala honors effort over polish.",
            "Say the direct thing you have been circling, without heat."
        ])
        case 4: ("Budha, Mercury", "speech and discernment", [
            "Write the message twice: once to vent, once to send.",
            "Sort one muddle into a list today; Budha's day rewards clear categories."
        ])
        case 5: ("Guru, Jupiter", "counsel and generosity", [
            "Ask advice from someone you respect before deciding — Guru's day favors received wisdom.",
            "Teach or share one thing you know; generosity is the day's dharma."
        ])
        case 6: ("Shukra, Venus", "relationship and beauty", [
            "Tend one relationship on purpose today, not in passing.",
            "Make one thing more beautiful than it needs to be."
        ])
        default: ("Shani, Saturn", "discipline and patience", [
            "Finish something old before starting anything new — Shani's day counts completions.",
            "Accept one slow process without pushing it; patience is the practice."
        ])
        }
        return DailyExpertNote(
            specialistId: "mateo-vedic",
            headline: "By the Vedic week, today belongs to \(graha) — a day of \(theme).",
            move: pick(day, moves),
            askPrompt: "What duty deserves my attention today?"
        )
    }

    // MARK: - Naomi (BaZi/Five Elements: traditional seasonal element)

    private static func naomi(day: Int, date: Date) -> DailyExpertNote {
        let (element, quality, moves): (String, String, [String]) = switch seasonalElement(of: date) {
        case "Wood": ("Wood", "growth and planning", [
            "Plant one thing today — a request, a draft, a seed of a plan — and let it be small.",
            "Growth season favors direction over speed: decide where, not how fast."
        ])
        case "Fire": ("Fire", "visibility and expansion", [
            "Visibility helps today; overcommitment does not. Say yes to one thing fully.",
            "Show the work you usually hide — Fire season rewards being seen, briefly."
        ])
        case "Metal": ("Metal", "refinement and boundaries", [
            "Cut one thing cleanly today — a task, a habit, a maybe that should be a no.",
            "Refine instead of adding: the strongest move in Metal season is subtraction."
        ])
        default: ("Water", "depth and conservation", [
            "Conserve today: go deeper on one thing rather than wider on five.",
            "Water season favors listening; let the other person finish, then decide."
        ])
        }
        return DailyExpertNote(
            specialistId: "naomi-chinese",
            headline: "In the traditional calendar, this stretch of the year belongs to \(element) — a season of \(quality).",
            move: pick(day, moves),
            askPrompt: "What is the practical strategy for today?"
        )
    }

    // MARK: - Soren (Hellenistic: planetary days, restraint counsel)

    private static func soren(day: Int, date: Date) -> DailyExpertNote {
        let (planet, topics, moves): (String, String, [String]) = switch weekday(of: date) {
        case 1: ("the Sun", "honors and visible work", [
            "Do the visible thing well and the invisible things quietly; a poor day for false modesty.",
            "Claim credit once, plainly, where it is due — and nowhere else."
        ])
        case 2: ("the Moon", "the household and changing moods", [
            "Judge nothing final today; Moon days shift by evening.",
            "Tend the domestic and the routine — a poor day for grand launches."
        ])
        case 3: ("Mars", "contest and cutting through", [
            "Good for finishing fights already started; poor for starting new ones.",
            "Spend the heat on a task, not a person."
        ])
        case 4: ("Mercury", "letters, lists, and errands", [
            "Good for letters, lists, and errands; poor for oaths.",
            "Answer the messages, file the papers, and promise nothing large."
        ])
        case 5: ("Jupiter", "counsel and increase", [
            "A fitting day to ask, negotiate, or extend goodwill — within your means.",
            "Take the meeting; defer the signature to a soberer hour."
        ])
        case 6: ("Venus", "accord and pleasures", [
            "Make peace where peace is cheap today; it will not be cheaper later.",
            "A good day for company and agreements of the heart, not of the purse."
        ])
        default: ("Saturn", "endings and structures", [
            "A good day to finish, a poor day to promise.",
            "Review what stands, repair what leans, and begin nothing you cannot sustain."
        ])
        }
        return DailyExpertNote(
            specialistId: "elias-ancient",
            headline: "By the old reckoning, today is \(planet)'s day — kept for \(topics).",
            move: pick(day, moves),
            askPrompt: "What should I hold back from today?"
        )
    }

    // MARK: - Nadia (Evolutionary: pattern reflection; transit used symbolically)

    private static func nadia(day: Int, date: Date, sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) -> DailyExpertNote {
        let reading = TransitEngine.dailyReading(sun: sun, moon: moon, rising: rising, on: date)
        let headline: String
        if let reading, reading.aspect.family == "friction" {
            headline = "Today's sky adds a little friction around your \(reading.natalRole.displayName) — useful weather for noticing your default defense."
        } else {
            headline = pick(day, [
                "Notice the moment today when you explain yourself twice — that is the pattern knocking.",
                "Watch what you reach for when a plan changes today; the reflex is the map.",
                "Today, catch one 'I always' or 'I never' as you say it — absolutes mark old stories.",
                "Pay attention to which message you reread before sending; that is where the work is.",
                "Notice who you rehearse conversations with in your head today, and what you are protecting."
            ])
        }
        return DailyExpertNote(
            specialistId: "nadia-evolutionary",
            headline: headline,
            move: pick(day, [
                "One line tonight: what did I protect today, and did it need protecting?",
                "Choose one small response on purpose today instead of on reflex.",
                "Name the feeling before the reply — even just to yourself.",
                "Let one uncomfortable moment finish without fixing it."
            ]),
            askPrompt: "Help me work with today's reflection."
        )
    }

    // MARK: - Calendar helpers

    /// 1 = Sunday … 7 = Saturday (Gregorian), independent of locale first-weekday.
    private static func weekday(of date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.component(.weekday, from: date)
    }

    /// Classical seasonal element by solar-term month boundaries (approximate):
    /// Wood Feb–Apr, Fire May–Jul, Metal Aug–Oct, Water Nov–Jan.
    private static func seasonalElement(of date: Date) -> String {
        switch Calendar.current.component(.month, from: date) {
        case 2...4: "Wood"
        case 5...7: "Fire"
        case 8...10: "Metal"
        default: "Water"
        }
    }

    private static func pick(_ day: Int, _ options: [String]) -> String {
        guard !options.isEmpty else { return "" }
        return options[day % options.count]
    }
}
