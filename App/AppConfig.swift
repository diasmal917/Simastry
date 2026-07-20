import Foundation

nonisolated enum AppConfig {
    static let projectID = "veufwogjdfwjxweftfws"
    static let revenueCatAPIKey = ""
    static let predictionAPIBaseURL = infoValue("SimastryPredictionAPIBaseURL")
    /// Production Supabase project. In DEBUG these resolve a local override (see
    /// `DebugSupabaseOverride`) for integration testing; release builds and the
    /// unmodified production defaults are never affected.
    static var supabaseAnonKey: String {
        #if DEBUG
        if let override = DebugSupabaseOverride.anonKey { return override }
        #endif
        return productionSupabaseAnonKey
    }
    static var supabaseURL: String {
        #if DEBUG
        if let override = DebugSupabaseOverride.url { return override }
        #endif
        return productionSupabaseURL
    }

    private static let productionSupabaseAnonKey = "sb_publishable_xB_035Vop01OlsW19lWx4A_2sWlSMrT"
    private static let productionSupabaseURL = "https://veufwogjdfwjxweftfws.supabase.co"
    static let teamID = "A6PP462J72"
    static let toolkitURL = ""
    static let telemetryDeckAppID = ""

    static let predictionRateLimit = (perMinute: 3, perHour: 20, perDay: 50)
    static let astrologyTradition = "Western Tropical Synastry"

    static let deepLinkScheme = "simastry"
    static let universalLinkHost = "simastry.com"
    static let legacyUniversalLinkHosts = ["simastry.vercel.app", "simastry.app"]
    static let websiteDisplayName = "Simastry.com"
    static let websiteURL = URL(string: "https://simastry.com")!
    static let appStoreURL = websiteURL

    /// Public discovery remains compiled for a later experiment, but the
    /// primary-companion pilot is a private relationship workspace.
    static let socialDiscoveryEnabled = false
    static let llmChatEnabled = true
    static let roomGuideReplyEnabled = false
    static let companionStreamingEnabled = true
    static let momentsEnabled = false
    static let guidedRoomsEnabled = false
    static let multiCompanionPanelsEnabled = false
    static let customCompanionsEnabled = false
    static let auraWalletEnabled = false
    /// Follow-ups happen only after a user records an offline outcome. The
    /// pilot never fabricates proactive or companion-initiated messages.
    static let companionInitiatedMessagingEnabled = false
    /// When true, expert-astrologer replies stream over SSE and render
    /// incrementally; the JSON request remains the fallback if streaming is
    /// unavailable or fails before the first token.
    static let expertAstrologerStreamingEnabled = true
    private static let remoteRollbackDefaultsKey = "simastry_companion_remote_rollback"

    /// Pilot is the release default. The rollback value is hydrated from the
    /// released pilot-persona set and cached locally so it still works during an
    /// outage. Suspending any certified pilot row acts as the remote kill switch;
    /// launch arguments keep QA deterministic.
    static var experienceMode: ExperienceMode {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-SimastryExpertArchive") || companionRemoteRollbackEnabled {
            return .expertArchive
        }
        if arguments.contains("-SimastryCompanionFull") {
            return .companionFull
        }
        return .companionPilot
    }

    static var companionRemoteRollbackEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-SimastryCompanionRollback")
            || UserDefaults.standard.bool(forKey: remoteRollbackDefaultsKey)
    }

    static func cacheCompanionRemoteRollback(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: remoteRollbackDefaultsKey)
    }

    /// Rollback and archive are separate intentions even though both leave the
    /// companion modes. Operators may temporarily restore the preserved expert
    /// pipeline; the explicit archive launch mode remains strictly read-only.
    static var restoresLegacyExpertExperience: Bool {
        companionRemoteRollbackEnabled
            && !ProcessInfo.processInfo.arguments.contains("-SimastryExpertArchive")
    }

    /// Compatibility shim for preserved legacy surfaces. New code should branch
    /// on `experienceMode` explicitly rather than recreating an inverted flag.
    static var expertAstrologersEnabled: Bool {
        restoresLegacyExpertExperience
    }

    static let privacyPolicyURL = URL(string: "https://simastry.com/privacy")!
    static let termsOfServiceURL = URL(string: "https://simastry.com/terms")!
    static let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static let astrologerDirectoryURL = URL(string: "https://simastry.com/astrologers")!
    static let astrologerPartnerURL = URL(string: "https://simastry.com/partners")!
    static let astrologerContactEmail = "astrologers@simastry.com"

    static let allValues: [String: String] = [
        "SIMASTRY_PROJECT_ID": projectID,
        "SIMASTRY_REVENUECAT_API_KEY": revenueCatAPIKey,
        "SIMASTRY_PREDICTION_API_BASE_URL": predictionAPIBaseURL,
        "SIMASTRY_SUPABASE_ANON_KEY": supabaseAnonKey,
        "SIMASTRY_SUPABASE_URL": supabaseURL,
        "SIMASTRY_TEAM_ID": teamID,
        "SIMASTRY_TOOLKIT_URL": toolkitURL,
    ]

    private static func infoValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}

#if DEBUG
/// DEBUG-only Supabase backend override for local integration testing against a
/// `supabase start` stack. It is never compiled into release builds, so
/// production always targets the remote project. Enable either:
///
///   • Launch argument `-SimastryUseLocalSupabase`
///       → URL `http://127.0.0.1:54321` + the standard local anon key.
///   • Environment variables (take precedence; use for a non-default key/port):
///       `SIMASTRY_SUPABASE_URL_OVERRIDE`
///       `SIMASTRY_SUPABASE_ANON_KEY_OVERRIDE`
///
/// Example: run the app (or `xcodebuild test`) with `-SimastryUseLocalSupabase`,
/// or set `SIMASTRY_SUPABASE_URL_OVERRIDE=http://127.0.0.1:54321`.
enum DebugSupabaseOverride {
    static let localURL = "http://127.0.0.1:54321"

    /// The anon key `supabase start` mints for local stacks (identical across
    /// local instances). Override with the env var if your CLI prints another.
    static let localAnonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

    static var url: String? {
        let environment = ProcessInfo.processInfo.environment
        if let value = environment["SIMASTRY_SUPABASE_URL_OVERRIDE"], !value.isEmpty {
            return value
        }
        if ProcessInfo.processInfo.arguments.contains("-SimastryUseLocalSupabase") {
            return localURL
        }
        return nil
    }

    /// Resolved only when a URL override is active, so the anon key always
    /// matches the backend being targeted.
    static var anonKey: String? {
        guard url != nil else { return nil }
        let environment = ProcessInfo.processInfo.environment
        if let value = environment["SIMASTRY_SUPABASE_ANON_KEY_OVERRIDE"], !value.isEmpty {
            return value
        }
        return localAnonKey
    }

    static var isActive: Bool { url != nil }
}
#endif
