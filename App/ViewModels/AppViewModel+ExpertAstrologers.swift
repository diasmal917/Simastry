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
        expertManualAstrologyData = ExpertManualAstrologyData()
        ExpertManualAstrologyData.clear()
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

        // Intake is isolated so a missing/lagging table never blocks chat sync.
        do {
            if let intake = try await supabase.fetchExpertAstrologyIntake() {
                hydrateFromIntake(intake)
            }
        } catch {
            CrashReporter.log(error, context: "refreshExpertAstrologyIntake")
        }

        await refreshExpertChartImports()
    }

    // MARK: - Expert Astrology Intake

    /// Mirrors the user's birth + manual tradition data to
    /// `public.expert_astrology_intake`. The snapshot is built on the main actor
    /// so the upsert task only carries a Sendable value across actors.
    func persistExpertAstrologyIntakeIfPossible() {
        guard isAuthenticated else { return }
        #if DEBUG
        if isDebugPreviewStateActive { return }
        #endif

        let draft = currentExpertAstrologyIntakeRecord(userId: UUID())
        Task { [weak self, draft] in
            guard let self else { return }
            guard let userId = await self.supabase.currentUserId else { return }
            var record = draft
            record.userId = userId
            do {
                try await self.supabase.upsertExpertAstrologyIntake(record)
            } catch {
                CrashReporter.log(error, context: "persistExpertAstrologyIntake")
            }
        }
    }

    /// Builds the intake snapshot from onboarding birth data + manual fields.
    /// Birth/partner times are dropped when the matching "unknown" flag is set,
    /// honoring the table's `*_birth_time_unknown ⇒ *_birth_time IS NULL` checks.
    func currentExpertAstrologyIntakeRecord(userId: UUID) -> ExpertAstrologyIntakeRecord {
        let manual = expertManualAstrologyData
        let birthTimeUnknown = manual.userDoesNotKnowBirthTime
        let partnerBirthTimeUnknown = manual.partnerDoesNotKnowBirthTime
        let birthPlace = (onboardingBirthplace ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let partnerPlace = manual.partnerBirthPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        return ExpertAstrologyIntakeRecord(
            userId: userId,
            birthDate: Self.formatIntakeDate(onboardingBirthday),
            birthTime: birthTimeUnknown ? nil : Self.formatIntakeTime(onboardingBirthTime),
            birthTimeUnknown: birthTimeUnknown,
            birthPlace: birthPlace.isEmpty ? nil : birthPlace,
            partnerBirthDate: Self.formatIntakeDate(manual.partnerBirthDate),
            partnerBirthTime: partnerBirthTimeUnknown ? nil : Self.formatIntakeTime(manual.partnerBirthTime),
            partnerBirthTimeUnknown: partnerBirthTimeUnknown,
            partnerBirthPlace: partnerPlace.isEmpty ? nil : partnerPlace,
            userSuppliedTraditionData: manual.intakeTraditionData
        )
    }

    /// Reloads a saved intake row into local state. Local edits always win:
    /// manual fields and birth context are only filled where they are currently
    /// empty, so unsynced changes and onboarding/profile sync are never clobbered.
    private func hydrateFromIntake(_ record: ExpertAstrologyIntakeRecord) {
        var manual = expertManualAstrologyData
        manual.applyIntakeTraditionData(record.userSuppliedTraditionData)
        if record.birthTimeUnknown { manual.userDoesNotKnowBirthTime = true }
        if record.partnerBirthTimeUnknown { manual.partnerDoesNotKnowBirthTime = true }

        if manual.partnerBirthDate == nil, let date = Self.parseIntakeDate(record.partnerBirthDate) {
            manual.partnerBirthDate = date
        }
        if manual.partnerBirthTime == nil, !manual.partnerDoesNotKnowBirthTime,
           let time = Self.parseIntakeTime(record.partnerBirthTime) {
            manual.partnerBirthTime = time
        }
        if manual.partnerBirthPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let place = record.partnerBirthPlace?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty {
            manual.partnerBirthPlace = place
        }

        if manual != expertManualAstrologyData {
            expertManualAstrologyData = manual
        }

        // Backfill the user's own birth context only when missing locally.
        if onboardingBirthday == nil, let date = Self.parseIntakeDate(record.birthDate) {
            onboardingBirthday = date
        }
        if onboardingBirthTime == nil, !record.birthTimeUnknown, let time = Self.parseIntakeTime(record.birthTime) {
            onboardingBirthTime = time
        }
        if (onboardingBirthplace ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let place = record.birthPlace?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty {
            onboardingBirthplace = place
        }
    }

    static func formatIntakeDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        return intakeFormatter(format: "yyyy-MM-dd").string(from: date)
    }

    static func formatIntakeTime(_ date: Date?) -> String? {
        guard let date else { return nil }
        return intakeFormatter(format: "HH:mm:ss").string(from: date)
    }

    private static func parseIntakeDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return intakeFormatter(format: "yyyy-MM-dd").date(from: string)
    }

    private static func parseIntakeTime(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        // Postgres `time` serializes as HH:mm:ss; tolerate a bare HH:mm too.
        for format in ["HH:mm:ss", "HH:mm"] {
            if let date = intakeFormatter(format: format).date(from: string) {
                return date
            }
        }
        return nil
    }

    /// Wall-clock formatter in the user's current timezone, matching the values
    /// the date/time pickers produce.
    private static func intakeFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
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
            birthDateAvailable: onboardingBirthday != nil,
            birthTimeAvailable: onboardingBirthTime != nil,
            birthPlaceAvailable: !(onboardingBirthplace ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
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
        context explicitContext: UserAstrologyContext? = nil,
        selectedPersonId: UUID? = nil
    ) async -> Bool {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let specialist = ExpertAstrologerRegistry.specialist(id: specialistId) else { return false }
        guard validateGuideMessageForSend(trimmed) else { return false }
        if let selectedPersonId { persistPersonAstrologyIntakeIfPossible(personId: selectedPersonId) }
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
        let readiness = ExpertReadinessBuilder.checklist(
            for: specialist,
            question: trimmed,
            context: context,
            manualData: expertManualAstrologyData
        )
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
            selectedPersonId: selectedPersonId,
            profileContext: context,
            transcript: specialistConversation(for: specialistId),
            readiness: readiness,
            manualData: expertManualAstrologyData
        )

        var streamingMessageId: UUID?
        func applyPartial(_ text: String) {
            if let id = streamingMessageId,
               let index = specialistMessages.firstIndex(where: { $0.id == id }) {
                specialistMessages[index].content = text
            } else {
                // First streamed token: retire the typing indicator and start the
                // assistant bubble that grows as more text arrives.
                typingSpecialistIds.remove(specialistId)
                let message = SpecialistMessage(
                    conversationId: conversationId,
                    specialistId: specialistId,
                    role: .specialist,
                    content: text,
                    mode: .individual,
                    profileContextSummary: context.summary
                )
                streamingMessageId = message.id
                specialistMessages.append(message)
            }
        }

        let finalText: String
        do {
            let outcome = try await generateExpertAstrologerReply(request: request) { applyPartial($0) }
            finalText = outcome.text
            await consumeMessage()
            analytics.track(
                .specialistResponseCompleted,
                params: analyticsParams(
                    specialistId: specialistId,
                    mode: .individual,
                    question: trimmed,
                    context: context,
                    extra: usageEventParams(outcome.usageEventId)
                )
            )
        } catch {
            finalText = Self.specialistFailureMessage(for: specialist, error: error)
            analytics.track(
                .specialistResponseFailed,
                params: analyticsParams(specialistId: specialistId, mode: .individual, question: trimmed, context: context)
            )
        }

        typingSpecialistIds.remove(specialistId)

        let finalized: SpecialistMessage
        if let id = streamingMessageId,
           let index = specialistMessages.firstIndex(where: { $0.id == id }) {
            specialistMessages[index].content = finalText
            finalized = specialistMessages[index]
        } else {
            finalized = SpecialistMessage(
                conversationId: conversationId,
                specialistId: specialistId,
                role: .specialist,
                content: finalText,
                mode: .individual,
                profileContextSummary: context.summary
            )
            specialistMessages.append(finalized)
        }
        syncExpertAstrologerMessagesIfPossible([finalized])
        saveExpertAstrologerState()
        return true
    }

    func startEveryoneConsultation(
        question: String,
        multiConsultationId: UUID = UUID(),
        context explicitContext: UserAstrologyContext? = nil,
        selectedPersonId: UUID? = nil
    ) async -> UUID? {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard validateGuideMessageForSend(trimmed) else { return nil }
        if let selectedPersonId { persistPersonAstrologyIntakeIfPossible(personId: selectedPersonId) }
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
            selectedPersonId: selectedPersonId,
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
            selectedPersonId: nil,
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
        selectedPersonId: UUID?,
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

        let manualData = expertManualAstrologyData
        await withTaskGroup(of: EveryoneSpecialistResult.self) { group in
            for specialist in specialistsToRun {
                let readiness = ExpertReadinessBuilder.checklist(
                    for: specialist,
                    question: question,
                    context: context,
                    manualData: manualData
                )
                let request = ExpertAstrologerReplyService.Request(
                    specialistId: specialist.id,
                    mode: .everyone,
                    userQuestion: question,
                    conversationId: nil,
                    multiConsultationId: multiConsultationId,
                    selectedPersonId: selectedPersonId,
                    profileContext: context,
                    transcript: [],
                    readiness: readiness,
                    manualData: manualData
                )
                group.addTask {
                    await self.streamEveryoneSpecialistReply(
                        multiConsultationId: multiConsultationId,
                        specialist: specialist,
                        request: request
                    )
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
                var extra: [String: String] = [
                    "latencyMs": "\(result.latencyMs)",
                    "retry": isRetry ? "true" : "false"
                ]
                if let usageEventId = result.usageEventId {
                    extra["usageEventId"] = usageEventId.uuidString
                }
                analytics.track(
                    event,
                    params: analyticsParams(
                        specialistId: result.specialistId,
                        mode: .everyone,
                        question: question,
                        context: context,
                        extra: extra
                    )
                )
            }
        }
    }

    private func everyoneResponseKey(multiConsultationId: UUID, specialistId: String) -> String {
        "\(multiConsultationId.uuidString).\(specialistId)"
    }

    /// Streams one specialist's Everyone-mode reply, growing its card in memory
    /// as tokens arrive, and returns the final result for persistence + analytics.
    private func streamEveryoneSpecialistReply(
        multiConsultationId: UUID,
        specialist: AstrologySpecialist,
        request: ExpertAstrologerReplyService.Request
    ) async -> EveryoneSpecialistResult {
        let startedAt = Date()
        func applyPartial(_ text: String) {
            setEveryoneResponsePartial(
                multiConsultationId: multiConsultationId,
                specialistId: specialist.id,
                text: text
            )
        }
        do {
            let outcome = try await generateExpertAstrologerReply(request: request) { applyPartial($0) }
            return EveryoneSpecialistResult(
                specialistId: specialist.id,
                response: outcome.text,
                errorMessage: nil,
                latencyMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                usageEventId: outcome.usageEventId
            )
        } catch {
            return EveryoneSpecialistResult(
                specialistId: specialist.id,
                response: nil,
                errorMessage: Self.specialistFailureMessage(for: specialist, error: error),
                latencyMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                usageEventId: nil
            )
        }
    }

    /// Updates only the in-memory streamed text for an Everyone card. The final
    /// value is persisted and synced once on completion via `updateEveryoneResponse`.
    private func setEveryoneResponsePartial(
        multiConsultationId: UUID,
        specialistId: String,
        text: String
    ) {
        guard let index = specialistConsultationResponses.firstIndex(where: {
            $0.multiConsultationId == multiConsultationId && $0.specialistId == specialistId
        }) else { return }
        specialistConsultationResponses[index].specialistResponse = text
        specialistConsultationResponses[index].errorMessage = nil
    }

    private func usageEventParams(_ usageEventId: UUID?) -> [String: String] {
        guard let usageEventId else { return [:] }
        return ["usageEventId": usageEventId.uuidString]
    }

    /// Generates an expert reply, streaming when enabled. `onPartial` receives
    /// the cumulative assistant text on each delta (called on the main actor).
    /// Falls back to the JSON request when streaming is disabled, unavailable,
    /// or fails before the first token; a mid-stream failure surfaces as an error.
    private func generateExpertAstrologerReply(
        request: ExpertAstrologerReplyService.Request,
        onPartial: (String) -> Void = { _ in }
    ) async throws -> ExpertAstrologerReplyOutcome {
        #if DEBUG
        if isDebugPreviewStateActive {
            if shouldForceExpertAstrologerPreviewFailure(for: request.specialistId) {
                throw ExpertAstrologerError.generationFailed
            }
            let text = ExpertAstrologerReplyService.localFallback(for: request)
            await simulateStreamedExpertPreview(text, onPartial: onPartial)
            return ExpertAstrologerReplyOutcome(text: text, usageEventId: nil)
        }
        #endif

        guard AppConfig.llmChatEnabled, supabase.canInvokeCompanionReply else {
            return ExpertAstrologerReplyOutcome(
                text: ExpertAstrologerReplyService.localFallback(for: request),
                usageEventId: nil
            )
        }
        guard ExpertAstrologerRegistry.specialist(id: request.specialistId) != nil else {
            throw ExpertAstrologerError.missingSpecialist
        }

        if AppConfig.expertAstrologerStreamingEnabled {
            var accumulated = ""
            var sawDelta = false
            var metaUsageEventId: UUID?
            do {
                let stream = supabase.streamExpertAstrologerReply(
                    request: request,
                    maxTokens: ExpertAstrologerReplyService.replyMaxTokens
                )
                for try await event in stream {
                    switch event {
                    case let .meta(usageEventId, _, _):
                        metaUsageEventId = usageEventId
                    case let .delta(chunk):
                        sawDelta = true
                        accumulated += chunk
                        onPartial(accumulated)
                    case let .done(text, usageEventId):
                        let final = text.isEmpty ? accumulated : text
                        if !final.isEmpty { onPartial(final) }
                        return ExpertAstrologerReplyOutcome(
                            text: final,
                            usageEventId: usageEventId ?? metaUsageEventId
                        )
                    case let .error(_, message):
                        if sawDelta {
                            throw SupabaseServiceError.functionFailed(message)
                        }
                        throw ExpertAstrologerStreamFallback.unavailable
                    }
                }
                // Stream closed without an explicit `done` frame.
                if sawDelta {
                    return ExpertAstrologerReplyOutcome(text: accumulated, usageEventId: metaUsageEventId)
                }
                // Nothing arrived — fall through to the JSON request.
            } catch is ExpertAstrologerStreamFallback {
                // Intentional fall-through to JSON.
            } catch {
                // A failure after streaming began is a real error; only pre-token
                // failures are silently downgraded to the JSON fallback.
                if sawDelta { throw error }
            }
        }

        guard let response = await GuideReplyService.withTimeout(seconds: ExpertAstrologerReplyService.replyTimeout, operation: { [supabase] in
            try await supabase.invokeExpertAstrologerReply(
                request: request,
                maxTokens: ExpertAstrologerReplyService.replyMaxTokens
            )
        }) else {
            throw ExpertAstrologerError.generationFailed
        }
        return ExpertAstrologerReplyOutcome(text: response, usageEventId: nil)
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

/// Internal signal that streaming could not start (no tokens received), so the
/// caller should transparently fall back to the JSON request.
private enum ExpertAstrologerStreamFallback: Error {
    case unavailable
}

private struct ExpertAstrologerReplyOutcome: Sendable {
    let text: String
    let usageEventId: UUID?
}

private struct EveryoneSpecialistResult: Sendable {
    let specialistId: String
    let response: String?
    let errorMessage: String?
    let latencyMs: Int
    let usageEventId: UUID?
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

    func expertAstrologerPreviewDelayMs() -> Int {
        let raw = ProcessInfo.processInfo.environment["SIMASTRY_EXPERT_PREVIEW_DELAY_MS"]
            .flatMap(Int.init) ?? 450
        return min(max(raw, 0), 5_000)
    }

    /// Replays the local fallback as incremental chunks so preview/UI-test runs
    /// exercise the same incremental-render path as live SSE, within the
    /// existing preview delay budget.
    func simulateStreamedExpertPreview(_ text: String, onPartial: (String) -> Void) async {
        let chunks = Self.previewStreamChunks(text)
        guard !chunks.isEmpty else { return }
        let perChunkMs = max(1, expertAstrologerPreviewDelayMs() / chunks.count)
        var accumulated = ""
        for chunk in chunks {
            try? await Task.sleep(for: .milliseconds(perChunkMs))
            if Task.isCancelled { return }
            accumulated += chunk
            onPartial(accumulated)
        }
    }

    static func previewStreamChunks(_ text: String, maxChunks: Int = 14) -> [String] {
        guard !text.isEmpty else { return [] }
        let characters = Array(text)
        let chunkSize = max(1, Int(ceil(Double(characters.count) / Double(maxChunks))))
        var chunks: [String] = []
        var index = 0
        while index < characters.count {
            let upper = min(index + chunkSize, characters.count)
            chunks.append(String(characters[index..<upper]))
            index = upper
        }
        return chunks
    }
}
#endif
