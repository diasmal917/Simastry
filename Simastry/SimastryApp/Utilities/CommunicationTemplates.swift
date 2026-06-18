nonisolated struct CommunicationGuideData: Sendable {
    let title: String
    let tips: [String]
    let avoid: String
    let bestApproach: String
}

nonisolated struct CommunicationTemplates {
    static let guides: [ZodiacSign: CommunicationGuideData] = [
        .aries: CommunicationGuideData(
            title: "How to Talk to an Aries",
            tips: [
                "Be direct and get to the point — they respect honesty over diplomacy",
                "Match their energy — enthusiasm is contagious to them",
                "Don't tell them what to do — frame things as challenges instead",
                "Give them space to lead the conversation sometimes"
            ],
            avoid: "Avoid being passive-aggressive or beating around the bush. Aries reads that as dishonesty and loses respect fast.",
            bestApproach: "Confident, straightforward, and energetic — treat them as an equal, never talk down."
        ),
        .taurus: CommunicationGuideData(
            title: "How to Talk to a Taurus",
            tips: [
                "Be patient — they need time to process before responding",
                "Show consistency — erratic behavior makes them shut down",
                "Appeal to their senses — calm tone, comfortable setting",
                "Once you earn their trust, don't break it — they rarely give second chances"
            ],
            avoid: "Avoid rushing them into decisions or springing surprises. Taurus needs stability and hates feeling pressured.",
            bestApproach: "Steady, reliable, and warm — prove through actions, not just words."
        ),
        .gemini: CommunicationGuideData(
            title: "How to Talk to a Gemini",
            tips: [
                "Keep things intellectually stimulating — they get bored fast",
                "Be flexible — they change topics quickly and that's normal for them",
                "Use humor — wit is their love language",
                "Don't demand emotional depth too early — let it come naturally"
            ],
            avoid: "Avoid being monotone, repetitive, or overly serious all the time. Gemini needs mental variety.",
            bestApproach: "Light, curious, and adaptable — match their pace and keep surprising them."
        ),
        .cancer: CommunicationGuideData(
            title: "How to Talk to a Cancer",
            tips: [
                "Lead with empathy — validate their feelings before problem-solving",
                "Create emotional safety — they open up when they feel secure",
                "Remember the small things — they notice and it means everything",
                "Don't dismiss their mood shifts — they feel deeply and need that respected"
            ],
            avoid: "Avoid being cold, dismissive, or making fun of their emotions. Cancer will retreat into their shell and stop communicating.",
            bestApproach: "Gentle, attentive, and emotionally present — make them feel like home."
        ),
        .leo: CommunicationGuideData(
            title: "How to Talk to a Leo",
            tips: [
                "Acknowledge their efforts — genuine appreciation goes far",
                "Be warm and generous with compliments — but keep them real",
                "Give them the spotlight sometimes — they thrive when seen",
                "If you need to give feedback, sandwich it with positivity"
            ],
            avoid: "Avoid public criticism, ignoring them, or making them feel small. Leo's pride is their armor and their weakness.",
            bestApproach: "Warm, admiring, and loyal — treat them like royalty and they'll treat you like family."
        ),
        .virgo: CommunicationGuideData(
            title: "How to Talk to a Virgo",
            tips: [
                "Be specific and detailed — vague communication frustrates them",
                "Show that you've thought things through before bringing it up",
                "Appreciate their acts of service — that's how they show love",
                "Don't mistake their criticism for coldness — they're trying to help"
            ],
            avoid: "Avoid being sloppy, disorganized, or dismissing their concerns as overthinking. They've already analyzed it more than you.",
            bestApproach: "Thoughtful, precise, and grounded — show you care through competence and reliability."
        ),
        .libra: CommunicationGuideData(
            title: "How to Talk to a Libra",
            tips: [
                "Keep things balanced and fair — they're allergic to injustice",
                "Present both sides when discussing issues — they appreciate nuance",
                "Be charming but authentic — they can spot performative behavior",
                "Give them space to weigh decisions — don't force quick answers"
            ],
            avoid: "Avoid being confrontational, aggressive, or creating unnecessary drama. Libra will withdraw from chaos.",
            bestApproach: "Diplomatic, graceful, and considerate — make every interaction feel harmonious."
        ),
        .scorpio: CommunicationGuideData(
            title: "How to Talk to a Scorpio",
            tips: [
                "Be honest above all else — they detect lies instinctively",
                "Respect their privacy — don't push them to share before they're ready",
                "Go deep — surface-level small talk bores them",
                "Show loyalty — once you're in their inner circle, stay there"
            ],
            avoid: "Avoid betraying their trust, being fake, or trying to manipulate them. Scorpio never forgets and rarely forgives deception.",
            bestApproach: "Authentic, intense, and trustworthy — match their depth and they'll give you everything."
        ),
        .sagittarius: CommunicationGuideData(
            title: "How to Talk to a Sagittarius",
            tips: [
                "Keep it adventurous — they love big ideas and spontaneity",
                "Be honest, even bluntly — they respect raw truth",
                "Don't cling — give them freedom and they'll always come back",
                "Laugh with them — humor is how they process everything"
            ],
            avoid: "Avoid being possessive, overly routine-oriented, or taking their jokes too seriously. Sagittarius needs room to roam.",
            bestApproach: "Free-spirited, honest, and fun — be their adventure partner, not their anchor."
        ),
        .capricorn: CommunicationGuideData(
            title: "How to Talk to a Capricorn",
            tips: [
                "Respect their time — get to the point efficiently",
                "Show ambition — they're attracted to drive and discipline",
                "Be patient with emotional expression — they show love through actions, not words",
                "Support their goals — even if they seem unrealistically ambitious"
            ],
            avoid: "Avoid being lazy, flaky, or dismissing their work ethic. Capricorn judges reliability above all else.",
            bestApproach: "Mature, goal-oriented, and dependable — earn their respect through consistency and results."
        ),
        .aquarius: CommunicationGuideData(
            title: "How to Talk to an Aquarius",
            tips: [
                "Respect their individuality — don't try to change them",
                "Engage with their ideas — they love intellectual conversation",
                "Give them independence — smothering drives them away fast",
                "Be open-minded — they think differently and that's the point"
            ],
            avoid: "Avoid being conventional, emotionally demanding, or dismissing their unconventional views. Aquarius needs intellectual freedom.",
            bestApproach: "Progressive, independent, and curious — be their equal in thought, not their emotional anchor."
        ),
        .pisces: CommunicationGuideData(
            title: "How to Talk to a Pisces",
            tips: [
                "Lead with empathy — they absorb everyone's emotions around them",
                "Be gentle with criticism — they take everything to heart",
                "Create space for their imagination — don't always demand practicality",
                "Check in on them — they often put others first and forget themselves"
            ],
            avoid: "Avoid being harsh, dismissive of their feelings, or forcing them to toughen up. Pisces' sensitivity is their superpower, not a weakness.",
            bestApproach: "Compassionate, imaginative, and patient — meet them in their emotional world."
        )
    ]

    // MARK: - Why This Works Reasoning

    static let reasoning: [String: String] = [
        "Aries": "Aries is a fire sign — they respect people who match their energy and don't beat around the bush",
        "Taurus": "Taurus is an earth sign — they need to feel safe before they open up, and rushing them triggers their stubborn side",
        "Gemini": "Gemini is an air sign ruled by Mercury — their mind moves fast, so conversations need to keep up",
        "Cancer": "Cancer is a water sign ruled by the Moon — their moods shift like tides, and they need to feel emotionally secure before they can be real with you",
        "Leo": "Leo is a fire sign ruled by the Sun — recognition isn't vanity for them, it's how they know you actually see them",
        "Virgo": "Virgo is an earth sign ruled by Mercury — they notice everything, so vagueness feels dismissive to them",
        "Libra": "Libra is an air sign ruled by Venus — conflict physically stresses them, so approach disagreements as 'us vs the problem'",
        "Scorpio": "Scorpio is a water sign — surface-level conversation bores them, and they can sense when you're not being genuine",
        "Sagittarius": "Sagittarius is a fire sign ruled by Jupiter — they need room to explore, and feeling trapped is their dealbreaker",
        "Capricorn": "Capricorn is an earth sign ruled by Saturn — they value competence and follow-through over charm",
        "Aquarius": "Aquarius is an air sign ruled by Uranus — they think differently on purpose, and trying to 'fix' that pushes them away",
        "Pisces": "Pisces is a water sign ruled by Neptune — they absorb other people's emotions, so your mood becomes their mood"
    ]

    static let approachReasoning: [String: String] = [
        "Aries": "Fire signs process through action, not discussion — leading with confidence shows you speak their language",
        "Taurus": "Earth signs build trust slowly — consistency proves you're safe, which is their prerequisite for everything",
        "Gemini": "Mercury-ruled signs live in their heads — keeping things light and curious matches how they naturally connect",
        "Cancer": "Moon-ruled signs read emotional tone before words — warmth and presence matter more than what you actually say",
        "Leo": "Sun-ruled signs need to feel like the center of your attention — genuine warmth unlocks their incredible generosity",
        "Virgo": "Mercury gives Virgo an eye for detail — showing you've thought things through is how you earn their respect",
        "Libra": "Venus-ruled signs crave beauty in all forms — graceful communication isn't shallow to them, it's essential",
        "Scorpio": "Water signs feel before they think — authenticity is the only currency that works with them",
        "Sagittarius": "Jupiter expands everything it touches — Sagittarius needs a partner in curiosity, not a voice of caution",
        "Capricorn": "Saturn teaches through discipline — Capricorn respects people who show up consistently, not just when it's easy",
        "Aquarius": "Uranus breaks patterns — Aquarius connects through ideas first, emotions second, and that order matters to them",
        "Pisces": "Neptune dissolves boundaries — Pisces needs someone who can hold space without trying to fix everything"
    ]

    // MARK: - Share Card Copy

    /// One-liners for the shareable Simastry card. Written with the SIGN as
    /// the subject — share cards travel to people who don't know whose card
    /// it is, so "Sagittarius responds to…" reads clearly where "they" would
    /// dangle. Kept short enough to render untruncated at post size.
    nonisolated struct ShareCardCopy: Sendable {
        let approach: String
        let avoid: String
    }

    static let shareCardCopy: [ZodiacSign: ShareCardCopy] = [
        .aries: ShareCardCopy(
            approach: "Aries responds to directness and confidence — say it straight, as an equal.",
            avoid: "Aries pulls away from hints, stalling, and passive-aggression."
        ),
        .taurus: ShareCardCopy(
            approach: "Taurus warms to patience and proof — steady beats flashy every time.",
            avoid: "Taurus shuts down under pressure and sprung surprises."
        ),
        .gemini: ShareCardCopy(
            approach: "Gemini lights up at curiosity, wit, and a fresh angle.",
            avoid: "Gemini drifts when the conversation goes flat and repetitive."
        ),
        .cancer: ShareCardCopy(
            approach: "Cancer opens up to warmth, patience, and real check-ins.",
            avoid: "Cancer retreats from coldness and brushed-off feelings."
        ),
        .leo: ShareCardCopy(
            approach: "Leo glows under genuine admiration and undivided attention.",
            avoid: "Leo hardens at public criticism and being overlooked."
        ),
        .virgo: ShareCardCopy(
            approach: "Virgo trusts precision, effort, and a thought-through plan.",
            avoid: "Virgo loses patience with sloppiness and vague promises."
        ),
        .libra: ShareCardCopy(
            approach: "Libra responds to grace, fairness, and a calm tone.",
            avoid: "Libra withdraws from drama and forced confrontation."
        ),
        .scorpio: ShareCardCopy(
            approach: "Scorpio rewards honesty and depth — bring the real version.",
            avoid: "Scorpio remembers manipulation and fake charm forever."
        ),
        .sagittarius: ShareCardCopy(
            approach: "Sagittarius responds to honesty, humor, and room to breathe.",
            avoid: "Sagittarius pulls away from pressure, guilt, and a tight grip."
        ),
        .capricorn: ShareCardCopy(
            approach: "Capricorn respects consistency, results, and follow-through.",
            avoid: "Capricorn writes off flakiness and empty talk."
        ),
        .aquarius: ShareCardCopy(
            approach: "Aquarius connects through ideas, originality, and space.",
            avoid: "Aquarius disconnects when boxed into being conventional."
        ),
        .pisces: ShareCardCopy(
            approach: "Pisces opens to softness, imagination, and emotional presence.",
            avoid: "Pisces bruises under harshness and rushed fixes."
        )
    ]

    static let avoidReasoning: [String: String] = [
        "Aries": "Being passive triggers their impatience — they'd rather hear a hard truth than deal with indirectness",
        "Taurus": "Sudden changes threaten their sense of security — they need time to adjust, not ultimatums",
        "Gemini": "Repetition and rigidity feel like a cage to an air sign — their need for variety isn't flakiness, it's how they're wired",
        "Cancer": "Dismissing emotions tells a water sign you're not safe — once Cancer retreats into their shell, getting them back out takes real effort",
        "Leo": "Public criticism wounds their pride at the deepest level — fire signs need their dignity respected, even during disagreements",
        "Virgo": "Carelessness signals that you don't take them seriously — earth signs show love through effort, and they expect the same",
        "Libra": "Aggression overwhelms their nervous system — Venus-ruled signs literally feel physical discomfort from conflict",
        "Scorpio": "Deception is unforgivable to water signs — Scorpio's trust is hard-won and once broken, it rarely repairs",
        "Sagittarius": "Possessiveness feels suffocating to a fire sign — the tighter you grip, the faster they pull away",
        "Capricorn": "Flakiness reads as disrespect to Saturn-ruled signs — they measure love by reliability, not grand gestures",
        "Aquarius": "Trying to make them 'normal' attacks their core identity — Uranus-ruled signs need their uniqueness celebrated, not corrected",
        "Pisces": "Harshness cuts deeper than you think — Neptune-ruled signs don't have thick skin, and they shouldn't have to"
    ]
}
