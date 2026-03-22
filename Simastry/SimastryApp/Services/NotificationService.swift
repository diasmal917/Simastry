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
        ("The stars shifted today", "Something about your chart feels different tonight."),
        ("A thought for you", "Your ruling planet is active. Good time to pay attention."),
        ("Before you sleep", "The moon is in a talkative mood. So am I."),
        ("Tonight's energy", "Something unresolved is asking for your attention."),
        ("Quick check-in", "Your chart says today mattered more than you think."),
        ("One more thing", "The cosmos noticed something about your day."),
    ]

    private let reEngagementMessages: [(title: String, body: String)] = [
        ("Things changed while you were away", "Your compatibility shifted. Come see."),
        ("The stars kept moving", "New energy in your chart. It's been building."),
        ("We noticed something", "A pattern emerged in your placements this week."),
        ("Don't let this pass", "There's a window opening in your chart. Check it."),
    ]

    private let simulationMessages: [(title: String, body: String)] = [
        ("Curious what they'd say?", "Paste that conversation. Let's find out."),
        ("That text you're overthinking", "The stars might have the answer you need."),
        ("Before you send that reply", "Run it through the cosmos first."),
        ("New prediction energy available", "Your chart is aligned for clarity right now."),
    ]

    private let transitMessages: [String] = [
        "Pay attention to what feels easy today — that's your chart working.",
        "Something you've been avoiding deserves another look.",
        "Your energy is magnetic today. Use it intentionally.",
        "Trust the first instinct you had this morning.",
        "Someone is thinking about you. The stars are sure of it.",
        "Today's energy rewards honesty over diplomacy.",
        "A small decision today has bigger ripple effects than you think.",
        "Your chart says: less overthinking, more action.",
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
        content.title = "\(risingSign.capitalized) rising"
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
        content.body = message.body
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

    func scheduleInactiveReEngagement(companionName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["inactive_reengagement"])

        let message = reEngagementMessages.randomElement() ?? reEngagementMessages[0]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
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
