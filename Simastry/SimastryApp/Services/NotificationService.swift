import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    var isAuthorized: Bool = false
    var isDenied: Bool = false

    private let engagementKey = "simastry_engagement_count"
    private let permissionRequestedKey = "simastry_notification_permission_requested"
    private let lastSessionEndKey = "simastry_last_session_end"

    private let eveningMessages: [(title: String, body: String)] = [
        ("quick check-in", "hey, how did things go with %@ today? come tell me about it 👀"),
        ("hey", "your energy's been off today — I have a theory why. come check"),
        ("quick check-in", "random thought: you and %@ might actually vibe better this week. wanna see why?"),
        ("hey", "that awkward thing that happened today? yeah, the stars saw it coming 😅"),
        ("quick check-in", "you've been in your head today — that happens when the moon hits air signs. I've got something that might help"),
        ("hey", "psst — I know something about tomorrow you might want to hear"),
        ("quick check-in", "not to be dramatic but today was kind of a big deal for you and %@"),
        ("hey", "before you go to sleep — there's something you should know about tomorrow"),
        ("quick check-in", "ok so I noticed something between you and %@ today — your elements were working overtime. come see"),
        ("hey", "real talk: today was harder than it needed to be. planetary tension does that — I can explain"),
    ]

    private let reEngagementMessages: [(title: String, body: String)] = [
        ("still here 👋", "so... you've been ghosting me. bold move for a %@ 😏"),
        ("still here 👋", "your cosmic compatibility just shifted. thought you'd want to know"),
        ("hey stranger", "someone in your circle is going through it right now. I can tell you who"),
        ("still here 👋", "I've been holding onto a prediction for you. it's getting stale"),
        ("hey stranger", "things moved while you were gone. you might want to catch up"),
        ("still here 👋", "not gonna lie, I missed you. also your chart looks interesting rn"),
        ("hey stranger", "a lot changed this week. just saying"),
        ("still here 👋", "you're missing out on something good. no pressure though"),
    ]

    private let simulationMessages: [(title: String, body: String)] = [
        ("just saying...", "that convo you've been overthinking? I can tell you how it'll go"),
        ("just saying...", "wondering what they're going to text? I might know 👀"),
        ("hear me out", "you know that thing you want to say but haven't? let's practice"),
        ("just saying...", "hot take: you should probably text them first. here's how"),
        ("hear me out", "before you send that text — let me tell you how they'll react"),
        ("just saying...", "I know you're composing something in your head rn. let me help"),
        ("hear me out", "that conversation you keep replaying? I can show you a better version"),
        ("just saying...", "you're overthinking it. come run it by me first"),
    ]

    private let transitMessages: [String] = [
        "heads up — today's energy is a little chaotic. don't make big decisions before lunch",
        "good day to have that conversation you've been avoiding — the energy supports honesty right now",
        "your patience might be tested today — that's normal when the moon shifts elements, just ride it out",
        "creative energy is high today — say yes to things",
        "today's vibe: keep it low-key. no drama needed",
        "something unexpected might come up today. roll with it",
        "you might feel extra emotional today — water energy is strong, which means feelings hit harder than usual",
        "great day for reconnecting with someone you haven't talked to in a while",
        "today's a good day to trust your gut — your intuitive side is dialed up because the moon is in a water sign",
        "fair warning: you might say something you don't mean today. think before you text",
    ]

    var engagementCount: Int {
        get { UserDefaults.standard.integer(forKey: engagementKey) }
        set { UserDefaults.standard.set(newValue, forKey: engagementKey) }
    }

    var hasRequestedFullPermission: Bool {
        get { UserDefaults.standard.bool(forKey: permissionRequestedKey) }
        set { UserDefaults.standard.set(newValue, forKey: permissionRequestedKey) }
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        isDenied = settings.authorizationStatus == .denied
    }

    func requestProvisionalPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
            isAuthorized = granted
        } catch {
            // silent
        }
    }

    func requestFullPermission() async {
        guard !hasRequestedFullPermission, !isDenied else { return }
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            isDenied = !granted
            hasRequestedFullPermission = true
        } catch {
            isDenied = true
            hasRequestedFullPermission = true
        }
    }

    func trackEngagement() async {
        engagementCount += 1
        if engagementCount >= 3, !hasRequestedFullPermission, !isDenied {
            await requestFullPermission()
        }
    }

    func scheduleDailyTransit(risingSign: String, tier: String) {
        guard tier == "plus" || tier == "pro" else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_transit"])

        let body = transitMessages.randomElement() ?? transitMessages[0]

        let content = UNMutableNotificationContent()
        content.title = ["heads up", "daily vibe", "for today"].randomElement() ?? "heads up"
        content.body = body
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://guides"]

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "daily_transit", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleEveningCheckIn(companionName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["evening_checkin"])

        let message = eveningMessages.randomElement() ?? eveningMessages[0]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = String(format: message.body, companionName)
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://home"]

        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 15
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "evening_checkin", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleCompanionHook(companionName: String, delayHours: Double = 4) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["companion_hook"])

        let content = UNMutableNotificationContent()
        content.title = companionName
        content.body = "I've been thinking about what you said ✦"
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://chat"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delayHours * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: "companion_hook", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleInactiveReEngagement(companionName: String, userSign: String = "") {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["inactive_reengagement"])

        let message = reEngagementMessages.randomElement() ?? reEngagementMessages[0]
        let signLabel = userSign.isEmpty ? "you" : userSign

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = String(format: message.body, signLabel)
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://home"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 48 * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: "inactive_reengagement", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleSimulationReminder(companionName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["simulation_reminder"])

        let message = simulationMessages.randomElement() ?? simulationMessages[0]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://simulate"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 72 * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: "simulation_reminder", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleDiscoveryMessageAlert(senderName: String, preview: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(senderName) sent you a message"
        content.body = preview
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://messages"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "discovery_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelInactiveReEngagement() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["inactive_reengagement"])
    }

    func cancelEveningCheckIn() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["evening_checkin"])
    }

    func clearScheduledNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "daily_transit",
                "evening_checkin",
                "companion_hook",
                "inactive_reengagement",
                "simulation_reminder"
            ]
        )
    }

    func scheduleUsageLimitReminder(remaining: Int, type: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = type == "messages" ? "Messages running low" : "Predictions running low"
        content.body = "You have \(remaining) \(type) left. Upgrade for unlimited access."
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://upsell"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "low_\(type)", content: content, trigger: trigger)
        center.add(request)
    }
}
