import Foundation
import Supabase

nonisolated enum SupabaseServiceError: LocalizedError, Sendable {
    case notConfigured
    case invalidRedirectURL
    case missingSession
    case profileMismatch
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
        case .profileMismatch:
            "This profile belongs to a different signed-in account."
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
    static let companionReplyRequestTimeout: TimeInterval = 12
    /// Idle timeout for SSE streaming. URLSession resets this on each received
    /// chunk, so it bounds first-token latency and inter-token gaps, not the
    /// total stream duration.
    static let companionReplyStreamRequestTimeout: TimeInterval = 30
    static let zodiacsWalletLookupTimeout: TimeInterval = 16
    private static let deviceIdKey = "simastry_backend_device_id"

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

        #if DEBUG
        if DebugSupabaseOverride.isActive {
            print("[Simastry] DEBUG Supabase override active → \(rawURL)")
        }
        #endif

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
        system: String?,
        user: String?,
        maxTokens: Int = 1024,
        expertAstrologerRequest: ExpertAstrologerReplyService.Request? = nil
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
            maxTokens: maxTokens,
            expertAstrologerRequest: expertAstrologerRequest,
            stream: nil
        )
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.companionReplyRequestTimeout
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.backendDeviceId, forHTTPHeaderField: "X-Simastry-Device-Id")
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

    func fetchZodiacsWalletHoldings(for address: String) async throws -> AuraWalletHoldings {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AuraWalletHoldings.isSupportedPublicWalletAddress(trimmed) else {
            throw ZodiacsWalletServiceError.unsupportedAddress
        }

        let client = try configuredClient()
        guard let session = client.auth.currentSession else {
            throw SupabaseServiceError.missingSession
        }
        guard let url = URL(string: "\(AppConfig.supabaseURL)/functions/v1/zodiacs-wallet-lookup") else {
            throw SupabaseServiceError.notConfigured
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.zodiacsWalletLookupTimeout
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.backendDeviceId, forHTTPHeaderField: "X-Simastry-Device-Id")
        request.httpBody = try JSONEncoder().encode(ZodiacsWalletLookupRequest(publicAddress: trimmed))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseServiceError.invalidFunctionResponse
        }

        if http.statusCode == 429 {
            throw SupabaseServiceError.functionFailed(
                CompanionReplyErrorEnvelope.message(from: data)
                    ?? "Wallet lookup is being used quickly. Please wait and try again."
            )
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = CompanionReplyErrorEnvelope.message(from: data)
                ?? "Wallet lookup is unavailable right now."
            if message.localizedCaseInsensitiveContains("registry") {
                throw ZodiacsWalletServiceError.registryUnavailable
            }
            if message.localizedCaseInsensitiveContains("wallet balance")
                || message.localizedCaseInsensitiveContains("lookup") {
                throw ZodiacsWalletServiceError.rpcUnavailable
            }
            throw SupabaseServiceError.functionFailed(message)
        }

        let decoded = try JSONDecoder().decode(ZodiacsWalletLookupResponse.self, from: data)
        let counts = decoded.zodiacCounts.reduce(into: [ZodiacSign: Int]()) { partial, pair in
            guard let sign = ZodiacSign(rawValue: pair.key.lowercased()), pair.value > 0 else { return }
            partial[sign] = pair.value
        }
        return AuraWalletHoldings(publicAddress: decoded.publicAddress, zodiacCounts: counts)
    }

    func invokeExpertAstrologerReply(
        request expertRequest: ExpertAstrologerReplyService.Request,
        maxTokens: Int = 520
    ) async throws -> String {
        try await invokeCompanionReplyResult(
            kind: .chat,
            feature: .expertAstrologer,
            system: nil,
            user: nil,
            maxTokens: maxTokens,
            expertAstrologerRequest: expertRequest
        ).text
    }

    /// Streams an expert-astrologer reply over Server-Sent Events. The caller
    /// renders `delta` text incrementally and finalizes on `done`; `meta` and
    /// `error` carry usage/identity and failure info respectively.
    func streamExpertAstrologerReply(
        request expertRequest: ExpertAstrologerReplyService.Request,
        maxTokens: Int = 520
    ) -> AsyncThrowingStream<CompanionReplyStreamEvent, Error> {
        streamCompanionReply(
            kind: .chat,
            feature: .expertAstrologer,
            maxTokens: maxTokens,
            expertAstrologerRequest: expertRequest
        )
    }

    /// POSTs to `companion-reply` with `Accept: text/event-stream` (and
    /// `stream: true`) and yields decoded SSE frames. Only assistant `delta`
    /// text and the `meta`/`done`/`error` envelopes are surfaced — never raw
    /// prompts, hidden reasoning, or provider metadata.
    func streamCompanionReply(
        kind: CompanionReplyKind,
        feature: CompanionReplyFeature,
        maxTokens: Int,
        system: String? = nil,
        user: String? = nil,
        expertAstrologerRequest: ExpertAstrologerReplyService.Request? = nil
    ) -> AsyncThrowingStream<CompanionReplyStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
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
                        maxTokens: maxTokens,
                        expertAstrologerRequest: expertAstrologerRequest,
                        stream: true
                    )
                    var request = URLRequest(url: url)
                    request.timeoutInterval = Self.companionReplyStreamRequestTimeout
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
                    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                    request.setValue(Self.backendDeviceId, forHTTPHeaderField: "X-Simastry-Device-Id")
                    request.httpBody = try JSONEncoder().encode(payload)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw SupabaseServiceError.invalidFunctionResponse
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        if http.statusCode == 429 {
                            throw SupabaseServiceError.aiUsageLimit("You have reached today's AI guide limit.")
                        }
                        throw SupabaseServiceError.functionFailed(
                            "The expert is unavailable right now. Please try again."
                        )
                    }

                    var eventName = ""
                    var dataLines: [String] = []
                    func flush() {
                        defer { eventName = ""; dataLines = [] }
                        guard !dataLines.isEmpty else { return }
                        if let event = Self.parseSSE(event: eventName, data: dataLines.joined(separator: "\n")) {
                            continuation.yield(event)
                        }
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if line.isEmpty {
                            flush()
                        } else if line.hasPrefix(":") {
                            continue // SSE comment / keep-alive
                        } else if line.hasPrefix("event:") {
                            eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            var value = String(line.dropFirst(5))
                            if value.hasPrefix(" ") { value.removeFirst() }
                            dataLines.append(value)
                        }
                    }
                    flush() // emit a trailing frame that had no blank-line terminator
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func parseSSE(event: String, data: String) -> CompanionReplyStreamEvent? {
        guard let payload = data.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        switch event {
        case "meta":
            let frame = try? decoder.decode(SSEMetaFrame.self, from: payload)
            return .meta(
                usageEventId: frame?.usageEventId,
                specialistId: frame?.specialistId,
                mode: frame?.mode
            )
        case "delta":
            guard let frame = try? decoder.decode(SSEDeltaFrame.self, from: payload) else { return nil }
            return .delta(frame.text)
        case "done":
            let frame = try? decoder.decode(SSEDoneFrame.self, from: payload)
            return .done(text: frame?.text ?? "", usageEventId: frame?.usageEventId)
        case "error":
            let frame = try? decoder.decode(SSEErrorFrame.self, from: payload)
            return .error(
                code: frame?.code,
                message: frame?.message ?? "The expert is unavailable right now. Please try again."
            )
        default:
            return nil
        }
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

    func fetchExpertAstrologerMessages(limit: Int = 500) async throws -> [SpecialistMessage] {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return [] }
        let rows: [ExpertAstrologerMessageRecord] = try await client
            .from("expert_astrologer_messages")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: true)
            .limit(limit)
            .execute()
            .value
        return rows.compactMap(\.localMessage)
    }

    func fetchExpertAstrologerConsultationResponses(limit: Int = 160) async throws -> [SpecialistConsultationResponse] {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return [] }
        let rows: [ExpertAstrologerConsultationResponseRecord] = try await client
            .from("expert_astrologer_consultation_responses")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: true)
            .limit(limit)
            .execute()
            .value
        return rows.compactMap(\.localResponse)
    }

    func upsertExpertAstrologerMessages(_ messages: [SpecialistMessage]) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        let individualMessages = messages.filter { $0.mode == .individual }
        guard !individualMessages.isEmpty else { return }

        let conversations = Dictionary(grouping: individualMessages, by: \.conversationId)
            .compactMap { conversationId, messages -> ExpertAstrologerConversationRecord? in
                guard let first = messages.first else { return nil }
                return ExpertAstrologerConversationRecord(
                    id: conversationId,
                    userId: userId,
                    specialistId: first.specialistId,
                    createdAt: messages.map(\.timestamp).min() ?? Date(),
                    updatedAt: Date(),
                    lastMessageAt: messages.map(\.timestamp).max()
                )
            }
        let records = individualMessages.map { ExpertAstrologerMessageRecord(userId: userId, message: $0) }

        try await client.from("expert_astrologer_conversations").upsert(conversations).execute()
        try await client.from("expert_astrologer_messages").upsert(records).execute()
    }

    func upsertExpertAstrologerConsultation(
        id: UUID,
        userQuestion: String,
        profileContextSummary: String?
    ) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        let record = ExpertAstrologerConsultationRecord(
            id: id,
            userId: userId,
            userQuestion: userQuestion,
            profileContextSummary: profileContextSummary
        )
        try await client.from("expert_astrologer_consultations").upsert(record).execute()
    }

    func upsertExpertAstrologerConsultationResponses(_ responses: [SpecialistConsultationResponse]) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        guard !responses.isEmpty else { return }

        let consultations = Dictionary(grouping: responses, by: \.multiConsultationId)
            .compactMap { consultationId, responses -> ExpertAstrologerConsultationRecord? in
                guard let first = responses.first else { return nil }
                return ExpertAstrologerConsultationRecord(
                    id: consultationId,
                    userId: userId,
                    userQuestion: first.userQuestion,
                    profileContextSummary: first.profileContextSummary,
                    createdAt: responses.map(\.timestamp).min() ?? Date(),
                    updatedAt: Date()
                )
            }
        let records = responses.map { ExpertAstrologerConsultationResponseRecord(userId: userId, response: $0) }

        try await client.from("expert_astrologer_consultations").upsert(consultations).execute()
        try await client.from("expert_astrologer_consultation_responses").upsert(records).execute()
    }

    // MARK: - Expert Astrology Intake

    /// Loads the signed-in user's single intake row, if any. RLS limits the
    /// result to the current user.
    func fetchExpertAstrologyIntake() async throws -> ExpertAstrologyIntakeRecord? {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return nil }
        let rows: [ExpertAstrologyIntakeRecord] = try await client
            .from("expert_astrology_intake")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Upserts the user's intake snapshot. The backend reads this row to hydrate
    /// expert-astrologer prompts.
    func upsertExpertAstrologyIntake(_ record: ExpertAstrologyIntakeRecord) async throws {
        let client = try configuredClient()
        _ = try await requireCurrentUserId(matching: record.userId)
        try await client
            .from("expert_astrology_intake")
            .upsert(record, onConflict: "user_id")
            .execute()
    }

    func deleteExpertAstrologyIntake(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("expert_astrology_intake")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Expert Astrology Chart Imports

    /// Uploads a chart screenshot to the private `expert-astrology-charts`
    /// bucket. `path` must start with the lowercased user id (RLS + table checks).
    func uploadExpertChartImage(data: Data, contentType: String, path: String) async throws {
        let client = try configuredClient()
        let bucket = client.storage.from(ExpertChartImportRecord.bucket)
        try await bucket.upload(path, data: data, options: FileOptions(contentType: contentType, upsert: false))
    }

    func insertExpertChartImport(_ record: ExpertChartImportRecord) async throws {
        let client = try configuredClient()
        _ = try await requireCurrentUserId(matching: record.userId)
        try await client.from("expert_astrology_chart_imports").insert(record).execute()
    }

    /// Moves user-confirmed fields into `confirmed_data` and flips the row to
    /// `confirmed`. `extracted_data` is never written from the client.
    func confirmExpertChartImport(id: UUID, confirmedData: [String: String]) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        let payload = ExpertChartImportConfirmation(
            confirmed_data: confirmedData,
            status: ExpertChartImportStatus.confirmed.rawValue
        )
        try await client.from("expert_astrology_chart_imports")
            .update(payload)
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    /// All of the user's chart imports, newest first, so the client can resolve
    /// the latest import per subject locally in a single round-trip.
    func fetchExpertChartImports(limit: Int = 200) async throws -> [ExpertChartImportRecord] {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return [] }
        return try await client.from("expert_astrology_chart_imports")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func upsertPersonAstrologyIntake(_ record: ExpertPersonAstrologyIntakeRecord) async throws {
        let client = try configuredClient()
        _ = try await requireCurrentUserId(matching: record.userId)
        try await client.from("expert_person_astrology_intake")
            .upsert(record, onConflict: "user_id,person_id")
            .execute()
    }

    func deletePersonAstrologyIntake(personId: UUID) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        try await client.from("expert_person_astrology_intake")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("person_id", value: personId.uuidString)
            .execute()
    }

    /// Best-effort removal of a user's uploaded chart screenshots. The DB rows
    /// cascade on auth-user deletion; this clears the private storage objects too.
    func deleteExpertChartImages(for userId: String) async {
        guard let client = try? configuredClient() else { return }
        let bucket = client.storage.from(ExpertChartImportRecord.bucket)
        let owner = userId.lowercased()
        var paths: [String] = []
        if let selfFiles = try? await bucket.list(path: "\(owner)/self") {
            paths += selfFiles.map { "\(owner)/self/\($0.name)" }
        }
        if let peopleDirs = try? await bucket.list(path: "\(owner)/people") {
            for dir in peopleDirs {
                if let files = try? await bucket.list(path: "\(owner)/people/\(dir.name)") {
                    paths += files.map { "\(owner)/people/\(dir.name)/\($0.name)" }
                }
            }
        }
        if !paths.isEmpty {
            _ = try? await bucket.remove(paths: paths)
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

    func deleteGuideFeedback(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("guide_feedback_events")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteExpertAstrologerData(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("expert_astrology_intake")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        try await client.from("expert_person_astrology_intake")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        try await client.from("expert_astrology_chart_imports")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        try await client.from("expert_astrologer_consultation_responses")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        try await client.from("expert_astrologer_consultations")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        try await client.from("expert_astrologer_messages")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        try await client.from("expert_astrologer_conversations")
            .delete()
            .eq("user_id", value: userId)
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
        let userId = try await requireCurrentUserId()
        let connection = UserConnectionData(ownerId: userId, profileId: profileId, createdAt: Date())
        try await client.from("user_connections").insert(connection).execute()
    }

    func removeUserConnection(profileId: UUID) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
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

    func deleteAvatarFiles(for userId: String) async throws {
        let client = try configuredClient()
        let paths = ["jpg", "jpeg", "png", "heic", "webp"].map { "\(userId)/profile.\($0)" }
        _ = try await client.storage.from("avatars").remove(paths: paths)
    }

    func deleteSocialProfile(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("public_profiles")
            .delete()
            .eq("id", value: userId)
            .execute()
    }

    func deleteUserConnections(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("user_connections")
            .delete()
            .or("owner_id.eq.\(userId),profile_id.eq.\(userId)")
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
        let userId = try await requireCurrentUserId()

        let block = DiscoveryBlockData(
            blockerId: userId,
            blockedId: blockedId,
            createdAt: Date()
        )

        try await client.from("discovery_blocks").upsert(block).execute()
    }

    func reportDiscoveryProfile(_ report: DiscoveryReportData) async throws {
        let client = try configuredClient()
        _ = try await requireCurrentUserId(matching: report.reporterId)
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
        _ = try await requireCurrentUserId(matching: message.senderId)
        try await client.from("discovery_messages").insert(message).execute()
    }

    func markDiscoveryConversationRead(with participantId: UUID) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        try await client.from("discovery_messages")
            .update(["is_read": true])
            .eq("recipient_id", value: userId.uuidString)
            .eq("sender_id", value: participantId.uuidString)
            .execute()
    }

    func deleteDiscoveryConversation(with participantId: UUID) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
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
        _ = try await requireCurrentUserId(matching: thread.creatorId)
        try await client.from("chat_threads").insert(thread).execute()
        try await client.from("chat_thread_members").insert(members).execute()
        if let openingMessage {
            try await client.from("chat_messages").insert(openingMessage).execute()
        }
    }

    func sendChatMessage(_ message: ChatMessage) async throws {
        let client = try configuredClient()
        _ = try await requireCurrentUserId(matching: message.createdBy)
        try await client.from("chat_messages").insert(message).execute()
    }

    func markChatThreadRead(threadId: UUID) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        try await client.from("chat_thread_members")
            .update(["last_read_at": ISO8601DateFormatter().string(from: Date())])
            .eq("thread_id", value: threadId.uuidString)
            .eq("member_kind", value: ChatMemberKind.human.rawValue)
            .eq("human_user_id", value: userId.uuidString)
            .execute()
    }

    func leaveChatThread(threadId: UUID) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        try await client.from("chat_thread_members")
            .update(["is_active": false])
            .eq("thread_id", value: threadId.uuidString)
            .eq("member_kind", value: ChatMemberKind.human.rawValue)
            .eq("human_user_id", value: userId.uuidString)
            .execute()
    }

    func reportChatThread(_ report: ChatReportData) async throws {
        let client = try configuredClient()
        _ = try await requireCurrentUserId(matching: report.reporterId)
        try await client.from("chat_reports").insert(report).execute()
    }

    func deleteGuidedRoomData(for userId: String) async throws {
        let client = try configuredClient()
        try await client.from("chat_messages")
            .delete()
            .or("sender_user_id.eq.\(userId),created_by.eq.\(userId)")
            .execute()
        try await client.from("chat_reports")
            .delete()
            .eq("reporter_id", value: userId)
            .execute()
        try await client.from("chat_thread_members")
            .delete()
            .eq("human_user_id", value: userId)
            .execute()
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

    private func requireCurrentUserId(matching expectedUserId: UUID? = nil) async throws -> UUID {
        guard let userId = await currentUserId else {
            throw SupabaseServiceError.missingSession
        }
        if let expectedUserId, expectedUserId != userId {
            throw SupabaseServiceError.profileMismatch
        }
        return userId
    }

    private func uuidOrFilter(column: String, ids: [UUID]) -> String {
        ids.map { "\(column).eq.\($0.uuidString)" }.joined(separator: ",")
    }

    private static var backendDeviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: deviceIdKey)
        return generated
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
    case dailyDecision = "daily_decision"
    case expertAstrologer = "expert_astrologer"
}

