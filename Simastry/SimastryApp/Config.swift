import Foundation

nonisolated enum Config {
    private static func value(_ key: String) -> String {
        ProcessInfo.processInfo.environment[key] ?? ""
    }

    static let EXPO_PUBLIC_PROJECT_ID: String = value("EXPO_PUBLIC_PROJECT_ID")
    static let EXPO_PUBLIC_REVENUECAT_API_KEY: String = value("EXPO_PUBLIC_REVENUECAT_API_KEY")
    static let EXPO_PUBLIC_RORK_API_BASE_URL: String = value("EXPO_PUBLIC_RORK_API_BASE_URL")
    static let EXPO_PUBLIC_RORK_AUTH_URL: String = value("EXPO_PUBLIC_RORK_AUTH_URL")
    static let EXPO_PUBLIC_SUPABASE_ANON_KEY: String = value("EXPO_PUBLIC_SUPABASE_ANON_KEY")
    static let EXPO_PUBLIC_SUPABASE_URL: String = value("EXPO_PUBLIC_SUPABASE_URL")
    static let EXPO_PUBLIC_TEAM_ID: String = value("EXPO_PUBLIC_TEAM_ID")
    static let EXPO_PUBLIC_TOOLKIT_URL: String = value("EXPO_PUBLIC_TOOLKIT_URL")
}
