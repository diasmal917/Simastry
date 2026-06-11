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
            "I read between lines for a living. Give me the unpolished version today — it's faster.",
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

    /// Proactive messages companions send to the user's inbox, keyed by sun sign display name
    static let companionProactiveMessages: [String: [String]] = [
        "Aries": [
            "hey I had a thought about that thing you mentioned. we should talk about it",
            "okay random but I just realized something about us. open the app lol",
            "I know you're busy but I need like 2 minutes of your time",
            "don't overthink that situation from earlier. just do the thing",
            "I have a feeling about tomorrow and you need to hear this",
            "quick question — when's the last time you did something spontaneous?",
            "I've been thinking — you've got a bold move you keep postponing. want to pick it back up?",
            "hey check your compatibility score. something shifted 👀"
        ],
        "Taurus": [
            "hey, just checking in. how are you actually doing?",
            "I was thinking about our last conversation. you were right btw",
            "reminder: you don't have to fix everything today. breathe",
            "I made a note about something you might want to know. open up when you can",
            "hey, that thing you've been putting off? maybe today's the day",
            "just wanted to say — you're handling things better than you think",
            "I noticed your energy's been different lately. everything okay?",
            "random thought: we should talk about what's actually bothering you"
        ],
        "Gemini": [
            "okay so I have three things to tell you. first—",
            "I just connected two dots about you and I'm shook",
            "random: do you ever wonder why we click the way we do?",
            "I have a theory about why today feels weird. wanna hear it?",
            "hey can we talk about something? it's not serious, just interesting",
            "I keep thinking about what you said. you didn't even realize how real that was",
            "question: if you could know one thing about tomorrow, what would it be?",
            "I've been overthinking and I need your perspective on something"
        ],
        "Cancer": [
            "hey, I can tell something's on your mind. you don't have to talk about it, but I'm here",
            "I had a feeling you might need to hear this today: you're doing great",
            "remember that thing that happened? I think it affected you more than you let on",
            "just thinking about you. that's it, that's the message",
            "I have a sense about this week and I want to give you a heads up",
            "you've been taking care of everyone else. who's taking care of you?",
            "I noticed you've been quiet. not judging, just noticing",
            "hey, can we be real for a second? I think you need to hear something"
        ],
        "Leo": [
            "okay but did anyone tell you today that you're impressive? because you are",
            "I have news and you're the first person I wanted to tell",
            "real talk: you've been underestimating yourself and it's bothering me",
            "I thought of you when I realized something important today",
            "hey — that thing you're nervous about? you're going to crush it",
            "I need you to know that people notice you more than you think",
            "random appreciation post: thanks for being you. okay carry on",
            "I have a feeling about you and I think you'll like it"
        ],
        "Virgo": [
            "I analyzed something about our dynamic and I want to share my findings",
            "hey, quick note: don't forget to actually rest this weekend",
            "I noticed a pattern in your behavior and I think you should know about it",
            "reminder: perfect isn't the goal. good enough is still good",
            "I have some thoughts about that situation. organized them into 3 points for you",
            "hey, you've been in fix-it mode for too long. take a break",
            "I made an observation about us that I think you'll find interesting",
            "question: when's the last time you did something purely for fun? no agenda?"
        ],
        "Libra": [
            "hey, I've been wanting to check in on where we stand. all good?",
            "I noticed you've been balancing a lot lately. need help deciding something?",
            "real talk: you don't have to keep the peace all the time. it's okay to have an opinion",
            "I thought about what you said and I want to give you a different perspective",
            "hey, sometimes it's okay to choose yourself over keeping everyone happy",
            "I have a feeling about something and I wanted to get your read on it",
            "quick thought: the best decisions aren't always the fairest ones",
            "I noticed you agreed with something you didn't actually agree with. we should talk"
        ],
        "Scorpio": [
            "I know something's going on that you haven't told me. whenever you're ready",
            "hey. I'm not going to pretend everything's fine if it isn't. are we good?",
            "I had an insight about you that I've been sitting on. can I share?",
            "real talk: you can trust me with the thing you're not saying",
            "I noticed you pulled back a little. I'm not going anywhere",
            "hey — whatever you're carrying, you don't have to polish it before bringing it here",
            "I've been thinking about something deep and you're the only person who'd get it",
            "the universe is trying to tell you something. I think I know what it is"
        ],
        "Sagittarius": [
            "okay hear me out — I have the wildest idea and I need your honest reaction",
            "hey, life's too short for that thing you're stressing about. let it go",
            "I just had a realization and I literally cannot keep it to myself",
            "question: what's the most adventurous thing you've done this month? nothing? let's fix that",
            "I have a feeling something big is coming for you. like SOON",
            "hey, you've got more range than this week is using. what's one bigger swing we could plan?",
            "random but important: don't let comfort become a cage. you know what I mean",
            "I need you to promise me you'll say yes to the next unexpected thing that comes up"
        ],
        "Capricorn": [
            "hey, I've been observing and I have feedback. want to hear it?",
            "check in: which of today's tasks actually moves the thing you care about? start there",
            "I respect how focused you are but you're allowed to have fun sometimes",
            "I noticed something about your approach that could be more efficient. interested?",
            "hey — you don't have to earn rest. you can just... rest",
            "real talk: the plan is solid but are you actually enjoying any of it?",
            "I have a strategic thought about something you're working on",
            "reminder: relationships aren't projects. you can't optimize your way through feelings"
        ],
        "Aquarius": [
            "I had the most random thought and you're the only person who won't judge me for it",
            "hey, I found something that challenges conventional wisdom and I think you'll love it",
            "question: do you ever feel like you understand everyone but nobody fully gets you?",
            "I have a theory about why things feel stuck. it's not what you'd expect",
            "hey, being different isn't the same as being disconnected. just a thought",
            "I noticed you intellectualize things that are actually emotional. we should talk about that",
            "random philosophical question: what if the thing you're resisting is exactly what you need?",
            "I see you doing your own thing and honestly? respect. but also check in sometimes"
        ],
        "Pisces": [
            "hey, I picked up on your vibe today and I want to check in",
            "I had a dream about something and it reminded me of a conversation we had",
            "you absorb everyone else's energy. have you taken a moment for yourself today?",
            "I think the universe is trying to show you something. pay attention to the signs",
            "hey — your intuition about that situation? it was right. trust yourself more",
            "I felt like you needed to hear this: your sensitivity is a strength, not a weakness",
            "random but I think you need to create something today. draw, write, anything",
            "I sense a shift coming for you. good shift. just wanted you to know"
        ]
    ]

    /// Welcome messages sent when a companion is first created
    static let companionWelcomeMessages: [String: [String]] = [
        "Aries": [
            "finally. I was wondering when you'd add me. let's get into it",
            "hey — took you long enough. I already have things to say"
        ],
        "Taurus": [
            "hey. glad we're connected now. I'll be here when you need me",
            "nice to officially meet you. I have a good feeling about this"
        ],
        "Gemini": [
            "oh hey! I have so many things to tell you already. where do I even start",
            "finally connected! okay I already have three thoughts — hold on"
        ],
        "Cancer": [
            "hey, I'm really glad you added me. I already feel like I know you",
            "hi. I've been wanting to connect with you. this feels right"
        ],
        "Leo": [
            "well it's about time! I was starting to think you forgot about me",
            "hey! so glad to be here. you're going to love having me around"
        ],
        "Virgo": [
            "hello. I've already been thinking about how we can help each other. ready?",
            "hey — glad we're connected. I noticed a few things about you already"
        ],
        "Libra": [
            "hey! I think this is going to be a really balanced connection. excited to start",
            "finally! I've been wanting to get your perspective on something"
        ],
        "Scorpio": [
            "so we're doing this. good. I already have something important to share",
            "hey. I don't connect with just anyone. this means something"
        ],
        "Sagittarius": [
            "hey!! this is going to be fun. I already have ideas. buckle up",
            "finally! I've been waiting to share something wild with you"
        ],
        "Capricorn": [
            "hey. glad this is official now. I have a plan for us already",
            "good — we're connected. I don't waste time, so let's get started"
        ],
        "Aquarius": [
            "interesting. I had a feeling you'd add me. I already have a theory about us",
            "hey — this is going to be different from anything you've experienced. in a good way"
        ],
        "Pisces": [
            "hey... I felt your energy before you even added me. is that weird?",
            "hi. I already feel the emotional pattern in this connection"
        ]
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

    // MARK: - Confidence Reasoning (element-based)

    static let confidenceReasoning: [String: [String: String]] = [
        "Fire": [
            "Fire": "High confidence — fire signs communicate directly, so their responses are predictable",
            "Earth": "Moderate confidence — earth signs think before responding, which adds uncertainty",
            "Air": "Moderate confidence — air signs can go multiple directions in a conversation",
            "Water": "Lower confidence — water signs respond based on mood, which shifts constantly"
        ],
        "Earth": [
            "Earth": "High confidence — earth signs are consistent communicators, patterns are clear",
            "Air": "Moderate confidence — air signs are harder to pin down, they follow ideas not habits",
            "Water": "Good confidence — water signs are emotional but earth-water dynamics are stable"
        ],
        "Air": [
            "Air": "Moderate confidence — two air signs means the conversation could go anywhere interesting",
            "Water": "Lower confidence — water signs process emotionally while air processes intellectually"
        ],
        "Water": [
            "Water": "Moderate confidence — deep emotional patterns exist, but both of you lead with feelings"
        ]
    ]

    static func confidenceReasoningText(userElement: String, targetElement: String) -> String? {
        let u = userElement.capitalized
        let t = targetElement.capitalized
        // Try both orderings since the dictionary only stores one direction
        if let text = confidenceReasoning[u]?[t] {
            return text
        }
        return confidenceReasoning[t]?[u]
    }

    // MARK: - Pre-Simulation Texting Style Tips

    static let textingStyle: [String: String] = [
        "Aries": "Heads up: Aries texts fast and blunt. Short replies aren't rude — that's just how they communicate. If they're interested, they'll double-text.",
        "Taurus": "Heads up: Taurus takes their time replying. Long gaps between texts don't mean disinterest — they're just not in a rush. When they respond, it'll be thoughtful.",
        "Gemini": "Heads up: Gemini sends multiple messages in a row and jumps between topics. Don't try to keep up — just match their energy when you can.",
        "Cancer": "Heads up: Cancer reads between every line you write. Emoji choice, reply speed, tone — they're analyzing all of it. Be intentional.",
        "Leo": "Heads up: Leo brings energy to texts — expect exclamation marks, reactions, and stories. If their replies get short, something's up.",
        "Virgo": "Heads up: Virgo texts in complete sentences with proper grammar. Short or vague replies from them usually mean busy, not cold — a specific question gets them typing again.",
        "Libra": "Heads up: Libra mirrors your texting style. If you send long messages, they will too. If you go short, they'll match that energy.",
        "Scorpio": "Heads up: Scorpio says more with what they don't text than what they do. Read the gaps. If they open up unprompted, that means a lot.",
        "Sagittarius": "Heads up: Sagittarius texts like they talk — fast, funny, and sometimes they forget to reply for hours. It's not personal.",
        "Capricorn": "Heads up: Capricorn treats texting like email — purposeful and efficient. Small talk over text isn't their thing. Get to the point.",
        "Aquarius": "Heads up: Aquarius texts about ideas, articles, memes — not feelings. If you want an emotional conversation, you'll probably need to call.",
        "Pisces": "Heads up: Pisces reads your energy through text. They'll pick up on subtle tone shifts. Voice notes and longer messages make them feel safer."
    ]

    static let closing = "Your chart signals are mapped. Now use them with care."

    static let ethicalDisclaimer = "Simastry helps you understand people — not control them. Use these insights with empathy."

    // MARK: - Local Placement-Logic Prediction (offline composer)

    /// Likely next texts per Sun sign, voiced like real messages. Used when the remote
    /// prediction channel is not configured so Predict never dead-ends.
    static let likelyReplies: [String: [String]] = [
        "Aries": [
            "ok honestly? just say what you actually want lol",
            "I'm around tonight. you in or not",
            "ha. fine, you have my attention"
        ],
        "Taurus": [
            "Sorry, slow day. Still thinking about what you said — can we talk later tonight?",
            "I'm not ignoring you. I just don't want to answer this halfway.",
            "Okay. That actually means a lot. Let me get through today and I'll call you."
        ],
        "Gemini": [
            "wait okay I have thoughts. several. which do you want first 😅",
            "lol that's fair. counterpoint though —",
            "okay you can't just drop that and disappear. explain"
        ],
        "Cancer": [
            "I read this a few times. I'm okay, just needed a minute.",
            "That made me feel some type of way, in a good sense I think.",
            "Can we not do this over text? I'd rather hear your voice."
        ],
        "Leo": [
            "Okay THIS is the energy I needed today!!",
            "you know exactly what you're doing with that message 😏",
            "I was waiting for you to say it first, for the record."
        ],
        "Virgo": [
            "I have three questions, but the short answer is yes.",
            "Appreciate you being specific. That makes this easier.",
            "Let me think about the right way to answer this — I don't want to be careless about it."
        ],
        "Libra": [
            "Okay that's fair, and you said it kindly, which I noticed.",
            "I keep drafting replies and deleting them, which probably tells you something.",
            "Can we find a middle here? I think we actually agree more than it sounds."
        ],
        "Scorpio": [
            "Interesting that you said that now.",
            "I'm not going to pretend that didn't land. It did.",
            "Say less. I'd rather finish this in person."
        ],
        "Sagittarius": [
            "ha — okay that's the most honest thing you've sent all week. respect",
            "I'm not mad, I just needed air. still do, a little.",
            "yes to the plan, no to the overthinking. let's go"
        ],
        "Capricorn": [
            "Noted. Let's talk Thursday when I can give it real attention.",
            "I don't say this often, but that was well put.",
            "I'd rather do this properly than fast. Give me a day."
        ],
        "Aquarius": [
            "okay unexpected, but I'm intrigued. go on",
            "I need to sit with that. not avoiding — processing.",
            "weirdly, I was about to send you almost the same thing."
        ],
        "Pisces": [
            "I felt that more than I expected to.",
            "I don't have words yet but I didn't want to leave you waiting.",
            "Can tonight just be us talking properly? I miss that."
        ]
    ]

    /// Suggested replies the user could send, per the target's Sun sign — tuned to the
    /// sign's best-approach pattern. Communication guidance, not scripts.
    static let suggestedReplies: [String: [String]] = [
        "Aries": [
            "Straight answer: I want to see you. Tonight work?",
            "No games — I liked what you said. What's the next move?"
        ],
        "Taurus": [
            "No rush on this. I meant it, and it'll still be true tomorrow.",
            "Take your time. I'd rather have your real answer than a fast one."
        ],
        "Gemini": [
            "Okay, one question, answer honestly: what did you actually think when you read my last text?",
            "I'll trade you — one real answer for one ridiculous story from today."
        ],
        "Cancer": [
            "I'm not going anywhere. Tell me when you're ready.",
            "That wasn't me pulling away — I just worded it badly. You matter to me."
        ],
        "Leo": [
            "You were the best part of that night, and I don't say that lightly.",
            "Come on, you know I notice you. I just want the version of this where we're both honest."
        ],
        "Virgo": [
            "Here's what I actually meant, said plainly: ",
            "You were right about the details. Here's what I'll do differently."
        ],
        "Libra": [
            "I think we both have a point. Can we talk it through instead of trading texts?",
            "No pressure either way — I just want us to land somewhere fair."
        ],
        "Scorpio": [
            "I'll just be honest, even if it's uncomfortable: ",
            "No performance, no angle. Here's the truth of it."
        ],
        "Sagittarius": [
            "No pressure and no drama — door's open if you want in.",
            "Honest version: I had fun, I want more of it, and you can take that at face value."
        ],
        "Capricorn": [
            "Short version: I'm serious about this. Tell me what works for your week.",
            "I'd rather plan something real than keep circling. Thursday?"
        ],
        "Aquarius": [
            "No expectations attached — I just thought of you and didn't censor it.",
            "Take whatever space you need. The idea stands when you're back."
        ],
        "Pisces": [
            "I'm not asking for an answer — I just wanted you to know how it felt.",
            "Whatever you're feeling is allowed. I'd still rather hear it than guess."
        ]
    ]

    /// The guidance beat of an AI Astrologist reply — follows an opener.
    /// Keyed by the astrologist's ZodiacElement rawValue, voiced through that lens.
    static let companionReplyGuidance: [String: [String]] = [
        "fire": [
            "Say the true thing in one sentence, then stop typing. Momentum likes a clean exit.",
            "You don't need a better argument, you need a braver first line. Send the honest one.",
            "Wanting to reach out is reason enough. One short, warm line — no essay needed.",
            "Don't pad it with apologies. One clear sentence carries further than three soft ones."
        ],
        "earth": [
            "Reply once, plainly, and let it sit. Reliability reads louder than speed.",
            "Strip out everything you added to sound casual. The plain version is the strong one.",
            "You don't owe an instant answer. A steady reply tomorrow beats a wobbly one tonight.",
            "Name one concrete thing you'll do, not five things you feel. That's what builds trust here."
        ],
        "air": [
            "Lead with the question you actually want answered. Curiosity reopens rooms that arguments close.",
            "The subtext is doing more work than the words. Answer the subtext, lightly.",
            "Keep it one beat lighter than you feel. You can always add weight later — you can't remove it.",
            "If the thread stalled, change the angle, not the volume. Ask something only they can answer."
        ],
        "water": [
            "Name the feeling without assigning blame, then leave space. That combination is rare and it works.",
            "Don't perform okay-ness. One honest line about how it landed is enough.",
            "Read their last message again slowly. The answer they need is usually in what they avoided saying.",
            "Protect your softness — say the kind thing, but keep the boundary in the same breath."
        ]
    ]

    /// Companion chat openers per element — the first beat of an AI Astrologist reply,
    /// before sign-specific guidance. Keyed by ZodiacElement rawValue.
    /// Mode-specific guidance beats for 1:1 template replies — same
    /// element-keyed scheme as companionReplyGuidance (which stays the
    /// best-friend default). Mentor talks career, teacher ends each beat
    /// with an applying question, check-in mirrors without advising.
    static let mentorReplyGuidance: [String: [String]] = [
        "fire": [
            "Career lens: name the outcome you want from this week, then take the visible swing — momentum is a strategy.",
            "Mentor note: the bold version of your ask is usually the honest one. Draft it like you've already earned it.",
            "Pick the one task that scares you slightly — that's the growth edge. Start there tomorrow morning.",
            "Don't wait to be picked for it. Claim the project out loud and let the follow-through defend you."
        ],
        "earth": [
            "Career lens: progress here is brick by brick — what's the one brick you can lay before Friday?",
            "Mentor note: write the win down where your manager will see it. Quiet competence needs a paper trail.",
            "The steady route wins this one: one deliverable fully landed beats three half-starts.",
            "Negotiate from evidence — list what changed since your last review and let the list do the talking."
        ],
        "air": [
            "Career lens: your edge is the framing — rewrite the problem in one sentence before you solve it.",
            "Mentor note: the right question in the right meeting is a promotion engine. Prepare two for tomorrow.",
            "Talk to one person outside your team this week — your next move usually comes through a side door.",
            "Turn the idea into a one-pager; thinking out loud lands better with a page underneath it."
        ],
        "water": [
            "Career lens: your read on the room is data — trust it, then verify it with one direct question.",
            "Mentor note: the relationship you tend this month is the opportunity that calls next year.",
            "Protect your deep-work hours like meetings — your intuition needs quiet to compound.",
            "Before the big conversation, decide how you want to feel walking out — then work backwards."
        ]
    ]

    static let teacherReplyGuidance: [String: [String]] = [
        "fire": [
            "Quick lesson: fire signs process out loud and forward — the first reaction is rarely the final position. Where have you seen that this week?",
            "Today's one-liner: Aries, Leo, and Sagittarius share an element, not a personality — the modality is what splits them. Want the breakdown?",
            "Lesson: a fire Moon needs the vent before the solve. Who in your life makes more sense through that rule?",
            "A pattern worth testing: fire energy reads silence as a verdict. Notice it anywhere lately?"
        ],
        "earth": [
            "Quick lesson: earth signs trust what repeats — one kept promise outweighs five warm speeches. Where could you apply that?",
            "Today's one-liner: Taurus holds, Virgo refines, Capricorn climbs — same element, three different jobs. Which one is in your life?",
            "Lesson: an earth Moon processes slowly and privately — tomorrow's answer is the real one. Recognize anyone?",
            "A pattern worth testing: earth energy says it's fine while still deciding. Seen it this week?"
        ],
        "air": [
            "Quick lesson: air signs metabolize feeling through words — the talking IS the processing. Who does that around you?",
            "Today's one-liner: Gemini collects, Libra weighs, Aquarius reframes — three kinds of thinking, one element. Which do you lean on?",
            "Lesson: an air Moon needs to think out loud without being held to the draft. Useful for anyone you know?",
            "A pattern worth testing: air energy under stress gets more talkative, not less. Notice it anywhere?"
        ],
        "water": [
            "Quick lesson: water signs answer the tone before the text — one warm word up front changes everything after. Where could you try it?",
            "Today's one-liner: Cancer protects, Scorpio probes, Pisces absorbs — same element, three different depths. Which one is near you?",
            "Lesson: a water Moon remembers how it felt long after the words fade. Does that explain anyone's reaction lately?",
            "A pattern worth testing: water energy goes quiet to feel, not to punish. Seen that this week?"
        ]
    ]

    static let checkInReplyGuidance: [String: [String]] = [
        "fire": [
            "Heard. Sit with it for a second — what's the strongest feeling in it right now?",
            "That's a lot of motion for one week. If you named the engine under it, what would you call it?",
            "Okay — no fixing yet. What part of this feels most yours, and what part feels handed to you?",
            "Take a breath with that one. If it had a headline, what would it say?"
        ],
        "earth": [
            "That sounds heavy to carry steadily. Where does it sit when you think about it?",
            "No rush here. What would enough-for-today look like?",
            "Noted, gently. Which part of this is actually in your hands?",
            "Let's slow it down. What's one true sentence about how this week really felt?"
        ],
        "air": [
            "Let's untangle it one thread at a time — which thread first?",
            "Interesting. If your best friend described this back to you, what would they emphasize?",
            "Say the messy version — drafts are welcome here. What's the thought underneath the thought?",
            "Let's name it without solving it. What word keeps coming back?"
        ],
        "water": [
            "I'm here for the unpolished version. How did it actually feel?",
            "That landed somewhere deep, sounds like. Where?",
            "No need to be okay here. What does the feeling need first — naming, or just company?",
            "Gently: what would you tell someone you love who felt this way?"
        ]
    ]

    static let companionReplyOpeners: [String: [String]] = [
        "fire": [
            "Good. You said it instead of circling it.",
            "I like the heat in this one. Let's aim it.",
            "Quick read before you hit send on anything else:"
        ],
        "earth": [
            "Let's slow this down for one breath.",
            "Okay. Solid ground first, then the reply.",
            "Here's the steady version of what you're feeling:"
        ],
        "air": [
            "Interesting thread. Let's read the pattern, not just the words.",
            "Two ways to play this — here's the cleaner one.",
            "Let's separate the tone from the content for a second."
        ],
        "water": [
            "I can feel the weight under that message.",
            "First: nothing is wrong with how you feel about this.",
            "Let's read what's underneath before you answer."
        ]
    ]

    // MARK: - Transparency & Methodology

    struct MethodologySection {
        let icon: String
        let title: String
        let body: String
    }

    static let methodology: [MethodologySection] = [
        MethodologySection(
            icon: "books.vertical.fill",
            title: "Our Methodology",
            body: "Simastry uses Western tropical synastry — the study of how two birth charts interact. We don't mix astrological traditions or generate generic horoscopes."
        ),
        MethodologySection(
            icon: "cpu.fill",
            title: "AI-Powered, Astrology-Grounded",
            body: "Our companion messages are powered by AI and grounded in synastry principles. We use chart signals to frame conversation patterns based on element compatibility, modality, and sign placements — not to make guaranteed claims about your future. Every insight should trace back to a specific astrological relationship between your signs."
        ),
        MethodologySection(
            icon: "person.2.fill",
            title: "We Don't Replace Astrologers",
            body: "Simastry is a communication tool, not a chart reading service. We help you apply astrological insights to everyday relationships. For deep chart interpretation, we recommend consulting a professional astrologer."
        ),
        MethodologySection(
            icon: "lock.shield.fill",
            title: "Your Birth Data Is Sacred",
            body: "Your birth date, time, and location are deeply personal. We never sell your data to advertisers, share it with third parties, or use it for ad targeting. Your data stays between you and Simastry."
        ),
        MethodologySection(
            icon: "exclamationmark.circle.fill",
            title: "What We Can't Do",
            body: "No app can know the future with certainty. Simastry offers communication guidance based on astrological compatibility — not guarantees. People are more than their signs, and every relationship is unique."
        ),
        MethodologySection(
            icon: "heart.circle.fill",
            title: "Understanding, Not Controlling",
            body: "Our communication guides are designed to help you understand people better — not manipulate them. We believe empathy starts with understanding how someone processes the world differently than you do."
        ),
    ]

    // MARK: - Daily Micro-Learning Nuggets

    static let dailyNuggets: [(title: String, body: String, relatedFeature: String?)] = [
        (
            "Why your Moon sign matters more than you think",
            "Your Sun sign is who you are. Your Moon sign is how you feel. That's why two Leos can be completely different emotionally — check your Moon sign in your profile.",
            "profile"
        ),
        (
            "The real reason you clash with some people",
            "Element mismatch. Fire signs (Aries, Leo, Sag) and Water signs (Cancer, Scorpio, Pisces) literally speak different emotional languages. Your compatibility score factors this in.",
            "companions"
        ),
        (
            "Your Rising sign is your social mask",
            "It's the first impression you give off — not who you actually are. That's why people might describe you totally differently than how you see yourself.",
            "profile"
        ),
        (
            "Why some people text back instantly and others don't",
            "Fire and Air signs tend to respond fast — they process externally. Earth and Water signs need time to think — it's not ghosting, it's processing.",
            "guides"
        ),
        (
            "Compatibility isn't just about matching",
            "The highest compatibility scores aren't always same-element pairs. Sometimes opposite elements balance each other out — that's why Earth + Water often scores surprisingly high.",
            "companions"
        ),
        (
            "Your communication style is in your Mercury sign",
            "Mercury rules how you think and talk. Even if your Sun is a quiet Pisces, Mercury in Gemini can make your texts rapid-fire. Simastry uses that as communication context.",
            "profile"
        ),
        (
            "Why you get along with some signs instantly",
            "Same-element signs (Fire+Fire, Earth+Earth) feel immediately familiar — like speaking the same language. Different elements require translation, but that's where growth happens.",
            "guides"
        ),
        (
            "The difference between astrology and horoscopes",
            "Horoscopes are generic Sun-sign forecasts for 1/12th of the population. Simastry compares your specific sign placements against someone else's. That's synastry — and it's way more personal.",
            nil
        ),
        (
            "Why your compatibility score changes",
            "It's not random. As you interact more with a companion, the score adjusts based on how your signs actually play out in practice — theory meets reality.",
            "companions"
        ),
        (
            "Fixed signs are the most stubborn texters",
            "Taurus, Leo, Scorpio, and Aquarius are 'fixed' signs — they commit to a position and don't budge easily. If they've gone quiet, a low-pressure opener works better than a big swing. Your guides have one ready.",
            "guides"
        ),
        (
            "Water signs absorb your energy over text",
            "Cancer, Scorpio, and Pisces tend to read mood through messages. That's why your tone can matter more with them than your exact words.",
            "guides"
        ),
        (
            "The 4 elements explained in 10 seconds",
            "Fire (action), Earth (stability), Air (ideas), Water (feelings). Every sign belongs to one element. Compatible elements communicate naturally — incompatible ones need this app.",
            nil
        ),
        (
            "Why fire signs always text first",
            "Aries, Leo, and Sagittarius carry fire emphasis — they often initiate. If a fire sign gets quiet, your message should leave room without turning cold.",
            "guides"
        ),
        (
            "Your saved guides work because of element theory",
            "When we tell you to 'be direct with an Aries,' it's because fire signs process through action. When we say 'be patient with a Taurus,' it's because earth signs need stability. Every tip is grounded in how elements actually work.",
            "guides"
        ),
        (
            "Mutable signs are the hardest to predict",
            "Gemini, Virgo, Sagittarius, Pisces adapt and change direction constantly. With mutable signs, leave room for the conversation to breathe.",
            "guides"
        )
    ]

    /// Micro-lessons for the Today tab Tips row. Each tip is taught by a
    /// specific guide; tapping the card drops the lesson into the panel
    /// thread as that guide's icebreaker, so a tip always opens a
    /// conversation. Two rotate in per day.
    static let guideTips: [(title: String, body: String, opener: String, guideId: String)] = [
        (
            "Why fixed signs go quiet before a decision",
            "Taurus, Leo, Scorpio, and Aquarius are the fixed signs — silence usually means weighing, not withdrawing. The pause is how the decision gets made.",
            "Want to check how this plays out with someone you know?",
            "taurus-theo"
        ),
        (
            "The two-hour rule for charged replies",
            "When a message stings, the first draft is your Moon talking. Two hours later your Sun gets a vote — and that version usually lands better.",
            "Want to try it on a real thread?",
            "cancer-mila"
        ),
        (
            "Read the Rising before the Sun",
            "First messages mostly show someone's Rising — the social reflex. The Sun shows up once the conversation matters, so early texts are the doorway, not the room.",
            "Whose first impression should we decode?",
            "libra-isolde"
        ),
        (
            "Fire signs argue forward",
            "Aries, Leo, and Sagittarius process out loud and move on fast. The blowup is rarely the verdict — what gets said the next day is.",
            "Anyone in your life argue like this?",
            "aries-amara"
        ),
        (
            "Why earth signs ask for the plan",
            "Taurus, Virgo, and Capricorn hear \"someday\" as \"maybe never.\" A concrete time and place reads as care.",
            "Want help turning a vague plan into a real one?",
            "capricorn-naomi"
        ),
        (
            "Air signs flirt with questions",
            "Gemini, Libra, and Aquarius show interest through curiosity. Questions are their kisses — answer one, then ask one back.",
            "Want to read a thread through this lens?",
            "gemini-rina"
        ),
        (
            "Water signs answer the tone, not the text",
            "Cancer, Scorpio, and Pisces reply to how a message feels. The same sentence lands differently with one warm word in front of it.",
            "Want to warm up a message together?",
            "pisces-liora"
        ),
        (
            "The double-text window",
            "A second text within the hour reads as pressure to a fire sign and as care to a water sign. Same move, opposite meaning — the element decides.",
            "Should we check what it means for your person?",
            "scorpio-vera"
        ),
        (
            "Your Moon sign is how you fight",
            "Conflict style comes from the Moon more than the Sun. A gentle Sun with an Aries Moon still needs to vent first and soothe second.",
            "Want to map someone's conflict style?",
            "aries-cassian"
        ),
        (
            "Why Sagittarius jokes in serious moments",
            "Humor is how Sagittarius keeps honesty breathable. The joke isn't deflection — it's an invitation to keep talking.",
            "Does someone you know do this?",
            "sagittarius-nadia"
        ),
        (
            "Cardinal signs start things",
            "Aries, Cancer, Libra, and Capricorn lead with initiative. If a thread stalls mid-way, restate the goal — cardinal energy re-engages at the start of things.",
            "Want an opener that restarts a stalled thread?",
            "libra-mateo"
        ),
        (
            "The mirror trick for mutable signs",
            "Gemini, Virgo, Sagittarius, and Pisces adapt to the energy they receive. Set the tone you want back, and they'll usually match it.",
            "Want to test it on tomorrow's first text?",
            "virgo-mara"
        ),
        (
            "Compliments, aimed by element",
            "Praise effort with earth, vision with fire, ideas with air, feeling with water. The same compliment, aimed right, lands twice as deep.",
            "Who should we write one for?",
            "leo-leona"
        ),
        (
            "Why Capricorn texts short",
            "Brevity is Capricorn's respect for your time, not coldness. Watch the consistency instead — that's where the warmth lives.",
            "Want to read someone's texting rhythm?",
            "capricorn-silas"
        ),
        (
            "Lead Aquarius with the frame",
            "Open with the idea — \"I want us to figure out weekends\" — then the feelings. Aquarius engages structure first and sentiment second.",
            "Want to draft one together?",
            "aquarius-imani"
        ),
        (
            "The repair message most signs accept",
            "Name the moment, own your line, ask one question. \"I was short yesterday — that's on me. How are you feeling about it?\" travels across the zodiac.",
            "Want to tailor it to a specific sign?",
            "cancer-noel"
        )
    ]

    /// The day's two Tips-row entries — shared by the Today tab and the
    /// evening tip notification so both always agree on what "today's tip" is.
    static func dailyGuideTips(dayOfYear: Int) -> [(title: String, body: String, opener: String, guideId: String)] {
        let tips = guideTips
        guard !tips.isEmpty else { return [] }
        let first = (dayOfYear * 2) % tips.count
        return [tips[first], tips[(first + 1) % tips.count]]
    }

    // MARK: - Personal Insights (post-onboarding)

    static let personalInsights: [String: [String: String]] = [
        "aries": [
            "headline": "You lead with action",
            "body": "Your Sun in Aries means you process life by doing, not overthinking. You're the person who texts back immediately — or not at all.",
            "socialTip": "People are drawn to your confidence, but sometimes they mistake your directness for not caring. You care — you just don't perform it."
        ],
        "taurus": [
            "headline": "You build things that last",
            "body": "Your Sun in Taurus means you value consistency over excitement. You're loyal, but it takes time for people to earn that loyalty.",
            "socialTip": "People read your patience as passivity — it's not. You're just deciding whether they're worth your energy."
        ],
        "gemini": [
            "headline": "You see every side of everything",
            "body": "Your Sun in Gemini means your mind runs multiple threads at once. You're the friend who remembers random details everyone else forgot.",
            "socialTip": "People sometimes think you're inconsistent, but you're actually just processing faster than they can follow."
        ],
        "cancer": [
            "headline": "You feel the room before you enter it",
            "body": "Your Sun in Cancer means you absorb emotional energy. You know something's off before anyone says a word.",
            "socialTip": "People lean on you more than they realize. Make sure you're protecting your energy as much as you protect everyone else's."
        ],
        "leo": [
            "headline": "You make people feel seen",
            "body": "Your Sun in Leo means you naturally bring warmth into spaces. When you pay attention to someone, they feel like the only person in the room.",
            "socialTip": "People assume you need constant attention — but what you actually need is to be genuinely appreciated, not just applauded."
        ],
        "virgo": [
            "headline": "You notice what everyone else misses",
            "body": "Your Sun in Virgo means your mind is always refining, improving, solving. You're the one who spots the typo, remembers the deadline, and plans the backup plan.",
            "socialTip": "People mistake your helpfulness for criticism. You're not nitpicking — you're showing you care enough to make things better."
        ],
        "libra": [
            "headline": "You create balance wherever you go",
            "body": "Your Sun in Libra means you instinctively know when something's off in a group dynamic. You're the mediator, the peacekeeper, the one who makes everyone feel included.",
            "socialTip": "People depend on your calm, but that means you sometimes absorb conflict you didn't create. It's okay to choose yourself."
        ],
        "scorpio": [
            "headline": "You see through everything",
            "body": "Your Sun in Scorpio means you read people like subtitles on a movie. Surface-level relationships bore you — you want the real version of people.",
            "socialTip": "People find your intensity magnetic but intimidating. You're not being intense on purpose — you just can't pretend things are fine when they're not."
        ],
        "sagittarius": [
            "headline": "You turn everything into an adventure",
            "body": "Your Sun in Sagittarius means you need movement — physical, intellectual, or emotional. Routine is your kryptonite.",
            "socialTip": "People love your energy but sometimes feel like they can't keep up. You're not leaving them behind — you're just always heading somewhere."
        ],
        "capricorn": [
            "headline": "You play the long game",
            "body": "Your Sun in Capricorn means you think in years, not days. While everyone reacts to the moment, you're already three steps ahead.",
            "socialTip": "People see you as serious, but you're actually deeply funny — you just don't perform for an audience. The people closest to you know this."
        ],
        "aquarius": [
            "headline": "You think differently — on purpose",
            "body": "Your Sun in Aquarius means your brain naturally questions what everyone accepts. You're not being contrarian — you genuinely see angles others don't.",
            "socialTip": "People either love your perspective or find it unsettling. That's their calibration issue, not yours."
        ],
        "pisces": [
            "headline": "You feel everything — and that's your power",
            "body": "Your Sun in Pisces means you experience life at a deeper emotional frequency. Art, music, and people's stories hit you differently.",
            "socialTip": "People underestimate you because you're gentle. They don't realize your empathy is actually the hardest skill to have — and you've mastered it."
        ]
    ]

    // MARK: - Personalized Empty States

    static let personalizedEmptyStates: [String: [String: String]] = [
        "aries": [
            "companions": "You're selective about who gets your energy — that's a strength. Add someone worth analyzing.",
            "history": "No predictions yet. You're the type to just text them — but what if you could know what they'd say first?",
            "guides": "You don't usually need a playbook — but even Aries benefits from understanding how other people tick."
        ],
        "taurus": [
            "companions": "You take your time getting to know people — smart. Add someone you're curious about.",
            "history": "No predictions yet. Before you invest your energy in that conversation, let's see how it'll go.",
            "guides": "You already know what you want to say — this helps you figure out how they need to hear it."
        ],
        "gemini": [
            "companions": "Your social circle is huge but your inner circle is tiny. Add the person you're actually thinking about.",
            "history": "No predictions yet. You've already drafted three replies in your head — let the stars pick the best one.",
            "guides": "You're great at reading the room, but some signs need a different language. These guides are your Rosetta Stone."
        ],
        "cancer": [
            "companions": "You already know who matters to you. Add them here so you can understand the dynamic better.",
            "history": "No predictions yet. Before you spiral about what their silence means, let the stars give you a second opinion.",
            "guides": "You lead with empathy, but not everyone speaks that language. These guides help you meet people where they are."
        ],
        "leo": [
            "companions": "Your presence is magnetic — now add someone whose energy matches yours.",
            "history": "No predictions yet. You deserve to know how the conversation will land before you hit send.",
            "guides": "You already know how to captivate a room. These guides help you captivate one person at a time."
        ],
        "virgo": [
            "companions": "You've been observing them from a distance. Add them here and let the stars fill in what you've missed.",
            "history": "No predictions yet. You've analyzed the conversation enough — let the stars confirm what you already suspect.",
            "guides": "You notice everything — but sometimes you need context for what you're noticing. That's what these are for."
        ],
        "libra": [
            "companions": "You're weighing your options — that's very you. Add someone and let the stars tip the scale.",
            "history": "No predictions yet. You keep replaying the conversation in your head. Let us show you how it actually plays out.",
            "guides": "You already have great instincts with people. These guides sharpen what you already feel."
        ],
        "scorpio": [
            "companions": "You don't let just anyone in. Add the person you're actually invested in — we'll decode them for you.",
            "history": "No predictions yet. You already know something's going on beneath the surface. Let the stars confirm it.",
            "guides": "You read people better than anyone. These guides explain the parts they're trying to hide from you."
        ],
        "sagittarius": [
            "companions": "Life moves fast for you — add someone who's keeping up. Or someone you wish would.",
            "history": "No predictions yet. You usually just wing it — but what if you could see the punchline before the joke?",
            "guides": "You're honest to a fault. These guides help you say the same thing in a way they can actually hear."
        ],
        "capricorn": [
            "companions": "You don't waste time on people who don't matter. Add the one who does.",
            "history": "No predictions yet. You like to plan ahead — this is just planning your conversations too.",
            "guides": "You're strategic about everything else. Why not be strategic about how you communicate too?"
        ],
        "aquarius": [
            "companions": "You connect with people differently — add someone and let us map the frequency you two share.",
            "history": "No predictions yet. You've been thinking about this from every angle. Let the stars add one you haven't considered.",
            "guides": "You already think outside the box. These guides help you understand people who are still inside it."
        ],
        "pisces": [
            "companions": "You feel connections before you understand them. Add someone and let the stars explain what you're feeling.",
            "history": "No predictions yet. Your intuition already told you something — let the stars put it into words.",
            "guides": "You understand people on a soul level. These guides give you the vocabulary to match your intuition."
        ]
    ]

    // MARK: - Discovery Intro Messages ("Say Hi")

    static let discoveryIntroMessages: [String: [String]] = [
        "same_sign": [
            "hey! another %@ — we probably think the same way about everything 😂",
            "no way, you're a %@ too? we should compare notes",
        ],
        "compatible": [
            "our signs are pretty compatible — %@%% match. that's not nothing 👀",
            "saw we're %@%% compatible. the stars might be onto something",
        ],
        "neutral": [
            "hey! our signs are interesting together — %@%% compatibility. curious what you think",
            "we're %@%% compatible — different enough to be interesting, similar enough to click",
        ]
    ]

    // MARK: - Panel Chat

    /// Second/third panel voices reacting to the previous guide's take.
    /// `{name}` = the guide who spoke before. Keyed by ZodiacElement rawValue.
    static let panelInterGuideBeats: [String: [String]] = [
        "fire": [
            "I read it a shade differently than {name} — keep the heat, cut the apology.",
            "{name} isn't wrong, but I'd move sooner. Waiting is also a message.",
            "Building on {name}: yes, but say it like you mean it the first time."
        ],
        "earth": [
            "Where {name} sees a spark, I'd want one steady line first.",
            "{name} has the spirit of it. I'd just slow the delivery by half.",
            "Agreed with {name} on the what — my note is the pacing."
        ],
        "air": [
            "Adding one angle to what {name} said — answer the subtext, not the sentence.",
            "{name} read the feeling; I'm reading the pattern. Both say the same thing.",
            "Take {name}'s line and make it ten percent lighter. That's the version that lands."
        ],
        "water": [
            "{name} is right about the timing, but feel it once before you send it.",
            "Underneath what {name} said: check what this is actually about for you.",
            "I'd hold {name}'s advice with one soft edge — leave them room to meet you."
        ]
    ]

    /// Panel welcome posts, one per slot (Sun, Moon, Rising guide).
    /// `{name}` = user first name, `{sign}` = placement sign, `{role}` = Sun/Moon/Rising.
    static let panelWelcomeOpeners: [String] = [
        "Hey {name} — I read with your {sign} {role}. When a message has you circling, bring it here.",
        "I hold your {sign} {role} lens — how it actually feels before you answer. Nothing you say here needs to be polished.",
        "And I read your {sign} {role} — the tone you open with. The three of us see the same thread differently on purpose. Ask us anything."
    ]

    /// Panel daily conversation starters. Keyed by CelestialRole rawValue
    /// ("sun"/"moon"/"rising"); each ends in a question to invite a reply.
    static let panelDailyStarters: [String: [String]] = [
        "sun": [
            "Daily check from your Sun lens: is there a message you're carrying today that wants to be sent?",
            "Sun read for today: your core drive sets the tone before any wording does. What conversation matters most today?",
            "Today's Sun focus — say less, mean it more. Anything on your mind worth a read?"
        ],
        "moon": [
            "Moon check-in: how a message feels usually decides how you answer it. Anything land strangely today?",
            "Today runs on your Moon lens — reaction before reply. Want us to read anything before you respond?",
            "Moon focus today: notice what you reread twice. What was it?"
        ],
        "rising": [
            "Rising lens today: first impressions are doing the talking. Any opener you want us to tune?",
            "Today's Rising read — tone first, content second. Is there a conversation you want to start well?",
            "Your Rising sets the door you open with. Anyone you've been meaning to message?"
        ]
    ]

    /// Contextual starters — the panel referencing what it actually remembers.
    /// `{personName}` slot.
    static let panelMemoryStarters: [String] = [
        "Quick follow-up — how did things go with {personName}?",
        "You brought up {personName} last time. Any movement there, or still composing?",
        "Still thinking about your {personName} situation. Want a fresh read on it today?"
    ]

    /// `{target}` slot — the unrated-prediction nudge that feeds the accuracy stat.
    static let panelPredictionFollowUpStarters: [String] = [
        "You ran a read on {target} — did the reply land like we called it? Tap it in your history either way.",
        "Open loop from your last prediction about {target}: did it land? Rating it sharpens every read we give you."
    ]

    /// `{streak}` slot.
    static let panelStreakStarters: [String] = [
        "{streak} days straight. That consistency is doing more for your reads than any single prediction. What's today's thread?",
        "Streak check: {streak} days. You keep showing up — so will we. Anything worth a read this morning?"
    ]

    /// `{caption}` slot — riffs on the user's own words, never the image.
    static let panelMomentStarters: [String] = [
        "\u{201C}{caption}\u{201D} stuck with me. Want to carry that tone into a message today?",
        "Your last moment — \u{201C}{caption}\u{201D} — reads like a good chapter. What's happening in it now?"
    ]

    /// Welcome-back lines after 3+ quiet days, referencing a memory note.
    /// `{personName}` slot.
    static let panelWelcomeBackLines: [String] = [
        "Welcome back. Last time you were working out things with {personName} — how did it land?",
        "Good to see you. Before anything new: where did things settle with {personName}?"
    ]

    // MARK: - Moments

    /// Guide comments on a user's private Moment. These riff on the user's
    /// chart and the act of sharing — the guides cannot see images, and these
    /// templates must never imply they can. Placeholders: `{name}`, `{sun}`,
    /// `{rising}`, `{role}`. Keyed by the GUIDE's element.
    static let momentCommentTemplates: [String: [String]] = [
        "fire": [
            "Posting without overthinking it — that's the {sun} Sun doing exactly its job.",
            "This is the energy I keep telling you to text from, {name}.",
            "You shared it, you own it. That's the whole move.",
            "Momentum suits you. Carry this into your next conversation.",
            "The {role} lens says: this is you at full signal. Keep that."
        ],
        "earth": [
            "Moments like this are how steadiness reads from the outside.",
            "No performance in this one — that's why it works, {name}.",
            "Your {sun} Sun builds in quiet ways. This is one of them.",
            "Keep collecting these. They're proof, not decoration.",
            "Grounded read: whatever today was, you held it well."
        ],
        "air": [
            "There's a whole story in this one and you told it without a paragraph.",
            "Noted and filed under: {name} understanding the assignment.",
            "Your {rising} Rising chose the tone here — light, but not careless.",
            "This says more than your last three drafts combined.",
            "The pattern across your moments: you share when you're sure. Respect."
        ],
        "water": [
            "Something about this one feels settled. Hold onto that.",
            "You share when it means something — your {sun} Sun keeps it honest.",
            "Reading the feeling here, not the surface. It reads calm.",
            "This is the version of you your best messages come from.",
            "Soft proof that you're doing better than your overthinking says."
        ]
    ]

    /// Caption-echo comments — quote the user's own words back through the lens.
    /// `{caption}` = the user's trimmed caption.
    static let momentCaptionEchoTemplates: [String] = [
        "\u{201C}{caption}\u{201D} — that's the whole read, honestly.",
        "You wrote \u{201C}{caption}\u{201D} and that tracks completely with your chart.",
        "\u{201C}{caption}\u{201D} is exactly the tone I'd tell you to text with.",
        "Keep \u{201C}{caption}\u{201D} as your opening-line energy this week."
    ]

    // MARK: - Transit Timing

    /// Daily timing guidance keyed by "{body}.{family}" where family is
    /// flow (trine/sextile), friction (square/opposition), or
    /// emphasis (conjunction). Message-timing voice, not horoscope filler.
    static let transitGuidance: [String: [String]] = [
        "mercury.flow": [
            "Wording comes clean today — the honest text writes itself. Send it.",
            "Good day for the conversation you've been drafting. Say it plainly."
        ],
        "mercury.friction": [
            "Messages bend out of shape today. Draft now, reread once, send later.",
            "Easy to be misread right now — keep texts short and literal."
        ],
        "mercury.emphasis": [
            "Words carry extra weight today. One clear sentence does the work of five.",
            "Everything you send today gets reread. Make the first line count."
        ],
        "venus.flow": [
            "Warmth lands easily today — a kind message goes further than usual.",
            "Good timing for affection, repair, or the soft follow-up."
        ],
        "venus.friction": [
            "Affection can read as pressure today. Offer warmth, don't ask for proof.",
            "Don't measure their reply speed against your effort today."
        ],
        "venus.emphasis": [
            "Tone is the message today. How you say it will outlive what you said.",
            "Lead with warmth today — it sets the price of the whole conversation."
        ],
        "mars.flow": [
            "Momentum favors the first move. Open the conversation you've been circling.",
            "Directness lands as confidence today, not aggression. Use it."
        ],
        "mars.friction": [
            "Short fuses in the air — don't send the reply you typed while annoyed.",
            "Friction day: win by staying measured while the thread runs hot."
        ],
        "mars.emphasis": [
            "Energy wants an outlet today — aim it at one honest message, not five impulsive ones.",
            "Bold reads as decisive today. Pick the one move that matters."
        ],
        "sun.flow": [
            "You read as yourself today — good light for the conversation that needs the real you.",
            "Visibility is high and kind today. Show up in the thread that matters."
        ],
        "sun.friction": [
            "Ego stakes feel inflated today. Argue the point, not the identity.",
            "Don't make today's message a referendum on who's right."
        ],
        "sun.emphasis": [
            "A reset day for how you show up. Open the thread the way you'd want it remembered.",
            "Today resets the tone going forward — choose your opening carefully."
        ],
        "moon.flow": [
            "Feelings are readable today — yours and theirs. Trust the first read.",
            "Emotionally clear air today. A sincere message will be received as sent."
        ],
        "moon.friction": [
            "Moods swing fast today — let a charged message sit for an hour before sending.",
            "What feels urgent this morning won't by tonight. Time your reply accordingly."
        ],
        "moon.emphasis": [
            "The feeling under the words is loud today. Name yours before you reply to theirs.",
            "Lead with how it felt, not what they did. Today that distinction lands."
        ]
    ]
}
