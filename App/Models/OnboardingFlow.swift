import Foundation

// MARK: - Onboarding goal

/// The one thing a new user wants help with right now. Chosen on the first
/// setup screen and used to land them inside a real product capability —
/// never a completion page. Raw values are persisted; do not rename.
nonisolated enum OnboardingGoal: String, CaseIterable, Codable, Identifiable, Sendable {
    case prepareConversation = "prepare_conversation"
    case understandSomeone = "understand_someone"
    case decodeMessage = "decode_message"
    case clarityToday = "clarity_today"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prepareConversation: "Prepare for a conversation"
        case .understandSomeone: "Understand someone"
        case .decodeMessage: "Decode a message"
        case .clarityToday: "Get clarity for today"
        }
    }

    var subtitle: String {
        switch self {
        case .prepareConversation: "Practice what you want to say."
        case .understandSomeone: "See how your communication styles meet."
        case .decodeMessage: "Explore tone, subtext, and possible replies."
        case .clarityToday: "See your personal Compass."
        }
    }

    var systemImage: String {
        switch self {
        case .prepareConversation: "theatermasks.fill"
        case .understandSomeone: "person.2.fill"
        case .decodeMessage: "text.magnifyingglass"
        case .clarityToday: "location.north.circle.fill"
        }
    }

    /// Person-centered goals ask "Who is this about?" before entering the
    /// product; the other goals go straight in.
    var involvesAPerson: Bool {
        switch self {
        case .prepareConversation, .understandSomeone: true
        case .decodeMessage, .clarityToday: false
        }
    }
}

// MARK: - Support style

/// How the companion should support the user, chosen once during setup and
/// mapped onto the existing calibration dimensions (tone, directness,
/// length). A presentation preference — never an intimacy mechanic.
nonisolated enum OnboardingSupportStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case tellMeStraight = "tell_me_straight"
    case thinkItThrough = "think_it_through"
    case findTheWords = "find_the_words"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tellMeStraight: "Tell me straight"
        case .thinkItThrough: "Help me think it through"
        case .findTheWords: "Help me find the words"
        }
    }

    var subtitle: String {
        switch self {
        case .tellMeStraight: "Clear, concise, and candid."
        case .thinkItThrough: "Calm context before conclusions."
        case .findTheWords: "Practical language I can actually use."
        }
    }

    var systemImage: String {
        switch self {
        case .tellMeStraight: "arrow.right.circle.fill"
        case .thinkItThrough: "lightbulb.fill"
        case .findTheWords: "text.quote"
        }
    }

    /// Seeds the chosen companion's support preferences. The user can change
    /// every dimension later in the companion's support sheet.
    var seededPreferences: CompanionSupportPreferences {
        switch self {
        case .tellMeStraight:
            CompanionSupportPreferences(tone: .candid, directness: .direct, length: .concise)
        case .thinkItThrough:
            CompanionSupportPreferences(tone: .steady, directness: .balanced, length: .medium)
        case .findTheWords:
            CompanionSupportPreferences(tone: .warm, directness: .balanced, length: .medium)
        }
    }
}

// MARK: - Persisted progress

/// Everything needed to resume an interrupted setup. Stored as JSON in
/// UserDefaults; cleared when the first task launches (or on sign-out /
/// account deletion). Never contains birth data — the chart pipeline keeps
/// its own staged storage.
nonisolated struct OnboardingProgress: Codable, Equatable, Sendable {
    enum Stage: String, Codable, Sendable {
        case goal
        case chart
        case supportStyle
        case companion
        case person
        case account
    }

    var goal: OnboardingGoal?
    var supportStyle: OnboardingSupportStyle?
    var chartDecided: Bool = false
    var companionChosen: Bool = false
    var personId: UUID?
    var personDecided: Bool = false

    var hasStarted: Bool {
        goal != nil
    }

    /// The step the flow should resume at.
    var resumeStage: Stage {
        guard goal != nil else { return .goal }
        if !chartDecided { return .chart }
        if supportStyle == nil { return .supportStyle }
        if !companionChosen { return .companion }
        if goal?.involvesAPerson == true && !personDecided { return .person }
        return .account
    }
}

nonisolated enum OnboardingProgressStore {
    static let defaultsKey = "simastry_onboarding_progress_v1"

    static func load(defaults: UserDefaults = .standard) -> OnboardingProgress {
        guard let data = defaults.data(forKey: defaultsKey),
              let progress = try? JSONDecoder().decode(OnboardingProgress.self, from: data) else {
            return OnboardingProgress()
        }
        return progress
    }

    static func save(_ progress: OnboardingProgress, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey)
    }
}

// MARK: - Companion presentation

/// Onboarding-only presentation copy for the four certified companions.
/// The registry's own metadata (names, promises, portraits) stays canonical;
/// these anchors, "best when" lines, and sample replies exist so the choice
/// screen can show a voice, not a stat sheet.
nonisolated struct CompanionOnboardingPresentation: Sendable {
    let personaID: CompanionPersonaID
    /// The certified personality anchor, e.g. "Courage, without recklessness."
    let anchor: String
    let bestWhen: String
    let sampleResponse: String

    static func presentation(for id: CompanionPersonaID) -> CompanionOnboardingPresentation? {
        all.first { $0.personaID == id }
    }

    static let all: [CompanionOnboardingPresentation] = [
        CompanionOnboardingPresentation(
            personaID: .amara,
            anchor: "Courage, without recklessness.",
            bestWhen: "Best when you keep rehearsing a conversation instead of having it.",
            sampleResponse: "You don't need the perfect opener. You need one honest sentence you can stand behind. Let's write it."
        ),
        CompanionOnboardingPresentation(
            personaID: .theo,
            anchor: "Calm clarity, without passivity.",
            bestWhen: "Best when everything feels urgent and you can't tell what actually matters.",
            sampleResponse: "Before you reply, separate what happened from what you're afraid it means. Then we answer only the first part."
        ),
        CompanionOnboardingPresentation(
            personaID: .isolde,
            anchor: "Tactful fairness and firm boundaries.",
            bestWhen: "Best when you want to hold your ground without burning the bridge.",
            sampleResponse: "You can be generous about their reasons and still say no. Here's a version that does both."
        ),
        CompanionOnboardingPresentation(
            personaID: .zev,
            anchor: "Emotional translation, without mind-reading.",
            bestWhen: "Best when a message left you with a feeling you can't quite name.",
            sampleResponse: "We can't know what they meant — only what was said. Let's name what it stirred in you, then decide what to ask."
        ),
    ]
}
