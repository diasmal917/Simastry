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
}
