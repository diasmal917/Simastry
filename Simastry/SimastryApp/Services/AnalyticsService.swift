import Foundation

/// Privacy-first analytics service.
/// Uses TelemetryDeck when available, falls back to local event logging.
/// No PII is ever collected. All events are anonymous.
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    // Event categories
    enum Event: String {
        // Onboarding
        case onboardingStarted = "onboarding_started"
        case onboardingSignsSelected = "onboarding_signs_selected"
        case onboardingInsightViewed = "onboarding_insight_viewed"
        case onboardingCompleted = "onboarding_completed"

        // Auth
        case signInApple = "sign_in_apple"
        case signInGoogle = "sign_in_google"
        case signInEmail = "sign_in_email"
        case signUpEmail = "sign_up_email"
        case signOut = "sign_out"

        // Core Features
        case predictionGenerated = "prediction_generated"
        case predictionShared = "prediction_shared"
        case companionCreated = "companion_created"
        case companionDeleted = "companion_deleted"
        case companionDetailViewed = "companion_detail_viewed"

        // First Read Activation
        case firstReadStarted = "first_read_started"
        case firstReadMessageEntered = "first_read_message_entered"
        case firstReadSignSelected = "first_read_sign_selected"
        case firstReadGeneratedTemplate = "first_read_generated_template"
        case firstReadGeneratedAI = "first_read_generated_ai"
        case firstReadFailed = "first_read_failed"
        case firstReadFallbackUsed = "first_read_fallback_used"
        case firstReadSaved = "first_read_saved"
        case firstReadContinueGuidesTapped = "first_read_continue_guides_tapped"
        case panelSeededFromFirstRead = "panel_seeded_from_first_read"
        case replyOptionCopied = "reply_option_copied"
        case replyOptionTuned = "reply_option_tuned"
        case guideFeedbackSubmitted = "guide_feedback_submitted"
        case firstReadHelpfulnessSubmitted = "first_read_helpfulness_submitted"

        // Guides
        case guideViewed = "guide_viewed"
        case guideSaved = "guide_saved"
        case guideShared = "guide_shared"
        case guideDeleted = "guide_deleted"

        // Engagement
        case didYouKnowViewed = "did_you_know_viewed"
        case didYouKnowTapped = "did_you_know_tapped"
        case communicationGuideViewed = "communication_guide_viewed"
        case compatibilityBreakdownViewed = "compatibility_breakdown_viewed"

        // Monetization
        case upsellShown = "upsell_shown"
        case upsellDismissed = "upsell_dismissed"
        case subscriptionStarted = "subscription_started"
        case subscriptionRestored = "subscription_restored"

        // Navigation
        case tabSwitched = "tab_switched"
        case methodologyViewed = "methodology_viewed"
        case astrologerPartnerViewed = "astrologer_partner_viewed"

        // Retention
        case appOpened = "app_opened"
        case sessionDuration = "session_duration"
        case widgetTapped = "widget_tapped"
        case deepLinkOpened = "deep_link_opened"
        case notificationTapped = "notification_tapped"
    }

    private var sessionStart: Date = Date()
    private var eventLog: [(event: String, params: [String: String], timestamp: Date)] = []

    private init() {
        sessionStart = Date()
    }

    /// Track an event with optional parameters. No PII is ever included.
    func track(_ event: Event, params: [String: String] = [:]) {
        // Log locally for debugging
        let entry = (event: event.rawValue, params: params, timestamp: Date())
        eventLog.append(entry)

        #if DEBUG
        print("[Analytics] \(event.rawValue) \(params.isEmpty ? "" : params.description)")
        #endif

        // TelemetryDeck integration point:
        // When TelemetryDeck SDK is added, uncomment:
        // TelemetryDeck.signal(event.rawValue, parameters: params)
    }

    /// Track with a single key-value parameter
    func track(_ event: Event, key: String, value: String) {
        track(event, params: [key: value])
    }

    /// Call on app going to background to log session duration
    func endSession() {
        let duration = Date().timeIntervalSince(sessionStart)
        let minutes = Int(duration / 60)
        track(.sessionDuration, key: "minutes", value: "\(minutes)")
    }

    /// Get recent event counts for AI summary
    func getEventSummary() -> [String: Int] {
        var counts: [String: Int] = [:]
        for entry in eventLog {
            counts[entry.event, default: 0] += 1
        }
        return counts
    }

    /// Clear local log (after summary is exported)
    func clearLog() {
        eventLog.removeAll()
    }
}
