import Foundation

extension AppViewModel {
    func loadExpertAstrologerState() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: Self.specialistMessagesKey),
           let messages = try? decoder.decode([SpecialistMessage].self, from: data) {
            specialistMessages = messages.sorted { $0.timestamp < $1.timestamp }
        } else {
            specialistMessages = []
        }

        if let data = UserDefaults.standard.data(forKey: Self.specialistConsultationResponsesKey),
           let responses = try? decoder.decode([SpecialistConsultationResponse].self, from: data) {
            specialistConsultationResponses = responses.sorted { $0.timestamp < $1.timestamp }
        } else {
            specialistConsultationResponses = []
        }
    }

    func saveExpertAstrologerState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(specialistMessages) {
            UserDefaults.standard.set(data, forKey: Self.specialistMessagesKey)
        }
        if let data = try? encoder.encode(specialistConsultationResponses) {
            UserDefaults.standard.set(data, forKey: Self.specialistConsultationResponsesKey)
        }
    }

    func clearExpertAstrologerState() {
        specialistMessages = []
        specialistConsultationResponses = []
        typingSpecialistIds = []
        runningEveryoneConsultationIds = []
        runningEveryoneResponseKeys = []
        UserDefaults.standard.removeObject(forKey: Self.specialistMessagesKey)
        UserDefaults.standard.removeObject(forKey: Self.specialistConsultationResponsesKey)
        UserDefaults.standard.removeObject(forKey: Self.specialistConversationIdsKey)
    }

    func refreshExpertAstrologerStateFromRemote() async {
        guard isAuthenticated else { return }
        #if DEBUG
        if isDebugPreviewStateActive { return }
        #endif

        do {
            let remoteMessages = try await supabase.fetchExpertAstrologerMessages()
            let remoteResponses = try await supabase.fetchExpertAstrologerConsultationResponses()
            mergeExpertAstrologerMessages(remoteMessages)
            mergeExpertAstrologerResponses(remoteResponses)
            saveExpertAstrologerState()
            syncPendingExpertAstrologerStateIfPossible()
        } catch {
            // Expert chats are cached locally; remote sync should not block the
            // consultation flow when connectivity or schema rollout lags.
            CrashReporter.log(error, context: "refreshExpertAstrologerState")
        }
    }

    func specialistConversationId(for specialistId: String) -> UUID {
        var map = (UserDefaults.standard.data(forKey: Self.specialistConversationIdsKey))
            .flatMap { try? JSONDecoder().decode([String: UUID].self, from: $0) } ?? [:]
        if let existing = map[specialistId] {
            return existing
        }

        let id = UUID()
        map[specialistId] = id
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: Self.specialistConversationIdsKey)
        }
        return id
    }

    func specialistConversation(for specialistId: String) -> [SpecialistMessage] {
        let conversationId = specialistConversationId(for: specialistId)
        return specialistMessages
            .filter { $0.conversationId == conversationId && $0.specialistId == specialistId && $0.mode == .individual }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func currentAstrologyContext(partner: RelationshipPerson? = nil) -> UserAstrologyContext {
        return UserAstrologyContext(
            userName: profile?.displayName,
            sunSign: userSunSign?.displayName,
            moonSign: userMoonSign?.displayName,
            risingSign: userRisingSign?.displayName,
            birthDateAvailable: onboardingBirthday != nil || userSunSign != nil,
            birthTimeAvailable: onboardingBirthTime != nil || userRisingSign != nil,
            birthPlaceAvailable: !(onboardingBirthplace ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || userRisingSign != nil,
            partnerName: partner?.displayName,
            partnerSunSign: partner?.sunSign.displayName,
            partnerMoonSign: partner?.moonSign?.displayName,
            partnerRisingSign: partner?.risingSign?.displayName,
            partnerBirthDateAvailable: partner?.birthDate != nil,
            partnerBirthTimeAvailable: partner?.birthTime != nil,
            partnerBirthPlaceAvailable: partner?.birthPlace?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        )
    }

    @discardableResult
    func submitIndividualSpecialistMessage(
        specialistId: String,
        question: String,
        context explicitContext: UserAstrologyContext? = nil
    ) async -> Bool {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let specialist = ExpertAstrologerRegistry.specialist(id: specialistId) else { return false }
        guard validateGuideMessageForSend(trimmed) else { return false }
        guard canSendMessage() else {
            showToast(
                "Messages used up",
                subtitle: "You've used all \(dailyMessageLimit) messages today. Upgrade for unlimited messages.",
                isError: true
            )
            showUpsell = true
            return false
        }

        let conversationId = specialistConversationId(for: specialistId)
        let context = explicitContext ?? currentAstrologyContext()
        let outgoing = SpecialistMessage(
            conversationId: conversationId,
            specialistId: specialistId,
            role: .user,
            content: trimmed,
            mode: .individual,
            profileContextSummary: context.summary
        )
        specialistMessages.append(outgoing)
        saveExpertAstrologerState()
        syncExpertAstrologerMessagesIfPossible([outgoing])

        typingSpecialistIds.insert(specialistId)
        analytics.track(
            .specialistResponseStarted,
            params: analyticsParams(specialistId: specialistId, mode: .individual, question: trimmed, context: context)
        )

        let request = ExpertAstrologerReplyService.Request(
            specialistId: specialistId,
            mode: .individual,
            userQuestion: trimmed,
            conversationId: conversationId,
            multiConsultationId: nil,
            profileContext: context,
            transcript: specialistConversation(for: specialistId)
        )

        let response: String
        do {
            response = try await generateExpertAstrologerReply(request: request)
            await consumeMessage()
            analytics.track(
                .specialistResponseCompleted,
                params: analyticsParams(specialistId: specialistId, mode: .individual, question: trimmed, context: context)
            )
        } catch {
            response = Self.specialistFailureMessage(for: specialist, error: error)
            analytics.track(
                .specialistResponseFailed,
                params: analyticsParams(specialistId: specialistId, mode: .individual, question: trimmed, context: context)
            )
        }

        typingSpecialistIds.remove(specialistId)
        let incoming = SpecialistMessage(
                conversationId: conversationId,
                specialistId: specialistId,
                role: .specialist,
                content: response,
                mode: .individual,
                profileContextSummary: context.summary
        )
        specialistMessages.append(incoming)
        syncExpertAstrologerMessagesIfPossible([incoming])
        saveExpertAstrologerState()
        return true
    }

    func startEveryoneConsultation(
        question: String,
        multiConsultationId: UUID = UUID(),
        context explicitContext: UserAstrologyContext? = nil
    ) async -> UUID? {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard validateGuideMessageForSend(trimmed) else { return nil }
        guard !runningEveryoneConsultationIds.contains(multiConsultationId) else {
            return multiConsultationId
        }
        guard canSendMessage() else {
            showToast(
                "Messages used up",
                subtitle: "You've used all \(dailyMessageLimit) messages today. Upgrade for unlimited messages.",
                isError: true
            )
            showUpsell = true
            return nil
        }

        runningEveryoneConsultationIds.insert(multiConsultationId)
        defer {
            runningEveryoneConsultationIds.remove(multiConsultationId)
        }

        let context = explicitContext ?? currentAstrologyContext()
        analytics.track(.everyoneModeSelected, params: analyticsParams(specialistId: "everyone", mode: .everyone, question: trimmed, context: context))

        let specialists = ExpertAstrologerRegistry.specialists
        for specialist in specialists {
            upsertEveryoneResponsePlaceholder(
                multiConsultationId: multiConsultationId,
                specialistId: specialist.id,
                userQuestion: trimmed,
                profileContextSummary: context.summary
            )
        }
        saveExpertAstrologerState()
        syncExpertAstrologerConsultationIfPossible(
            id: multiConsultationId,
            userQuestion: trimmed,
            profileContextSummary: context.summary
        )
        syncExpertAstrologerResponsesIfPossible(everyoneResponses(for: multiConsultationId))

        await runEveryoneResponses(
            multiConsultationId: multiConsultationId,
            specialists: specialists,
            question: trimmed,
            context: context,
            isRetry: false
        )

        if everyoneResponses(for: multiConsultationId).contains(where: { $0.specialistResponse != nil }) {
            await consumeMessage()
        }

        return multiConsultationId
    }

    @discardableResult
    func retryEveryoneResponse(_ response: SpecialistConsultationResponse) async -> Bool {
        guard response.errorMessage != nil || response.specialistResponse == nil else {
            return false
        }
        guard let specialist = ExpertAstrologerRegistry.specialist(id: response.specialistId) else {
            return false
        }
        let key = everyoneResponseKey(
            multiConsultationId: response.multiConsultationId,
            specialistId: response.specialistId
        )
        guard !runningEveryoneResponseKeys.contains(key) else {
            return false
        }

        let context = currentAstrologyContext()
        updateEveryoneResponse(
            multiConsultationId: response.multiConsultationId,
            specialistId: response.specialistId,
            response: nil,
            errorMessage: nil
        )
        await runEveryoneResponses(
            multiConsultationId: response.multiConsultationId,
            specialists: [specialist],
            question: response.userQuestion,
            context: context,
            isRetry: true
        )
        return true
    }

    func everyoneResponses(for multiConsultationId: UUID?) -> [SpecialistConsultationResponse] {
        guard let multiConsultationId else { return [] }
        return specialistConsultationResponses
            .filter { $0.multiConsultationId == multiConsultationId }
            .sorted { lhs, rhs in
                let lhsIndex = ExpertAstrologerRegistry.specialists.firstIndex { $0.id == lhs.specialistId } ?? .max
                let rhsIndex = ExpertAstrologerRegistry.specialists.firstIndex { $0.id == rhs.specialistId } ?? .max
                return lhsIndex < rhsIndex
            }
    }

    private func updateEveryoneResponse(
        multiConsultationId: UUID,
        specialistId: String,
        response: String?,
        errorMessage: String?
    ) {
        guard let index = specialistConsultationResponses.firstIndex(where: {
            $0.multiConsultationId == multiConsultationId && $0.specialistId == specialistId
        }) else { return }

        var updated = specialistConsultationResponses[index]
        updated.specialistResponse = response
        updated.errorMessage = errorMessage
        specialistConsultationResponses[index] = updated
        saveExpertAstrologerState()
        syncExpertAstrologerResponsesIfPossible([updated])
    }

    private func upsertEveryoneResponsePlaceholder(
        multiConsultationId: UUID,
        specialistId: String,
        userQuestion: String,
        profileContextSummary: String?
    ) {
        if let index = specialistConsultationResponses.firstIndex(where: {
            $0.multiConsultationId == multiConsultationId && $0.specialistId == specialistId
        }) {
            var updated = specialistConsultationResponses[index]
            updated.specialistResponse = nil
            updated.errorMessage = nil
            specialistConsultationResponses[index] = updated
            return
        }

        specialistConsultationResponses.append(
            SpecialistConsultationResponse(
                multiConsultationId: multiConsultationId,
                specialistId: specialistId,
                userQuestion: userQuestion,
                profileContextSummary: profileContextSummary
            )
        )
    }

    private func runEveryoneResponses(
        multiConsultationId: UUID,
        specialists: [AstrologySpecialist],
        question: String,
        context: UserAstrologyContext,
        isRetry: Bool
    ) async {
        let specialistsToRun = specialists.filter { specialist in
            let key = everyoneResponseKey(multiConsultationId: multiConsultationId, specialistId: specialist.id)
            return !runningEveryoneResponseKeys.contains(key)
        }
        guard !specialistsToRun.isEmpty else { return }

        let startedKeys = specialistsToRun.map {
            everyoneResponseKey(multiConsultationId: multiConsultationId, specialistId: $0.id)
        }
        defer {
            for specialist in specialistsToRun {
                typingSpecialistIds.remove(specialist.id)
            }
            for key in startedKeys {
                runningEveryoneResponseKeys.remove(key)
            }
        }

        for specialist in specialistsToRun {
            let key = everyoneResponseKey(multiConsultationId: multiConsultationId, specialistId: specialist.id)
            runningEveryoneResponseKeys.insert(key)
            typingSpecialistIds.insert(specialist.id)
            analytics.track(
                .specialistResponseStarted,
                params: analyticsParams(
                    specialistId: specialist.id,
                    mode: .everyone,
                    question: question,
                    context: context,
                    extra: ["retry": isRetry ? "true" : "false"]
                )
            )
        }

        await withTaskGroup(of: EveryoneSpecialistResult.self) { group in
            for specialist in specialistsToRun {
                let request = ExpertAstrologerReplyService.Request(
                    specialistId: specialist.id,
                    mode: .everyone,
                    userQuestion: question,
                    conversationId: nil,
                    multiConsultationId: multiConsultationId,
                    profileContext: context,
                    transcript: []
                )
                group.addTask {
                    let startedAt = Date()
                    do {
                        let text = try await self.generateExpertAstrologerReply(request: request)
                        return EveryoneSpecialistResult(
                            specialistId: specialist.id,
                            response: text,
                            errorMessage: nil,
                            latencyMs: Int(Date().timeIntervalSince(startedAt) * 1000)
                        )
                    } catch {
                        return EveryoneSpecialistResult(
                            specialistId: specialist.id,
                            response: nil,
                            errorMessage: Self.specialistFailureMessage(for: specialist, error: error),
                            latencyMs: Int(Date().timeIntervalSince(startedAt) * 1000)
                        )
                    }
                }
            }

            for await result in group {
                let key = everyoneResponseKey(
                    multiConsultationId: multiConsultationId,
                    specialistId: result.specialistId
                )
                let specialist = ExpertAstrologerRegistry.specialist(id: result.specialistId)
                let errorMessage = result.errorMessage
                    ?? "The \(specialist?.displayName ?? "specialist") could not respond right now. Please try again."

                updateEveryoneResponse(
                    multiConsultationId: multiConsultationId,
                    specialistId: result.specialistId,
                    response: result.response,
                    errorMessage: result.response == nil ? errorMessage : nil
                )
                typingSpecialistIds.remove(result.specialistId)
                runningEveryoneResponseKeys.remove(key)

                let event: AnalyticsService.Event = result.response == nil
                    ? .specialistResponseFailed
                    : .specialistResponseCompleted
                analytics.track(
                    event,
                    params: analyticsParams(
                        specialistId: result.specialistId,
                        mode: .everyone,
                        question: question,
                        context: context,
                        extra: [
                            "latencyMs": "\(result.latencyMs)",
                            "retry": isRetry ? "true" : "false"
                        ]
                    )
                )
            }
        }
    }

    private func everyoneResponseKey(multiConsultationId: UUID, specialistId: String) -> String {
        "\(multiConsultationId.uuidString).\(specialistId)"
    }

    private func generateExpertAstrologerReply(
        request: ExpertAstrologerReplyService.Request
    ) async throws -> String {
        #if DEBUG
        if isDebugPreviewStateActive {
            if shouldForceExpertAstrologerPreviewFailure(for: request.specialistId) {
                throw ExpertAstrologerError.generationFailed
            }
            try? await Task.sleep(for: .milliseconds(450))
            return ExpertAstrologerReplyService.localFallback(for: request)
        }
        #endif

        guard AppConfig.llmChatEnabled, supabase.canInvokeCompanionReply else {
            return ExpertAstrologerReplyService.localFallback(for: request)
        }
        guard ExpertAstrologerRegistry.specialist(id: request.specialistId) != nil else {
            throw ExpertAstrologerError.missingSpecialist
        }

        guard let response = await GuideReplyService.withTimeout(seconds: ExpertAstrologerReplyService.replyTimeout, operation: { [supabase] in
            try await supabase.invokeExpertAstrologerReply(
                request: request,
                maxTokens: ExpertAstrologerReplyService.replyMaxTokens
            )
        }) else {
            throw ExpertAstrologerError.generationFailed
        }
        return response
    }

    private func analyticsParams(
        specialistId: String,
        mode: ExpertAstrologerMode,
        question: String,
        context: UserAstrologyContext,
        extra: [String: String] = [:]
    ) -> [String: String] {
        var params = context.analyticsParams
        params["specialistId"] = specialistId
        params["mode"] = mode.rawValue
        params["questionCategory"] = questionCategory(for: question)
        for (key, value) in extra {
            params[key] = value
        }
        return params
    }

    private func questionCategory(for question: String) -> String {
        let normalized = question.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let known = ["love", "relationships", "career", "family", "timing", "life direction"]
        return known.first { normalized == $0 || normalized.contains($0) } ?? "custom"
    }

    nonisolated private static func specialistFailureMessage(for specialist: AstrologySpecialist, error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }
        return "The \(specialist.displayName) could not respond right now. Please try again."
    }

    private func mergeExpertAstrologerMessages(_ remoteMessages: [SpecialistMessage]) {
        guard !remoteMessages.isEmpty else { return }
        var merged: [UUID: SpecialistMessage] = [:]
        for message in specialistMessages {
            merged[message.id] = message
        }
        for message in remoteMessages {
            merged[message.id] = message
        }
        specialistMessages = merged.values.sorted { $0.timestamp < $1.timestamp }
        persistSpecialistConversationIds()
    }

    private func mergeExpertAstrologerResponses(_ remoteResponses: [SpecialistConsultationResponse]) {
        guard !remoteResponses.isEmpty else { return }
        var merged: [UUID: SpecialistConsultationResponse] = [:]
        for response in specialistConsultationResponses {
            merged[response.id] = response
        }
        for response in remoteResponses {
            merged[response.id] = response
        }
        specialistConsultationResponses = merged.values.sorted { $0.timestamp < $1.timestamp }
    }

    private func persistSpecialistConversationIds() {
        var map = (UserDefaults.standard.data(forKey: Self.specialistConversationIdsKey))
            .flatMap { try? JSONDecoder().decode([String: UUID].self, from: $0) } ?? [:]
        for message in specialistMessages where message.mode == .individual {
            map[message.specialistId] = message.conversationId
        }
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: Self.specialistConversationIdsKey)
        }
    }

    private func syncPendingExpertAstrologerStateIfPossible() {
        syncExpertAstrologerMessagesIfPossible(specialistMessages)
        syncExpertAstrologerResponsesIfPossible(specialistConsultationResponses)
    }

    private func syncExpertAstrologerMessagesIfPossible(_ messages: [SpecialistMessage]) {
        guard isAuthenticated, !messages.isEmpty else { return }
        #if DEBUG
        if isDebugPreviewStateActive { return }
        #endif

        Task { [weak self, messages] in
            guard let self else { return }
            do {
                try await self.supabase.upsertExpertAstrologerMessages(messages)
            } catch {
                CrashReporter.log(error, context: "syncExpertAstrologerMessages")
            }
        }
    }

    private func syncExpertAstrologerConsultationIfPossible(
        id: UUID,
        userQuestion: String,
        profileContextSummary: String?
    ) {
        guard isAuthenticated else { return }
        #if DEBUG
        if isDebugPreviewStateActive { return }
        #endif

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.supabase.upsertExpertAstrologerConsultation(
                    id: id,
                    userQuestion: userQuestion,
                    profileContextSummary: profileContextSummary
                )
            } catch {
                CrashReporter.log(error, context: "syncExpertAstrologerConsultation")
            }
        }
    }

    private func syncExpertAstrologerResponsesIfPossible(_ responses: [SpecialistConsultationResponse]) {
        guard isAuthenticated, !responses.isEmpty else { return }
        #if DEBUG
        if isDebugPreviewStateActive { return }
        #endif

        Task { [weak self, responses] in
            guard let self else { return }
            do {
                try await self.supabase.upsertExpertAstrologerConsultationResponses(responses)
            } catch {
                CrashReporter.log(error, context: "syncExpertAstrologerResponses")
            }
        }
    }
}

private enum ExpertAstrologerError: Error {
    case missingSpecialist
    case generationFailed
}

private struct EveryoneSpecialistResult: Sendable {
    let specialistId: String
    let response: String?
    let errorMessage: String?
    let latencyMs: Int
}

#if DEBUG
private extension AppViewModel {
    func shouldForceExpertAstrologerPreviewFailure(for specialistId: String) -> Bool {
        let environment = ProcessInfo.processInfo.environment
        if specialistIdSet(from: environment["SIMASTRY_EXPERT_FAIL_SPECIALIST_IDS"]).contains(specialistId) {
            return true
        }

        let oneShotIds = specialistIdSet(from: environment["SIMASTRY_EXPERT_FAIL_ONCE_SPECIALIST_IDS"])
        guard oneShotIds.contains(specialistId),
              !consumedExpertAstrologerPreviewFailures.contains(specialistId) else {
            return false
        }
        consumedExpertAstrologerPreviewFailures.insert(specialistId)
        return true
    }

    func specialistIdSet(from value: String?) -> Set<String> {
        guard let value else { return [] }
        return Set(
            value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}
#endif
