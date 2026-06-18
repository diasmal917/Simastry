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
        ("quick check-in", "Want a private chart-signal read before you reply?"),
        ("hey", "Your Moon pattern may need a softer answer tonight."),
        ("quick check-in", "A small timing shift could change the tone of your next message."),
        ("hey", "Before you text back, reread theirs once — tone first, content second."),
        ("quick check-in", "Your chart lens has a note about emotional pacing today."),
        ("hey", "A short pause might help your reply land better."),
        ("quick check-in", "There may be timing pressure in the conversation. Want to read it?"),
        ("hey", "Before bed, save the message you almost sent and check the tone."),
        ("quick check-in", "Your element pattern may explain why this felt louder than it was."),
        ("hey", "End-of-day reset: one placement read can shrink today before tomorrow."),
    ]

    private let reEngagementMessages: [(title: String, body: String)] = [
        ("still here", "Your %@ lens may need a cleaner read before the next conversation."),
        ("still here", "A chart-signal check-in is waiting when you want it."),
        ("hey stranger", "A saved conversation lens may help you re-enter gently."),
        ("still here", "You have a message thread ready when you want to talk it through."),
        ("hey stranger", "A lot can shift in tone after a few days away."),
        ("still here", "Your chart context is still here when you want to talk it through."),
        ("hey stranger", "This week may be worth reviewing through timing pressure."),
        ("still here", "No pressure. Just a clean place to think before you text."),
    ]

    private let simulationMessages: [(title: String, body: String)] = [
        ("just saying...", "that convo you've been overthinking? let's make the next message cleaner"),
        ("just saying...", "wondering how to answer? your chart lens can help"),
        ("hear me out", "you know that thing you want to say but haven't? let's practice"),
        ("just saying...", "hot take: you should probably text them first. here's how"),
        ("hear me out", "before you send that text — let's check the tone"),
        ("just saying...", "I know you're composing something in your head rn. let me help"),
        ("hear me out", "that conversation you keep replaying? let's find the better version"),
        ("just saying...", "you're overthinking it. come run it by me first"),
    ]

    private let transitMessages: [String] = [
        "heads up — today's chart signal favors a pause before big decisions",
        "good day to have the conversation you've been avoiding, if the tone stays honest",
        "your patience might be tested today; take a breath before replying",
        "creative fire is stronger today — useful for brave but kind messages",
        "today's timing favors low drama and clean wording",
        "something unexpected might change the tone; give yourself room to respond",
        "water emphasis can make feelings hit harder than usual",
        "a good day for reconnecting if the message stays simple",
        "trust your first instinct, then check whether the tone is fair",
        "you might speak faster than you mean to today. Think before you text",
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

    func scheduleDailyTransit(risingSign: String, tier: String, readingBody: String? = nil) {
        guard tier == "plus" || tier == "pro" else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_transit"])

        // Prefer the real computed transit read; fall back to generic copy.
        let body = readingBody ?? transitMessages.randomElement() ?? transitMessages[0]

        let content = UNMutableNotificationContent()
        content.title = ["heads up", "chart note", "for today"].randomElement() ?? "heads up"
        content.body = body
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://home"]

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "daily_transit", content: content, trigger: trigger)
        center.add(request)
    }

    /// One-shot follow-up after a prediction: come back and rate the outcome.
    /// Privacy-safe — never references conversation content.
    func schedulePredictionOutcomeFollowUp(delayHours: Double = 22) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["prediction_outcome_followup"])

        let content = UNMutableNotificationContent()
        content.title = "Your panel is curious"
        content.body = "Did they reply like the panel said? Tap to log it."
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://simulate"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delayHours * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: "prediction_outcome_followup", content: content, trigger: trigger)
        center.add(request)
    }

    func cancelPredictionOutcomeFollowUp() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["prediction_outcome_followup"])
    }

    /// Daily nudge that the panel posted its conversation starter.
    /// Privacy-safe: names the guide and the focus lens, never message content.
    func schedulePanelStarter(guideName: String, focusName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["panel_daily_starter"])

        let content = UNMutableNotificationContent()
        content.title = "Your panel"
        content.body = "\(guideName) opened today's \(focusName) read for your panel."
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://panel"]

        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "panel_daily_starter", content: content, trigger: trigger)
        center.add(request)
    }

    /// Daily communication brief. Content is built from the user's own chart
    /// signals only — no names, no message content — so previews stay private.
    func scheduleDailyBrief(focusName: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_brief"])

        let content = UNMutableNotificationContent()
        content.title = "Daily brief · \(focusName) focus"
        content.body = body
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://home"]

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "daily_brief", content: content, trigger: trigger)
        center.add(request)
    }

    /// Evening nudge with the day's Tips-row headline, attributed to its
    /// guide ("New tip from Theo"). Scheduled as individual fires for the
    /// next several evenings so each notification matches that day's
    /// rotation even if the app stays closed. Privacy-safe: lesson titles
    /// only, never user content.
    func scheduleGuideTipNudges(days: Int = 5) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.guideTipIdentifiers)

        let calendar = Calendar.current
        for offset in 0..<min(days, Self.guideTipIdentifiers.count) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: Date()) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = 18
            components.minute = 0
            guard let fireDate = calendar.date(from: components), fireDate > Date() else { continue }

            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: day) ?? 1
            guard let tip = AstrologyTemplates.dailyGuideTips(dayOfYear: dayOfYear).first,
                  let guide = FactoryCompanionCatalog.all.first(where: { $0.id == tip.guideId }) else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "New tip from \(guide.name)"
            content.body = tip.title
            content.sound = .default
            content.userInfo = ["deeplink": "simastry://home"]

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "guide_tip_\(offset)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    static let guideTipIdentifiers = (0..<7).map { "guide_tip_\($0)" }

    /// One-shot morning nudge when a sealed draft unseals. Privacy-safe:
    /// never includes the draft text.
    func scheduleSealedDraftRelease(at releaseAt: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["sealed_draft_release"])

        let content = UNMutableNotificationContent()
        content.title = "Morning eyes"
        content.body = "Your sealed draft is ready to reread. Still true in daylight?"
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://home"]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: releaseAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: "sealed_draft_release", content: content, trigger: trigger))
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
        content.title = "Simastry"
        content.body = "A private companion note is waiting."
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
        content.title = "New Simastry message"
        content.body = "Open Simastry to read it privately."
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
                "daily_brief",
                "evening_checkin",
                "companion_hook",
                "inactive_reengagement",
                "simulation_reminder",
                "panel_daily_starter",
                "prediction_outcome_followup",
                "sealed_draft_release"
            ] + Self.guideTipIdentifiers
        )
    }

    func scheduleUsageLimitReminder(remaining: Int, type: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Messages running low"
        content.body = "You have \(remaining) \(type) left. Upgrade for unlimited access."
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://upsell"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "low_\(type)", content: content, trigger: trigger)
        center.add(request)
    }
}
