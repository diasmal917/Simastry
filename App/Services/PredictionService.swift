import Foundation

nonisolated enum PredictionServiceError: LocalizedError, Sendable {
    case serviceUnavailable
    case invalidRequest
    case invalidResponse
    case emptyResponse
    case blockedByPrivacy(String)
    case serverError(String)
    case aiUsageLimit(String)

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            "The guidance service is not connected yet."
        case .invalidRequest:
            "Add the missing details for this question, then try again."
        case .invalidResponse:
            "The guidance response used an unexpected format."
        case .emptyResponse:
            "The reading came back empty. Try again in a moment."
        case .blockedByPrivacy(let message):
            message
        case .serverError(let message):
            message
        case .aiUsageLimit(let message):
            message
        }
    }
}

nonisolated final class PredictionService {
    static let defaultRemotePredictionTimeout: Double = 8

    private let privacyService: ConversationPrivacyService
    private let historyKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Server-proxied generation channel (the companion-reply edge function).
    /// The Anthropic key lives only in edge-function secrets — never in the
    /// app binary. Injected by AppViewModel; nil in isolation (tests).
    var replyChannel: (@Sendable (_ system: String, _ user: String) async throws -> String)?
    var isRemoteChannelAvailable: (@Sendable () -> Bool)?
    var remotePredictionTimeout: Double = defaultRemotePredictionTimeout

    init(
        privacyService: ConversationPrivacyService = ConversationPrivacyService(),
        historyKey: String = "simastry_prediction_history"
    ) {
        self.privacyService = privacyService
        self.historyKey = historyKey

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    var isConfigured: Bool {
        replyChannel != nil && (isRemoteChannelAvailable?() ?? false)
    }

    func generatePrediction(request: PredictionRequest, tier: String) async throws -> PredictionResult {
        try validateRequest(request)

        let preparedConversation = privacyService.prepare(request.trimmedConversationText)
        let preparedQuestion = request.trimmedQuestion.map { privacyService.prepare($0) }
        let preparedHypotheticalReply = request.trimmedHypotheticalReply.map { privacyService.prepare($0) }
        let preparedOptions = request.comparisonOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { privacyService.prepare($0) }
        let trimmedAdditionalContext = request.additionalContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let preparedAdditionalContext = trimmedAdditionalContext.isEmpty
            ? nil
            : privacyService.prepare(trimmedAdditionalContext)

        if !request.trimmedConversationText.isEmpty {
            try validatePrivacy(preparedConversation)
        }
        if let preparedQuestion {
            try validatePrivacy(preparedQuestion)
        }
        if let preparedHypotheticalReply {
            try validatePrivacy(preparedHypotheticalReply)
        }
        for preparedOption in preparedOptions {
            try validatePrivacy(preparedOption)
        }
        if let preparedAdditionalContext {
            try validatePrivacy(preparedAdditionalContext)
        }

        guard isConfigured else {
            // No remote channel configured: return practical reflection so
            // Compass never dead-ends. Privacy validation above still applies.
            let result = composeLocalPrediction(
                request: request,
                preparedConversation: preparedConversation,
                preparedQuestion: preparedQuestion,
                preparedHypotheticalReply: preparedHypotheticalReply,
                preparedOptions: preparedOptions,
                preparedAdditionalContext: preparedAdditionalContext
            )
            save(result)
            return result
        }

        let systemPrompt = makeSystemPrompt(for: request)
        let userPrompt = makeUserPrompt(
            for: request,
            preparedConversation: preparedConversation,
            preparedQuestion: preparedQuestion,
            preparedHypotheticalReply: preparedHypotheticalReply,
            preparedOptions: preparedOptions,
            preparedAdditionalContext: preparedAdditionalContext
        )

        guard let replyChannel else {
            throw PredictionServiceError.serviceUnavailable
        }

        let text: String
        let remoteAttempt = await Self.withRemoteTimeout(seconds: remotePredictionTimeout) {
            try await replyChannel(systemPrompt, userPrompt)
        }
        switch remoteAttempt {
        case .success(let remoteText):
            text = remoteText
        case .failure(let error):
            if let limitError = Self.aiUsageLimitError(from: error) {
                throw limitError
            }
            let result = composeLocalPrediction(
                request: request,
                preparedConversation: preparedConversation,
                preparedQuestion: preparedQuestion,
                preparedHypotheticalReply: preparedHypotheticalReply,
                preparedOptions: preparedOptions,
                preparedAdditionalContext: preparedAdditionalContext
            )
            save(result)
            return result
        case nil:
            let result = composeLocalPrediction(
                request: request,
                preparedConversation: preparedConversation,
                preparedQuestion: preparedQuestion,
                preparedHypotheticalReply: preparedHypotheticalReply,
                preparedOptions: preparedOptions,
                preparedAdditionalContext: preparedAdditionalContext
            )
            save(result)
            return result
        }

        // Parse the structured response from Claude
        let parsed = parseClaudeResponse(text)
        let displayAnswer = parsed.directAnswer ?? parsed.predictedMessage

        guard !displayAnswer.isEmpty else {
            throw PredictionServiceError.emptyResponse
        }

        let result = PredictionResult(
            id: UUID(),
            mode: request.mode,
            category: request.category,
            compassIntent: request.intent,
            compassTopic: request.topic,
            question: preparedQuestion?.redactedText ?? request.category.defaultQuestion,
            conversationText: preparedConversation.redactedText.isEmpty ? nil : preparedConversation.redactedText,
            userSunSign: request.userSunSign,
            userMoonSign: request.userMoonSign,
            userRisingSign: request.userRisingSign,
            targetSunSign: request.targetSunSign,
            targetMoonSign: request.targetMoonSign,
            targetRisingSign: request.targetRisingSign,
            predictedMessage: parsed.predictedMessage.isEmpty ? displayAnswer : parsed.predictedMessage,
            directAnswer: parsed.directAnswer,
            timingWindow: request.hasTimingEvidence ? "Today’s calculated transit window" : nil,
            astrologicalBreakdown: evidenceBreakdown(for: request),
            practicalNextMove: parsed.practicalNextMove ?? localReflectiveNextMove(for: request),
            safetyNote: parsed.safetyNote,
            plausibleAlternative: parsed.plausibleAlternative ?? localReflectiveAlternative(for: request),
            suggestedReply: parsed.suggestedReply ?? (request.intent == .conversation
                ? "Could we talk about this directly? I’d rather understand than guess."
                : nil),
            evidence: normalizedEvidence(for: request),
            contextQuality: contextQuality(for: request),
            // Retained only for decoding old history. Compass never presents a
            // pseudo-precise confidence score.
            confidence: 0,
            tone: parsed.tone,
            privacySummary: combinedPrivacySummary(
                conversation: preparedConversation,
                question: preparedQuestion,
                hypotheticalReply: preparedHypotheticalReply,
                extras: preparedOptions + [preparedAdditionalContext].compactMap { $0 }
            ),
            createdAt: Date(),
            isLocalComposition: false
        )

        save(result)
        return result
    }

    private static func aiUsageLimitError(from error: Error) -> PredictionServiceError? {
        if let predictionError = error as? PredictionServiceError,
           case let .aiUsageLimit(message) = predictionError {
            return .aiUsageLimit(message)
        }
        if let supabaseError = error as? SupabaseServiceError,
           case let .aiUsageLimit(message) = supabaseError {
            return .aiUsageLimit(message)
        }
        return nil
    }

    private static func withRemoteTimeout<Output: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> Output
    ) async -> Result<Output, Error>? {
        let coordinator = PredictionTimeoutCoordinator<Output>()
        let operationTask = Task {
            do {
                await coordinator.complete(.success(try await operation()))
            } catch is CancellationError {
                return
            } catch {
                await coordinator.complete(.failure(error))
            }
        }
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            await coordinator.complete(nil)
        }

        let result = await coordinator.wait()
        operationTask.cancel()
        timeoutTask.cancel()
        return result
    }

    // MARK: - Honest local fallback

    /// When remote guidance is unavailable, return useful reflection without
    /// pretending to forecast a reply or inventing an astrological window.
    private func composeLocalPrediction(
        request: PredictionRequest,
        preparedConversation: ConversationPrivacyResult,
        preparedQuestion: ConversationPrivacyResult?,
        preparedHypotheticalReply: ConversationPrivacyResult?,
        preparedOptions: [ConversationPrivacyResult],
        preparedAdditionalContext: ConversationPrivacyResult?
    ) -> PredictionResult {
        let question = preparedQuestion?.redactedText ?? request.category.defaultQuestion
        let takeaway = localReflectiveTakeaway(for: request)
        let nextMove = localReflectiveNextMove(for: request)
        let alternative = localReflectiveAlternative(for: request)
        let fallbackEvidence = normalizedEvidence(for: request)

        return PredictionResult(
            id: UUID(),
            mode: request.mode,
            category: request.category,
            compassIntent: request.intent,
            compassTopic: request.topic,
            question: question,
            conversationText: preparedConversation.redactedText.isEmpty ? nil : preparedConversation.redactedText,
            userSunSign: request.userSunSign,
            userMoonSign: request.userMoonSign,
            userRisingSign: request.userRisingSign,
            targetSunSign: request.targetSunSign,
            targetMoonSign: request.targetMoonSign,
            targetRisingSign: request.targetRisingSign,
            predictedMessage: takeaway,
            directAnswer: takeaway,
            timingWindow: nil,
            astrologicalBreakdown: "This on-device fallback used only your question and the context you supplied. It did not calculate or infer a forecast window.",
            practicalNextMove: nextMove,
            safetyNote: localSafetyNote(for: request.category),
            plausibleAlternative: alternative,
            suggestedReply: request.intent == .conversation
                ? "Could we talk about this directly? I’d rather understand than guess."
                : nil,
            evidence: fallbackEvidence,
            contextQuality: contextQuality(for: request),
            confidence: 0,
            tone: nil,
            privacySummary: combinedPrivacySummary(
                conversation: preparedConversation,
                question: preparedQuestion,
                hypotheticalReply: preparedHypotheticalReply,
                extras: preparedOptions + [preparedAdditionalContext].compactMap { $0 }
            ),
            createdAt: Date(),
            isLocalComposition: true
        )
    }

    private func localReflectiveTakeaway(for request: PredictionRequest) -> String {
        switch request.intent {
        case .general:
            return "Separate what you know from what you hope is true. The useful answer is the next step that gives you clearer information."
        case .conversation:
            return "This thread cannot prove the other person’s intent. The strongest signal is whether their next action matches the tone of their words."
        case .compareOptions:
            return "Prefer the option that is reversible, aligned with your real priority, and easiest to test with one small step."
        case .timing:
            return "The supplied sky context can support a present-moment reflection, but it does not justify a long-range date or guarantee."
        }
    }

    private func localReflectiveNextMove(for request: PredictionRequest) -> String {
        switch request.intent {
        case .general:
            return "Write down one observable fact, then take the smallest action that would teach you something new."
        case .conversation:
            return "Ask one clear, low-pressure question and let their response—not a prediction—supply the next piece of evidence."
        case .compareOptions:
            return "Run a 24-hour test of the least costly option, then compare how each path affects your stated priority."
        case .timing:
            return "Use today for a low-stakes move; wait for reviewed chart timing before making a date-specific claim."
        }
    }

    private func localReflectiveAlternative(for request: PredictionRequest) -> String {
        switch request.intent {
        case .general:
            return "Another possibility is that the question needs more real-world context before any advice can be specific."
        case .conversation:
            return "Silence or brevity may reflect bandwidth rather than interest; a direct conversation is more reliable than tone-reading alone."
        case .compareOptions:
            return "If the options are not reversible, pausing to gather one missing fact may be better than choosing today."
        case .timing:
            return "Practical constraints may matter more than the current transit, so treat availability and consequences as primary evidence."
        }
    }

    private func localSafetyNote(for category: FutureQuestionCategory) -> String? {
        switch category {
        case .familyPath:
            return "This is not medical or fertility advice, and it should not be read as a fixed child count."
        case .moneyDirection:
            return "This is not financial, investing, tax, or legal advice."
        case .commitment:
            return "This is reflective guidance, not a guaranteed commitment or marriage date."
        case .privateQuestion:
            return "This is reflective guidance, not medical, legal, financial, fertility, or crisis advice."
        default:
            return nil
        }
    }


    private func normalizedEvidence(for request: PredictionRequest) -> [ReadingEvidence] {
        if !request.evidence.isEmpty { return request.evidence }
        return [ReadingEvidence(
            basis: .generalLens,
            label: "Question and context",
            detail: "No calculated chart or transit evidence was supplied."
        )]
    }

    private func evidenceBreakdown(for request: PredictionRequest) -> String {
        let evidence = normalizedEvidence(for: request)
        let labels = evidence.map { "\($0.basis.title): \($0.label)" }.joined(separator: "; ")
        return "This reading used only the labeled inputs shown here (\(labels)). Astrology is an interpretation layer, not observed proof, and no unlabeled placement or date was added."
    }

    private func contextQuality(for request: PredictionRequest) -> ContextQuality {
        let optionCount = request.comparisonOptions.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        let contextCharacters = request.trimmedConversationText.count
            + request.additionalContext.trimmingCharacters(in: .whitespacesAndNewlines).count

        if contextCharacters >= 240 || optionCount >= 3 || request.evidence.count >= 3 {
            return .detailed
        }
        if contextCharacters > 0 || optionCount >= 2 || !request.evidence.isEmpty {
            return .someContext
        }
        return .questionOnly
    }

    /// Parse Claude's text response into structured prediction data.
    private func parseClaudeResponse(_ text: String) -> (
        predictedMessage: String,
        directAnswer: String?,
        timingWindow: String?,
        breakdown: String,
        practicalNextMove: String?,
        safetyNote: String?,
        plausibleAlternative: String?,
        suggestedReply: String?,
        tone: SimulationTone?
    ) {
        // Try JSON parsing first (if Claude returns structured JSON)
        let sanitizedText = Self.extractJSONObject(from: text) ?? text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let jsonData = sanitizedText.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let directAnswer = cleanParsedText(json["direct_answer"] as? String)
            let message = cleanParsedText(json["predicted_message"] as? String) ?? directAnswer ?? ""
            let timingWindow = cleanParsedText(json["timing_window"] as? String)
            let breakdown = json["astrological_breakdown"] as? String ?? ""
            let practicalNextMove = cleanParsedText(json["practical_next_move"] as? String)
            let safetyNote = cleanParsedText(json["safety_note"] as? String)
            let plausibleAlternative = cleanParsedText(json["plausible_alternative"] as? String)
            let suggestedReply = cleanParsedText(json["suggested_reply"] as? String)
            let toneStr = json["tone"] as? String
            let tone = toneStr.flatMap { SimulationTone(rawValue: $0.lowercased()) }
            return (
                message,
                directAnswer,
                timingWindow,
                breakdown,
                practicalNextMove,
                safetyNote,
                plausibleAlternative,
                suggestedReply,
                tone
            )
        }

        // Fallback: parse sections from plain text
        var message = ""
        var breakdown = ""
        var tone: SimulationTone? = nil

        let sections = sanitizedText.components(separatedBy: "\n\n")
        if sections.count >= 2 {
            message = sections[0].trimmingCharacters(in: .whitespacesAndNewlines)
            breakdown = sections[1...].joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            message = sanitizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            breakdown = "This interpretation uses only the context listed with the reading; it is not proof or certainty."
        }

        // Detect tone
        let lowerText = sanitizedText.lowercased()
        if lowerText.contains("playful") || lowerText.contains("flirty") { tone = .playful }
        else if lowerText.contains("guarded") || lowerText.contains("defensive") { tone = .guarded }
        else if lowerText.contains("warm") || lowerText.contains("friendly") { tone = .warm }
        else if lowerText.contains("cold") || lowerText.contains("distant") { tone = .cold }
        else if lowerText.contains("confident") || lowerText.contains("direct") { tone = .confident }
        else if lowerText.contains("anxious") || lowerText.contains("nervous") { tone = .anxious }

        return (message, message, nil, breakdown, nil, nil, nil, nil, tone)
    }

    private func cleanParsedText(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !Self.looksLikeCodeOrJSON(trimmed) else {
            return nil
        }
        return trimmed
    }

    private static func extractJSONObject(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end else {
            return nil
        }
        return String(trimmed[start...end])
    }

    private static func looksLikeCodeOrJSON(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("```")
            || lower.hasPrefix("{")
            || lower.hasPrefix("[")
            || lower.contains("\"predicted_message\"")
            || lower.contains("\"direct_answer\"")
            || lower.contains("astrological_breakdown")
    }

    func loadHistory() -> [PredictionResult] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? decoder.decode([PredictionResult].self, from: data) else {
            return []
        }

        return decoded.sorted { $0.createdAt > $1.createdAt }
    }

    func deleteHistoryItem(id: UUID) {
        let filtered = loadHistory().filter { $0.id != id }
        persist(filtered)
    }

    func setOutcome(_ outcome: PredictionOutcome?, for id: UUID) {
        var history = loadHistory()
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history[index].outcome = outcome
        persist(history)
    }

    func setFollowUp(_ followUp: ReadingFollowUp?, for id: UUID) {
        var history = loadHistory()
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history[index].followUp = followUp
        persist(history)
    }

    func setHelpfulness(_ helpfulness: ReadingHelpfulness?, for id: UUID) {
        var history = loadHistory()
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history[index].helpfulness = helpfulness
        persist(history)
    }

    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    private func save(_ result: PredictionResult) {
        var history = loadHistory().filter { $0.id != result.id }
        history.insert(result, at: 0)
        persist(history)
    }

    private func persist(_ results: [PredictionResult]) {
        guard let data = try? encoder.encode(results) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func makeSystemPrompt(for request: PredictionRequest) -> String {
        """
        You are Simastry's practical guidance engine. Help the user reach a
        grounded next step. Astrology is an optional interpretation layer, not
        proof, and a conversation is not evidence of another person's thoughts.

        Intent: \(request.intent.title)
        Category: \(request.category.title)

        Rules:
        - Lead with a direct takeaway, one practical next move, and one plausible alternative.
        - Use only facts and evidence supplied in the user prompt.
        - Never invent placements, aspects, transits, birth times, houses, observations, or timing.
        - Return timing_window as null unless the intent is Timing AND a supplied Calculated evidence item explicitly supports timing.
        - Even with timing evidence, stay within the period described by that evidence. Do not extrapolate a long-range date.
        - Label interpretation as interpretation. Never turn a zodiac sign into certainty about behavior.
        - For conversation questions, do not claim to know or predict the other person's private thoughts. A suggested reply may be offered as preparation.
        - Do not give a guaranteed marriage date.
        - Do not give an exact child count as fate.
        - Do not give medical, fertility, legal, investing, tax, or financial advice.
        - If the user asks about money, discuss prosperity patterns, career behavior, and practical structure only.
        - If the user asks about children or pregnancy, avoid medical claims and keep it about family/home themes.
        \(Self.auraImageSafetyRules)
        - Keep the answer concise, warm, clear, and useful to someone who does not believe in astrology.
        - Return valid JSON with exactly these fields:
          {"predicted_message":"one-line takeaway","direct_answer":"direct takeaway","timing_window":null,"astrological_breakdown":"what evidence was used and what was interpretation","practical_next_move":"one specific action","plausible_alternative":"one credible alternative explanation","suggested_reply":null,"safety_note":null,"tone":"warm"}
        - tone must be one of: playful, guarded, warm, cold, anxious, confident, flirty, distant
        - Return ONLY the JSON object, no markdown.
        """
    }

    private static let auraImageSafetyRules = """
        - If Aura Snapshot descriptors are provided, use them only as color, brightness/light, contrast, user-selected mood, and safe symbolic interpretation.
        - Do not request, accept, or infer from raw image data, base64, EXIF, embeddings, face landmarks, face geometry, biometric traits, identity, ethnicity, age, gender, attractiveness, fertility, health, or mental-health status.
        """

    private func makeUserPrompt(
        for request: PredictionRequest,
        preparedConversation: ConversationPrivacyResult,
        preparedQuestion: ConversationPrivacyResult?,
        preparedHypotheticalReply: ConversationPrivacyResult?,
        preparedOptions: [ConversationPrivacyResult],
        preparedAdditionalContext: ConversationPrivacyResult?
    ) -> String {
        var sections: [String] = []

        if let privacySummary = combinedPrivacySummary(
            conversation: preparedConversation,
            question: preparedQuestion,
            hypotheticalReply: preparedHypotheticalReply,
            extras: preparedOptions + [preparedAdditionalContext].compactMap { $0 }
        ) {
            sections.append("Privacy handling:\n\(privacySummary)")
        }

        sections.append("Compass intent:\n\(request.intent.title)")
        sections.append("Topic:\n\(request.topic?.title ?? request.category.title)")

        if !preparedConversation.redactedText.isEmpty {
            sections.append("Conversation:\n\(preparedConversation.redactedText)")
        }

        if let preparedQuestion {
            sections.append("What the user wants to know:\n\(preparedQuestion.redactedText)")
        } else {
            sections.append("What the user wants to know:\n\(request.category.defaultQuestion)")
        }

        let options = preparedOptions.map(\.redactedText)
        if !options.isEmpty {
            sections.append("Options to compare:\n\(options.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))")
        }

        if let preparedAdditionalContext, !preparedAdditionalContext.redactedText.isEmpty {
            sections.append("Additional context:\n\(preparedAdditionalContext.redactedText)")
        }

        let userChart = chartLine(
            label: "User-confirmed chart context",
            sun: request.userSunSign,
            moon: request.userMoonSign,
            rising: request.userRisingSign
        )
        if let userChart {
            sections.append(userChart)
        }

        let targetChart = chartLine(
            label: "Other person's user-confirmed chart context",
            sun: request.targetSunSign,
            moon: request.targetMoonSign,
            rising: request.targetRisingSign
        )
        if let targetChart {
            sections.append(targetChart)
        }

        if request.evidence.isEmpty {
            sections.append("Permitted evidence:\nGeneral lens only. No calculated transit or timing evidence was supplied.")
        } else {
            let evidenceLines = request.evidence.map { item in
                "- [\(item.basis.title)] \(item.label): \(item.detail)\(item.supportsTiming ? " (supports the stated timing scope)" : "")"
            }
            sections.append("Permitted evidence (use only these items):\n\(evidenceLines.joined(separator: "\n"))")
        }

        if request.intent == .timing {
            sections.append(request.hasTimingEvidence
                ? "Timing rule:\nUse only the explicit scope in the calculated evidence. Do not extend it."
                : "Timing rule:\nNo timing claim is permitted; timing_window must be null.")
        }

        if let auraSnapshot = request.auraSnapshot {
            sections.append("Aura Snapshot compact descriptors:\n\(auraSnapshot.compactSummary)")
        }

        if let preparedHypotheticalReply {
            sections.append("Alternative reply the user is considering sending:\n\(preparedHypotheticalReply.redactedText)\n\nUse that message as the user's next move, then predict how the other person would answer.")
        }

        return sections.joined(separator: "\n\n")
    }

    private func chartLine(label: String, sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) -> String? {
        var parts: [String] = []
        if let sun { parts.append("Sun in \(sun.displayName)") }
        if let moon { parts.append("Moon in \(moon.displayName)") }
        if let rising { parts.append("Rising in \(rising.displayName)") }
        guard !parts.isEmpty else { return nil }
        return "\(label):\n\(parts.joined(separator: ", "))"
    }

    private func validateRequest(_ request: PredictionRequest) throws {
        if request.intent == .conversation && request.trimmedConversationText.isEmpty {
            throw PredictionServiceError.invalidRequest
        }

        if request.intent == .compareOptions {
            let optionCount = request.comparisonOptions.filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
            guard optionCount >= 2 else { throw PredictionServiceError.invalidRequest }
        }

        if request.intent == .timing && !request.hasTimingEvidence {
            throw PredictionServiceError.invalidRequest
        }

        guard request.trimmedQuestion != nil else { throw PredictionServiceError.invalidRequest }
    }

    private func validatePrivacy(_ result: ConversationPrivacyResult) throws {
        guard result.canProceed else {
            throw PredictionServiceError.blockedByPrivacy(
                result.blockingMessage ?? "This conversation includes content Simastry cannot safely process."
            )
        }
    }

    private func combinedPrivacySummary(
        conversation: ConversationPrivacyResult,
        question: ConversationPrivacyResult?,
        hypotheticalReply: ConversationPrivacyResult?,
        extras: [ConversationPrivacyResult] = []
    ) -> String? {
        let summaries = [
            conversation.privacySummary,
            question?.privacySummary,
            hypotheticalReply?.privacySummary
        ].compactMap { $0 } + extras.compactMap(\.privacySummary)

        guard !summaries.isEmpty else { return nil }
        return summaries.joined(separator: " ")
    }
}

