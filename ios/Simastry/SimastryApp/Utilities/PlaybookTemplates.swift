import Foundation

// MARK: - Situation Playbooks
// Per-person, per-situation communication scripts — the "communication
// styles, not predictions" feature. Framed in behavioral results language so
// it earns its keep with skeptics; astrology is the visible lens, never a
// belief requirement.

nonisolated enum PlaybookSituation: String, Codable, CaseIterable, Identifiable, Sendable {
    case giveFeedback
    case askForSomething
    case resolveConflict
    case apologize
    case hypeThemUp
    case hardConversation
    case setBoundary
    case reconnect

    var id: String { rawValue }

    var title: String {
        switch self {
        case .giveFeedback: "Give feedback"
        case .askForSomething: "Ask for something"
        case .resolveConflict: "Resolve a conflict"
        case .apologize: "Apologize"
        case .hypeThemUp: "Hype them up"
        case .hardConversation: "Hard conversation"
        case .setBoundary: "Set a boundary"
        case .reconnect: "Reconnect"
        }
    }

    var systemImage: String {
        switch self {
        case .giveFeedback: "text.badge.checkmark"
        case .askForSomething: "hand.raised.fingers.spread.fill"
        case .resolveConflict: "arrow.triangle.merge"
        case .apologize: "heart.text.square.fill"
        case .hypeThemUp: "flame.fill"
        case .hardConversation: "bubble.left.and.exclamationmark.bubble.right.fill"
        case .setBoundary: "hand.raised.fill"
        case .reconnect: "arrow.uturn.left.circle.fill"
        }
    }
}

nonisolated struct Playbook: Equatable, Sendable {
    let situation: PlaybookSituation
    let script: String
    let whyItWorks: String
    let avoid: String
}

nonisolated enum PlaybookComposer {
    /// Deterministic per inputs; `variantSeed` lets the UI rotate variants
    /// (e.g. by day) while tests pass fixed seeds.
    static func playbook(
        situation: PlaybookSituation,
        personName: String,
        sun: ZodiacSign,
        moon: ZodiacSign?,
        relationshipType: RelationshipType,
        userSun: ZodiacSign?,
        variantSeed: Int = 0
    ) -> Playbook {
        let variants = PlaybookTemplates.scripts[situation]?[sun] ?? []
        let situationIndex = PlaybookSituation.allCases.firstIndex(of: situation) ?? 0
        let relationshipIndex = RelationshipType.allCases.firstIndex(of: relationshipType) ?? 0
        let script = variants.isEmpty
            ? "Say the true thing in one sentence, then give \(personName) room to answer."
            : variants[(situationIndex + relationshipIndex + variantSeed) % variants.count]
                .replacingOccurrences(of: "{name}", with: personName)

        var why: [String] = []
        if let lead = PlaybookTemplates.situationWhy[situation]?[sun.element] {
            why.append(lead)
        }
        if let approach = CommunicationTemplates.approachReasoning[sun.displayName] {
            why.append(approach + ".")
        }
        if let moon, let modifier = PlaybookTemplates.moonModifiers[moon.element] {
            why.append(modifier.replacingOccurrences(of: "{moon}", with: moon.displayName))
        }
        if let register = PlaybookTemplates.registerNotes[relationshipType] {
            why.append(register)
        }

        var avoid: [String] = []
        if let situationAvoid = PlaybookTemplates.situationAvoid[situation] {
            avoid.append(situationAvoid)
        }
        if let signAvoid = CommunicationTemplates.avoidReasoning[sun.displayName] {
            avoid.append(signAvoid + ".")
        }

        return Playbook(
            situation: situation,
            script: script,
            whyItWorks: why.joined(separator: " "),
            avoid: avoid.joined(separator: " ")
        )
    }
}

