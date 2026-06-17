import Foundation
import Supabase

nonisolated final class SupabaseService {
    let client: SupabaseClient

    private var authRedirectURL: URL {
        let scheme = Bundle.main.bundleIdentifier ?? "app.simastry.ios"
        guard let url = URL(string: "\(scheme)://auth/callback") else {
            preconditionFailure("Invalid auth redirect URL")
        }
        return url
    }

    init() {
        let rawURL = AppConfig.supabaseURL
        let rawKey = AppConfig.supabaseAnonKey

        guard !rawURL.isEmpty, let url = URL(string: rawURL), !rawKey.isEmpty else {
            preconditionFailure("Supabase URL and anon key must be configured")
        }

        client = SupabaseClient(supabaseURL: url, supabaseKey: rawKey)
    }

    var currentUserId: UUID? {
        get async {
            try? await client.auth.session.user.id
        }
    }

    func currentAccessToken() async -> String? {
        do {
            return try await client.auth.session.accessToken
        } catch {
            return nil
        }
    }

    func signInWithApple(idToken: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
    }

    func signInWithGoogle() async throws {
        _ = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: authRedirectURL,
            scopes: "openid email profile https://www.googleapis.com/auth/userinfo.email"
        )
    }

    func isAuthCallbackURL(_ url: URL) -> Bool {
        let scheme = Bundle.main.bundleIdentifier ?? "app.simastry.ios"
        return url.scheme == scheme && url.host == "auth"
    }

    func handleAuthCallback(_ url: URL) async throws {
        try await client.auth.session(from: url)
    }

    func signUpWithEmail(email: String, password: String) async throws -> Bool {
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
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func isAuthenticated() async -> Bool {
        do {
            _ = try await client.auth.session
            return true
        } catch {
            return false
        }
    }

    func fetchProfile() async throws -> UserProfile? {
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
        try await client.from("profiles").upsert(profile).execute()
    }

    func fetchCompanions() async throws -> [CompanionData] {
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
        try await client.from("companions").insert(companion).execute()
    }

    func updateCompanion(_ companion: CompanionData) async throws {
        try await client.from("companions")
            .update(companion)
            .eq("id", value: companion.id.uuidString)
            .execute()
    }

    func deleteCompanion(id: UUID) async throws {
        try await client.from("companions")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func fetchMessages(companionId: UUID) async throws -> [MessageData] {
        let messages: [MessageData] = try await client
            .from("messages")
            .select()
            .eq("companion_id", value: companionId.uuidString)
            .execute()
            .value
        return messages
    }

    func searchPublicProfiles(query: String) async throws -> [SearchableUserProfile] {
        guard let userId = await currentUserId else { return [] }
        let normalizedQuery = normalizedProfileSearchQuery(query)
        guard !normalizedQuery.isEmpty else { return [] }

        let pattern = "%\(normalizedQuery)%"
        let profiles: [SearchableUserProfile] = try await client
            .from("public_profiles")
            .select()
            .eq("is_discoverable", value: true)
            .neq("id", value: userId.uuidString)
            .or("username.ilike.\(pattern),display_name.ilike.\(pattern)")
            .order("username", ascending: true)
            .limit(8)
            .execute()
            .value

        return profiles
    }

    func fetchConnectedProfiles() async throws -> [SearchableUserProfile] {
        let connections: [UserConnectionRow] = try await client
            .from("user_connections")
            .select("profile_id")
            .order("created_at", ascending: false)
            .execute()
            .value

        guard !connections.isEmpty else { return [] }

        let profileIdValues: [any PostgrestFilterValue] = connections.map { $0.profileId.uuidString }
        let profiles: [SearchableUserProfile] = try await client
            .from("public_profiles")
            .select()
            .in("id", values: profileIdValues)
            .execute()
            .value

        let profilesById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        return connections.compactMap { profilesById[$0.profileId] }
    }

    func addUserConnection(profileId: UUID) async throws {
        guard let userId = await currentUserId else { return }
        let payload = UserConnectionInsert(ownerId: userId, profileId: profileId)
        try await client
            .from("user_connections")
            .insert(payload)
            .execute()
    }

    func removeUserConnection(profileId: UUID) async throws {
        guard let userId = await currentUserId else { return }
        try await client
            .from("user_connections")
            .delete()
            .eq("owner_id", value: userId.uuidString)
            .eq("profile_id", value: profileId.uuidString)
            .execute()
    }

    func upsertPublicProfile(
        username: String?,
        displayName: String?,
        avatarURL: String?,
        avatarPath: String?,
        bio: String?,
        sunSign: ZodiacSign?,
        moonSign: ZodiacSign?,
        risingSign: ZodiacSign?,
        communicationHint: String?,
        iceBreakers: [String],
        isDiscoverable: Bool
    ) async throws -> SearchableUserProfile? {
        guard let userId = await currentUserId else { return nil }
        let payload = PublicProfileUpsert(
            id: userId,
            username: normalizedUsername(username),
            displayName: displayName?.trimmedNonEmpty,
            avatarURL: avatarURL?.trimmedNonEmpty,
            avatarPath: avatarPath?.trimmedNonEmpty,
            bio: bio?.trimmedNonEmpty,
            sunSign: sunSign,
            moonSign: moonSign,
            risingSign: risingSign,
            communicationHint: communicationHint?.trimmedNonEmpty,
            iceBreakers: Array(iceBreakers.prefix(8)),
            isDiscoverable: isDiscoverable
        )

        let profile: SearchableUserProfile = try await client
            .from("public_profiles")
            .upsert(payload)
            .select()
            .single()
            .execute()
            .value

        return profile
    }

    func uploadAvatar(
        data: Data,
        contentType: String = "image/jpeg",
        fileExtension: String = "jpg"
    ) async throws -> AvatarUploadResult? {
        guard let userId = await currentUserId else { return nil }
        let normalizedExtension = fileExtension.trimmingCharacters(in: .alphanumerics.inverted).lowercased()
        let pathExtension = normalizedExtension.isEmpty ? "jpg" : normalizedExtension
        let path = "\(userId.uuidString)/avatar.\(pathExtension)"

        try await client.storage
            .from("avatars")
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: contentType, upsert: true)
            )

        let publicURL = try publicAvatarURL(path: path, cacheNonce: UUID().uuidString)
        return AvatarUploadResult(path: path, publicURL: publicURL)
    }

    func publicAvatarURL(path: String, cacheNonce: String? = nil) throws -> String {
        try client.storage
            .from("avatars")
            .getPublicURL(path: path, cacheNonce: cacheNonce)
            .absoluteString
    }

    private func normalizedProfileSearchQuery(_ query: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- "))
        return query
            .lowercased()
            .unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedUsername(_ username: String?) -> String? {
        username?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
            .trimmedNonEmpty
    }
}

private extension String {
    nonisolated var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
