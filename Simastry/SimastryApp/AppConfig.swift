import Foundation

nonisolated enum AppConfig {
    static let projectID = "veufwogjdfwjxweftfws"
    static let revenueCatAPIKey = ""
    static let predictionAPIBaseURL = infoValue("SimastryPredictionAPIBaseURL")
    static let supabaseAnonKey = "sb_publishable_xB_035Vop01OlsW19lWx4A_2sWlSMrT"
    static let supabaseURL = "https://veufwogjdfwjxweftfws.supabase.co"
    static let teamID = "A6PP462J72"
    static let toolkitURL = ""
    static let telemetryDeckAppID = ""

    static let predictionRateLimit = (perMinute: 3, perHour: 20, perDay: 50)
    static let astrologyTradition = "Western Tropical Synastry"

    static let deepLinkScheme = "simastry"
    static let universalLinkHost = "simastry.vercel.app"
    static let websiteURL = URL(string: "https://simastry.vercel.app")!
    static let appStoreURL = websiteURL

    static let socialDiscoveryEnabled = true
    static let llmChatEnabled = false

    static let privacyPolicyURL = URL(string: "https://simastry.vercel.app/privacy")!
    static let termsOfServiceURL = URL(string: "https://simastry.vercel.app/terms")!
    static let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static let astrologerDirectoryURL = URL(string: "https://simastry.vercel.app/astrologers")!
    static let astrologerPartnerURL = URL(string: "https://simastry.vercel.app/partners")!
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
