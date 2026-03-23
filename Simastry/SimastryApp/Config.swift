import Foundation

nonisolated enum Config {
    private static func value(_ key: String, fallback: String = "") -> String {
        let env = ProcessInfo.processInfo.environment[key] ?? ""
        return env.isEmpty ? fallback : env
    }

    static let EXPO_PUBLIC_PROJECT_ID: String = value("EXPO_PUBLIC_PROJECT_ID")
    static let EXPO_PUBLIC_REVENUECAT_API_KEY: String = value("EXPO_PUBLIC_REVENUECAT_API_KEY", fallback: "appl_PANKHRiryKbpJfwDGmhEyOgdbEq")
    static let ANTHROPIC_API_KEY: String = value("ANTHROPIC_API_KEY", fallback: "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")
    static let EXPO_PUBLIC_RORK_API_BASE_URL: String = value("EXPO_PUBLIC_RORK_API_BASE_URL")
    static let EXPO_PUBLIC_RORK_AUTH_URL: String = value("EXPO_PUBLIC_RORK_AUTH_URL")
    static let EXPO_PUBLIC_SOCIAL_DISCOVERY_ENABLED: String = value("EXPO_PUBLIC_SOCIAL_DISCOVERY_ENABLED", fallback: "true")
    static let EXPO_PUBLIC_SUPABASE_ANON_KEY: String = value("EXPO_PUBLIC_SUPABASE_ANON_KEY", fallback: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZldWZ3b2dqZGZ3anh3ZWZ0ZndzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMTA5MDMsImV4cCI6MjA4NzY4NjkwM30.C80K7KdY-hFJ-eox3iOWxxFrzkj6JMcGlzmehelLF6g")
    static let EXPO_PUBLIC_SUPABASE_URL: String = value("EXPO_PUBLIC_SUPABASE_URL", fallback: "https://veufwogjdfwjxweftfws.supabase.co")
    static let EXPO_PUBLIC_TEAM_ID: String = value("EXPO_PUBLIC_TEAM_ID")
    static let EXPO_PUBLIC_TOOLKIT_URL: String = value("EXPO_PUBLIC_TOOLKIT_URL")
}