private actor PredictionTimeoutCoordinator<Output: Sendable> {
    private var didComplete = false
    private var storedResult: Result<Output, Error>?
    private var continuation: CheckedContinuation<Result<Output, Error>?, Never>?

    func wait() async -> Result<Output, Error>? {
        await withCheckedContinuation { continuation in
            if didComplete {
                continuation.resume(returning: storedResult)
            } else {
                self.continuation = continuation
            }
        }
    }

    func complete(_ result: Result<Output, Error>?) {
        guard !didComplete else { return }
        didComplete = true
        storedResult = result
        continuation?.resume(returning: result)
        continuation = nil
    }
}

nonisolated private struct PredictionProxyRequest: Encodable, Sendable {
    let mode: SimulationMode
    let tier: String
    let systemPrompt: String
    let userPrompt: String
}

nonisolated private struct PredictionProxyResponse: Decodable, Sendable {
    let predictedMessage: String
    let astrologicalBreakdown: String
    let confidence: Int
    let tone: String?

    enum CodingKeys: String, CodingKey {
        case predictedMessage = "predicted_message"
        case astrologicalBreakdown = "astrological_breakdown"
        case confidence
        case tone
    }

    var normalizedTone: SimulationTone? {
        guard let tone else { return nil }
        return SimulationTone(rawValue: tone.lowercased())
    }
}