nonisolated struct CompanionReplyPayload: Encodable, Sendable {
    let kind: String
    let feature: String
    let system: String?
    let user: String?
    let maxTokens: Int
    let expertAstrologerRequest: ExpertAstrologerReplyService.Request?
    /// Opts the request into SSE streaming. Omitted (nil) for plain JSON calls,
    /// so existing non-streaming payloads encode exactly as before.
    let stream: Bool?
}

nonisolated struct CompanionReplyResult: Equatable, Sendable {
    let text: String
    let usageEventId: UUID?
}

/// A decoded Server-Sent Event from `companion-reply`. Carries only assistant
/// text and the surrounding envelope — never chain-of-thought or provider data.
nonisolated enum CompanionReplyStreamEvent: Equatable, Sendable {
    case meta(usageEventId: UUID?, specialistId: String?, mode: String?)
    case delta(String)
    case done(text: String, usageEventId: UUID?)
    case error(code: String?, message: String)
}

private struct SSEMetaFrame: Decodable {
    let usageEventId: UUID?
    let specialistId: String?
    let mode: String?
}

private struct SSEDeltaFrame: Decodable {
    let text: String
}

private struct SSEDoneFrame: Decodable {
    let text: String?
    let usageEventId: UUID?
}

private struct SSEErrorFrame: Decodable {
    let code: String?
    let message: String?
}

nonisolated struct CompanionReplyResponse: Decodable, Sendable {
    let text: String
    let usageEventId: UUID?
}

nonisolated private struct ZodiacsWalletLookupRequest: Encodable, Sendable {
    let publicAddress: String
}

nonisolated private struct ZodiacsWalletLookupResponse: Decodable, Sendable {
    let publicAddress: String
    let zodiacCounts: [String: Int]
    let checkedAt: String?

    enum CodingKeys: String, CodingKey {
        case publicAddress
        case zodiacCounts
        case checkedAt
    }
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
