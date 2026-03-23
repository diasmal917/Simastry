import Foundation

nonisolated enum AppConfig {
    static let EXPO_PUBLIC_PROJECT_ID: String = Config.EXPO_PUBLIC_PROJECT_ID
    static let EXPO_PUBLIC_REVENUECAT_API_KEY: String = Config.EXPO_PUBLIC_REVENUECAT_API_KEY
    static let EXPO_PUBLIC_RORK_API_BASE_URL: String = Config.EXPO_PUBLIC_RORK_API_BASE_URL
    static let EXPO_PUBLIC_RORK_AUTH_URL: String = Config.EXPO_PUBLIC_RORK_AUTH_URL
    static let EXPO_PUBLIC_SUPABASE_ANON_KEY: String = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY
    static let EXPO_PUBLIC_SUPABASE_URL: String = Config.EXPO_PUBLIC_SUPABASE_URL
    static let EXPO_PUBLIC_TEAM_ID: String = Config.EXPO_PUBLIC_TEAM_ID
    static let EXPO_PUBLIC_TOOLKIT_URL: String = Config.EXPO_PUBLIC_TOOLKIT_URL

    // TelemetryDeck (privacy-first analytics)
    static let telemetryDeckAppID = "" // Add your TelemetryDeck app ID here

    // Rate limiting (API cost protection)
    static let predictionRateLimit = (perMinute: 3, perHour: 20, perDay: 50)

    // Astrology tradition
    static let astrologyTradition = "Western Tropical Synastry"

    // Deep linking
    static let deepLinkScheme = "simastry"
    static let universalLinkHost = "simastry.app"
    static let appStoreURL = URL(string: "https://apps.apple.com/app/simastry/id0000000000")! // Replace with real App Store ID
    static let socialDiscoveryEnabled =
        !EXPO_PUBLIC_SUPABASE_URL.isEmpty &&
        !EXPO_PUBLIC_SUPABASE_ANON_KEY.isEmpty &&
        Config.EXPO_PUBLIC_SOCIAL_DISCOVERY_ENABLED.lowercased() == "true"

    // Legal URLs — update these before App Store submission
    static let privacyPolicyURL = URL(string: "https://simastry.app/privacy")!
    static let termsOfServiceURL = URL(string: "https://simastry.app/terms")!
    static let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // Astrologer partnership
    static let astrologerDirectoryURL = URL(string: "https://simastry.app/astrologers")!
    static let astrologerPartnerURL = URL(string: "https://simastry.app/partners")!
    static let astrologerContactEmail = "astrologers@simastry.app"

    static let allValues: [String: String] = [
        "EXPO_PUBLIC_PROJECT_ID": EXPO_PUBLIC_PROJECT_ID,
        "EXPO_PUBLIC_REVENUECAT_API_KEY": EXPO_PUBLIC_REVENUECAT_API_KEY,
        "EXPO_PUBLIC_RORK_API_BASE_URL": EXPO_PUBLIC_RORK_API_BASE_URL,
        "EXPO_PUBLIC_RORK_AUTH_URL": EXPO_PUBLIC_RORK_AUTH_URL,
        "EXPO_PUBLIC_SOCIAL_DISCOVERY_ENABLED": Config.EXPO_PUBLIC_SOCIAL_DISCOVERY_ENABLED,
        "EXPO_PUBLIC_SUPABASE_ANON_KEY": EXPO_PUBLIC_SUPABASE_ANON_KEY,
        "EXPO_PUBLIC_SUPABASE_URL": EXPO_PUBLIC_SUPABASE_URL,
        "EXPO_PUBLIC_TEAM_ID": EXPO_PUBLIC_TEAM_ID,
        "EXPO_PUBLIC_TOOLKIT_URL": EXPO_PUBLIC_TOOLKIT_URL,
    ]
}
