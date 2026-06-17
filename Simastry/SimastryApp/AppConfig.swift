import Foundation

nonisolated enum AppConfig {
    static let projectID: String = "veufwogjdfwjxweftfws"
    static let revenueCatAPIKey: String = ""
    static let predictionAPIBaseURL: String = infoValue("SimastryPredictionAPIBaseURL")
    static let supabaseAnonKey: String = "sb_publishable_xB_035Vop01OlsW19lWx4A_2sWlSMrT"
    static let supabaseURL: String = "https://veufwogjdfwjxweftfws.supabase.co"
    static let teamID: String = ""
    static let toolkitURL: String = ""

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
