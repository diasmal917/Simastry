import Foundation
import UserNotifications

nonisolated final class NotificationService {
    var isAuthorized: Bool = false
    var isDenied: Bool = false

    private let engagementKey = "simastry_engagement_count"
    private let permissionRequestedKey = "simastry_notification_permission_requested"
    private let lastSessionEndKey = "simastry_last_session_end"

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

        let content = UNMutableNotificationContent()
        content.title = "Good morning ✦"
        let snippet = AstrologyTemplates.risingSign[risingSign] ?? "The stars have something for you today"
        content.body = "\(risingSign.capitalized) — \(snippet)"
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

        let content = UNMutableNotificationContent()
        content.title = companionName
        content.body = "How was your day? I have something to tell you. ✦"
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://chat"]

        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0
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

        let content = UNMutableNotificationContent()
        content.title = companionName
        content.body = "The stars shifted while you were away. Come see. ✦"
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://home"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 48 * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: "inactive_reengagement", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleSimulationReminder(companionName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["simulation_reminder"])

        let content = UNMutableNotificationContent()
        content.title = "The cosmos is ready"
        content.body = "Your simulation agents are waiting for a new question ✦"
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
