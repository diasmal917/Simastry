import Foundation

/// Crash reporting service.
/// Placeholder for integration with Sentry, Firebase Crashlytics, or similar.
/// To integrate:
/// 1. Add the SDK via SPM (e.g., sentry-cocoa or firebase-ios-sdk)
/// 2. Call CrashReporter.configure() in SimastryApp.init()
/// 3. Use CrashReporter.log() for non-fatal errors
final class CrashReporter {

    /// Call once at app launch to initialize crash reporting
    static func configure() {
        // Integration point for crash reporting SDK
        // Sentry: SentrySDK.start { options in ... }
        // Firebase: FirebaseApp.configure(); Crashlytics.crashlytics()
        #if DEBUG
        print("[CrashReporter] Initialized (debug mode — no remote reporting)")
        #endif
    }

    /// Log a non-fatal error for debugging
    static func log(_ error: Error, context: String = "") {
        #if DEBUG
        print("[CrashReporter] \(context): \(error.localizedDescription)")
        #endif
        // Sentry: SentrySDK.capture(error: error)
        // Firebase: Crashlytics.crashlytics().record(error: error)
    }

    /// Log a non-fatal message
    static func log(_ message: String) {
        #if DEBUG
        print("[CrashReporter] \(message)")
        #endif
        // Sentry: SentrySDK.capture(message: message)
    }

    /// Set user context (anonymous ID only, no PII)
    static func setUser(id: String) {
        // Sentry: SentrySDK.setUser(User(userId: id))
        // Firebase: Crashlytics.crashlytics().setUserID(id)
        #if DEBUG
        print("[CrashReporter] User set: \(id.prefix(8))...")
        #endif
    }
}
