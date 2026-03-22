import Foundation
import Supabase

nonisolated enum SupabaseServiceError: LocalizedError, Sendable {
    case notConfigured

    var errorDescription: String? {
        "Authentication is not configured yet."
    }
}

nonisolated final class SupabaseService {
    let client: SupabaseClient
    private let isConfigured: Bool

    private var authRedirectURL: URL {
        let scheme = Bundle.main.bundleIdentifier ?? "app.rork.simastry"
        guard let url = URL(string: "\(scheme)://auth/callback") else {
            preconditionFailure("Invalid auth redirect URL")
        }
        return url
    }

    init() {
        let rawURL = Config.EXPO_PUBLIC_SUPABASE_URL
        let rawKey = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY

        guard !rawURL.isEmpty, let url = URL(string: rawURL), !rawKey.isEmpty else {
            isConfigured = false
            client = SupabaseClient(
                supabaseURL: URL(string: "https://example.invalid")!,
                supabaseKey: "unconfigured"
            )
            return
        }

        isConfigured = true
        client = SupabaseClient(supabaseURL: url, supabaseKey: rawKey)
    }

    var currentUserId: UUID? {
        get async {
            guard isConfigured else { return nil }
            return try? await client.auth.session.user.id
        }
    }

    func signInWithApple(idToken: String) async throws {
        try requireConfiguration()
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
    }

    func signInWithGoogle() async throws {
        try requireConfiguration()
        _ = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: authRedirectURL,
            scopes: "openid email profile https://www.googleapis.com/auth/userinfo.email"
        )
    }

    func isAuthCallbackURL(_ url: URL) -> Bool {
        let scheme = Bundle.main.bundleIdentifier ?? "app.rork.simastry"
        return url.scheme == scheme && url.host == "auth"
    }

    func handleAuthCallback(_ url: URL) async throws {
        try requireConfiguration()
        try await client.auth.session(from: url)
    }

    func signUpWithEmail(email: String, password: String) async throws -> Bool {
        try requireConfiguration()
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: authRedirectURL
        )
        switch response {
        case .session(_):
            return true
        case .user(_):
            return false
        }
    }

    func signInWithEmail(email: String, password: String) async throws {
        try requireConfiguration()
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        guard isConfigured else { return }
        try await client.auth.signOut()
    }

    func isAuthenticated() async -> Bool {
        guard isConfigured else { return false }
        do {
            _ = try await client.auth.session
            return true
        } catch {
            return false
        }
    }

    func fetchProfile() async throws -> UserProfile? {
        try requireConfiguration()
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
        try requireConfiguration()
        try await client.from("profiles").upsert(profile).execute()
    }

    func fetchCompanions() async throws -> [CompanionData] {
        try requireConfiguration()
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
        try requireConfiguration()
        try await client.from("companions").insert(companion).execute()
    }

    func updateCompanion(_ companion: CompanionData) async throws {
        try requireConfiguration()
        try await client.from("companions")
            .update(companion)
            .eq("id", value: companion.id.uuidString)
            .execute()
    }

    func deleteCompanion(id: UUID) async throws {
        try requireConfiguration()
        try await client.from("companions")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func fetchMessages(companionId: UUID) async throws -> [MessageData] {
        try requireConfiguration()
        let messages: [MessageData] = try await client
            .from("messages")
            .select()
            .eq("companion_id", value: companionId.uuidString)
            .execute()
            .value
        return messages
    }

    private func requireConfiguration() throws {
        guard isConfigured else {
            throw SupabaseServiceError.notConfigured
        }
    }
}
