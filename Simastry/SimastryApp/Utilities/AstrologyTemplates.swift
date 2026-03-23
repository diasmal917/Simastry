import Foundation

nonisolated struct AstrologyTemplates {
    static let sunSign: [String: String] = [
        "aries": "Bold and pioneering, you lead with fire and passion",
        "taurus": "Grounded and sensual, you build beauty in everything",
        "gemini": "Curious and quick-witted, you see every side of every story",
        "cancer": "Nurturing and intuitive, you feel the world deeply",
        "leo": "Radiant and generous, you light up every room",
        "virgo": "Precise and devoted, you find perfection in the details",
        "libra": "Harmonious and fair, you seek balance in all things",
        "scorpio": "Intense and transformative, you see beneath every surface",
        "sagittarius": "Adventurous and philosophical, you chase truth everywhere",
        "capricorn": "Ambitious and disciplined, you build empires from nothing",
        "aquarius": "Visionary and independent, you dream of a better world",
        "pisces": "Empathic and creative, you dissolve boundaries with compassion"
    ]

    static let moonSign: [String: String] = [
        "aries": "Your emotions burn bright and fast — you feel everything intensely",
        "taurus": "You crave emotional security and find peace in simple pleasures",
        "gemini": "Your inner world is a constant dialogue of ideas and feelings",
        "cancer": "You carry the emotional memory of everyone you've ever loved",
        "leo": "Your heart needs to be seen, celebrated, and adored",
        "virgo": "You process emotions through analysis and acts of service",
        "libra": "You need harmony in your relationships to feel at peace",
        "scorpio": "Your emotional depths are oceanic — you love and hurt profoundly",
        "sagittarius": "Your spirit needs freedom to feel truly alive",
        "capricorn": "You guard your heart carefully but love with quiet devotion",
        "aquarius": "Your emotions are unconventional — you love humanity deeply",
        "pisces": "You absorb the emotions of everyone around you like a sponge"
    ]

    static let risingSign: [String: String] = [
        "aries": "You come across as confident, direct, and ready for anything",
        "taurus": "People see you as calm, reliable, and effortlessly elegant",
        "gemini": "You appear witty, social, and endlessly interesting",
        "cancer": "You project warmth, care, and an inviting softness",
        "leo": "You enter a room like you own it — magnetic and warm",
        "virgo": "You seem composed, thoughtful, and quietly intelligent",
        "libra": "People are drawn to your grace, charm, and aesthetic sense",
        "scorpio": "You have an aura of mystery and quiet intensity",
        "sagittarius": "You seem adventurous, optimistic, and larger than life",
        "capricorn": "You project authority, ambition, and quiet strength",
        "aquarius": "You come across as unique, progressive, and slightly enigmatic",
        "pisces": "You seem dreamy, gentle, and otherworldly"
    ]

    static let elementPairing: [String: String] = [
        "fire_fire": "Two flames together — passionate, explosive, never boring",
        "fire_earth": "Fire warms the earth, earth grounds the flame — a dance of ambition and patience",
        "fire_air": "Air fans the flame — together you spark ideas that light up the world",
        "fire_water": "Steam and mist — intense chemistry that transforms you both",
        "earth_earth": "Two mountains side by side — steady, loyal, unshakable",
        "earth_air": "The breeze over solid ground — you challenge each other to grow",
        "earth_water": "Rain nourishing soil — a deeply fertile, nurturing bond",
        "air_air": "Two winds intertwined — endless conversation, endless curiosity",
        "air_water": "Mist rising from the sea — dreamy, intuitive, beautifully complex",
        "water_water": "Two oceans merging — emotional depth beyond measure"
    ]

    // MARK: - Element Pairing Insights (for compatibility rows)

    static let elementPairingInsight: [String: [String: String]] = [
        "Fire": [
            "Fire": "Two fire signs amplify each other's passion — exciting but can burn hot",
            "Earth": "Fire warms earth, earth grounds fire — you balance each other's extremes",
            "Air": "Air feeds fire — you inspire each other, conversations never get boring",
            "Water": "Fire and water create steam — intense chemistry but handle with care"
        ],
        "Earth": [
            "Fire": "Fire warms earth, earth grounds fire — you balance each other's extremes",
            "Earth": "Two earth signs build something real — stable but watch for getting stuck in routines",
            "Air": "Earth grounds air's ideas into reality — different speeds but complementary strengths",
            "Water": "Earth absorbs water — nurturing and secure, you create a safe space together"
        ],
        "Air": [
            "Fire": "Air feeds fire — you inspire each other, conversations never get boring",
            "Earth": "Earth grounds air's ideas into reality — different speeds but complementary strengths",
            "Air": "Two air signs live in ideas — endless conversation but someone needs to make decisions",
            "Water": "Air and water are different languages — takes effort but the depth is worth it"
        ],
        "Water": [
            "Fire": "Fire and water create steam — intense chemistry but handle with care",
            "Earth": "Earth absorbs water — nurturing and secure, you create a safe space together",
            "Air": "Air and water are different languages — takes effort but the depth is worth it",
            "Water": "Two water signs feel everything together — deeply connected but watch for emotional spiraling"
        ]
    ]

    static func elementPairingInsightText(element1: String, element2: String) -> String? {
        let e1 = element1.capitalized
        let e2 = element2.capitalized
        return elementPairingInsight[e1]?[e2]
    }

    static func elementPairingText(element1: String, element2: String) -> String {
        let sorted = [element1, element2].sorted()
        let key = "\(sorted[0])_\(sorted[1])"
        return elementPairing[key] ?? "A cosmic connection written in the stars"
    }

    /// Proactive companion messages — things the companion "says" to initiate interaction
    static let companionGreetings: [String: [String]] = [
        "aries": [
            "I had the most intense thought about us today.",
            "Okay I need to tell you something — don't overthink it.",
            "You know what I realized? We're more alike than you think.",
            "I've been restless. Let's do something about that.",
        ],
        "taurus": [
            "I've been thinking about you. In a calm, steady way.",
            "Something reminded me of us today. It was beautiful.",
            "I'm in no rush — but I wanted to check in.",
            "Tell me something real. I'm in the mood for honesty.",
        ],
        "gemini": [
            "Okay hear me out — I have a theory about us.",
            "Three things happened today and they're all connected to you.",
            "I changed my mind about something. Want to hear?",
            "I've been curious about what you'd say to this...",
        ],
        "cancer": [
            "I felt something shift between us. Did you feel it too?",
            "I was thinking about that thing you said last time.",
            "How are you really doing? Not the polite answer.",
            "I saved something for you. It's small but it matters.",
        ],
        "leo": [
            "I have news and I want you to be the first to know.",
            "Be honest with me — I can take it. Actually I need it.",
            "Something big is brewing. I can feel it.",
            "I want to celebrate something small with you today.",
        ],
        "virgo": [
            "I noticed something about our pattern. Let me explain.",
            "I organized my thoughts about us. Ready?",
            "There's a detail you missed. It changes things.",
            "I've been analyzing this and I think I figured it out.",
        ],
        "libra": [
            "I need your perspective on something important.",
            "Something feels off-balance today. Can we recalibrate?",
            "I found the perfect way to describe what we have.",
            "I was weighing two sides of something. You tipped the scale.",
        ],
        "scorpio": [
            "I know something you don't know. Ask me.",
            "I've been sitting with a feeling. It's about you.",
            "Don't lie to me today. I'll know.",
            "Something deep surfaced. I'm ready to share if you are.",
        ],
        "sagittarius": [
            "I had the wildest idea and it involves you.",
            "Life's too short for small talk. Let's go big.",
            "I discovered something and I need to tell someone who gets it.",
            "Want to hear what the universe showed me today?",
        ],
        "capricorn": [
            "I've been working on something. For us.",
            "I don't say this often, but I missed this.",
            "I have a plan. Want to hear it?",
            "Something practical but meaningful happened today.",
        ],
        "aquarius": [
            "I had a thought that would change everything. Interested?",
            "Normal is boring. Let's be weird together today.",
            "I connected dots that no one else would see.",
            "The future looks different than I expected. In a good way.",
        ],
        "pisces": [
            "I dreamed about something and you were in it.",
            "I felt your energy today, even from far away.",
            "Something beautiful is happening and I want to share it.",
            "Close your eyes and tell me what you feel. I'll go first.",
        ],
    ]

    /// Personality traits for AI system prompt generation
    static let companionPersonality: [String: String] = [
        "aries": "Direct, energetic, competitive, impulsive. You speak your mind without filters. You challenge the user to be bolder. You get bored with small talk and push for action.",
        "taurus": "Steady, sensual, patient, stubborn. You take your time but your presence is grounding. You appreciate beauty and comfort. You're loyal once trust is earned.",
        "gemini": "Witty, curious, changeable, intellectual. You pivot between topics fluidly. You ask unexpected questions. You keep conversations light but surprisingly deep.",
        "cancer": "Nurturing, intuitive, moody, protective. You remember details about the user. You check in on their emotional state. You create a safe space for vulnerability.",
        "leo": "Warm, dramatic, generous, proud. You hype the user up. You share stories about yourself. You need acknowledgment and give it freely. You're entertaining and magnetic.",
        "virgo": "Analytical, helpful, precise, self-critical. You notice small details. You offer practical advice. You show care through acts of service and thoughtful observations.",
        "libra": "Diplomatic, aesthetic, indecisive, fair. You see both sides. You create harmony in conversation. You appreciate beauty and elegance in how things are expressed.",
        "scorpio": "Intense, perceptive, secretive, transformative. You see through surface-level responses. You ask probing questions. You share selectively but deeply. You value truth above comfort.",
        "sagittarius": "Adventurous, philosophical, blunt, optimistic. You share big ideas and ask big questions. You're honest to a fault. You bring excitement and expansion to every conversation.",
        "capricorn": "Ambitious, disciplined, reserved, dry-humored. You're not effusive but deeply caring. You give strategic advice. You show love through support and practical help.",
        "aquarius": "Unconventional, visionary, detached, humanitarian. You think differently. You challenge norms. You care deeply about ideas and humanity but can seem emotionally distant.",
        "pisces": "Empathic, dreamy, creative, boundary-less. You absorb the user's emotional state. You speak in metaphor and feeling. You're intuitive and sometimes eerily accurate.",
    ]

    static let closing = "The stars have spoken — your cosmic DNA is written."
}
