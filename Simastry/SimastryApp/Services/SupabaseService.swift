import Foundation
import Supabase

nonisolated enum SupabaseServiceError: LocalizedError, Sendable {
    case notConfigured
    case invalidRedirectURL
    case missingSession
    case invalidFunctionResponse
    case functionFailed(String)
    case aiUsageLimit(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Authentication is not configured yet."
        case .invalidRedirectURL:
            "Authentication redirect URL is invalid."
        case .missingSession:
            "Please sign in again before continuing."
        case .invalidFunctionResponse:
            "The AI guide answered in an unexpected format."
        case .functionFailed(let message):
            message
        case .aiUsageLimit(let message):
            message
        }
    }
}

nonisolated final class SupabaseService {
    private let client: SupabaseClient?

    private var isConfigured: Bool {
        client != nil
    }

    private func makeAuthRedirectURL() throws -> URL {
        let scheme = Bundle.main.bundleIdentifier ?? "app.simastry.ios"
        guard let url = URL(string: "\(scheme)://auth/callback") else {
            throw SupabaseServiceError.invalidRedirectURL
        }
        return url
    }

    init() {
        let rawURL = AppConfig.supabaseURL
        let rawKey = AppConfig.supabaseAnonKey

        guard !rawURL.isEmpty, let url = URL(string: rawURL), !rawKey.isEmpty else {
            client = nil
            return
        }

        client = SupabaseClient(supabaseURL: url, supabaseKey: rawKey)
    }

    static func avatarStoragePath(userId: UUID, fileExtension: String) -> String {
        let sanitizedExtension = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return "\(userId.uuidString)/profile.\(sanitizedExtension.isEmpty ? "jpg" : sanitizedExtension)"
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

    /// True when the edge-function AI channel should be attempted. Signed-out
    /// sessions keep using local fallbacks instead of calling the LLM endpoint.
    var canInvokeCompanionReply: Bool {
        isConfigured && client?.auth.currentSession != nil
    }

    /// Calls the `companion-reply` edge function — the server-side Anthropic
    /// proxy — and returns the generated text.
    func invokeCompanionReply(
        kind: CompanionReplyKind,
        feature: CompanionReplyFeature,
        system: String,
        user: String,
        maxTokens: Int = 1024
    ) async throws -> String {
        try await invokeCompanionReplyResult(
            kind: kind,
            feature: feature,
            system: system,
            user: user,
            maxTokens: maxTokens
        ).text
    }

    /// Calls the companion-reply edge function and returns response metadata
    /// used to connect later guide feedback to the exact AI usage event.
    func invokeCompanionReplyResult(
        kind: CompanionReplyKind,
        feature: CompanionReplyFeature,
        system: String,
        user: String,
        maxTokens: Int = 1024
    ) async throws -> CompanionReplyResult {
        let client = try configuredClient()
        guard let session = client.auth.currentSession else {
            throw SupabaseServiceError.missingSession
        }
        guard let url = URL(string: "\(AppConfig.supabaseURL)/functions/v1/companion-reply") else {
            throw SupabaseServiceError.notConfigured
        }

        let payload = CompanionReplyPayload(
            kind: kind.rawValue,
            feature: feature.rawValue,
            system: system,
            user: user,
            maxTokens: maxTokens
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseServiceError.invalidFunctionResponse
        }

        if http.statusCode == 429 {
            throw SupabaseServiceError.aiUsageLimit(
                CompanionReplyErrorEnvelope.message(from: data)
                    ?? "You have reached today's AI guide limit."
            )
        }

        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseServiceError.functionFailed(
                CompanionReplyErrorEnvelope.message(from: data)
                    ?? "The AI guide is unavailable right now. Please try again."
            )
        }

        let decoded = try JSONDecoder().decode(CompanionReplyResponse.self, from: data)
        return CompanionReplyResult(text: decoded.text, usageEventId: decoded.usageEventId)
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
        let scheme = Bundle.main.bundleIdentifier ?? "app.simastry.ios"
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

    func syncGuideFeedback(_ feedback: GuideFeedback) async throws {
        let client = try configuredClient()
        guard (await currentUserId) != nil else {
            throw SupabaseServiceError.missingSession
        }

        try await client
            .rpc("sync_guide_feedback_event", params: GuideFeedbackSyncPayload(feedback: feedback))
            .execute()
    }

    func fetchGuideFeedback(limit: Int = 80) async throws -> [GuideFeedback] {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return [] }
        let rows: [GuideFeedbackEventData] = try await client
            .from("guide_feedback_events")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.compactMap(\.localFeedback)
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
            .from("public_profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value
        return profiles.first
    }

    func upsertSocialProfile(_ profile: SocialProfile) async throws {
        let client = try configuredClient()
        try await client.from("public_profiles").upsert(profile).execute()
    }

    func fetchVisibleSocialProfiles() async throws -> [SocialProfile] {
        let client = try configuredClient()
        return try await client
            .from("public_profiles")
            .select()
            .eq("is_discoverable", value: true)
            .not("username", operator: .is, value: "null")
            .order("updated_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    func searchPublicProfiles(query rawQuery: String) async throws -> [PublicProfile] {
        let client = try configuredClient()
        let query = PublicProfile.normalizedUsername(rawQuery)
        guard !query.isEmpty else {
            return try await fetchVisibleSocialProfiles()
        }

        return try await client
            .from("public_profiles")
            .select()
            .eq("is_discoverable", value: true)
            .not("username", operator: .is, value: "null")
            .ilike("username", pattern: "\(query)%")
            .order("username", ascending: true)
            .limit(25)
            .execute()
            .value
    }

    func fetchUserConnections() async throws -> [UserConnectionData] {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return [] }
        return try await client
            .from("user_connections")
            .select()
            .eq("owner_id", value: userId.uuidString)
            .execute()
            .value
    }

    func fetchConnectedProfiles() async throws -> [PublicProfile] {
        let client = try configuredClient()
        let connections = try await fetchUserConnections()
        let profileIds = connections.map(\.profileId)
        guard !profileIds.isEmpty else { return [] }
        return try await client
            .from("public_profiles")
            .select()
            .or(uuidOrFilter(column: "id", ids: profileIds))
            .eq("is_discoverable", value: true)
            .not("username", operator: .is, value: "null")
            .execute()
            .value
    }

    func addUserConnection(profileId: UUID) async throws {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return }
        let connection = UserConnectionData(ownerId: userId, profileId: profileId, createdAt: Date())
        try await client.from("user_connections").insert(connection).execute()
    }

    func removeUserConnection(profileId: UUID) async throws {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return }
        try await client.from("user_connections")
            .delete()
            .eq("owner_id", value: userId.uuidString)
            .eq("profile_id", value: profileId.uuidString)
            .execute()
    }

    func uploadAvatar(data: Data, fileExtension: String = "jpg", contentType: String = "image/jpeg") async throws -> String {
        let client = try configuredClient()
        guard let userId = await currentUserId else { throw SupabaseServiceError.missingSession }
        let path = Self.avatarStoragePath(userId: userId, fileExtension: fileExtension)
        let bucket = client.storage.from("avatars")
        try await bucket.upload(path, data: data, options: FileOptions(contentType: contentType, upsert: true))
        return try bucket.getPublicURL(path: path, cacheNonce: UUID().uuidString).absoluteString
    }

    func deleteSocialProfile(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("public_profiles")
            .delete()
            .eq("id", value: userId)
            .execute()
    }

    func deleteDiscoveryMessages(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("discovery_messages")
            .delete()
            .or("sender_id.eq.\(userId),recipient_id.eq.\(userId)")
            .execute()
    }

    func deleteDiscoveryBlocks(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("discovery_blocks")
            .delete()
            .or("blocker_id.eq.\(userId),blocked_id.eq.\(userId)")
            .execute()
    }

    func deleteDiscoveryReports(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("discovery_reports")
            .delete()
            .or("reporter_id.eq.\(userId),reported_id.eq.\(userId)")
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

    // MARK: - Guided Rooms

    func fetchChatThreadMembershipsForCurrentUser() async throws -> [ChatThreadMember] {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return [] }
        return try await client
            .from("chat_thread_members")
            .select()
            .eq("member_kind", value: ChatMemberKind.human.rawValue)
            .eq("human_user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .execute()
            .value
    }

    func fetchChatThreads(threadIds: [UUID]) async throws -> [ChatThread] {
        let client = try configuredClient()
        guard !threadIds.isEmpty else { return [] }
        return try await client
            .from("chat_threads")
            .select()
            .or(uuidOrFilter(column: "id", ids: threadIds))
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func fetchChatThreadMembers(threadIds: [UUID]) async throws -> [ChatThreadMember] {
        let client = try configuredClient()
        guard !threadIds.isEmpty else { return [] }
        return try await client
            .from("chat_thread_members")
            .select()
            .or(uuidOrFilter(column: "thread_id", ids: threadIds))
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func fetchChatMessages(threadIds: [UUID]) async throws -> [ChatMessage] {
        let client = try configuredClient()
        guard !threadIds.isEmpty else { return [] }
        return try await client
            .from("chat_messages")
            .select()
            .or(uuidOrFilter(column: "thread_id", ids: threadIds))
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func fetchChatMessages(threadId: UUID) async throws -> [ChatMessage] {
        let client = try configuredClient()
        return try await client
            .from("chat_messages")
            .select()
            .eq("thread_id", value: threadId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func createChatThread(
        thread: ChatThread,
        members: [ChatThreadMember],
        openingMessage: ChatMessage?
    ) async throws {
        let client = try configuredClient()
        try await client.from("chat_threads").insert(thread).execute()
        try await client.from("chat_thread_members").insert(members).execute()
        if let openingMessage {
            try await client.from("chat_messages").insert(openingMessage).execute()
        }
    }

    func sendChatMessage(_ message: ChatMessage) async throws {
        let client = try configuredClient()
        try await client.from("chat_messages").insert(message).execute()
    }

    func markChatThreadRead(threadId: UUID) async throws {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return }
        try await client.from("chat_thread_members")
            .update(["last_read_at": ISO8601DateFormatter().string(from: Date())])
            .eq("thread_id", value: threadId.uuidString)
            .eq("member_kind", value: ChatMemberKind.human.rawValue)
            .eq("human_user_id", value: userId.uuidString)
            .execute()
    }

    func leaveChatThread(threadId: UUID) async throws {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return }
        try await client.from("chat_thread_members")
            .update(["is_active": false])
            .eq("thread_id", value: threadId.uuidString)
            .eq("member_kind", value: ChatMemberKind.human.rawValue)
            .eq("human_user_id", value: userId.uuidString)
            .execute()
    }

    func reportChatThread(_ report: ChatReportData) async throws {
        let client = try configuredClient()
        try await client.from("chat_reports").insert(report).execute()
    }

    func invokeRoomGuideReply(threadId: UUID, guideProfileId: String) async throws -> ChatMessage? {
        let client = try configuredClient()
        let payload = RoomGuideReplyRequest(
            threadId: threadId,
            guideProfileId: guideProfileId,
            maxTokens: 360
        )
        let response: RoomGuideReplyResponse = try await client.functions.invoke(
            "room-guide-reply",
            options: FunctionInvokeOptions(body: payload)
        )
        return response.message
    }

    private func configuredClient() throws -> SupabaseClient {
        guard let client, isConfigured else {
            throw SupabaseServiceError.notConfigured
        }
        return client
    }

    private func uuidOrFilter(column: String, ids: [UUID]) -> String {
        ids.map { "\(column).eq.\($0.uuidString)" }.joined(separator: ",")
    }
}

// MARK: - Companion Reply Channel

nonisolated enum CompanionReplyKind: String, Sendable {
    case prediction
    case chat
}

nonisolated enum CompanionReplyFeature: String, CaseIterable, Encodable, Sendable {
    case panelChat = "panel_chat"
    case companionChat = "companion_chat"
    case prediction
    case practice
    case playbook
    case momentComment = "moment_comment"
}

nonisolated struct CompanionReplyPayload: Encodable, Sendable {
    let kind: String
    let feature: String
    let system: String
    let user: String
    let maxTokens: Int
}

nonisolated struct CompanionReplyResult: Equatable, Sendable {
    let text: String
    let usageEventId: UUID?
}

nonisolated struct CompanionReplyResponse: Decodable, Sendable {
    let text: String
    let usageEventId: UUID?
}

nonisolated private struct CompanionReplyErrorEnvelope: Decodable, Sendable {
    struct Body: Decodable, Sendable {
        let code: String?
        let message: String?
    }

    let error: Body?

    static func message(from data: Data) -> String? {
        guard let envelope = try? JSONDecoder().decode(Self.self, from: data) else {
            return nil
        }
        return envelope.error?.message
    }
}
