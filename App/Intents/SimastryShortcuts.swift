import AppIntents
import Foundation

enum SimastryShortcutDestination: String, CaseIterable, AppEnum {
    case today
    case predict
    case simulate
    case messages
    case expertAstrologers

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Simastry Destination"

    static var caseDisplayRepresentations: [SimastryShortcutDestination: DisplayRepresentation] = [
        .today: "Home",
        .predict: "Compass",
        .simulate: "Simulate",
        .messages: "Messages",
        .expertAstrologers: "Expert Astrologers"
    ]
}

enum ZodiacSignShortcutOption: String, CaseIterable, AppEnum {
    case aries
    case taurus
    case gemini
    case cancer
    case leo
    case virgo
    case libra
    case scorpio
    case sagittarius
    case capricorn
    case aquarius
    case pisces

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Zodiac Sign"

    static var caseDisplayRepresentations: [ZodiacSignShortcutOption: DisplayRepresentation] = [
        .aries: "Aries",
        .taurus: "Taurus",
        .gemini: "Gemini",
        .cancer: "Cancer",
        .leo: "Leo",
        .virgo: "Virgo",
        .libra: "Libra",
        .scorpio: "Scorpio",
        .sagittarius: "Sagittarius",
        .capricorn: "Capricorn",
        .aquarius: "Aquarius",
        .pisces: "Pisces"
    ]
}

// MARK: - Open Simastry Shortcut
struct OpenSimastryDestinationIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Simastry"
    static var description = IntentDescription("Open a specific Simastry surface")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Destination")
    var destination: SimastryShortcutDestination

    init() {
        destination = .today
    }

    init(destination: SimastryShortcutDestination) {
        self.destination = destination
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(destination.rawValue, forKey: AppViewModel.shortcutDestinationKey)
        return .result(dialog: "Opening \(destinationDisplayName)...")
    }

    private var destinationDisplayName: String {
        switch destination {
        case .today: "Home"
        case .predict: "Compass"
        case .simulate: "Simulate"
        case .messages: "Messages"
        case .expertAstrologers: "Expert Astrologers"
        }
    }
}

// MARK: - Get Communication Tip Shortcut
struct GetCommunicationTipIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Communication Tip"
    static var description = IntentDescription("Get a quick communication tip for a zodiac sign")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Zodiac Sign")
    var signName: ZodiacSignShortcutOption

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tips: [String: String] = [
            "aries": "Be direct and get to the point. Aries respects honesty over diplomacy.",
            "taurus": "Be patient and don't rush them. Give them time to process before expecting a response.",
            "gemini": "Keep it interesting. Match their energy and don't be afraid to jump between topics.",
            "cancer": "Be emotionally aware. They read between every line, so be intentional with your tone.",
            "leo": "Show genuine appreciation. They need to feel valued, not just acknowledged.",
            "virgo": "Be specific and organized. Vague requests frustrate them.",
            "libra": "Be fair and balanced. Present both sides and let them weigh in.",
            "scorpio": "Be authentic. They can sense inauthenticity instantly.",
            "sagittarius": "Keep it light and adventurous. Don't box them in with rigid plans.",
            "capricorn": "Respect their time. Get to the point and show you've thought things through.",
            "aquarius": "Lead with ideas, not emotions. They process intellectually first.",
            "pisces": "Be gentle with your tone. They absorb emotional energy from your words."
        ]

        let tip = tips[signName.rawValue] ?? "Open Simastry for personalized communication signals."
        return .result(dialog: "\(tip)")
    }
}

// MARK: - Daily Signal Shortcut
struct DailyVibeIntent: AppIntent {
    static var title: LocalizedStringResource = "Daily Signal Check"
    static var description = IntentDescription("Get your daily chart signal from Simastry")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let signals = [
            "Today's chart signal favors clear, direct conversations",
            "Keep it low-key. Save the big talks for tomorrow",
            "Creative fire is high — useful for brave but kind messages",
            "Your patience might be tested. Deep breaths",
            "Great day for reconnecting with someone",
            "Something unexpected might change the tone. Leave room to respond",
            "Good day to have the conversation you've been avoiding if you keep the tone honest"
        ]
        let index = Calendar.current.component(.hour, from: Date()) % signals.count
        UserDefaults.standard.set(SimastryShortcutDestination.today.rawValue, forKey: AppViewModel.shortcutDestinationKey)
        return .result(dialog: "\(signals[index])")
    }
}

// MARK: - Quick Bearing Shortcut

enum CompassBearingShortcutOption: String, CaseIterable, AppEnum {
    case work
    case love
    case money
    case timing

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Compass Bearing"

    static var caseDisplayRepresentations: [CompassBearingShortcutOption: DisplayRepresentation] = [
        .work: "Work",
        .love: "Love",
        .money: "Money",
        .timing: "Today’s timing"
    ]
}

