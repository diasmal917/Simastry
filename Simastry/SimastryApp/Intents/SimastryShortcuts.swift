import AppIntents

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
    var signName: String

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

        let tip = tips[signName.lowercased()] ?? "Open Simastry for personalized communication guides."
        return .result(dialog: "\(tip)")
    }
}

// MARK: - Daily Vibe Shortcut
struct DailyVibeIntent: AppIntent {
    static var title: LocalizedStringResource = "Daily Vibe Check"
    static var description = IntentDescription("Get your daily vibe from Simastry")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let vibes = [
            "Good energy today — lean into conversations",
            "Keep it low-key. Save the big talks for tomorrow",
            "Creative energy is high — say yes to things",
            "Your patience might be tested. Deep breaths",
            "Great day for reconnecting with someone",
            "Something unexpected might come up. Roll with it",
            "Good day to have that conversation you've been avoiding"
        ]
        let index = Calendar.current.component(.hour, from: Date()) % vibes.count
        return .result(dialog: "\(vibes[index])")
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
                "\(.applicationName) guide for \(\.$signName)"
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
