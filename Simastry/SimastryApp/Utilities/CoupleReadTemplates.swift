import Foundation

// MARK: - Couple Read
// Long-term communication patterns for two charts: commitment styles, how
// you fight, how you repair, how money talk goes. Reflection, never fate —
// the honesty rule means no "when will we marry" framing anywhere.

nonisolated struct CoupleRead: Equatable, Sendable {
    let headline: String
    let commitmentA: String
    let commitmentB: String
    let fight: String
    let repair: String
    let moneyTalk: String
    /// One whole-sign aspect line between the two Suns, when an aspect exists.
    let signalLine: String?
    let signalName: String?
}

nonisolated enum CoupleReadComposer {
    static func read(
        nameA: String,
        sunA: ZodiacSign,
        nameB: String,
        sunB: ZodiacSign,
        seed: Int = 0
    ) -> CoupleRead {
        let pairKey = TeamReadEngine.bridgeKey(sunA.element, sunB.element)

        var signalLine: String?
        var signalName: String?
        if let aspect = WholeSignAspect.between(sunA, sunB) {
            let lines = TeamReadTemplates.aspectPairLines[aspect.family] ?? []
            if !lines.isEmpty {
                signalLine = lines[(seed + nameA.count + nameB.count) % lines.count]
                    .replacingOccurrences(of: "{a}", with: nameA)
                    .replacingOccurrences(of: "{b}", with: nameB)
                signalName = aspect.displayName
            }
        }

        return CoupleRead(
            headline: "\(nameA) + \(nameB): how you two do commitment",
            commitmentA: commitmentLine(name: nameA, sun: sunA),
            commitmentB: commitmentLine(name: nameB, sun: sunB),
            fight: CoupleReadTemplates.fight[pairKey] ?? CoupleReadTemplates.fightDefault,
            repair: CoupleReadTemplates.repair[pairKey] ?? CoupleReadTemplates.repairDefault,
            moneyTalk: CoupleReadTemplates.moneyTalk[pairKey] ?? CoupleReadTemplates.moneyTalkDefault,
            signalLine: signalLine,
            signalName: signalName
        )
    }

    static func commitmentLine(name: String, sun: ZodiacSign) -> String {
        (CoupleReadTemplates.commitmentStyle[sun] ?? "{n} commits in their own rhythm — watch the actions more than the announcements.")
            .replacingOccurrences(of: "{n}", with: name)
    }
}

nonisolated enum CoupleReadTemplates {
    /// `{n}` slot — sign-as-subject commitment styles.
    static let commitmentStyle: [ZodiacSign: String] = [
        .aries: "{n} commits like a decision, not a drift — fast in, fully in, allergic to limbo.",
        .taurus: "{n} commits in layers — slowly, physically, and then permanently. Rushing it is the only thing that breaks it.",
        .gemini: "{n} commits to the conversation first — if the talking stays alive, so does everything else.",
        .cancer: "{n} commits like a home being built — every safe moment is a brick.",
        .leo: "{n} commits in public — loyalty is real when it's visible. Quiet devotion feels like half devotion.",
        .virgo: "{n} commits through acts of maintenance — remembering, fixing, showing up on schedule. That is the love letter.",
        .libra: "{n} commits to the partnership as a thing itself — 'us' gets a seat at the table and a vote.",
        .scorpio: "{n} commits totally or not at all — the middle setting doesn't exist. Trust is the entire currency.",
        .sagittarius: "{n} commits to a direction more than a structure — the door stays open precisely so choosing to stay means something.",
        .capricorn: "{n} commits like an institution — built to last, formalized, defended. Slow to start, slower to quit.",
        .aquarius: "{n} commits to the chosen weirdness of the two of you — convention optional, loyalty non-negotiable.",
        .pisces: "{n} commits like weather — fully surrounding, occasionally foggy, deeply felt."
    ]

    // Keyed by TeamReadEngine.bridgeKey(elementA, elementB) — sorted, so
    // "air+fire" not "fire+air". Ten combinations cover every couple.

    static let fight: [String: String] = [
        "fire+fire": "Fights are loud, fast, and over by dinner — the risk isn't the heat, it's keeping score of who started.",
        "earth+earth": "Fights are quiet sieges — two people waiting out the other's position. Someone has to move first on purpose.",
        "air+air": "Fights become debates that forget the feeling that started them — win the point, lose the evening.",
        "water+water": "Fights happen underwater — moods shift days before words arrive. Name it early or live in the subtext.",
        "earth+fire": "One of you wants it settled now, the other settled right — speed versus process is the recurring fight, whatever the topic.",
        "air+fire": "Sparks plus oxygen: arguments escalate fast and brilliantly — the skill is calling halftime before the third act.",
        "fire+water": "One heats, one floods: the fight doubles whenever the feeling under it goes unnamed — say the soft part first.",
        "air+earth": "One argues the idea, one argues the track record — you're rarely in the same fight. Sync the topic before the volume.",
        "earth+water": "You both bury it to keep the peace — and the fight you don't have becomes the weather you live in.",
        "air+water": "One needs to talk it through, one needs to feel it through — give the feeling a sentence and the sentence a feeling."
    ]
    static let fightDefault = "Your fights are style mismatches more than substance — name the style difference out loud and half the heat leaves."

    static let repair: [String: String] = [
        "fire+fire": "Repair fast and physically — a walk, a joke, a reset. Don't reopen the case files.",
        "earth+earth": "Repair through routine restored — the shared coffee, the fixed plan. Normalcy is the apology.",
        "air+air": "Repair by debriefing it once — what happened, what changes next time — then genuinely closing the tab.",
        "water+water": "Repair through tenderness before analysis — held first, understood second.",
        "earth+fire": "Repair in sequence: the quick acknowledgment now, the steady follow-through after. One without the other reopens it.",
        "air+fire": "Repair with humor plus one honest line — playfulness reopens the room, the line makes it real.",
        "fire+water": "Repair needs both temperatures: the warm direct apology and the patient sitting-with. Don't skip either.",
        "air+earth": "Repair with the agreement made concrete — talked through, then written down. Both languages spoken.",
        "earth+water": "Repair slowly and gently — small consistent gestures over grand statements. Trust the accumulation.",
        "air+water": "Repair by naming the feeling out loud together — translation is the apology."
    ]
    static let repairDefault = "Repair with one honest line and one small action — said once, done visibly."

    static let moneyTalk: [String: String] = [
        "fire+fire": "Money talk: two impulse engines — agree on a fun budget each and a 24-hour rule above it.",
        "earth+earth": "Money talk: two savers with different definitions of safe — compare the actual numbers, not the vibes.",
        "air+air": "Money talk: great theories, light tracking — automate the boring part so the conversation stays interesting.",
        "water+water": "Money is feelings here — security, care, guilt. Talk about what money means before what it does.",
        "earth+fire": "One spends on momentum, one saves on principle — pre-agree the split so neither becomes the cop.",
        "air+fire": "Optimism squared: brilliant plans, loose receipts — one shared tracker saves four arguments a month.",
        "fire+water": "Spontaneity meets security: the surprise trip is romance to one and risk to the other — budget the surprises.",
        "air+earth": "The theorist and the operator — let one design the money system and the other run it, not both do both.",
        "earth+water": "You both save for safety — name what enough looks like, or you'll never feel arrived.",
        "air+water": "One needs the plan said, one needs the worry heard — do both in the same conversation."
    ]
    static let moneyTalkDefault = "Money talk goes best scheduled, short, and concrete — one number, one decision, then dinner."
}
