import Foundation

// MARK: - Team Read
// Group communication dynamics for 2–5 people from the People tab — element
// and modality composition, pairwise whole-sign contacts, group roles, the
// friction pair with a bridge, and one actionable play.

nonisolated struct TeamReadMember: Equatable, Sendable {
    let name: String
    let sun: ZodiacSign
    let moon: ZodiacSign?
    let isUser: Bool
}

nonisolated struct TeamRead: Equatable, Sendable {
    struct Role: Equatable, Sendable {
        let memberName: String
        let title: String
        let line: String
    }

    struct PairHighlight: Equatable, Sendable {
        let nameA: String
        let nameB: String
        let aspect: WholeSignAspect
        let line: String
    }

    let headline: String
    let elementCounts: [ZodiacElement: Int]
    let modalityCounts: [String: Int]
    let roles: [Role]
    let highlights: [PairHighlight]
    let frictionPair: PairHighlight?
    let bridge: String?
    let play: String
}

nonisolated enum TeamReadEngine {
    /// Deterministic group read. Caller enforces 2...5 members.
    static func read(members: [TeamReadMember], seed: Int = 0) -> TeamRead {
        let elementCounts = Dictionary(grouping: members, by: { $0.sun.element })
            .mapValues(\.count)
        let modalityCounts = Dictionary(grouping: members, by: { $0.sun.modality })
            .mapValues(\.count)

        let roles = members.map { member in
            TeamRead.Role(
                memberName: member.name,
                title: TeamReadTemplates.modalityRoles[member.sun.modality] ?? "Connector",
                line: roleLine(for: member)
            )
        }

        // Pairwise whole-sign contacts, strongest first.
        var contacts: [(a: TeamReadMember, b: TeamReadMember, aspect: WholeSignAspect)] = []
        for i in members.indices {
            for j in members.indices where j > i {
                if let aspect = WholeSignAspect.between(members[i].sun, members[j].sun) {
                    contacts.append((members[i], members[j], aspect))
                }
            }
        }
        contacts.sort { $0.aspect.significance > $1.aspect.significance }

        let highlights = contacts.prefix(3).map { contact in
            TeamRead.PairHighlight(
                nameA: contact.a.name,
                nameB: contact.b.name,
                aspect: contact.aspect,
                line: pairLine(contact.a.name, contact.b.name, aspect: contact.aspect, seed: seed)
            )
        }

        let frictionContact = contacts.first { $0.aspect.family == "friction" }
        let frictionPair = frictionContact.map { contact in
            TeamRead.PairHighlight(
                nameA: contact.a.name,
                nameB: contact.b.name,
                aspect: contact.aspect,
                line: pairLine(contact.a.name, contact.b.name, aspect: contact.aspect, seed: seed)
            )
        }

        let bridge = frictionContact.map { contact in
            bridgeLine(contact.a, contact.b, seed: seed)
        }

        let dominantElement = elementCounts.max {
            ($0.value, elementOrder($0.key)) < ($1.value, elementOrder($1.key))
        }?.key ?? .fire
        let plays = TeamReadTemplates.playLines[dominantElement] ?? []
        let play = plays.isEmpty
            ? "This week's play: one honest message each — short beats polished."
            : plays[(seed + members.count) % plays.count]

        return TeamRead(
            headline: headline(for: members, dominantElement: dominantElement),
            elementCounts: elementCounts,
            modalityCounts: modalityCounts,
            roles: roles,
            highlights: Array(highlights),
            frictionPair: frictionPair,
            bridge: bridge,
            play: play
        )
    }

    // MARK: - Composition helpers

    private static func headline(for members: [TeamReadMember], dominantElement: ZodiacElement) -> String {
        let flavor = TeamReadTemplates.elementFlavors[dominantElement] ?? "signal"
        return "A \(members.count)-person group running on \(flavor)"
    }

    private static func roleLine(for member: TeamReadMember) -> String {
        let modalityLine = TeamReadTemplates.modalityRoleLines[member.sun.modality] ?? "keeps the group connected"
        let elementFlavor = TeamReadTemplates.elementFlavors[member.sun.element] ?? "signal"
        return "\(member.sun.displayName) \(modalityLine) — brings the \(elementFlavor)."
    }

    private static func pairLine(_ a: String, _ b: String, aspect: WholeSignAspect, seed: Int) -> String {
        let lines = TeamReadTemplates.aspectPairLines[aspect.family] ?? []
        guard !lines.isEmpty else {
            return "\(a) and \(b) read each other through the \(aspect.displayName) lens."
        }
        return lines[(seed + a.count + b.count) % lines.count]
            .replacingOccurrences(of: "{a}", with: a)
            .replacingOccurrences(of: "{b}", with: b)
    }

    private static func bridgeLine(_ a: TeamReadMember, _ b: TeamReadMember, seed: Int) -> String {
        let key = bridgeKey(a.sun.element, b.sun.element)
        let lines = TeamReadTemplates.bridgeLines[key] ?? TeamReadTemplates.bridgeLines["default"] ?? []
        guard !lines.isEmpty else {
            return "Bridge it by letting \(a.name) open and \(b.name) close — different speeds, same goal."
        }
        return lines[seed % lines.count]
            .replacingOccurrences(of: "{a}", with: a.name)
            .replacingOccurrences(of: "{b}", with: b.name)
    }

    static func bridgeKey(_ a: ZodiacElement, _ b: ZodiacElement) -> String {
        [a.rawValue, b.rawValue].sorted().joined(separator: "+")
    }

    private static func elementOrder(_ element: ZodiacElement) -> Int {
        ZodiacElement.allCases.firstIndex(of: element) ?? 0
    }
}

