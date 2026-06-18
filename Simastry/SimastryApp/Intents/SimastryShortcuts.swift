import AppIntents

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

// MARK: - Check Compatibility Shortcut
struct CheckCompatibilityIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Compatibility"
    static var description = IntentDescription("Check your compatibility with a companion")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Companion Name")
    var companionName: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Open app to companions tab
        return .result(dialog: "Opening Simastry to check your compatibility...")
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
        return .result(dialog: "\(signals[index])")
    }
}

// MARK: - App Shortcuts Provider
struct SimastryShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckCompatibilityIntent(),
            phrases: [
                "Check compatibility in \(.applicationName)",
                "Show my compatibility in \(.applicationName)",
                "Open \(.applicationName) companions"
            ],
            shortTitle: "Check Compatibility",
            systemImageName: "heart.circle"
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
    }
}