nonisolated enum PlaybookTemplates {
    /// Sendable 1–2 line scripts: 8 situations × 12 signs × 2 variants.
    /// `{name}` is the only slot.
    static let scripts: [PlaybookSituation: [ZodiacSign: [String]]] = [
        .giveFeedback: [
            .aries: [
                "Straight up — the energy you bring is the engine here. One change would make it unstoppable: can I show you?",
                "You move faster than anyone. One adjustment and nobody catches you — got two minutes?"
            ],
            .taurus: [
                "No rush on this — the foundation you built is solid. There's one piece worth reworking when you have space this week.",
                "What you've made works. I have one suggestion that makes it last longer — want it now or over coffee?"
            ],
            .gemini: [
                "Okay, two thoughts — one's a compliment, one's an idea. Compliment first: the way you framed it landed. The idea: tighten the middle part.",
                "Quick riff: it's 90% there. Want to trade notes on the other 10%?"
            ],
            .cancer: [
                "First — I see how much care went into this, and it shows. There's one part I think we can protect even better. Open to it?",
                "This clearly mattered to you, and it lands. One small change would keep anyone from misreading it — want my take?"
            ],
            .leo: [
                "You set the tone for everyone on this — genuinely. One tweak would make the strongest part even more visible. Want to hear it?",
                "Credit where it's due: this carries the room. There's one spot where your best work is getting buried — can I point at it?"
            ],
            .virgo: [
                "Specifics: parts one and three are airtight. Part two has a gap — here's exactly where, and a fix if you want it.",
                "You'll see it before I finish the sentence: section two. One pass and it's flawless."
            ],
            .libra: [
                "I want your read on this too — overall it's strong. One part feels unbalanced to me; tell me if you see it differently.",
                "Both sides of this are almost matched. If we weight the second half slightly more, it sings. Fair?"
            ],
            .scorpio: [
                "I'll be straight because you'd see through anything else: it's strong, and one part is hiding its real point. Worth a look together?",
                "Between us — the work is better than you're letting it look. Surface the part you buried."
            ],
            .sagittarius: [
                "Honest take, no padding: the big swing works. The setup before it drags. Cut it and you're golden.",
                "You want it straight, so: 80% brilliant, 20% safe. Lose the safe part."
            ],
            .capricorn: [
                "Quick one — the plan you ran is working, two things are already handled. One tweak would make it faster. Worth ten minutes this week?",
                "Respect for how you structured this. One change improves the outcome measurably — want the short version?"
            ],
            .aquarius: [
                "The unconventional part is the best part — keep it. The conventional part is what needs work, ironically. Thoughts?",
                "Nobody else would've approached it this way, which is why it works. One section fights the concept — want to rethink it together?"
            ],
            .pisces: [
                "The feeling in this comes through — that's the hard part and you nailed it. One section blurs the message; want to sharpen it together?",
                "There's real heart in this. Let's protect it by tightening the one part people might skim past."
            ]
        ],
        .askForSomething: [
            .aries: [
                "Direct ask, no buildup: I need {name} energy on something. You in?",
                "I'll keep it short — I need a favor and you're the first person I thought of. Can you take it?"
            ],
            .taurus: [
                "No pressure and no deadline panic — I have an ask, and you can think on it. Would you be up for helping me with something next week?",
                "I'd rather ask you than anyone because you actually follow through. One favor, your timeline."
            ],
            .gemini: [
                "Got a fun one for you — it's a favor, but the interesting kind. Want the pitch?",
                "Two-part question: are you around this week, and can I borrow that brain of yours for an hour?"
            ],
            .cancer: [
                "You're the person I trust with this — that's why I'm asking you and not someone else. Could you help me with something?",
                "No pressure at all, truly. But if you have room this week, your help would mean a lot."
            ],
            .leo: [
                "Honestly, nobody does this better than you — which is why I'm asking. Can I pull you in on something?",
                "I need the best version of this done, so I came straight to you. You free this week?"
            ],
            .virgo: [
                "Specific ask, scoped tight: thirty minutes, one task, your eye for detail. Possible this week?",
                "I'll make this easy to say yes to — here's exactly what I need and when. Tell me if it fits."
            ],
            .libra: [
                "I want to make this fair — I need a favor, and I owe you one back, your choice when. Deal?",
                "Would you be open to helping with something? I picked you because you'll make it better, not just done."
            ],
            .scorpio: [
                "I don't ask lightly and you know that. I need your help with something that matters. Can we talk?",
                "This stays between us — I need a hand with something real. You're the one I trust with it."
            ],
            .sagittarius: [
                "Adventure with a purpose: I need your help on something. Minimal boredom guaranteed. In?",
                "Straight ask, zero guilt either way: can you help me out this week?"
            ],
            .capricorn: [
                "I'll respect your time: one ask, clear scope, real payoff. Can I send you the details?",
                "You're the most reliable person I know, so I'm asking you first. One favor — does this week work?"
            ],
            .aquarius: [
                "No obligation, genuinely — but this is the kind of weird problem you actually enjoy. Want in?",
                "I need a perspective nobody else has. That's you. One favor?"
            ],
            .pisces: [
                "This would honestly take a weight off me — could you help with something this week?",
                "You have a way of making things easier. I could use exactly that right now — got space for a favor?"
            ]
        ],
        .resolveConflict: [
            .aries: [
                "Let's not let this sit — I'd rather clear it today. Say your piece, I'll say mine, we move forward.",
                "We hit a wall and I want past it. No politics, just direct: what bothered you most?"
            ],
            .taurus: [
                "No ambush — when you're ready, I want to sort out what happened. Steady conversation, no surprises.",
                "I'm not going anywhere and neither is this friendship. When you have space, let's untangle it calmly."
            ],
            .gemini: [
                "Can we talk it through? I think we're holding two different versions of the same story, and I want to compare them.",
                "I'd rather understand it than win it. Walk me through how it looked from your side?"
            ],
            .cancer: [
                "Before anything else: the friendship matters more than the argument. I want to understand how that actually felt for you.",
                "I've been thinking about what happened, and about you. Can we talk — gently, no scorekeeping?"
            ],
            .leo: [
                "I'll say it first: I respect you, and this fight doesn't change that. Let's fix it like two people who actually rate each other.",
                "Neither of us looks good staying mad. Talk tonight? I'll bring the first apology if you bring the second."
            ],
            .virgo: [
                "I want to fix the actual problem, not the vibes around it. Can we name what specifically went sideways?",
                "Here's what I think happened, step by step — correct me where I'm wrong. I want this solved, not smoothed over."
            ],
            .libra: [
                "I think we both have a point, which is exactly why it got tense. Can we find the version where neither of us loses?",
                "I want to hear your side fully before I say more about mine. When's good?"
            ],
            .scorpio: [
                "Let's skip the surface version — what's actually underneath this for you? I can handle the real answer.",
                "I'd rather have one honest hard conversation than six polite cold ones. Ready when you are."
            ],
            .sagittarius: [
                "Honestly? This got heavier than either of us wanted. Truth swap, ten minutes, then we're free of it.",
                "I'll go first with the honest version if you promise not to make it a whole thing: deal?"
            ],
            .capricorn: [
                "I want to resolve this properly, not patch it. Can we take twenty minutes and actually settle it?",
                "We're both too sensible to lose something good over this. Let's handle it like we handle everything else — directly."
            ],
            .aquarius: [
                "Stepping back from it: we disagreed on the thing, not on each other. Want to look at it from above instead of inside?",
                "No pressure to feel anything on schedule — but when you've had space, I'd like to actually understand your take."
            ],
            .pisces: [
                "I keep thinking about how that felt on your end. I'm not here to argue — I'm here to repair it.",
                "Soft start: I care more about us being okay than about being right. Can we talk when it feels possible?"
            ]
        ],
        .apologize: [
            .aries: [
                "I was wrong and I'm not going to dress it up. My move, my mistake. What can I do to make it right — today?",
                "No excuses: I messed up. Tell me the fix and I'm on it."
            ],
            .taurus: [
                "I'm sorry — and I know with you it's actions that count, so watch what I do next, not just this message.",
                "I broke something steady and I get why that lands hard with you. I'm going to rebuild it the slow, real way."
            ],
            .gemini: [
                "No spin on this one: I was wrong. You deserved the better version of me and got the careless one. I'm sorry.",
                "I owe you a real apology, not a clever one. I'm sorry — full stop."
            ],
            .cancer: [
                "I'm sorry. Not for how it looked — for how it felt. That's the part I'd take back first.",
                "I hurt you, and pretending it was small would hurt you twice. I'm sorry, truly."
            ],
            .leo: [
                "You deserved better from me and I know it. I'm sorry — publicly, privately, whichever counts more.",
                "I'm sorry. You show up generously and I didn't match it. That's on me."
            ],
            .virgo: [
                "I'm sorry — specifically for the thing I did, not a vague everything. Here's what I'll do differently, concretely.",
                "You noticed, of course. You were right to. I'm sorry, and I've already fixed the part I could fix."
            ],
            .libra: [
                "That wasn't fair to you, and fairness is the whole point with us. I'm sorry.",
                "I tipped the balance and you carried the weight. I'm sorry — let me carry the next part."
            ],
            .scorpio: [
                "No performance: I'm sorry. You can trust that I know exactly what I did.",
                "I'm sorry — and I know an apology without changed behavior is just noise to you. So watch."
            ],
            .sagittarius: [
                "Straight up: I'm sorry. No three-paragraph version — just the real one, and better from here.",
                "I got it wrong. I'm sorry. Now tell me we're not doing the awkward distance thing."
            ],
            .capricorn: [
                "I'm sorry. I take it seriously, I know what it cost, and I'm correcting it — not just apologizing for it.",
                "You hold a standard and I dropped below it. I'm sorry, and I'll meet it again."
            ],
            .aquarius: [
                "I'm sorry — no drama attached, no speech required back. Just wanted the truth on record.",
                "I got it wrong and you're owed the acknowledgment. I'm sorry. Take whatever space you want with it."
            ],
            .pisces: [
                "I'm sorry. I keep replaying how it must have felt, and I hate that I'm the reason.",
                "Gently and honestly: I'm sorry. You feel things fully and I was careless with that."
            ]
        ],
        .hypeThemUp: [
            .aries: [
                "Reminder, because someone has to say it: nobody attacks the thing like you do. Go take it.",
                "You were built for exactly this. First move, like always — go."
            ],
            .taurus: [
                "What you've built didn't happen by luck — it happened by you showing up every single day. Today's just another one you'll win.",
                "You're the most solid person in any room. Walk in like it."
            ],
            .gemini: [
                "You can out-think and out-talk everyone in that room. Don't perform it, just let it happen.",
                "They're getting the fastest mind in the building today. Almost unfair, honestly."
            ],
            .cancer: [
                "You care more than anyone — that's not softness, that's your engine. Let them feel it today.",
                "Whatever happens today, you've already done the hardest part: you kept your heart in it."
            ],
            .leo: [
                "The room changes when you walk in — that's not flattery, it's physics. Go be the event.",
                "Today's a stage and you've never missed on one. Shine without apologizing for it."
            ],
            .virgo: [
                "Nobody has done the homework like you have. You're not hoping today goes well — you've engineered it.",
                "You see what everyone else misses. That's the edge. Trust your own eyes today."
            ],
            .libra: [
                "You make hard rooms feel easy — that's a rare kind of power. Use it today.",
                "Everyone leaves a conversation with you feeling better. Today, that's exactly the weapon you need."
            ],
            .scorpio: [
                "You've survived harder than today without blinking. They have no idea what's underneath — show them a glimpse.",
                "Quiet intensity wins this one, and you've got the market cornered. Go."
            ],
            .sagittarius: [
                "Big day, your favorite kind. Aim at the honest version of the win and fire.",
                "You're at your best when the stakes are real and the air is fresh. Both are true today."
            ],
            .capricorn: [
                "You've put in the unglamorous hours nobody saw. Today is just the receipt printing.",
                "Standards like yours don't lose often. Today isn't the day they start."
            ],
            .aquarius: [
                "Nobody thinks like you, and today is precisely a nobody-thinks-like-you problem. Lucky them.",
                "Original beats polished today. You've never been anything but original."
            ],
            .pisces: [
                "You feel where things are going before anyone sees it. Trust that today — it's a superpower, not a hunch.",
                "All that imagination isn't a someday thing. It's exactly what today calls for."
            ]
        ],
        .hardConversation: [
            .aries: [
                "I need to talk to you about something real — no buildup, no ambush, just direct. Got ten minutes today?",
                "There's something I have to say and you'd respect it more straight than softened. Ready when you are."
            ],
            .taurus: [
                "Heads up, no surprises: there's something important I want to talk through. Pick a calm moment that works for you.",
                "Nothing is breaking — but something needs saying. Slow conversation, your timing."
            ],
            .gemini: [
                "I want to talk through something serious — actual conversation, both sides, not a verdict. When works?",
                "Real talk needed. I promise to keep it human, not heavy. Coffee?"
            ],
            .cancer: [
                "First: you're safe with me, this isn't a goodbye-shaped conversation. But something important needs air. When feels okay?",
                "I want to share something that's hard to say — gently and honestly. Choose a moment you feel steady."
            ],
            .leo: [
                "Respect first: I'm bringing this to you directly, not around you. Something needs saying. Can we talk one-on-one?",
                "I have something hard to say, and you deserve it face to face, not in a text. When can we meet?"
            ],
            .virgo: [
                "I want to talk through a specific thing — I'll come with the facts, not the drama. Thirty minutes this week?",
                "Something needs addressing and I'd rather do it precisely than emotionally. You'll appreciate the difference."
            ],
            .libra: [
                "I need a hard conversation, and I want it to stay a fair one. Both of us heard fully — when can we sit down?",
                "Something's been off and naming it kindly beats avoiding it politely. Can we talk?"
            ],
            .scorpio: [
                "The real version, no performance: there's something serious to discuss. You'd rather have the truth — I know you.",
                "Private conversation, full honesty, no audience. Something matters and you should hear it from me first."
            ],
            .sagittarius: [
                "I'll keep it honest and I'll keep it moving — there's something hard we need to cover. No drama marathon, promise.",
                "Hard topic incoming, handled the way we both prefer: direct, fast, no theater. When?"
            ],
            .capricorn: [
                "There's a serious matter I want to handle properly with you — scheduled, focused, resolved. What works this week?",
                "I respect you too much to let this slide sideways. One direct conversation and we're through it."
            ],
            .aquarius: [
                "No pressure to react in real time — I want to raise something hard, you can process it however you process. Talk soon?",
                "Something needs discussing. I'll bring the facts, you bring the distance, we'll figure it out like adults."
            ],
            .pisces: [
                "I want to talk about something difficult — and I'll hold it gently, I promise. When do you have quiet space?",
                "Something heavy needs saying, softly. You set the time; I'll bring the care."
            ]
        ],
        .setBoundary: [
            .aries: [
                "Straight with you: I can't do late changes anymore. Send them by Thursday and I'm all in.",
                "I'm drawing one clear line — {name}, I need this to stop. Everything else stays the same."
            ],
            .taurus: [
                "Calmly and permanently: this one thing doesn't work for me anymore. Nothing else changes — just this.",
                "I've thought about it for a while, so this isn't a mood: I need this boundary, starting now."
            ],
            .gemini: [
                "Quick clarity, not a lecture: that thing we do — I'm out on it going forward. Everything else, business as usual.",
                "One rule change on my end, said once, said kindly: I need this to be different from now on."
            ],
            .cancer: [
                "Because I care about us, not despite it: I need this boundary. Protecting it protects the relationship too.",
                "This is me looking after myself the way you'd want me to: I can't keep doing this part. The rest of us stays."
            ],
            .leo: [
                "Full respect, zero games: I need this line drawn. You'd do the same in my spot, and I'd respect you for it.",
                "I'm telling you directly because you'd hate hearing it sideways: this stops here. We're good otherwise."
            ],
            .virgo: [
                "Specific and simple: I need X to stop, starting now. Not a referendum on you — just one fixed thing.",
                "Here's the boundary, precisely scoped so there's no guessing: this, no more. Everything else as before."
            ],
            .libra: [
                "I want to be fair to both of us, and that means being honest: I need this boundary. It keeps things balanced, not distant.",
                "Said kindly and meant fully: this doesn't work for me anymore. Can we agree on it and keep everything else easy?"
            ],
            .scorpio: [
                "You respect people who hold their ground, so: this is mine. Fixed, not negotiable, not personal.",
                "One line, drawn once, never performed: this ends here. You'll know I mean it because I won't repeat it."
            ],
            .sagittarius: [
                "Honest and breezy as ever: that thing — I'm done with it. No drama attached, just a fact now.",
                "Freedom goes both ways, so here's mine: I need this boundary. Yours stay fully intact."
            ],
            .capricorn: [
                "Professionally and personally: this is a standard I'm setting, not a complaint I'm filing. It starts now.",
                "I'll say it once, clearly, like we both prefer: this boundary is firm. I trust you to take it seriously."
            ],
            .aquarius: [
                "No emotional invoice attached — just a system update: I need this to change. Logical, fixed, done.",
                "You of all people get autonomy: here's mine. This part changes; nothing else does."
            ],
            .pisces: [
                "Gently but really: I need this boundary. It's not a wall — it's the thing that lets me stay soft with you.",
                "I'm asking for this kindly, and I need it fully: this has to change. It protects what I love about us."
            ]
        ],
        .reconnect: [
            .aries: [
                "Enough silence — I miss you and waiting is boring. What are you doing Thursday?",
                "Cutting straight through the gap: you, me, catch-up, this week. Pick a day."
            ],
            .taurus: [
                "Been thinking about you — no agenda, just realized it's been a while. How's your month actually going?",
                "Some people are worth circling back to no matter how long it's been. You're top of that list. Coffee soon?"
            ],
            .gemini: [
                "I have approximately forty things to tell you and I'm only telling them in person. When are you free?",
                "Our chat went quiet and the group chats are worse without you in mine. Catch up this week?"
            ],
            .cancer: [
                "You crossed my mind today — the good kind of crossing. I miss you. How are you, really?",
                "No reason except the real one: I miss having you close. Can we fix that soon?"
            ],
            .leo: [
                "The world is objectively less interesting without you in my week. Let's fix that — dinner soon?",
                "Reaching out first because you're worth the move: I miss you. When can I see you?"
            ],
            .virgo: [
                "It's been 47 days, give or take, and that's too many. Lunch this week — I'll handle the logistics.",
                "Noticed the gap and decided to close it properly: are you free Tuesday or Thursday?"
            ],
            .libra: [
                "It's been too long and that's at least half my fault — let me make the first move back. Coffee soon?",
                "Thought of you today and realized I'd rather say it than just think it: I miss you. Catch up?"
            ],
            .scorpio: [
                "Not many people stay on my mind through silence. You do. Talk soon?",
                "The gap doesn't mean what gaps usually mean — you matter to me. Let's pick it back up."
            ],
            .sagittarius: [
                "Zero guilt, zero ceremony: it's been a while, life happened, and I still think you're great. Adventure soon?",
                "Picking up exactly where we left off, as is tradition. What's new and when do I hear it in person?"
            ],
            .capricorn: [
                "I know we're both busy, which is exactly why I'm scheduling this: catch-up, this month, non-negotiable. When works?",
                "Consistency matters to me and I've let ours slip — correcting that now. Dinner soon?"
            ],
            .aquarius: [
                "No script for this, just the honest version: I miss your brain. Talk soon?",
                "We don't do guilt-trip reunions — we just resume. So: resuming. What's the strangest thing that happened to you this year?"
            ],
            .pisces: [
                "You drifted through my mind today and stayed there. I miss you — how's your heart?",
                "Some connections don't fade, they just wait. Ours waited long enough — can we catch up soon?"
            ]
        ]
    ]

    /// Behavioral, results-first lead clause for whyItWorks — keyed by the
    /// person's Sun element.
    static let situationWhy: [PlaybookSituation: [ZodiacElement: String]] = [
        .giveFeedback: [
            .fire: "Fire-sign communicators take feedback best at speed — energy first, fix second, no long preamble.",
            .earth: "Earth-sign communicators respond to competence framing — lead with what's already handled before the ask.",
            .air: "Air-sign communicators treat feedback as a conversation, not a verdict — invite their read and they'll meet you halfway.",
            .water: "Water-sign communicators hear the care level before the content — acknowledge the effort first and the note lands clean."
        ],
        .askForSomething: [
            .fire: "Fire signs say yes to momentum — a direct, confident ask beats a hedged one every time.",
            .earth: "Earth signs say yes to clarity — scope the ask and respect their timeline and the answer improves.",
            .air: "Air signs say yes to interesting — frame the favor as a problem worth their brain, not a chore.",
            .water: "Water signs say yes to trust — name why it's them you're asking and the ask becomes a compliment."
        ],
        .resolveConflict: [
            .fire: "Fire signs resolve fast and resent slow-burn tension — direct and same-day beats careful and next-week.",
            .earth: "Earth signs need no-ambush conditions — schedule it calmly and the defensiveness drops by half.",
            .air: "Air signs de-escalate through understanding — compare versions of the story before assigning anything.",
            .water: "Water-sign communicators de-escalate when the feeling is named before the fix — validation first cuts the conflict in half."
        ],
        .apologize: [
            .fire: "Fire signs rate ownership over elaboration — a fast, square apology with an action attached reads as strength.",
            .earth: "Earth signs trust repair they can watch — pair the apology with visible changed behavior.",
            .air: "Air signs spot a crafted apology instantly — plain words, no spin, carry the most weight.",
            .water: "Water signs need the feeling acknowledged, not just the fact — apologize for the impact, not the optics."
        ],
        .hypeThemUp: [
            .fire: "Fire signs convert encouragement directly into momentum — aim it at the action, not the abstract.",
            .earth: "Earth signs trust evidence-based praise — point at what they built, not who they are in theory.",
            .air: "Air signs light up when their thinking is seen — praise the mind and the originality specifically.",
            .water: "Water signs are moved by being deeply seen — name the heart in their work and it fuels them for days."
        ],
        .hardConversation: [
            .fire: "Fire signs prefer the hit straight — softening reads as distrust; directness reads as respect.",
            .earth: "Earth signs handle hard topics best with warning and structure — no surprises, calm setting, clear scope.",
            .air: "Air signs need it framed as a dialogue — verdict-shaped openers shut the conversation before it starts.",
            .water: "Water signs need safety established first — lead with reassurance about the relationship, then the topic."
        ],
        .setBoundary: [
            .fire: "Fire signs respect lines drawn boldly — apologetic boundaries invite testing; clean ones earn respect.",
            .earth: "Earth signs accept boundaries that are stable — say it once, calmly, and never wobble on it.",
            .air: "Air signs take boundaries best as information, not accusation — keep it factual and drama-free.",
            .water: "Water signs accept boundaries framed as care — show the line protects the closeness rather than ending it."
        ],
        .reconnect: [
            .fire: "Fire signs respond to bold re-entry — confidence reads as warmth; tiptoeing reads as obligation.",
            .earth: "Earth signs value the steady return — no guilt theater, just genuine presence and a concrete plan.",
            .air: "Air signs reconnect through curiosity — a great question reopens more than a great apology.",
            .water: "Water signs reconnect through feeling — say you missed them plainly and mean it; they'll feel the difference."
        ]
    ]

    static let situationAvoid: [PlaybookSituation: String] = [
        .giveFeedback: "Don't stack three criticisms in one message — one note, fully landed, beats a list.",
        .askForSomething: "Don't bury the ask under apologies — guilt makes the yes worth less.",
        .resolveConflict: "Don't litigate the timeline — fix the feeling and the facts get easier.",
        .apologize: "Don't pad it with three qualifiers — one clean ownership line, then stop.",
        .hypeThemUp: "Don't make it generic — praise that fits anyone lands on no one.",
        .hardConversation: "Don't open with 'we need to talk' and then go silent — name the topic in the same breath.",
        .setBoundary: "Don't restate the boundary five ways — repetition reads as negotiation.",
        .reconnect: "Don't spend the first message apologizing for the silence — just be present in it."
    ]

    /// Appended when the person's Moon is known. `{moon}` slot.
    static let moonModifiers: [ZodiacElement: String] = [
        .fire: "Their {moon} Moon means the emotional reaction arrives fast and burns off fast — don't mistake the first response for the final one.",
        .earth: "Their {moon} Moon processes feelings slowly and privately — give the message time to settle before expecting movement.",
        .air: "Their {moon} Moon talks feelings into shape — leave openings for them to think out loud.",
        .water: "Their {moon} Moon reads tone before words — the emotional register carries more than the content."
    ]

    /// One-clause register shift by relationship type.
    static let registerNotes: [RelationshipType: String] = [
        .partner: "With a partner, warmth carries the structure — let the care show through the words.",
        .friend: "Friend register: keep it human and unpolished — perfect wording reads as distance here.",
        .family: "Family register: history is in the room — keep the message about now, not the archive.",
        .teammate: "Teammate register: keep it outcome-first — warmth through brevity, not intimacy.",
        .other: "Match the formality they use with you — mirror first, then lead."
    ]
}
