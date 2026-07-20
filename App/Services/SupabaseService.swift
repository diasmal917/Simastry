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

    var canInvokeCompanionTools: Bool {
        isConfigured && client?.auth.currentSession != nil
    }

    /// Remote rollback gate: an operator can suspend any pilot persona row.
    /// An incomplete certified quartet is cached as a rollback signal for the
    /// current and next launch. Schema/network failures preserve the old cache.
    func fetchCompanionPilotRollbackFlag() async throws -> Bool {
        let client = try configuredClient()
        let rows: [ReleasedCompanionPersonaID] = try await client
            .from("companion_personas")
            .select("id")
            .execute()
            .value
        let released = Set(rows.map { CompanionPersonaID(rawValue: $0.id) })
        return !CompanionPersonaRegistry.pilotIDs.isSubset(of: released)
    }

    /// Restores server-owned relationship and Talk state on every authenticated
    /// device. Third-party People records, memories, and outcomes are fetched
    /// only after this device has explicit private-sync consent.
    func fetchCompanionPilotSnapshot(includePrivateRecords: Bool) async throws -> CompanionServerSnapshot {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()

        let relationshipRows: [CompanionRelationshipSnapshotRow] = try await client
            .from("user_companion_relationships")
            .select("id,user_id,companion_id,status,is_primary,support_preferences,last_interaction_at,created_at,updated_at")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        let relationships = relationshipRows.compactMap { $0.model(currentUserId: userId) }

        let conversationRows: [CompanionConversationSnapshotRow] = try await client
            .from("companion_conversations")
            .select("id,user_id,companion_id,status,created_at,updated_at")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        let conversations = conversationRows.compactMap { $0.model(currentUserId: userId) }
        let conversationIDs = Set(conversations.map(\.id))

        let messageRows: [CompanionMessageSnapshotRow] = try await client
            .from("companion_messages")
            .select("id,conversation_id,user_id,companion_id,client_message_id,role,content,delivery_state,model_version,created_at")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        let messages = messageRows.compactMap {
            $0.model(currentUserId: userId, authorizedConversationIDs: conversationIDs)
        }

        var snapshot = CompanionServerSnapshot(
            relationships: relationships,
            conversations: conversations,
            messages: messages
        )
        guard includePrivateRecords else { return snapshot }

        let peopleRows: [RelationshipPersonSnapshotRow] = try await client
            .from("relationship_people")
            .select("id,user_id,display_name,relationship_kind,pronouns,birth_date,birth_time,birth_place,birth_chart,notes,communication_guide,archived_at,updated_at")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        snapshot.people = peopleRows.compactMap { $0.model(currentUserId: userId) }

        let memoryRows: [CompanionMemorySnapshotRow] = try await client
            .from("companion_memories")
            .select("id,user_id,scope,companion_id,content,source,source_id,deleted_at,created_at,updated_at")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        snapshot.memories = memoryRows.compactMap { $0.model(currentUserId: userId) }

        let outcomeRows: [CommunicationOutcomeSnapshotRow] = try await client
            .from("communication_outcomes")
            .select("client_outcome_id,user_id,companion_id,person_id,action_text,result_kind,result_summary,follow_up_state,acted_at,result_recorded_at,created_at")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        snapshot.outcomes = outcomeRows.compactMap { $0.model(currentUserId: userId) }
        return snapshot
    }

    /// Uploads exact-slug legacy threads through the authenticated, idempotent
    /// migration endpoint. Local history is retained unless every server count
    /// is verified against the submitted batch.
    func migrateLegacyCompanionThreads(
        _ threads: [CompanionLegacyThreadMigration]
    ) async throws -> [UUID: UUID] {
        guard !threads.isEmpty else { return [:] }
        let client = try configuredClient()
        guard let session = client.auth.currentSession else {
            throw SupabaseServiceError.missingSession
        }
        guard let url = URL(string: "\(AppConfig.supabaseURL)/functions/v1/companion-migrate") else {
            throw SupabaseServiceError.notConfigured
        }

        var serverConversationIDs: [UUID: UUID] = [:]
        for thread in threads {
            let payload = CompanionMigrationPayload(
                companionId: thread.companionId.rawValue,
                migrationVersion: CompanionPivotState.currentMigrationVersion,
                syncConsent: true,
                conversations: thread.conversations
            )
            var request = URLRequest(url: url)
            request.timeoutInterval = Self.companionReplyStreamRequestTimeout
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
            guard (200..<300).contains(http.statusCode) else {
                throw SupabaseServiceError.functionFailed(
                    CompanionReplyErrorEnvelope.message(from: data)
                        ?? "Your previous companion history could not be synced yet. It remains on this device."
                )
            }
            let result = try JSONDecoder().decode(CompanionMigrationResponse.self, from: data)
            let submittedMessages = thread.conversations.reduce(0) { $0 + $1.messages.count }
            guard result.companionId == thread.companionId.rawValue,
                  result.migrationVersion == CompanionPivotState.currentMigrationVersion,
                  result.counts.conversationsImported + result.counts.conversationsExisting
                    == thread.conversations.count,
                  result.counts.messagesImported + result.counts.messagesExisting
                    == submittedMessages,
                  result.conversations.count == thread.conversations.count else {
                throw SupabaseServiceError.invalidFunctionResponse
            }
            let submittedConversationIDs = Set(thread.conversations.map(\.legacyConversationId))
            let mappedConversationIDs = Set(result.conversations.map(\.legacyConversationId))
            guard submittedConversationIDs == mappedConversationIDs else {
                throw SupabaseServiceError.invalidFunctionResponse
            }
            for mapping in result.conversations {
                guard mapping.importedMessages + mapping.existingMessages
                        == thread.conversations.first(where: {
                            $0.legacyConversationId == mapping.legacyConversationId
                        })?.messages.count,
                      serverConversationIDs[mapping.legacyConversationId] == nil else {
                    throw SupabaseServiceError.invalidFunctionResponse
                }
                serverConversationIDs[mapping.legacyConversationId] = mapping.conversationId
            }
        }
        return serverConversationIDs
    }

    /// Mirrors the user-owned pilot state into the separate companion schema.
    /// Relationships are needed by the chat runtime and sync for every signed-in
    /// user. Existing device-local People, memories, and outcomes cross the
    /// device boundary only after the explicit private-sync consent.
    func syncCompanionPilotData(
        relationships: [CompanionRelationship],
        people: [RelationshipPerson],
        memories: [CompanionMemoryItem],
        outcomes: [CommunicationOutcome],
        includePrivateRecords: Bool
    ) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()

        let existingRelationships: [CompanionExistingRelationship] = try await client
            .from("user_companion_relationships")
            .select("id,companion_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        var serverRelationshipIDs = Dictionary(
            uniqueKeysWithValues: existingRelationships.compactMap { row in
                row.companionId.map { (CompanionPersonaID(rawValue: $0), row.id) }
            }
        )

        // Clear the old remote primary first so switching cannot trip the
        // database's one-primary partial unique index mid-sync. An empty local
        // cache (for example, a fresh device before hydration) must never clear
        // the server's already-selected primary.
        if relationships.contains(where: \.isPrimary) {
            try await client
                .from("user_companion_relationships")
                .update(CompanionClearPrimaryUpdate(isPrimary: false))
                .eq("user_id", value: userId.uuidString)
                .eq("is_primary", value: true)
                .execute()
        }

        for relationship in relationships.sorted(by: { !$0.isPrimary && $1.isPrimary }) {
            if let serverRelationshipId = serverRelationshipIDs[relationship.companionId] {
                try await client
                    .from("user_companion_relationships")
                    .update(CompanionRelationshipUpdate(
                        status: "active",
                        isPrimary: relationship.isPrimary,
                        supportPreferences: relationship.preferences,
                        lastInteractionAt: relationship.updatedAt
                    ))
                    .eq("id", value: serverRelationshipId.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
            } else {
                try await client
                    .from("user_companion_relationships")
                    .insert(CompanionRelationshipInsert(
                        id: relationship.id,
                        userId: userId,
                        companionId: relationship.companionId.rawValue,
                        status: "active",
                        isPrimary: relationship.isPrimary,
                        supportPreferences: relationship.preferences,
                        lastInteractionAt: relationship.updatedAt
                    ))
                    .execute()
                serverRelationshipIDs[relationship.companionId] = relationship.id
            }
        }

        guard includePrivateRecords else { return }

        let existingPeople: [CompanionExistingID] = try await client
            .from("relationship_people")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        let existingPeopleIDs = Set(existingPeople.map(\.id))
        let consentedAt = Date()

        for person in people {
            let mutable = RelationshipPersonUpdate(person: person)
            if existingPeopleIDs.contains(person.id) {
                try await client
                    .from("relationship_people")
                    .update(mutable)
                    .eq("id", value: person.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
            } else {
                try await client
                    .from("relationship_people")
                    .insert(RelationshipPersonInsert(
                        id: person.id,
                        userId: userId,
                        mutable: mutable,
                        legacyRecordId: person.id.uuidString,
                        migrationVersion: CompanionPivotState.currentMigrationVersion,
                        syncConsentAt: consentedAt
                    ))
                    .execute()
            }
        }

        let existingMemories: [CompanionExistingID] = try await client
            .from("companion_memories")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        let existingMemoryIDs = Set(existingMemories.map(\.id))

        for memory in memories {
            guard let insert = CompanionMemoryInsert(
                memory: memory,
                userId: userId,
                relationshipIDsByCompanion: serverRelationshipIDs,
                consentedAt: consentedAt
            ) else { continue }
            if existingMemoryIDs.contains(memory.id) {
                try await client
                    .from("companion_memories")
                    .update(CompanionMemoryUpdate(content: memory.content))
                    .eq("id", value: memory.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
            } else {
                try await client.from("companion_memories").insert(insert).execute()
            }
        }

        let existingOutcomes: [CompanionExistingOutcome] = try await client
            .from("communication_outcomes")
            .select("client_outcome_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        let existingOutcomeIDs = Set(existingOutcomes.map(\.clientOutcomeId))

        for outcome in outcomes {
            guard let relationshipId = serverRelationshipIDs[outcome.companionId] else { continue }
            let mutable = CommunicationOutcomeUpdate(outcome: outcome)
            if existingOutcomeIDs.contains(outcome.id) {
                try await client
                    .from("communication_outcomes")
                    .update(mutable)
                    .eq("client_outcome_id", value: outcome.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
            } else {
                try await client
                    .from("communication_outcomes")
                    .insert(CommunicationOutcomeInsert(
                        id: outcome.id,
                        clientOutcomeId: outcome.id,
                        userId: userId,
                        companionId: outcome.companionId.rawValue,
                        relationshipId: relationshipId,
                        personId: outcome.personId,
                        mutable: mutable
                    ))
                    .execute()
            }
        }
    }

    func deleteSyncedCompanionMemory(id: UUID) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        try await client.from("companion_memories")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func deleteSyncedRelationshipPerson(id: UUID) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        try await client.from("relationship_people")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func deleteSyncedCommunicationOutcome(clientOutcomeId: UUID) async throws {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        try await client.from("communication_outcomes")
            .delete()
            .eq("client_outcome_id", value: clientOutcomeId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    /// Atomically removes the authenticated user's primary-companion data.
    /// The server function is auth.uid()-scoped and leaves the public persona
    /// catalog and legacy expert archive untouched.
    func deleteCurrentUserCompanionData() async throws {
        let client = try configuredClient()
        _ = try await requireCurrentUserId()
        let rows: [CompanionDataDeletionRecord] = try await client
            .rpc("delete_current_user_companion_data")
            .execute()
            .value
        guard rows.count == 1, rows[0].hasValidCounts else {
            throw SupabaseServiceError.invalidFunctionResponse
        }
    }

    /// Semantic Decode references an owner-scoped People record. Third-party
    /// text is redacted by the client first and the endpoint is told not to
    /// persist it; the server still revalidates ownership and safety.
    func invokeCompanionDecode(
        companionId: CompanionPersonaID,
        personId: UUID,
        redactedMessage: String
    ) async throws -> CompanionDecodeResult {
        let client = try configuredClient()
        guard let session = client.auth.currentSession else {
            throw SupabaseServiceError.missingSession
        }
        guard let url = URL(string: "\(AppConfig.supabaseURL)/functions/v1/companion-decode") else {
            throw SupabaseServiceError.notConfigured
        }
        let payload = CompanionDecodePayload(
            companionId: companionId.rawValue,
            personId: personId,
            message: redactedMessage,
            persistMessage: false
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
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseServiceError.functionFailed(
                CompanionReplyErrorEnvelope.message(from: data)
                    ?? "Decode is unavailable right now."
            )
        }
        return try JSONDecoder().decode(CompanionDecodeResult.self, from: data)
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
        expertAstrologerRequest: ExpertAstrologerReplyService.Request? = nil,
        rehearsalRequest: RehearsalRequestBody? = nil
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
            rehearsalRequest: rehearsalRequest,
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

    /// One Rehearsal Room turn: the practice partner's next reply
    /// (mode "partner") or the coaching specialist's note (mode "coach").
    func invokeConversationRehearsal(
        request rehearsalRequest: RehearsalRequestBody,
        maxTokens: Int = 260
    ) async throws -> String {
        try await invokeCompanionReplyResult(
            kind: .chat,
            feature: .conversationRehearsal,
            system: nil,
            user: nil,
            maxTokens: maxTokens,
            rehearsalRequest: rehearsalRequest
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

    /// Streams the primary-companion endpoint. Unlike the preserved legacy
    /// channel, this request contains only canonical IDs and user text. Persona
    /// programs, chart context, memory, and transcripts are resolved server-side.
    func streamPrimaryCompanionChat(
        companionId: CompanionPersonaID,
        conversationId: UUID,
        clientMessageId: UUID,
        message: String
    ) -> AsyncThrowingStream<CompanionReplyStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let client = try configuredClient()
                    guard let session = client.auth.currentSession else {
                        throw SupabaseServiceError.missingSession
                    }
                    guard let url = URL(string: "\(AppConfig.supabaseURL)/functions/v1/companion-chat") else {
                        throw SupabaseServiceError.notConfigured
                    }

                    let payload = PrimaryCompanionChatPayload(
                        companionId: companionId.rawValue,
                        conversationId: conversationId,
                        clientMessageId: clientMessageId,
                        message: message,
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
                            throw SupabaseServiceError.aiUsageLimit("You have reached today's companion limit.")
                        }
                        throw SupabaseServiceError.functionFailed(
                            "Your companion is unavailable right now. Please try again."
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
                            continue
                        } else if line.hasPrefix("event:") {
                            eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            var value = String(line.dropFirst(5))
                            if value.hasPrefix(" ") { value.removeFirst() }
                            dataLines.append(value)
                        }
                    }
                    flush()
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

    /// Best-effort compatibility helper used by whole-account cleanup. The
    /// archive-specific path below reports whether physical object cleanup was
    /// confirmed instead of silently treating a Storage failure as success.
    func deleteExpertChartImages(for userId: String) async {
        do {
            try await deleteExpertChartImagesStrict(for: userId, knownPaths: [])
        } catch {
            CrashReporter.log(error, context: "deleteExpertChartImages")
        }
    }

    /// Atomically deletes every database row in the signed-in user's read-only
    /// expert archive. Storage is a separate service, so its cleanup result is
    /// returned explicitly and never changes the all-or-nothing DB guarantee.
    func deleteCurrentUserExpertArchive() async throws -> Bool {
        let client = try configuredClient()
        let userId = try await requireCurrentUserId()
        let rows: [ExpertArchiveDeletionRecord] = try await client
            .rpc("delete_current_user_expert_archive")
            .execute()
            .value
        guard rows.count == 1 else {
            throw SupabaseServiceError.invalidFunctionResponse
        }

        do {
            try await deleteExpertChartImagesStrict(
                for: userId.uuidString,
                knownPaths: rows[0].chartStoragePaths
            )
            return true
        } catch {
            CrashReporter.log(error, context: "deleteExpertArchiveStorage")
            return false
        }
    }

    private func deleteExpertChartImagesStrict(
        for userId: String,
        knownPaths: [String]
    ) async throws {
        let client = try configuredClient()
        let bucket = client.storage.from(ExpertChartImportRecord.bucket)
        let owner = userId.lowercased()
        let ownerPrefix = "\(owner)/"
        var paths = Set(knownPaths.filter { $0.lowercased().hasPrefix(ownerPrefix) })

        let selfFiles = try await bucket.list(path: "\(owner)/self")
        paths.formUnion(selfFiles.map { "\(owner)/self/\($0.name)" })

        let peopleDirs = try await bucket.list(path: "\(owner)/people")
        for dir in peopleDirs {
            let files = try await bucket.list(path: "\(owner)/people/\(dir.name)")
            paths.formUnion(files.map { "\(owner)/people/\(dir.name)/\($0.name)" })
        }

        if !paths.isEmpty {
            _ = try await bucket.remove(paths: paths.sorted())
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

    /// Fetches the private calculation source of truth. Legacy accounts may
    /// legitimately have profile sign caches but no provenance row yet.
    func fetchNatalChart() async throws -> NatalChartRecord? {
        let client = try configuredClient()
        guard let userId = await currentUserId else { return nil }
        let records: [NatalChartRecord] = try await client
            .from("user_birth_charts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return records.first
    }

    /// Upserts only for the current session owner. RLS repeats this guarantee
    /// in Postgres, keeping raw birth provenance private even if a caller is
    /// accidentally handed another record.
    func upsertNatalChart(_ record: NatalChartRecord) async throws {
        let client = try configuredClient()
        guard let userId = await currentUserId else {
            throw SupabaseServiceError.missingSession
        }
        if let recordUserId = record.userId, recordUserId != userId {
            throw SupabaseServiceError.profileMismatch
        }
        var ownedRecord = record
        ownedRecord.userId = userId
        try await client.from("user_birth_charts").upsert(ownedRecord).execute()
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

    fileprivate static func companionDateString(_ date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    fileprivate static func companionTimeString(_ date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute, .second], from: date)
        return String(format: "%02d:%02d:%02d", components.hour ?? 0, components.minute ?? 0, components.second ?? 0)
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
    case conversationRehearsal = "conversation_rehearsal"
}

nonisolated struct CompanionReplyPayload: Encodable, Sendable {
    let kind: String
    let feature: String
    let system: String?
    let user: String?
    let maxTokens: Int
    let expertAstrologerRequest: ExpertAstrologerReplyService.Request?
    var rehearsalRequest: RehearsalRequestBody? = nil
    /// Opts the request into SSE streaming. Omitted (nil) for plain JSON calls,
    /// so existing non-streaming payloads encode exactly as before.
    let stream: Bool?
}

/// Exact public request contract for the server-owned persona channel. Raw
/// system prompts and client-provided identity/context have no representation.
nonisolated private struct PrimaryCompanionChatPayload: Encodable, Sendable {
    let companionId: String
    let conversationId: UUID
    let clientMessageId: UUID
    let message: String
    let stream: Bool
}

nonisolated private struct CompanionDecodePayload: Encodable, Sendable {
    let companionId: String
    let personId: UUID
    let message: String
    let persistMessage: Bool
}

nonisolated private struct CompanionMigrationPayload: Encodable, Sendable {
    let companionId: String
    let migrationVersion: Int
    let syncConsent: Bool
    let conversations: [CompanionLegacyConversationMigration]
}

nonisolated private struct CompanionMigrationResponse: Decodable, Sendable {
    struct Counts: Decodable, Sendable {
        let conversationsImported: Int
        let conversationsExisting: Int
        let messagesImported: Int
        let messagesExisting: Int
    }

    let migrationVersion: Int
    let companionId: String
    let counts: Counts
    let conversations: [ConversationMapping]

    struct ConversationMapping: Decodable, Sendable {
        let legacyConversationId: UUID
        let conversationId: UUID
        let importedMessages: Int
        let existingMessages: Int
    }
}

nonisolated private struct ExpertArchiveDeletionRecord: Decodable, Sendable {
    let consultationResponsesDeleted: Int
    let consultationsDeleted: Int
    let messagesDeleted: Int
    let conversationsDeleted: Int
    let personIntakesDeleted: Int
    let chartImportsDeleted: Int
    let selfIntakesDeleted: Int
    let chartStoragePaths: [String]

    enum CodingKeys: String, CodingKey {
        case consultationResponsesDeleted = "consultation_responses_deleted"
        case consultationsDeleted = "consultations_deleted"
        case messagesDeleted = "messages_deleted"
        case conversationsDeleted = "conversations_deleted"
        case personIntakesDeleted = "person_intakes_deleted"
        case chartImportsDeleted = "chart_imports_deleted"
        case selfIntakesDeleted = "self_intakes_deleted"
        case chartStoragePaths = "chart_storage_paths"
    }
}

nonisolated private struct CompanionDataDeletionRecord: Decodable, Sendable {
    let companionMessagesDeleted: Int
    let companionConversationsDeleted: Int
    let companionMemoriesDeleted: Int
    let communicationOutcomesDeleted: Int
    let relationshipPeopleDeleted: Int
    let userCompanionRelationshipsDeleted: Int

    var hasValidCounts: Bool {
        companionMessagesDeleted >= 0
            && companionConversationsDeleted >= 0
            && companionMemoriesDeleted >= 0
            && communicationOutcomesDeleted >= 0
            && relationshipPeopleDeleted >= 0
            && userCompanionRelationshipsDeleted >= 0
    }

    enum CodingKeys: String, CodingKey {
        case companionMessagesDeleted = "companion_messages_deleted"
        case companionConversationsDeleted = "companion_conversations_deleted"
        case companionMemoriesDeleted = "companion_memories_deleted"
        case communicationOutcomesDeleted = "communication_outcomes_deleted"
        case relationshipPeopleDeleted = "relationship_people_deleted"
        case userCompanionRelationshipsDeleted = "user_companion_relationships_deleted"
    }
}

nonisolated private struct CompanionExistingID: Decodable, Sendable {
    let id: UUID
}

nonisolated private struct CompanionExistingRelationship: Decodable, Sendable {
    let id: UUID
    let companionId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case companionId = "companion_id"
    }
}

nonisolated private struct CompanionRelationshipSnapshotRow: Decodable, Sendable {
    let id: UUID
    let userId: UUID
    let companionId: String?
    let status: String
    let isPrimary: Bool
    let supportPreferences: CompanionSupportPreferences
    let lastInteractionAt: Date?
    let createdAt: Date
    let updatedAt: Date

    func model(currentUserId: UUID) -> CompanionRelationship? {
        guard userId == currentUserId,
              status == "active" || status == "archived",
              let companionId else { return nil }
        let canonicalId = CompanionPersonaID(rawValue: companionId)
        guard let persona = CompanionPersonaRegistry.persona(id: canonicalId) else { return nil }
        return CompanionRelationship(
            id: id,
            userId: userId,
            companionId: canonicalId,
            isPrimary: isPrimary && status == "active",
            preferences: supportPreferences,
            personaVersion: persona.personaVersion,
            createdAt: createdAt,
            updatedAt: lastInteractionAt ?? updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companionId = "companion_id"
        case status
        case isPrimary = "is_primary"
        case supportPreferences = "support_preferences"
        case lastInteractionAt = "last_interaction_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated private struct CompanionConversationSnapshotRow: Decodable, Sendable {
    let id: UUID
    let userId: UUID
    let companionId: String?
    let status: String
    let createdAt: Date
    let updatedAt: Date

    func model(currentUserId: UUID) -> CompanionConversation? {
        guard userId == currentUserId,
              status == "active" || status == "archived",
              let companionId else { return nil }
        let canonicalId = CompanionPersonaID(rawValue: companionId)
        guard CompanionPersonaRegistry.pilotIDs.contains(canonicalId) else { return nil }
        return CompanionConversation(
            id: id,
            userId: userId,
            companionId: canonicalId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companionId = "companion_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated private struct CompanionMessageSnapshotRow: Decodable, Sendable {
    let id: UUID
    let conversationId: UUID
    let userId: UUID
    let companionId: String?
    let clientMessageId: UUID
    let role: String
    let content: String
    let deliveryState: String
    let modelVersion: String?
    let createdAt: Date

    func model(
        currentUserId: UUID,
        authorizedConversationIDs: Set<UUID>
    ) -> CompanionChatMessage? {
        guard userId == currentUserId,
              authorizedConversationIDs.contains(conversationId),
              deliveryState == "complete",
              let companionId else { return nil }
        let canonicalId = CompanionPersonaID(rawValue: companionId)
        guard let persona = CompanionPersonaRegistry.persona(id: canonicalId) else { return nil }
        let localRole: CompanionChatRole
        switch role {
        case "user": localRole = .user
        case "companion": localRole = .assistant
        default: return nil
        }
        return CompanionChatMessage(
            id: id,
            conversationId: conversationId,
            clientMessageId: clientMessageId,
            role: localRole,
            content: content,
            personaVersion: persona.personaVersion,
            modelVersion: modelVersion,
            createdAt: createdAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case companionId = "companion_id"
        case clientMessageId = "client_message_id"
        case role
        case content
        case deliveryState = "delivery_state"
        case modelVersion = "model_version"
        case createdAt = "created_at"
    }
}

nonisolated private struct RelationshipBirthChartSnapshot: Decodable, Sendable {
    let sunSign: String?
    let moonSign: String?
    let risingSign: String?

    enum CodingKeys: String, CodingKey {
        case sunSign = "sun_sign"
        case moonSign = "moon_sign"
        case risingSign = "rising_sign"
    }
}

nonisolated private struct RelationshipGuideSnapshot: Decodable, Sendable {
    let situationStatus: String?
    let situationUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case situationStatus = "situation_status"
        case situationUpdatedAt = "situation_updated_at"
    }
}

nonisolated private struct RelationshipPersonSnapshotRow: Decodable, Sendable {
    let id: UUID
    let userId: UUID
    let displayName: String
    let relationshipKind: String?
    let pronouns: String?
    let birthDate: String?
    let birthTime: String?
    let birthPlace: String?
    let birthChart: RelationshipBirthChartSnapshot?
    let notes: String?
    let communicationGuide: RelationshipGuideSnapshot?
    let archivedAt: Date?
    let updatedAt: Date

    func model(currentUserId: UUID) -> RelationshipPerson? {
        guard userId == currentUserId,
              archivedAt == nil,
              let sunRaw = birthChart?.sunSign,
              let sunSign = ZodiacSign(rawValue: sunRaw) else { return nil }
        return RelationshipPerson(
            id: id,
            name: displayName,
            privateLabel: nil,
            relationshipType: relationshipKind.flatMap(RelationshipType.init(rawValue:)) ?? .other,
            birthDate: CompanionSnapshotDateParser.date(birthDate),
            birthTime: CompanionSnapshotDateParser.time(birthTime),
            birthPlace: birthPlace,
            sunSign: sunSign,
            moonSign: birthChart?.moonSign.flatMap(ZodiacSign.init(rawValue:)),
            risingSign: birthChart?.risingSign.flatMap(ZodiacSign.init(rawValue:)),
            notes: notes,
            imageData: nil,
            isChartCalculated: true,
            updatedAt: updatedAt,
            situationStatus: communicationGuide?.situationStatus.flatMap(SituationStatus.init(rawValue:)),
            situationUpdatedAt: communicationGuide?.situationUpdatedAt,
            pronouns: pronouns
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case displayName = "display_name"
        case relationshipKind = "relationship_kind"
        case pronouns
        case birthDate = "birth_date"
        case birthTime = "birth_time"
        case birthPlace = "birth_place"
        case birthChart = "birth_chart"
        case notes
        case communicationGuide = "communication_guide"
        case archivedAt = "archived_at"
        case updatedAt = "updated_at"
    }
}

nonisolated private struct CompanionMemorySnapshotRow: Decodable, Sendable {
    let id: UUID
    let userId: UUID
    let scope: String
    let companionId: String?
    let content: String
    let source: String
    let sourceId: UUID?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    func model(currentUserId: UUID) -> CompanionMemoryItem? {
        guard userId == currentUserId,
              deletedAt == nil,
              let localScope = CompanionMemoryScope(rawValue: scope) else { return nil }
        let canonicalId = companionId.map(CompanionPersonaID.init(rawValue:))
        if localScope == .personaRelationship,
           canonicalId.flatMap({ CompanionPersonaRegistry.persona(id: $0) }) == nil { return nil }
        let localSource: CompanionMemorySource
        switch source {
        case "outcome_recorded": localSource = .recordedOutcome
        case "legacy_import": localSource = .consentedMigration
        default: localSource = .userRecorded
        }
        return CompanionMemoryItem(
            id: id,
            userId: userId,
            companionId: canonicalId,
            scope: localScope,
            source: localSource,
            content: content,
            relatedPersonId: sourceId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case scope
        case companionId = "companion_id"
        case content
        case source
        case sourceId = "source_id"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated private struct CommunicationOutcomeSnapshotRow: Decodable, Sendable {
    let clientOutcomeId: UUID
    let userId: UUID
    let companionId: String
    let personId: UUID?
    let actionText: String
    let resultKind: String?
    let resultSummary: String?
    let followUpState: String
    let actedAt: Date?
    let resultRecordedAt: Date?
    let createdAt: Date

    func model(currentUserId: UUID) -> CommunicationOutcome? {
        let canonicalId = CompanionPersonaID(rawValue: companionId)
        guard userId == currentUserId,
              CompanionPersonaRegistry.pilotIDs.contains(canonicalId),
              let personId,
              let resultKind else { return nil }
        let result: CommunicationOutcomeResult
        switch resultKind {
        case "better": result = .betterThanExpected
        case "worse": result = .harderThanExpected
        case "no_response": result = .noResponse
        default: result = .asExpected
        }
        let followUp: CommunicationFollowUpState
        switch followUpState {
        case "dismissed": followUp = .dismissed
        case "delivered": followUp = .acknowledged
        default: followUp = .pending
        }
        return CommunicationOutcome(
            id: clientOutcomeId,
            userId: userId,
            personId: personId,
            companionId: canonicalId,
            intendedAction: actionText,
            result: result,
            userNotes: resultSummary,
            followUpState: followUp,
            occurredAt: actedAt ?? resultRecordedAt ?? createdAt,
            createdAt: resultRecordedAt ?? createdAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case clientOutcomeId = "client_outcome_id"
        case userId = "user_id"
        case companionId = "companion_id"
        case personId = "person_id"
        case actionText = "action_text"
        case resultKind = "result_kind"
        case resultSummary = "result_summary"
        case followUpState = "follow_up_state"
        case actedAt = "acted_at"
        case resultRecordedAt = "result_recorded_at"
        case createdAt = "created_at"
    }
}

nonisolated private enum CompanionSnapshotDateParser {
    static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    static func time(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm:ss"
        return formatter.date(from: String(value.prefix(8)))
    }
}

nonisolated private struct ReleasedCompanionPersonaID: Decodable, Sendable {
    let id: String
}

nonisolated private struct CompanionExistingOutcome: Decodable, Sendable {
    let clientOutcomeId: UUID

    enum CodingKeys: String, CodingKey {
        case clientOutcomeId = "client_outcome_id"
    }
}

nonisolated private struct CompanionClearPrimaryUpdate: Encodable, Sendable {
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case isPrimary = "is_primary"
    }
}

nonisolated private struct CompanionRelationshipInsert: Encodable, Sendable {
    let id: UUID
    let userId: UUID
    let companionId: String
    let status: String
    let isPrimary: Bool
    let supportPreferences: CompanionSupportPreferences
    let lastInteractionAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companionId = "companion_id"
        case status
        case isPrimary = "is_primary"
        case supportPreferences = "support_preferences"
        case lastInteractionAt = "last_interaction_at"
    }
}

nonisolated private struct CompanionRelationshipUpdate: Encodable, Sendable {
    let status: String
    let isPrimary: Bool
    let supportPreferences: CompanionSupportPreferences
    let lastInteractionAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case isPrimary = "is_primary"
        case supportPreferences = "support_preferences"
        case lastInteractionAt = "last_interaction_at"
    }
}

nonisolated private struct RelationshipBirthChartPayload: Encodable, Sendable {
    let sunSign: String
    let moonSign: String?
    let risingSign: String?

    enum CodingKeys: String, CodingKey {
        case sunSign = "sun_sign"
        case moonSign = "moon_sign"
        case risingSign = "rising_sign"
    }
}

/// Transparent, deterministic foundation uploaded with the consented People
/// record. The server may adapt it with both charts and the actual situation,
/// but it can always distinguish this rule-based layer from model inference.
nonisolated private struct RelationshipCommunicationGuidePayload: Encodable, Sendable {
    let method = "deterministic_sun_sign_v1"
    let foundationSign: String
    let title: String
    let tips: [String]
    let avoid: String
    let bestApproach: String
    let situationStatus: String?
    let situationUpdatedAt: Date?

    init(person: RelationshipPerson) {
        let guide = CommunicationTemplates.guides[person.sunSign]
        foundationSign = person.sunSign.rawValue
        title = guide?.title ?? "Communication Guide"
        tips = guide?.tips ?? []
        avoid = guide?.avoid ?? ""
        bestApproach = guide?.bestApproach ?? ""
        situationStatus = person.situationStatus?.rawValue
        situationUpdatedAt = person.situationUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case method
        case foundationSign = "foundation_sign"
        case title
        case tips
        case avoid
        case bestApproach = "best_approach"
        case situationStatus = "situation_status"
        case situationUpdatedAt = "situation_updated_at"
    }
}

nonisolated private struct RelationshipPersonUpdate: Encodable, Sendable {
    let displayName: String
    let relationshipKind: String
    let pronouns: String?
    let birthDate: String?
    let birthTime: String?
    let birthTimePrecision: String?
    let birthPlace: String?
    let birthChart: RelationshipBirthChartPayload
    let communicationGuide: RelationshipCommunicationGuidePayload
    let notes: String?
    let aiContextEnabled: Bool

    init(person: RelationshipPerson) {
        displayName = String(person.displayName.prefix(120))
        relationshipKind = String(person.relationshipType.rawValue.prefix(80))
        pronouns = person.pronouns.flatMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(80))
        }
        birthDate = person.birthDate.map(SupabaseService.companionDateString)
        birthTime = person.birthTime.map(SupabaseService.companionTimeString)
        birthTimePrecision = person.birthTime == nil ? nil : "exact"
        birthPlace = person.birthPlace.flatMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(240))
        }
        birthChart = RelationshipBirthChartPayload(
            sunSign: person.sunSign.rawValue,
            moonSign: person.moonSign?.rawValue,
            risingSign: person.risingSign?.rawValue
        )
        communicationGuide = RelationshipCommunicationGuidePayload(person: person)
        notes = person.notes.flatMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(10_000))
        }
        aiContextEnabled = true
    }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case relationshipKind = "relationship_kind"
        case pronouns
        case birthDate = "birth_date"
        case birthTime = "birth_time"
        case birthTimePrecision = "birth_time_precision"
        case birthPlace = "birth_place"
        case birthChart = "birth_chart"
        case communicationGuide = "communication_guide"
        case notes
        case aiContextEnabled = "ai_context_enabled"
    }
}

nonisolated private struct RelationshipPersonInsert: Encodable, Sendable {
    let id: UUID
    let userId: UUID
    let displayName: String
    let relationshipKind: String
    let pronouns: String?
    let birthDate: String?
    let birthTime: String?
    let birthTimePrecision: String?
    let birthPlace: String?
    let birthChart: RelationshipBirthChartPayload
    let communicationGuide: RelationshipCommunicationGuidePayload
    let notes: String?
    let aiContextEnabled: Bool
    let recordSource = "local_migration"
    let legacyRecordId: String
    let migrationVersion: Int
    let syncConsentAt: Date

    init(
        id: UUID,
        userId: UUID,
        mutable: RelationshipPersonUpdate,
        legacyRecordId: String,
        migrationVersion: Int,
        syncConsentAt: Date
    ) {
        self.id = id
        self.userId = userId
        displayName = mutable.displayName
        relationshipKind = mutable.relationshipKind
        pronouns = mutable.pronouns
        birthDate = mutable.birthDate
        birthTime = mutable.birthTime
        birthTimePrecision = mutable.birthTimePrecision
        birthPlace = mutable.birthPlace
        birthChart = mutable.birthChart
        communicationGuide = mutable.communicationGuide
        notes = mutable.notes
        aiContextEnabled = mutable.aiContextEnabled
        self.legacyRecordId = legacyRecordId
        self.migrationVersion = migrationVersion
        self.syncConsentAt = syncConsentAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case displayName = "display_name"
        case relationshipKind = "relationship_kind"
        case pronouns
        case birthDate = "birth_date"
        case birthTime = "birth_time"
        case birthTimePrecision = "birth_time_precision"
        case birthPlace = "birth_place"
        case birthChart = "birth_chart"
        case communicationGuide = "communication_guide"
        case notes
        case aiContextEnabled = "ai_context_enabled"
        case recordSource = "record_source"
        case legacyRecordId = "legacy_record_id"
        case migrationVersion = "migration_version"
        case syncConsentAt = "sync_consent_at"
    }
}

nonisolated private struct CompanionMemoryInsert: Encodable, Sendable {
    let id: UUID
    let userId: UUID
    let scope: String
    let companionId: String?
    let relationshipId: UUID?
    let memoryKind: String
    let content: String
    let source: String
    let sourceId: UUID?
    let isSensitive = false
    let legacyRecordId: String?
    let migrationVersion: Int?
    let syncConsentAt: Date?

    init?(
        memory: CompanionMemoryItem,
        userId: UUID,
        relationshipIDsByCompanion: [CompanionPersonaID: UUID],
        consentedAt: Date
    ) {
        let relationshipId = memory.companionId.flatMap { relationshipIDsByCompanion[$0] }
        if memory.scope == .personaRelationship && relationshipId == nil { return nil }

        id = memory.id
        self.userId = userId
        scope = memory.scope.rawValue
        companionId = memory.companionId?.rawValue
        self.relationshipId = relationshipId
        memoryKind = memory.source == .recordedOutcome ? "recorded_outcome" : "user_note"
        content = String(memory.content.prefix(2_000))
        switch memory.source {
        case .userRecorded:
            source = "user_explicit"
        case .recordedOutcome:
            source = "outcome_recorded"
        case .consentedMigration:
            source = "legacy_import"
        }
        sourceId = memory.relatedPersonId
        if memory.source == .consentedMigration {
            legacyRecordId = memory.id.uuidString
            migrationVersion = CompanionPivotState.currentMigrationVersion
            syncConsentAt = consentedAt
        } else {
            legacyRecordId = nil
            migrationVersion = nil
            syncConsentAt = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case scope
        case companionId = "companion_id"
        case relationshipId = "relationship_id"
        case memoryKind = "memory_kind"
        case content
        case source
        case sourceId = "source_id"
        case isSensitive = "is_sensitive"
        case legacyRecordId = "legacy_record_id"
        case migrationVersion = "migration_version"
        case syncConsentAt = "sync_consent_at"
    }
}

nonisolated private struct CompanionMemoryUpdate: Encodable, Sendable {
    let content: String
    let isSensitive = false

    init(content: String) {
        self.content = String(content.prefix(2_000))
    }

    enum CodingKeys: String, CodingKey {
        case content
        case isSensitive = "is_sensitive"
    }
}

nonisolated private struct CommunicationOutcomeUpdate: Encodable, Sendable {
    let actionText: String
    let actionState = "completed"
    let actedAt: Date
    let resultKind: String
    let resultSummary: String?
    let resultSource = "user_recorded"
    let resultRecordedAt: Date
    let followUpState: String
    let followUpDueAt: Date?

    init(outcome: CommunicationOutcome) {
        actionText = String(outcome.intendedAction.prefix(4_000))
        actedAt = outcome.occurredAt
        switch outcome.result {
        case .betterThanExpected: resultKind = "better"
        case .asExpected: resultKind = "mixed"
        case .harderThanExpected: resultKind = "worse"
        case .noResponse: resultKind = "no_response"
        }
        resultSummary = outcome.userNotes.flatMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(4_000))
        }
        resultRecordedAt = outcome.createdAt
        switch outcome.followUpState {
        case .pending:
            followUpState = "due"
            followUpDueAt = outcome.createdAt
        case .acknowledged, .dismissed:
            followUpState = "dismissed"
            followUpDueAt = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case actionText = "action_text"
        case actionState = "action_state"
        case actedAt = "acted_at"
        case resultKind = "result_kind"
        case resultSummary = "result_summary"
        case resultSource = "result_source"
        case resultRecordedAt = "result_recorded_at"
        case followUpState = "follow_up_state"
        case followUpDueAt = "follow_up_due_at"
    }
}

nonisolated private struct CommunicationOutcomeInsert: Encodable, Sendable {
    let id: UUID
    let clientOutcomeId: UUID
    let userId: UUID
    let companionId: String
    let relationshipId: UUID
    let personId: UUID
    let actionText: String
    let actionState: String
    let actedAt: Date
    let resultKind: String
    let resultSummary: String?
    let resultSource: String
    let resultRecordedAt: Date
    let followUpState: String
    let followUpDueAt: Date?

    init(
        id: UUID,
        clientOutcomeId: UUID,
        userId: UUID,
        companionId: String,
        relationshipId: UUID,
        personId: UUID,
        mutable: CommunicationOutcomeUpdate
    ) {
        self.id = id
        self.clientOutcomeId = clientOutcomeId
        self.userId = userId
        self.companionId = companionId
        self.relationshipId = relationshipId
        self.personId = personId
        actionText = mutable.actionText
        actionState = mutable.actionState
        actedAt = mutable.actedAt
        resultKind = mutable.resultKind
        resultSummary = mutable.resultSummary
        resultSource = mutable.resultSource
        resultRecordedAt = mutable.resultRecordedAt
        followUpState = mutable.followUpState
        followUpDueAt = mutable.followUpDueAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case clientOutcomeId = "client_outcome_id"
        case userId = "user_id"
        case companionId = "companion_id"
        case relationshipId = "relationship_id"
        case personId = "person_id"
        case actionText = "action_text"
        case actionState = "action_state"
        case actedAt = "acted_at"
        case resultKind = "result_kind"
        case resultSummary = "result_summary"
        case resultSource = "result_source"
        case resultRecordedAt = "result_recorded_at"
        case followUpState = "follow_up_state"
        case followUpDueAt = "follow_up_due_at"
    }
}

nonisolated struct CompanionDecodeResult: Decodable, Equatable, Sendable {
    let tone: String
    let likelyMeaning: String
    let plausibleAlternative: String
    let whatNotToAssume: String
    let replyDrafts: [String]
    let personaVersion: Int
    let modelVersion: String
    let messagePersisted: Bool
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
