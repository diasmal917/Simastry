import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    var isAuthorized: Bool = false
    var isDenied: Bool = false

    private let permissionRequestedKey = "simastry_notification_permission_requested"
    static let dailyMorningNoteScheduleDays = 7
    static let legacyDailyMorningNoteIdentifier = "daily_morning_note"
    static let dailyMorningNoteIdentifiers = (0..<dailyMorningNoteScheduleDays).map { "daily_morning_note_\($0)" }

    struct DailyMorningNoteRequest {
        let identifier: String
        let expertName: String
        let body: String
        let fireDate: Date
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

    /// Requested only from an explicit user enable (the daily-note toggle), so
    /// the system prompt is always tied to a choice the user just made.
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

    /// A short queue of one-shot 8:30 morning notes in the user's chosen
    /// expert's voice. Each body is composed for its exact fire date, so the
    /// push keeps matching Today even when the app is not opened daily.
    func scheduleDailyMorningNotes(_ notes: [DailyMorningNoteRequest]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.legacyDailyMorningNoteIdentifier] + Self.dailyMorningNoteIdentifiers
        )

        let calendar = Calendar.current
        for note in notes {
            guard note.fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(note.expertName) · Morning note"
            content.body = note.body
            content.sound = .default
            content.userInfo = ["deeplink": "simastry://home"]

            var dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: note.fireDate)
            dateComponents.calendar = calendar
            dateComponents.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: note.identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }

    /// One-shot follow-up after a prediction: come back and rate the outcome.
    /// Privacy-safe — never references conversation content.
    func schedulePredictionOutcomeFollowUp(delayHours: Double = 22) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["prediction_outcome_followup"])

        let content = UNMutableNotificationContent()
        content.title = "How did it play out?"
        content.body = "Tap to log whether the read matched what happened."
        content.sound = .default
        content.userInfo = ["deeplink": "simastry://predict"]

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

    /// Clears every retired notification type — the manipulative legacy copy
    /// was deleted, but installs that scheduled it still carry pending requests.
    func cancelLegacyGuideAndCompanionNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "evening_checkin",
                "companion_hook",
                "inactive_reengagement",
                "simulation_reminder",
                "panel_daily_starter"
            ] + Self.guideTipIdentifiers
        )
    }

    func clearScheduledNotifications() {
        // Retired identifiers (daily_transit/brief/decider, evening_checkin, …)
        // stay listed so updating wipes anything an older build scheduled.
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                Self.legacyDailyMorningNoteIdentifier,
                "daily_transit",
                "daily_brief",
                "daily_decider",
                "evening_checkin",
                "companion_hook",
                "inactive_reengagement",
                "simulation_reminder",
                "panel_daily_starter",
                "prediction_outcome_followup",
                "sealed_draft_release"
            ] + Self.dailyMorningNoteIdentifiers + Self.guideTipIdentifiers
        )
    }
}