extension CompassBearingShortcutOption {
    /// The draft the matching in-app bearing card arms. Intent/topic, the
    /// question salt, and the preview bank must stay in lockstep with
    /// `SimulateView.compassBearingItems` so a Siri-armed read shows exactly
    /// the question the card on screen shows that day.
    var draftIntent: CompassIntent {
        self == .timing ? .timing : .general
    }

    var draftTopic: CompassTopic? {
        switch self {
        case .work: .work
        case .love: .relationships
        case .money: .money
        case .timing: nil
        }
    }

    var questionSalt: Int {
        switch self {
        case .work: 0
        case .love: 1
        case .money: 2
        case .timing: 3
        }
    }

    var questionBank: FutureQuestionCategory? {
        self == .love ? .loveTiming : nil
    }

    var spokenName: String {
        switch self {
        case .work: "work"
        case .love: "love"
        case .money: "money"
        case .timing: "timing"
        }
    }
}

struct QuickBearingIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Bearing"
    static var description = IntentDescription("Open Compass with a one-tap read prefilled — you confirm before it spends a reading")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Bearing")
    var bearing: CompassBearingShortcutOption

    init() {
        bearing = .work
    }

    init(bearing: CompassBearingShortcutOption) {
        self.bearing = bearing
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Route to Compass and stage the bearing; SimulateView arms it —
        // prefill + expand only. A background intent must never call
        // `beginSubmission` itself: that would silently spend a weekly
        // credit on a question the user never saw.
        UserDefaults.standard.set(SimastryShortcutDestination.predict.rawValue, forKey: AppViewModel.shortcutDestinationKey)
        UserDefaults.standard.set(bearing.rawValue, forKey: AppViewModel.pendingBearingKey)
        return .result(dialog: "Setting up your \(bearing.spokenName) read — confirm it in Compass.")
    }
}

// MARK: - Current Window Shortcut

struct CurrentWindowIntent: AppIntent {
    static var title: LocalizedStringResource = "Current Window"
    static var description = IntentDescription("The window Compass finds in today's sky — read from the last computed set, no reading spent")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Re-reads the pre-composed widget payload only: zero network, zero
        // credits, no ephemeris work — the same contract the widget has.
        let line = Self.dialLine(windows: SharedDefaults.readDayWindows(), now: Date())
        return .result(dialog: "\(line)")
    }

    /// The Now dial's line, recomposed from the shared payload. Scope stays
    /// "today only": a gap falls forward to today's next window, never to
    /// tomorrow's, and an empty or expired payload gets the widget's honest
    /// fallback instead of an invented answer.
    static func dialLine(windows: [SharedDayWindow], now: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        if let active = windows.first(where: { $0.startsAt <= now && now < $0.endsAt }) {
            return "\(active.title) — until \(formatter.string(from: active.endsAt))."
        }

        if let next = windows
            .filter({ $0.startsAt > now && calendar.isDate($0.startsAt, inSameDayAs: now) })
            .min(by: { $0.startsAt < $1.startsAt }) {
            return "Between windows right now. Next: \(next.title), from \(formatter.string(from: next.startsAt))."
        }

        return "Open Simastry to compute today's windows."
    }
}

// MARK: - App Shortcuts Provider
struct SimastryShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenSimastryDestinationIntent(),
            phrases: [
                "Open \(\.$destination) in \(.applicationName)",
                "Show \(\.$destination) in \(.applicationName)",
                "\(.applicationName) \(\.$destination)"
            ],
            shortTitle: "Open Simastry",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: GetCommunicationTipIntent(),
            phrases: [
                "How should I talk to a \(\.$signName) in \(.applicationName)",
                "Communication tip for \(\.$signName) from \(.applicationName)",
                "\(.applicationName) communication lens for \(\.$signName)"
            ],
            shortTitle: "Communication Tip",
            systemImageName: "bubble.left.and.text.bubble.right"
        )
        AppShortcut(
            intent: DailyVibeIntent(),
            phrases: [
                "What's my vibe today in \(.applicationName)",
                "Daily vibe from \(.applicationName)",
                "\(.applicationName) daily check"
            ],
            shortTitle: "Daily Vibe",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: OpenSimastryDestinationIntent(destination: .expertAstrologers),
            phrases: [
                "Ask Expert Astrologers in \(.applicationName)",
                "Open Expert Astrologers in \(.applicationName)"
            ],
            shortTitle: "Expert Astrologers",
            systemImageName: "person.wave.2.fill"
        )
        AppShortcut(
            intent: QuickBearingIntent(),
            phrases: [
                "Quick \(\.$bearing) read in \(.applicationName)",
                "Run a \(\.$bearing) read in \(.applicationName)",
                "\(.applicationName) \(\.$bearing) bearing"
            ],
            shortTitle: "Quick Bearing",
            systemImageName: "location.north.circle.fill"
        )
        AppShortcut(
            intent: CurrentWindowIntent(),
            phrases: [
                "What's the current window in \(.applicationName)",
                "What does right now favor in \(.applicationName)",
                "\(.applicationName) current window"
            ],
            shortTitle: "Current Window",
            systemImageName: "clock.badge.checkmark"
        )
    }
}
