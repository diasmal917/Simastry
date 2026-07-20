import Foundation

extension AppViewModel {
    func refreshCompanionExperienceMode() async {
        do {
            let shouldRollback = try await supabase.fetchCompanionPilotRollbackFlag()
            AppConfig.cacheCompanionRemoteRollback(shouldRollback)
            experienceMode = AppConfig.experienceMode
        } catch {
            experienceMode = AppConfig.experienceMode
            CrashReporter.log(error, context: "refreshCompanionExperienceMode")
        }
    }

    var primaryCompanionRelationship: CompanionRelationship? {
        companionPivotState.relationships.first(where: \.isPrimary)
    }

    var primaryCompanionPersona: CompanionPersona? {
        primaryCompanionRelationship.flatMap { CompanionPersonaRegistry.persona(id: $0.companionId) }
    }

    var recommendedCompanionPersonas: [CompanionPersona] {
        CompanionPersonaRegistry.recommendations(
            sun: userSunSign,
            moon: userMoonSign,
            rising: userRisingSign,
            guidanceStyle: .stored
        )
    }

    var pendingCommunicationOutcomes: [CommunicationOutcome] {
        companionPivotState.outcomes
            .filter { $0.followUpState == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// `seeding` applies onboarding's support-style calibration to the chosen
    /// relationship the moment it is created or promoted; nil leaves the
    /// relationship's existing preferences untouched.
    func choosePrimaryCompanion(
        _ companionId: CompanionPersonaID,
        seeding preferences: CompanionSupportPreferences? = nil
    ) {
        guard CompanionPersonaRegistry.pilotIDs.contains(companionId),
              let persona = CompanionPersonaRegistry.persona(id: companionId) else {
            showToast(
                "Companion not available",
                subtitle: "This companion has not completed pilot certification yet.",
                isError: true
            )
            return
        }

        let previousPrimary = primaryCompanionRelationship?.companionId
        guard companionPivotState.selectPrimary(companionId, userId: profile?.id) != nil else { return }

        if let preferences,
           let index = companionPivotState.relationships.firstIndex(where: { $0.companionId == companionId }) {
            companionPivotState.relationships[index].preferences = preferences
        }

        ensureConversation(for: persona)
        persistCompanionPivotState()
        scheduleCompanionPilotSync()
        homeSetupPhase = .complete
        analytics.track(
            previousPrimary == nil ? .primaryCompanionChosen : .primaryCompanionSwitched,
            params: ["companion_id": companionId.rawValue]
        )
    }

    func updatePrimaryCompanionSupport(_ preferences: CompanionSupportPreferences) {
        guard let primaryId = primaryCompanionRelationship?.id,
              let index = companionPivotState.relationships.firstIndex(where: { $0.id == primaryId }) else {
            return
        }
        companionPivotState.relationships[index].preferences = preferences
        companionPivotState.relationships[index].updatedAt = Date()
        persistCompanionPivotState()
        scheduleCompanionPilotSync()
    }

    func conversation(for companionId: CompanionPersonaID) -> CompanionConversation? {
        companionPivotState.conversations.first { $0.companionId == companionId }
    }

    func primaryCompanionConversation() -> CompanionConversation? {
        guard let companionId = primaryCompanionRelationship?.companionId else { return nil }
        return conversation(for: companionId)
    }

    func companionChatMessages(conversationId: UUID) -> [CompanionChatMessage] {
        companionPivotState.messages
            .filter { $0.conversationId == conversationId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func appendCompanionUserMessage(
        _ content: String,
        conversationId: UUID,
        clientMessageId: UUID
    ) -> CompanionChatMessage {
        if let existing = companionPivotState.messages.first(where: {
            $0.conversationId == conversationId
                && $0.clientMessageId == clientMessageId
                && $0.role == .user
        }) {
            return existing
        }
        let message = CompanionChatMessage(
            conversationId: conversationId,
            clientMessageId: clientMessageId,
            role: .user,
            content: content,
            personaVersion: primaryCompanionPersona?.personaVersion ?? 1
        )
        companionPivotState.messages.append(message)
        touchConversation(conversationId)
        persistCompanionPivotState()
        return message
    }

    @discardableResult
    func appendCompanionAssistantMessage(
        _ content: String,
        conversationId: UUID,
        clientMessageId: UUID? = nil,
        modelVersion: String? = nil
    ) -> CompanionChatMessage {
        if let clientMessageId,
           let index = companionPivotState.messages.firstIndex(where: {
               $0.conversationId == conversationId
                   && $0.clientMessageId == clientMessageId
                   && $0.role == .assistant
           }) {
            companionPivotState.messages[index].content = content
            let message = companionPivotState.messages[index]
            touchConversation(conversationId)
            persistCompanionPivotState()
            return message
        }
        let message = CompanionChatMessage(
            conversationId: conversationId,
            clientMessageId: clientMessageId,
            role: .assistant,
            content: content,
            personaVersion: primaryCompanionPersona?.personaVersion ?? 1,
            modelVersion: modelVersion
        )
        companionPivotState.messages.append(message)
        touchConversation(conversationId)
        persistCompanionPivotState()
        return message
    }

    func addCompanionMemory(
        content: String,
        scope: CompanionMemoryScope,
        relatedPersonId: UUID? = nil,
        source: CompanionMemorySource = .userRecorded
    ) {
        let trimmed = String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !trimmed.isEmpty else { return }
        companionPivotState.memories.append(
            CompanionMemoryItem(
                userId: profile?.id,
                companionId: scope == .personaRelationship ? primaryCompanionRelationship?.companionId : nil,
                scope: scope,
                source: source,
                content: trimmed,
                relatedPersonId: relatedPersonId
            )
        )
        persistCompanionPivotState()
        scheduleCompanionPilotSync()
    }

    func updateCompanionMemory(id: UUID, content: String) {
        guard let index = companionPivotState.memories.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !trimmed.isEmpty else { return }
        companionPivotState.memories[index].content = trimmed
        companionPivotState.memories[index].updatedAt = Date()
        persistCompanionPivotState()
        scheduleCompanionPilotSync()
    }

    func deleteCompanionMemory(id: UUID) {
        companionPivotState.memories.removeAll { $0.id == id }
        persistCompanionPivotState()
        guard isAuthenticated else { return }
        Task {
            do {
                try await supabase.deleteSyncedCompanionMemory(id: id)
            } catch {
                CrashReporter.log(error, context: "deleteSyncedCompanionMemory")
            }
        }
    }

    func deleteCommunicationOutcome(id: UUID) {
        companionPivotState.outcomes.removeAll { $0.id == id }
        persistCompanionPivotState()
        guard isAuthenticated else { return }
        Task {
            do {
                try await supabase.deleteSyncedCommunicationOutcome(clientOutcomeId: id)
            } catch {
                CrashReporter.log(error, context: "deleteSyncedCommunicationOutcome")
            }
        }
    }

    func recordCommunicationOutcome(
        person: RelationshipPerson,
        intendedAction: String,
        result: CommunicationOutcomeResult,
        notes: String?
    ) {
        guard let companionId = primaryCompanionRelationship?.companionId else { return }
        let trimmedAction = String(intendedAction.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !trimmedAction.isEmpty else { return }
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let outcome = CommunicationOutcome(
            userId: profile?.id,
            personId: person.id,
            companionId: companionId,
            intendedAction: trimmedAction,
            result: result,
            userNotes: trimmedNotes?.isEmpty == false ? String(trimmedNotes!.prefix(1_000)) : nil
        )
        companionPivotState.outcomes.append(outcome)
        persistCompanionPivotState()
        analytics.track(.communicationOutcomeRecorded, params: ["result": result.rawValue])

        // Outcomes remain their own explicit record. They are not silently
        // copied into free-form memory, so deleting one removes the
        // companion's only claimed source for what happened offline.
        scheduleCompanionPilotSync()
    }

    func resolveCommunicationOutcome(_ id: UUID, state: CommunicationFollowUpState) {
        guard let index = companionPivotState.outcomes.firstIndex(where: { $0.id == id }) else { return }
        companionPivotState.outcomes[index].followUpState = state
        persistCompanionPivotState()
        scheduleCompanionPilotSync()
    }

    /// Device-local threads and People records are eligible for server sync
    /// only after an explicit opt-in. Migration is exact-slug-only and
    /// idempotent; user-created companions remain read-only legacy records.
    func grantCompanionSyncConsentAndMigrateLegacyData() {
        companionPivotState.syncConsent = true
        analytics.track(.privateSyncConsentGranted)
        guard companionPivotState.migrationVersion < CompanionPivotState.currentMigrationVersion else {
            persistCompanionPivotState()
            syncAndHydrateConsentedCompanionData()
            return
        }

        let defaults = UserDefaults.standard
        let exactThreadMap = defaults.data(forKey: Self.guideThreadIdsKey)
            .flatMap { try? JSONDecoder().decode([String: UUID].self, from: $0) } ?? [:]

        for (slug, legacyThreadId) in exactThreadMap {
            let personaId = CompanionPersonaID(rawValue: slug)
            guard CompanionPersonaRegistry.pilotIDs.contains(personaId) else { continue }
            if !companionPivotState.conversations.contains(where: { $0.id == legacyThreadId }) {
                companionPivotState.conversations.append(
                    CompanionConversation(
                        id: legacyThreadId,
                        userId: profile?.id,
                        companionId: personaId,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                )
            }
            let existingIds = Set(companionPivotState.messages.map(\.id))
            for legacy in companionMessages where legacy.companionId == legacyThreadId && !existingIds.contains(legacy.id) {
                companionPivotState.messages.append(
                    CompanionChatMessage(
                        id: legacy.id,
                        conversationId: legacyThreadId,
                        clientMessageId: legacy.id,
                        role: legacy.direction == .outgoing ? .user : .assistant,
                        content: legacy.content,
                        personaVersion: 1,
                        createdAt: legacy.timestamp
                    )
                )
            }
        }

        let knownLegacyIds = Set(companionPivotState.legacyRecords.map(\.id))
        for custom in companions where !knownLegacyIds.contains(custom.id) {
            companionPivotState.legacyRecords.append(
                LegacyCompanionRecord(
                    id: custom.id,
                    originalName: custom.name,
                    originalSign: custom.sunSign,
                    importedAt: Date(),
                    isReadOnly: true
                )
            )
        }

        companionPivotState.migrationVersion = CompanionPivotState.currentMigrationVersion
        persistCompanionPivotState()
        syncAndHydrateConsentedCompanionData()
    }

    func revokeCompanionSyncConsent() {
        companionPivotState.syncConsent = false
        persistCompanionPivotState()
        analytics.track(.privateSyncConsentRevoked)
    }

    func claimCompanionStateForAuthenticatedUser() {
        guard let userId = profile?.id else { return }
        for index in companionPivotState.relationships.indices where companionPivotState.relationships[index].userId == nil {
            companionPivotState.relationships[index].userId = userId
        }
        for index in companionPivotState.conversations.indices where companionPivotState.conversations[index].userId == nil {
            companionPivotState.conversations[index].userId = userId
        }
        for index in companionPivotState.memories.indices where companionPivotState.memories[index].userId == nil {
            companionPivotState.memories[index].userId = userId
        }
        for index in companionPivotState.outcomes.indices where companionPivotState.outcomes[index].userId == nil {
            companionPivotState.outcomes[index].userId = userId
        }
        persistCompanionPivotState()
    }

    /// Hydrates server state before any local mirror runs. Exact companion IDs
    /// are the merge key; display names and signs never participate.
    func refreshCompanionPilotStateFromServer(includePrivateRecords: Bool? = nil) async {
        guard isAuthenticated else { return }
        let includesPrivate = includePrivateRecords ?? companionPivotState.syncConsent
        do {
            let snapshot = try await supabase.fetchCompanionPilotSnapshot(
                includePrivateRecords: includesPrivate
            )
            mergeCompanionServerSnapshot(snapshot, includePrivateRecords: includesPrivate)
        } catch {
            CrashReporter.log(error, context: "fetchCompanionPilotSnapshot")
        }
    }

    func openPrimaryCompanion(withDraft draft: String? = nil) {
        if let draft, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            primaryCompanionDraft = draft
        }
        selectedTab = .messages
    }

    func streamPrimaryCompanionReply(
        companionId: CompanionPersonaID,
        conversationId: UUID,
        clientMessageId: UUID,
        message: String
    ) -> AsyncThrowingStream<CompanionReplyStreamEvent, Error> {
        guard AppConfig.companionStreamingEnabled else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: SupabaseServiceError.notConfigured)
            }
        }
        return supabase.streamPrimaryCompanionChat(
            companionId: companionId,
            conversationId: conversationId,
            clientMessageId: clientMessageId,
            message: message
        )
    }

    func semanticDecode(message: String, personId: UUID) async throws -> CompanionDecodeResult {
        guard let companionId = primaryCompanionRelationship?.companionId else {
            throw SupabaseServiceError.functionFailed("Choose a primary companion first.")
        }
        guard companionPivotState.syncConsent else {
            throw SupabaseServiceError.functionFailed(
                "Turn on private sync in Companion memory before using AI Decode with a saved person."
            )
        }
        try await syncCompanionPilotDataNow(includePrivateRecords: true)
        let result = try await supabase.invokeCompanionDecode(
            companionId: companionId,
            personId: personId,
            redactedMessage: message
        )
        analytics.track(.companionDecodeCompleted)
        return result
    }

    /// Honest, clearly labeled on-device fallback. It offers one reflection and
    /// one real-world move without pretending to semantically decode the text.
    func primaryCompanionOfflineFallback(for message: String, persona: CompanionPersona) -> String {
        let asksAboutReply = message.localizedCaseInsensitiveContains("reply")
            || message.localizedCaseInsensitiveContains("text")
            || message.localizedCaseInsensitiveContains("message")
        let nextMove = asksAboutReply
            ? "Draft the one sentence you can stand behind, then read it once for pressure before sending."
            : "Name the person, the concrete moment, and what you want to be different after the conversation."
        switch persona.id.rawValue {
        case CompanionPersonaID.amara.rawValue:
            return "Let's get to the honest part without turning urgency into pressure. \(nextMove)"
        case CompanionPersonaID.theo.rawValue:
            return "Slow this down to what you know, what you assume, and what needs proof. \(nextMove)"
        case CompanionPersonaID.isolde.rawValue:
            return "We can protect both fairness and your boundary; neither requires self-erasure. \(nextMove)"
        case CompanionPersonaID.zev.rawValue:
            return "There may be a real feeling here, but we do not need to invent the other person's inner story. \(nextMove)"
        default:
            return nextMove
        }
    }

    func clearCompanionPivotState() {
        companionPivotState = CompanionPivotState()
        CompanionPivotStore.shared.clear()
    }

    func syncCompanionPilotDataNow(includePrivateRecords: Bool? = nil) async throws {
        let includesPrivate = includePrivateRecords ?? companionPivotState.syncConsent
        if let running = companionSyncTask {
            let runningIncludesPrivate = companionSyncIncludesPrivateRecords
            try await running.value
            guard includesPrivate && !runningIncludesPrivate else { return }
            // The relationship-only pass has completed; run the requested
            // private-record pass directly rather than racing it.
            try await supabase.syncCompanionPilotData(
                relationships: companionPivotState.relationships,
                people: relationshipPeople,
                memories: companionPivotState.memories,
                outcomes: companionPivotState.outcomes,
                includePrivateRecords: true
            )
            return
        }

        let relationships = companionPivotState.relationships
        let people = relationshipPeople
        let memories = companionPivotState.memories
        let outcomes = companionPivotState.outcomes
        let task = Task { [supabase] in
            try await supabase.syncCompanionPilotData(
                relationships: relationships,
                people: people,
                memories: memories,
                outcomes: outcomes,
                includePrivateRecords: includesPrivate
            )
        }
        companionSyncTask = task
        companionSyncIncludesPrivateRecords = includesPrivate
        defer {
            companionSyncTask = nil
            companionSyncIncludesPrivateRecords = false
        }
        try await task.value
    }

    func scheduleCompanionPilotSync() {
        guard isAuthenticated else { return }
        #if DEBUG
        if isDebugPreviewStateActive { return }
        #endif
        let includesPrivate = companionPivotState.syncConsent
        Task {
            do {
                try await syncCompanionPilotDataNow(includePrivateRecords: includesPrivate)
                if includesPrivate {
                    try await migrateLegacyCompanionThreadsIfNeeded()
                }
            } catch {
                CrashReporter.log(error, context: "syncCompanionPilotData")
            }
        }
    }

    private func syncAndHydrateConsentedCompanionData() {
        guard isAuthenticated else { return }
        Task {
            do {
                try await syncCompanionPilotDataNow(includePrivateRecords: true)
                try await migrateLegacyCompanionThreadsIfNeeded()
                await refreshCompanionPilotStateFromServer(includePrivateRecords: true)
            } catch {
                CrashReporter.log(error, context: "syncAndHydrateConsentedCompanionData")
            }
        }
    }

    private func migrateLegacyCompanionThreadsIfNeeded() async throws {
        guard companionPivotState.syncConsent, let userId = profile?.id else { return }
        let completionKey = "simastry_companion_server_migration_v\(CompanionPivotState.currentMigrationVersion)_\(userId.uuidString)"
        guard !UserDefaults.standard.bool(forKey: completionKey) else { return }

        let threads = try legacyCompanionThreadMigrations()
        guard !threads.isEmpty else {
            UserDefaults.standard.set(true, forKey: completionKey)
            return
        }
        let conversationMappings = try await supabase.migrateLegacyCompanionThreads(threads)
        remapMigratedLegacyConversations(conversationMappings)
        UserDefaults.standard.set(true, forKey: completionKey)
    }

    private func legacyCompanionThreadMigrations() throws -> [CompanionLegacyThreadMigration] {
        let exactThreadMap = UserDefaults.standard.data(forKey: Self.guideThreadIdsKey)
            .flatMap { try? JSONDecoder().decode([String: UUID].self, from: $0) } ?? [:]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return try exactThreadMap.keys.sorted().compactMap { slug in
            let companionId = CompanionPersonaID(rawValue: slug)
            guard slug == companionId.rawValue,
                  CompanionPersonaRegistry.pilotIDs.contains(companionId),
                  let conversationId = exactThreadMap[slug] else { return nil }
            let legacyMessages = companionMessages
                .filter { $0.companionId == conversationId && $0.source == .companion }
                .sorted { $0.timestamp < $1.timestamp }
            guard legacyMessages.count <= 200 else {
                throw SupabaseServiceError.functionFailed(
                    "A previous companion thread is larger than the safe migration batch. It remains on this device for a later import."
                )
            }
            let messages = try legacyMessages.map { message -> CompanionLegacyMessageMigration in
                    guard !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          message.content.count <= 50_000 else {
                        throw SupabaseServiceError.functionFailed(
                            "A previous companion message could not be safely imported. The thread remains on this device."
                        )
                    }
                    return CompanionLegacyMessageMigration(
                        legacyMessageId: message.id,
                        role: message.direction == .outgoing ? "user" : "companion",
                        content: message.content,
                        createdAt: formatter.string(from: message.timestamp)
                    )
                }
            guard !messages.isEmpty else { return nil }
            return CompanionLegacyThreadMigration(
                companionId: companionId,
                conversations: [
                    CompanionLegacyConversationMigration(
                        legacyConversationId: conversationId,
                        title: nil,
                        messages: messages
                    ),
                ]
            )
        }
    }

    /// Server-generated IDs become authoritative only after every submitted
    /// legacy conversation and message count has been verified.
    private func remapMigratedLegacyConversations(_ mappings: [UUID: UUID]) {
        guard !mappings.isEmpty else { return }

        let remappedConversations = companionPivotState.conversations.map { conversation in
            guard let serverID = mappings[conversation.id] else { return conversation }
            return CompanionConversation(
                id: serverID,
                userId: conversation.userId,
                companionId: conversation.companionId,
                createdAt: conversation.createdAt,
                updatedAt: conversation.updatedAt
            )
        }
        var conversationsByID: [UUID: CompanionConversation] = [:]
        for conversation in remappedConversations {
            if let current = conversationsByID[conversation.id], current.updatedAt > conversation.updatedAt {
                continue
            }
            conversationsByID[conversation.id] = conversation
        }
        companionPivotState.conversations = conversationsByID.values.sorted { $0.createdAt < $1.createdAt }
        companionPivotState.messages = companionPivotState.messages.map { message in
            guard let serverConversationID = mappings[message.conversationId] else { return message }
            return CompanionChatMessage(
                id: message.id,
                conversationId: serverConversationID,
                clientMessageId: message.clientMessageId ?? message.id,
                role: message.role,
                content: message.content,
                personaVersion: message.personaVersion,
                modelVersion: message.modelVersion,
                createdAt: message.createdAt
            )
        }
        persistCompanionPivotState()
    }

    private func ensureConversation(for persona: CompanionPersona) {
        if companionPivotState.conversations.contains(where: { $0.companionId == persona.id }) {
            return
        }
        let conversation = CompanionConversation(
            id: UUID(),
            userId: profile?.id,
            companionId: persona.id,
            createdAt: Date(),
            updatedAt: Date()
        )
        companionPivotState.conversations.append(conversation)
        companionPivotState.messages.append(
            CompanionChatMessage(
                conversationId: conversation.id,
                role: .assistant,
                content: "I’m \(persona.displayName), an AI companion. Tell me about the person or conversation on your mind, and we’ll find one useful next move in real life.",
                personaVersion: persona.personaVersion,
                modelVersion: "local-welcome-v1"
            )
        )
    }

    private func touchConversation(_ id: UUID) {
        guard let index = companionPivotState.conversations.firstIndex(where: { $0.id == id }) else { return }
        companionPivotState.conversations[index].updatedAt = Date()
    }

    private func persistCompanionPivotState() {
        CompanionPivotStore.shared.save(companionPivotState)
    }

    private func mergeCompanionServerSnapshot(
        _ snapshot: CompanionServerSnapshot,
        includePrivateRecords: Bool
    ) {
        var relationshipsByCompanion: [CompanionPersonaID: CompanionRelationship] = [:]
        for relationship in companionPivotState.relationships {
            if let current = relationshipsByCompanion[relationship.companionId],
               current.updatedAt > relationship.updatedAt {
                continue
            }
            relationshipsByCompanion[relationship.companionId] = relationship
        }
        for remote in snapshot.relationships {
            if let local = relationshipsByCompanion[remote.companionId], local.updatedAt > remote.updatedAt {
                relationshipsByCompanion[remote.companionId] = CompanionRelationship(
                    id: remote.id,
                    userId: remote.userId,
                    companionId: remote.companionId,
                    isPrimary: local.isPrimary,
                    preferences: local.preferences,
                    personaVersion: remote.personaVersion,
                    createdAt: min(local.createdAt, remote.createdAt),
                    updatedAt: local.updatedAt
                )
            } else {
                relationshipsByCompanion[remote.companionId] = remote
            }
        }
        var mergedRelationships = relationshipsByCompanion.values.sorted { $0.createdAt < $1.createdAt }
        let primaryCandidates = mergedRelationships.indices.filter { mergedRelationships[$0].isPrimary }
        if primaryCandidates.count > 1,
           let winner = primaryCandidates.max(by: {
               mergedRelationships[$0].updatedAt < mergedRelationships[$1].updatedAt
           }) {
            for index in primaryCandidates where index != winner {
                mergedRelationships[index].isPrimary = false
            }
        }
        companionPivotState.relationships = mergedRelationships

        var conversationsByID: [UUID: CompanionConversation] = [:]
        for conversation in companionPivotState.conversations {
            if let current = conversationsByID[conversation.id], current.updatedAt > conversation.updatedAt {
                continue
            }
            conversationsByID[conversation.id] = conversation
        }
        for remote in snapshot.conversations {
            if let local = conversationsByID[remote.id], local.updatedAt > remote.updatedAt {
                continue
            }
            conversationsByID[remote.id] = remote
        }
        companionPivotState.conversations = conversationsByID.values.sorted { $0.createdAt < $1.createdAt }

        var messages = companionPivotState.messages
        for remote in snapshot.messages {
            messages.removeAll { local in
                local.id == remote.id
                    || (local.conversationId == remote.conversationId
                        && local.clientMessageId == remote.clientMessageId
                        && local.role == remote.role)
            }
            messages.append(remote)
        }
        companionPivotState.messages = messages.sorted { $0.createdAt < $1.createdAt }

        if includePrivateRecords {
            var peopleByID: [UUID: RelationshipPerson] = [:]
            for person in relationshipPeople {
                if let current = peopleByID[person.id], current.updatedAt > person.updatedAt {
                    continue
                }
                peopleByID[person.id] = person
            }
            for remote in snapshot.people {
                if let local = peopleByID[remote.id], local.updatedAt > remote.updatedAt {
                    continue
                }
                var restored = remote
                restored.imageData = peopleByID[remote.id]?.imageData
                peopleByID[remote.id] = restored
            }
            relationshipPeople = peopleByID.values.sorted { $0.updatedAt > $1.updatedAt }
            persistRelationshipPeopleCache()

            var memoriesByID: [UUID: CompanionMemoryItem] = [:]
            for memory in companionPivotState.memories {
                if let current = memoriesByID[memory.id], current.updatedAt > memory.updatedAt {
                    continue
                }
                memoriesByID[memory.id] = memory
            }
            for remote in snapshot.memories {
                if let local = memoriesByID[remote.id], local.updatedAt > remote.updatedAt {
                    continue
                }
                memoriesByID[remote.id] = remote
            }
            companionPivotState.memories = memoriesByID.values.sorted { $0.updatedAt > $1.updatedAt }

            var outcomesByID: [UUID: CommunicationOutcome] = [:]
            for outcome in companionPivotState.outcomes {
                if let current = outcomesByID[outcome.id], current.createdAt > outcome.createdAt {
                    continue
                }
                outcomesByID[outcome.id] = outcome
            }
            for remote in snapshot.outcomes {
                outcomesByID[remote.id] = remote
            }
            companionPivotState.outcomes = outcomesByID.values.sorted { $0.createdAt > $1.createdAt }
        }

        persistCompanionPivotState()
    }
}
