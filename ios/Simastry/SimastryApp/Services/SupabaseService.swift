import Foundation
import Supabase

nonisolated enum SupabaseServiceError: LocalizedError, Sendable {
    case notConfigured
    case invalidRedirectURL

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Authentication is not configured yet."
        case .invalidRedirectURL:
            "Authentication redirect URL is invalid."
        }
    }
}

nonisolated final class SupabaseService {
    private let client: SupabaseClient?

    private var isConfigured: Bool {
        client != nil
    }

    private func makeAuthRedirectURL() throws -> URL {
        let scheme = Bundle.main.bundleIdentifier ?? "app.rork.simastry"
        guard let url = URL(string: "\(scheme)://auth/callback") else {
            throw SupabaseServiceError.invalidRedirectURL
        }
        return url
    }

    init() {
        let rawURL = Config.EXPO_PUBLIC_SUPABASE_URL
        let rawKey = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY

        guard !rawURL.isEmpty, let url = URL(string: rawURL), !rawKey.isEmpty else {
            client = nil
            return
        }

        client = SupabaseClient(supabaseURL: url, supabaseKey: rawKey)
    }

    var currentUserId: UUID? {
        get async {
            guard let client else { return nil }
            do {
                return try await client.auth.session.user.id
            } catch {
                return nil
            }
        }
    }

    /// True when the edge-function AI channel can be reached (Supabase
    /// configured). The function itself still requires a signed-in session.
    var canInvokeCompanionReply: Bool {
        isConfigured
    }

    /// Calls the `companion-reply` edge function — the server-side Anthropic
    /// proxy — and returns the generated text.
    func invokeCompanionReply(
        kind: CompanionReplyKind,
        system: String,
        user: String,
        maxTokens: Int = 1024
    ) async throws -> String {
        let client = try configuredClient()
        let payload = CompanionReplyPayload(kind: kind.rawValue, system: system, user: user, maxTokens: maxTokens)
        let response: CompanionReplyResponse = try await client.functions.invoke(
            "companion-reply",
            options: FunctionInvokeOptions(body: payload)
        )
        return response.text
    }

    func signInWithApple(idToken: String) async throws {
        let client = try configuredClient()
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
    }

    func signInWithGoogle() async throws {
        let client = try configuredClient()
        let redirectURL = try makeAuthRedirectURL()
        _ = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: redirectURL,
            scopes: "openid email profile https://www.googleapis.com/auth/userinfo.email"
        )
    }

    func isAuthCallbackURL(_ url: URL) -> Bool {
        let scheme = Bundle.main.bundleIdentifier ?? "app.rork.simastry"
        return url.scheme == scheme && url.host == "auth"
    }

    func handleAuthCallback(_ url: URL) async throws {
        let client = try configuredClient()
        try await client.auth.session(from: url)
    }

    func signUpWithEmail(email: String, password: String) async throws -> Bool {
        let client = try configuredClient()
        let redirectURL = try makeAuthRedirectURL()
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: redirectURL
        )
        switch response {
        case .session(_):
            return true
        case .user(_):
            return false
        }
    }

    func signInWithEmail(email: String, password: String) async throws {
        let client = try configuredClient()
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        guard let client else { return }
        try await client.auth.signOut()
    }

    enum AuthState: Sendable {
        /// A valid (possibly just refreshed) session exists.
        case authenticated
        /// No session is stored on this device — a definitive sign-out.
        case signedOut
        /// A session is stored but could not be verified or refreshed right
        /// now (offline, Supabase unreachable). Callers must not treat this
        /// as a sign-out: account-scoped local data has to survive it.
        case unverified
    }

    func authState() async -> AuthState {
        guard let client else { return .signedOut }
        do {
            _ = try await client.auth.session
            return .authenticated
        } catch {
            return client.auth.currentSession == nil ? .signedOut : .unverified
        }
    }

    func fetchProfile() async throws -> UserProfile? {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return nil }
        let profiles: [UserProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value
        return profiles.first
    }

    func upsertProfile(_ profile: UserProfile) async throws {
        let client = try configuredClient()
        try await client.from("profiles").upsert(profile).execute()
    }

    func fetchCompanions() async throws -> [CompanionData] {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return [] }
        let companions: [CompanionData] = try await client
            .from("companions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return companions
    }

    func insertCompanion(_ companion: CompanionData) async throws {
        let client = try configuredClient()
        try await client.from("companions").insert(companion).execute()
    }

    func updateCompanion(_ companion: CompanionData) async throws {
        let client = try configuredClient()
        try await client.from("companions")
            .update(companion)
            .eq("id", value: companion.id.uuidString)
            .execute()
    }

    func deleteCompanion(id: UUID) async throws {
        let client = try configuredClient()
        try await client.from("companions")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func fetchMessages(companionId: UUID) async throws -> [MessageData] {
        let client = try configuredClient()
        let messages: [MessageData] = try await client
            .from("messages")
            .select()
            .eq("companion_id", value: companionId.uuidString)
            .execute()
            .value
        return messages
    }

    func deleteAllCompanions(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("companions")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteProfile(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("profiles")
            .delete()
            .eq("id", value: userId)
            .execute()
    }

    func fetchCurrentSocialProfile() async throws -> SocialProfile? {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return nil }
        let profiles: [SocialProfile] = try await client
            .from("social_profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value
        return profiles.first
    }

    func upsertSocialProfile(_ profile: SocialProfile) async throws {
        let client = try configuredClient()
        try await client.from("social_profiles").upsert(profile).execute()
    }

    func fetchVisibleSocialProfiles() async throws -> [SocialProfile] {
        let client = try configuredClient()
        return try await client
            .from("social_profiles")
            .select()
            .eq("is_visible", value: true)
            .execute()
            .value
    }

    func deleteSocialProfile(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("social_profiles")
            .delete()
            .eq("id", value: userId)
            .execute()
    }

    func fetchDiscoveryBlocks() async throws -> [DiscoveryBlockData] {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return [] }

        let sentBlocks: [DiscoveryBlockData] = try await client
            .from("discovery_blocks")
            .select()
            .eq("blocker_id", value: userId.uuidString)
            .execute()
            .value

        let receivedBlocks: [DiscoveryBlockData] = try await client
            .from("discovery_blocks")
            .select()
            .eq("blocked_id", value: userId.uuidString)
            .execute()
            .value

        return sentBlocks + receivedBlocks
    }

    func blockDiscoveryProfile(blockedId: UUID) async throws {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return }

        let block = DiscoveryBlockData(
            blockerId: userId,
            blockedId: blockedId,
            createdAt: Date()
        )

        try await client.from("discovery_blocks").upsert(block).execute()
    }

    func reportDiscoveryProfile(_ report: DiscoveryReportData) async throws {
        let client = try configuredClient()
        try await client.from("discovery_reports").insert(report).execute()
    }

    func fetchDiscoveryMessages() async throws -> [DiscoveryMessageData] {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return [] }
        let messages: [DiscoveryMessageData] = try await client
            .from("discovery_messages")
            .select()
            .or("sender_id.eq.\(userId.uuidString),recipient_id.eq.\(userId.uuidString)")
            .order("created_at", ascending: false)
            .execute()
            .value
        return messages
    }

    func sendDiscoveryMessage(_ message: DiscoveryMessageData) async throws {
        let client = try configuredClient()
        try await client.from("discovery_messages").insert(message).execute()
    }

    func markDiscoveryConversationRead(with participantId: UUID) async throws {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return }
        try await client.from("discovery_messages")
            .update(["is_read": true])
            .eq("recipient_id", value: userId.uuidString)
            .eq("sender_id", value: participantId.uuidString)
            .execute()
    }

    func deleteDiscoveryConversation(with participantId: UUID) async throws {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return }
        try await client.from("discovery_messages")
            .delete()
            .or(
                "and(sender_id.eq.\(userId.uuidString),recipient_id.eq.\(participantId.uuidString)),and(sender_id.eq.\(participantId.uuidString),recipient_id.eq.\(userId.uuidString))"
            )
            .execute()
    }

    private func configuredClient() throws -> SupabaseClient {
        guard let client, isConfigured else {
            throw SupabaseServiceError.notConfigured
        }
        return client
    }
}

// MARK: - Companion Reply Channel

nonisolated enum CompanionReplyKind: String, Sendable {
    case prediction
    case chat
}

nonisolated struct CompanionReplyPayload: Encodable, Sendable {
    let kind: String
    let system: String
    let user: String
    let maxTokens: Int
}

nonisolated struct CompanionReplyResponse: Decodable, Sendable {
    let text: String
}
