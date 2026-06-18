import Foundation

// MARK: - Career Read
// The user's work-style read from their own chart signals — patterns for
// reflection, never a forecast. Sun = how you work, Moon = how pressure
// lands, Rising = how week one reads to colleagues.

nonisolated enum CareerTemplates {
    /// Keyed by the user's Sun — how you decide, lead, and move at work.
    static let workStyle: [ZodiacSign: String] = [
        .aries: "You decide by moving — momentum is your planning style. You're at your best owning the open problem nobody has claimed yet.",
        .taurus: "You build in straight lines: steady scope, finished things, no thrash. Your output compounds where others sprint and stall.",
        .gemini: "You work in connections — between people, ideas, and teams. Variety isn't a distraction for you; it's the fuel.",
        .cancer: "You lead by making the room safe to do hard work in. People bring you the problem before it becomes the crisis.",
        .leo: "You raise the energy and the standard at once. Work gets better when it's seen — so you make sure it's seen.",
        .virgo: "You find the flaw before it ships and the process before it's needed. Quality is your signature, not your bottleneck.",
        .libra: "You make decisions fair and rooms workable. The deal that closes without anyone feeling beaten — that's your craft.",
        .scorpio: "You go deep where others skim. Give you the gnarly, ambiguous problem and you'll surface with the real answer.",
        .sagittarius: "You see the bigger map and say the true thing about it. Strategy and candor are the same skill in your hands.",
        .capricorn: "You play the long game on purpose: structure, delivery, then the next rung. Your reputation is your compounding asset.",
        .aquarius: "You solve sideways — the angle nobody briefed. Systems bend around your better version of them.",
        .pisces: "You sense where the work is drifting before the metrics say it. Imagination plus empathy is your professional edge."
    ]

    /// Keyed by the user's Moon — how deadlines and conflict actually land.
    static let underPressure: [ZodiacSign: String] = [
        .aries: "Under deadline pressure you get faster and blunter — powerful, if you flag it as pace, not anger.",
        .taurus: "Pressure makes you slower and surer — protect that; your no-rush is what keeps the team from shipping panic.",
        .gemini: "You talk your way through pressure — thinking out loud is your release valve. Find the colleague who can hold that.",
        .cancer: "Pressure hits you in the loyalty first — you protect people before tasks. Name what you need early, not after.",
        .leo: "Pressure makes you carry the room — generous, but watch the silent cost. Let someone carry you back.",
        .virgo: "Pressure sharpens your checklist and your self-criticism in equal measure. Ship at ninety-five percent — the last five is mostly tax.",
        .libra: "Pressure makes you balance everyone's needs at once. Pick a side earlier; fairness includes you.",
        .scorpio: "You go quiet and dig in under pressure — effective, but tell the team you're digging, not disappearing.",
        .sagittarius: "Pressure makes you zoom out — useful perspective, but land one concrete next step before the big picture.",
        .capricorn: "You absorb pressure like it's the job description. It works until it doesn't — schedule the decompression.",
        .aquarius: "You detach to think under pressure — your best ideas come from that distance. Narrate it so it doesn't read as checked out.",
        .pisces: "You absorb the room's stress as your own — porous is powerful, but you need the boundary ritual at day's end."
    ]

    /// Keyed by the user's Rising — how colleagues read you in week one.
    static let firstWeekRead: [ZodiacSign: String] = [
        .aries: "Week one, you read as the fast one — direct, hungry, slightly ahead of the brief.",
        .taurus: "Week one, you read as the solid one — unhurried, dependable, already trusted with keys.",
        .gemini: "Week one, you read as the quick one — names learned, dots connected, jokes landed.",
        .cancer: "Week one, you read as the warm one — people tell you things by Friday they haven't told their manager.",
        .leo: "Week one, you read as the presence — the meeting is different when you're in it, and everyone noticed.",
        .virgo: "Week one, you read as the precise one — the question you asked in the all-hands was the right one.",
        .libra: "Week one, you read as the diplomat — somehow already easing the tension you weren't told about.",
        .scorpio: "Week one, you read as the intense one — quiet, watchful, clearly not to be underestimated.",
        .sagittarius: "Week one, you read as the candid one — refreshing in the meeting, memorable at lunch.",
        .capricorn: "Week one, you read as the serious one — early, prepared, already mapping the org chart.",
        .aquarius: "Week one, you read as the original — the suggestion nobody expected, delivered like it was obvious.",
        .pisces: "Week one, you read as the perceptive one — somehow already tuned to the team's unwritten rules."
    ]

    /// Keyed by the user's Sun — two short strength chips.
    static let strengths: [ZodiacSign: [String]] = [
        .aries: ["First mover on hard problems", "Honest under pressure"],
        .taurus: ["Reliability that compounds", "Calm in long projects"],
        .gemini: ["Cross-team translation", "Fast learning curves"],
        .cancer: ["Team trust building", "Early problem sensing"],
        .leo: ["Raising the room's standard", "Visible, generous leadership"],
        .virgo: ["Quality control instincts", "Process that scales"],
        .libra: ["Negotiation without casualties", "Fair decision framing"],
        .scorpio: ["Depth on ambiguous problems", "Unshakeable focus"],
        .sagittarius: ["Strategic candor", "Big-picture navigation"],
        .capricorn: ["Long-game execution", "Standards that lift teams"],
        .aquarius: ["Original problem angles", "Systems thinking"],
        .pisces: ["Drift detection", "Creative empathy"]
    ]

    /// Keyed by the user's Sun — the one pattern worth watching.
    static let watchOut: [ZodiacSign: String] = [
        .aries: "Starting beats finishing a little too often — pair with a closer, or become one on purpose.",
        .taurus: "Comfort with the proven can read as resistance to the new — try the pilot before the verdict.",
        .gemini: "Six open threads feel alive but read as scattered — close two, loudly.",
        .cancer: "Absorbing the team's load quietly leads to a cliff — ask before you're owed.",
        .leo: "Needing the credit can cost you the alliance — let someone else win a visible one.",
        .virgo: "The perfect version ships late — define good-enough before you start, not during.",
        .libra: "Keeping everyone okay can delay the call only you can make — decide, then soothe.",
        .scorpio: "Holding information feels safe but reads as distance — share one card early.",
        .sagittarius: "The blunt true thing lands better with one beat of timing — same honesty, better hour.",
        .capricorn: "The grind is a strategy until it's an identity — take the visible rest.",
        .aquarius: "The brilliant detached take needs one warm sentence attached — translation is part of the idea.",
        .pisces: "Vague yeses cost you twice — make the maybe explicit."
    ]
}
