import AppIntents
import Foundation

enum SimastryShortcutDestination: String, CaseIterable, AppEnum {
    case today
    case predict
    case messages
    case nadia

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Simastry Destination"

    static var caseDisplayRepresentations: [SimastryShortcutDestination: DisplayRepresentation] = [
        .today: "Today",
        .predict: "Predict",
        .messages: "Messages",
        .nadia: "Nadia"
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
        case .today: "Today"
        case .predict: "Predict"
        case .messages: "Messages"
        case .nadia: "Nadia"
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
            intent: OpenSimastryDestinationIntent(destination: .nadia),
            phrases: [
                "Ask Nadia in \(.applicationName)",
                "Open Nadia in \(.applicationName)"
            ],
            shortTitle: "Ask Nadia",
            systemImageName: "person.wave.2.fill"
        )
    }
}