nonisolated enum TeamReadTemplates {
    static let modalityRoles: [String: String] = [
        "cardinal": "Initiator",
        "fixed": "Anchor",
        "mutable": "Translator"
    ]

    static let modalityRoleLines: [String: String] = [
        "cardinal": "starts things the group didn't know it was waiting for",
        "fixed": "holds the group steady when everything else moves",
        "mutable": "translates between the people who'd otherwise miss each other"
    ]

    static let elementFlavors: [ZodiacElement: String] = [
        .fire: "energy",
        .earth: "structure",
        .air: "ideas",
        .water: "glue"
    ]

    /// `{a}`/`{b}` slots; keyed by WholeSignAspect.family.
    static let aspectPairLines: [String: [String]] = [
        "friction": [
            "{a} and {b} run on different clocks — squares read as urgency vs. process, not disrespect.",
            "{a} and {b} pull in opposite directions, which is friction until it's range. Name the difference out loud and it becomes the group's reach.",
            "When {a} and {b} clash, it's style, not loyalty — both want the same win by different roads."
        ],
        "flow": [
            "{a} and {b} shorthand each other — trines mean fewer words needed. Watch they don't accidentally exclude the room.",
            "{a} and {b} are the easy channel in this group — route the delicate messages through that line.",
            "Things move when {a} and {b} agree first — that pairing is the group's ignition."
        ],
        "emphasis": [
            "{a} and {b} share a lens — double strength, same blind spot. Pair one of them with a different element for big calls.",
            "{a} and {b} amplify each other — great for momentum, worth a third voice for balance."
        ]
    ]

    /// Keyed by TeamReadEngine.bridgeKey (sorted element pair) + "default".
    static let bridgeLines: [String: [String]] = [
        "earth+fire": [
            "Bridge it by splitting the message: let {a} open with the spark, {b} close with the plan.",
            "Give {a} the kickoff and {b} the follow-through — sequenced, they're unstoppable; simultaneous, they collide."
        ],
        "air+water": [
            "Bridge it by naming the feeling before debating the idea — {b} needs the first, {a} leads with the second.",
            "Let {a} put words to it and {b} check how it lands — both halves of the same message."
        ],
        "fire+water": [
            "Bridge it with timing: {a} wants it now, {b} wants it felt first. A one-beat pause fixes most of it.",
            "Heat plus depth: let {a} bring the push and {b} the read on whether the room is ready."
        ],
        "air+fire": [
            "Bridge it by giving the idea a deadline — {a} supplies the angle, {b} the launch.",
            "These two accelerate each other — the bridge is a finish line, not a referee."
        ],
        "earth+water": [
            "Bridge it gently — both build slowly. Agree on one small next step and let trust do the rest.",
            "Steady plus deep: the bridge is patience made explicit. Say the timeline out loud."
        ],
        "air+earth": [
            "Bridge it by writing it down — {a} thinks out loud, {b} trusts what's on paper.",
            "Idea meets execution: let {a} pitch in the morning and {b} respond after a day. Both versions improve."
        ],
        "default": [
            "Bridge it by splitting roles: one opens, one closes — different speeds, same goal."
        ]
    ]

    /// One actionable group tip, keyed by dominant element.
    static let playLines: [ZodiacElement: [String]] = [
        .fire: [
            "This week's play: point all that ignition at one shared goal — scattered fire is just heat.",
            "Play of the week: decide fast, then protect the decision for 48 hours before reopening it."
        ],
        .earth: [
            "This week's play: celebrate one finished thing out loud — this group ships quietly and forgets to say so.",
            "Play of the week: pick the one risk worth taking — all this stability can afford exactly one bold move."
        ],
        .air: [
            "This week's play: one written recap after decisions — this group generates ideas faster than it logs them.",
            "Play of the week: turn the best running joke into a real plan. The group's humor is smarter than it pretends."
        ],
        .water: [
            "This week's play: say the appreciation out loud instead of assuming it's felt — this group runs on it.",
            "Play of the week: one direct ask each — all that intuition works better with words attached."
        ]
    ]
}
