import Foundation

nonisolated enum Config {
    // The Anthropic key intentionally has no entry here: AI generation routes
    // through the companion-reply Supabase edge function, and the key lives
    // only in edge-function secrets — never in the app binary.
    static let EXPO_PUBLIC_PROJECT_ID = ""
    static let EXPO_PUBLIC_REVENUECAT_API_KEY = ""
    static let EXPO_PUBLIC_RORK_API_BASE_URL = ""
    static let EXPO_PUBLIC_RORK_AUTH_URL = ""
    static let EXPO_PUBLIC_SOCIAL_DISCOVERY_ENABLED = "false"
    static let EXPO_PUBLIC_LLM_CHAT_ENABLED = "false"
    static let EXPO_PUBLIC_SUPABASE_ANON_KEY = ""
    static let EXPO_PUBLIC_SUPABASE_URL = ""
    static let EXPO_PUBLIC_TEAM_ID = ""
    static let EXPO_PUBLIC_TOOLKIT_URL = ""
}
