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
            "The prediction channel is not connected yet."
        case .invalidRequest:
            "Add the missing details for this question, then try again."
        case .invalidResponse:
            "The stars answered in an unexpected format."
        case .emptyResponse:
            "The prediction came back empty. Try again in a moment."
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

        if !request.trimmedConversationText.isEmpty {
            try validatePrivacy(preparedConversation)
        }
        if let preparedQuestion {
            try validatePrivacy(preparedQuestion)
        }
        if let preparedHypotheticalReply {
            try validatePrivacy(preparedHypotheticalReply)
        }

        guard isConfigured else {
            // No remote channel configured: compose a placement-logic reading locally so
            // Predict never dead-ends. Privacy validation above still applies.
            let result = composeLocalPrediction(
                request: request,
                preparedConversation: preparedConversation,
                preparedQuestion: preparedQuestion,
                preparedHypotheticalReply: preparedHypotheticalReply
            )
            save(result)
            return result
        }

        let systemPrompt = makeSystemPrompt(for: request)
        let userPrompt = makeUserPrompt(
            for: request,
            preparedConversation: preparedConversation,
            preparedQuestion: preparedQuestion,
            preparedHypotheticalReply: preparedHypotheticalReply
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
                preparedHypotheticalReply: preparedHypotheticalReply
            )
            save(result)
            return result
        case nil:
            let result = composeLocalPrediction(
                request: request,
                preparedConversation: preparedConversation,
                preparedQuestion: preparedQuestion,
                preparedHypotheticalReply: preparedHypotheticalReply
            )
            save(result)
            return result
        }

        // Parse the structured response from Claude
        let parsed = parseClaudeResponse(text)
        let displayAnswer = parsed.directAnswer ?? parsed.predictedMessage

        guard !displayAnswer.isEmpty, !parsed.breakdown.isEmpty else {
            throw PredictionServiceError.emptyResponse
        }

        let result = PredictionResult(
            id: UUID(),
            mode: request.mode,
            category: request.category,
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
            timingWindow: parsed.timingWindow,
            astrologicalBreakdown: parsed.breakdown,
            practicalNextMove: parsed.practicalNextMove,
            safetyNote: parsed.safetyNote,
            confidence: min(max(parsed.confidence, 0), 100),
            tone: parsed.tone,
            privacySummary: combinedPrivacySummary(
                conversation: preparedConversation,
                question: preparedQuestion,
                hypotheticalReply: preparedHypotheticalReply
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

    // MARK: - Local Placement-Logic Composer

    /// Builds a prediction from the method layer alone: the pasted message context,
    /// the target's placements, and traditional Western tropical interpretation.
    /// Deterministic per (conversation, day) so repeated taps don't feel random.
    private func composeLocalPrediction(
        request: PredictionRequest,
        preparedConversation: ConversationPrivacyResult,
        preparedQuestion: ConversationPrivacyResult?,
        preparedHypotheticalReply: ConversationPrivacyResult?
    ) -> PredictionResult {
        guard request.category == .messageOutcome else {
            return composeLocalFutureAnswer(
                request: request,
                preparedConversation: preparedConversation,
                preparedQuestion: preparedQuestion,
                preparedHypotheticalReply: preparedHypotheticalReply
            )
        }

        let sun = request.targetSunSign ?? request.userSunSign ?? .libra
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let seed = abs(preparedConversation.redactedText.count
            &+ (preparedHypotheticalReply?.redactedText.count ?? 0)
            &+ dayOfYear)

        let replies = AstrologyTemplates.likelyReplies[sun.displayName] ?? ["They keep it brief and wait to see your next move."]
        let predictedMessage = replies[seed % replies.count]

        var breakdownSentences: [String] = []
        if let core = CommunicationTemplates.reasoning[sun.displayName] {
            breakdownSentences.append("\(core).")
        }
        if let moon = request.targetMoonSign {
            breakdownSentences.append("Their \(moon.displayName) Moon shapes the reaction underneath: \(moonClause(for: moon)).")
        }
        if let rising = request.targetRisingSign {
            breakdownSentences.append("Their \(rising.displayName) Rising sets the first response: \(risingClause(for: rising)).")
        }
        if request.trimmedHypotheticalReply != nil {
            breakdownSentences.append("Read against the message you're considering, this is the most likely register they answer in.")
        }
        let breakdown = breakdownSentences.joined(separator: " ")

        return PredictionResult(
            id: UUID(),
            mode: request.mode,
            category: request.category,
            question: preparedQuestion?.redactedText ?? request.category.defaultQuestion,
            conversationText: preparedConversation.redactedText,
            userSunSign: request.userSunSign,
            userMoonSign: request.userMoonSign,
            userRisingSign: request.userRisingSign,
            targetSunSign: request.targetSunSign,
            targetMoonSign: request.targetMoonSign,
            targetRisingSign: request.targetRisingSign,
            predictedMessage: predictedMessage,
            astrologicalBreakdown: breakdown.isEmpty
                ? "Read through \(sun.displayName)'s \(sun.element.rawValue) \(sun.modality) lens against the pasted message context."
                : breakdown,
            confidence: localConfidence(for: request, conversationLength: preparedConversation.redactedText.count),
            tone: localTone(for: sun, seed: seed),
            privacySummary: combinedPrivacySummary(
                conversation: preparedConversation,
                question: preparedQuestion,
                hypotheticalReply: preparedHypotheticalReply
            ),
            createdAt: Date(),
            isLocalComposition: true
        )
    }

    private func composeLocalFutureAnswer(
        request: PredictionRequest,
        preparedConversation: ConversationPrivacyResult,
        preparedQuestion: ConversationPrivacyResult?,
        preparedHypotheticalReply: ConversationPrivacyResult?
    ) -> PredictionResult {
        let question = preparedQuestion?.redactedText ?? request.category.defaultQuestion
        let anchor = request.userSunSign ?? request.targetSunSign
        let anchorName = anchor?.displayName ?? "your chart"
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let seed = abs(question.count &+ (anchor?.rawValue.count ?? 0) &+ dayOfYear)
        let timingWindow = localTimingWindow(for: request.category, seed: seed)
        let answer = localDirectAnswer(
            for: request.category,
            question: question,
            anchorName: anchorName,
            timingWindow: timingWindow
        )
        let nextMove = localNextMove(for: request.category, question: question)
        let safetyNote = localSafetyNote(for: request.category)
        let breakdown = localFutureBreakdown(for: request.category, anchor: anchor, target: request.targetSunSign)

        return PredictionResult(
            id: UUID(),
            mode: request.mode,
            category: request.category,
            question: question,
            conversationText: preparedConversation.redactedText.isEmpty ? nil : preparedConversation.redactedText,
            userSunSign: request.userSunSign,
            userMoonSign: request.userMoonSign,
            userRisingSign: request.userRisingSign,
            targetSunSign: request.targetSunSign,
            targetMoonSign: request.targetMoonSign,
            targetRisingSign: request.targetRisingSign,
            predictedMessage: answer,
            directAnswer: answer,
            timingWindow: timingWindow,
            astrologicalBreakdown: breakdown,
            practicalNextMove: nextMove,
            safetyNote: safetyNote,
            confidence: localFutureConfidence(for: request),
            tone: localTone(for: anchor ?? .libra, seed: seed),
            privacySummary: combinedPrivacySummary(
                conversation: preparedConversation,
                question: preparedQuestion,
                hypotheticalReply: preparedHypotheticalReply
            ),
            createdAt: Date(),
            isLocalComposition: true
        )
    }

    private func localConfidence(for request: PredictionRequest, conversationLength: Int) -> Int {
        guard let targetSunSign = request.targetSunSign else {
            return localFutureConfidence(for: request)
        }

        var confidence = 58
        switch targetSunSign.element {
        case .fire, .earth: confidence += 8   // steadier texting patterns
        case .air: confidence += 4
        case .water: confidence += 2
        }
        if request.targetMoonSign != nil { confidence += 7 }
        if request.targetRisingSign != nil { confidence += 5 }
        if conversationLength > 240 { confidence += 6 } else if conversationLength > 80 { confidence += 3 }
        return min(confidence, 86)
    }

    private func localFutureConfidence(for request: PredictionRequest) -> Int {
        var confidence = 58
        if request.userSunSign != nil { confidence += 8 }
        if request.userMoonSign != nil { confidence += 5 }
        if request.userRisingSign != nil { confidence += 4 }
        if request.targetSunSign != nil { confidence += 3 }
        switch request.category {
        case .careerSuccess, .privateQuestion, .messageOutcome:
            confidence += 4
        case .moneyDirection, .familyPath:
            confidence -= 3
        case .loveTiming, .commitment:
            break
        }
        return min(max(confidence, 48), 78)
    }

    private func localTimingWindow(for category: FutureQuestionCategory, seed: Int) -> String {
        let windows: [String]
        switch category {
        case .loveTiming:
            windows = ["the next 6 to 10 weeks", "late this season", "the next 3 months"]
        case .commitment:
            windows = ["the next 9 to 18 months", "after one more consistency test", "the next serious relationship chapter"]
        case .familyPath:
            windows = ["the next 12 to 24 months", "after your home base feels steadier", "the next chapter where care and stability become louder"]
        case .careerSuccess:
            windows = ["the next 4 to 8 weeks", "the next quarter", "the next visible work cycle"]
        case .moneyDirection:
            windows = ["the next 3 to 6 months", "after one cleaner structure is in place", "the next practical earning cycle"]
        case .privateQuestion:
            windows = ["the next 24 to 72 hours", "after one quiet signal repeats", "the next honest opening"]
        case .messageOutcome:
            windows = ["the next reply window"]
        }
        return windows[seed % windows.count]
    }

    private func localDirectAnswer(
        for category: FutureQuestionCategory,
        question: String,
        anchorName: String,
        timingWindow: String
    ) -> String {
        let lowercasedQuestion = question.lowercased()

        switch category {
        case .loveTiming:
            if lowercasedQuestion.contains("text") || lowercasedQuestion.contains("reply") {
                return "A reply or small signal is more likely around \(timingWindow), but the stronger sign is whether they follow up without you carrying the whole thread."
            }
            return "A real romantic opening looks more likely around \(timingWindow), especially if you stop treating low-effort attention as the main signal."
        case .commitment:
            return "Commitment is possible, but the strongest window is \(timingWindow). The pattern favors consistency over a dramatic declaration."
        case .familyPath:
            return "A family or home-building chapter is showing, but not as a fixed child count. The clearer window is \(timingWindow)."
        case .careerSuccess:
            return "Yes, success is available here. The next opening looks like \(timingWindow), with \(anchorName) needing visible follow-through instead of quiet competence."
        case .moneyDirection:
            return "Wealth grows through structure, not a lucky spike. The next money opening is \(timingWindow), but it needs practical choices."
        case .privateQuestion:
            return "The private thing on your mind is asking for one honest move, not a dramatic reveal. The clearest opening is \(timingWindow)."
        case .messageOutcome:
            return "They are likely to answer, but the tone depends on the thread."
        }
    }

    private func localFutureBreakdown(for category: FutureQuestionCategory, anchor: ZodiacSign?, target: ZodiacSign?) -> String {
        let anchorLine = anchor.map { "\($0.displayName)'s \($0.element.rawValue) \(($0.modality)) pattern" } ?? "the chart pattern you gave"
        let targetLine = target.map { " The other person's \($0.displayName) lens adds timing sensitivity." } ?? ""
        switch category {
        case .loveTiming:
            return "\(anchorLine) opens fastest when desire has room and repetition. Love timing looks strongest when the pattern moves from curiosity into consistent presence.\(targetLine)"
        case .commitment:
            return "\(anchorLine) needs proof before promise. The commitment signal is less about one perfect date and more about whether the same effort repeats.\(targetLine)"
        case .familyPath:
            return "\(anchorLine) points toward care, belonging, and home as themes, but astrology should not name an exact child count as fate."
        case .careerSuccess:
            return "\(anchorLine) shows growth through visible action, useful skill, and choosing the room where your strengths can be seen."
        case .moneyDirection:
            return "\(anchorLine) points to prosperity through cleaner structure, steadier choices, and fewer energy leaks. This is not investment advice."
        case .privateQuestion:
            return "\(anchorLine) is highlighting what keeps repeating when you get quiet. The signal is not asking for certainty; it is asking you to name the next honest step.\(targetLine)"
        case .messageOutcome:
            return "\(anchorLine) shapes the next reply through tone, pacing, and emotional timing.\(targetLine)"
        }
    }

    private func localNextMove(for category: FutureQuestionCategory, question: String) -> String {
        let lowercasedQuestion = question.lowercased()

        switch category {
        case .loveTiming:
            if lowercasedQuestion.contains("text") || lowercasedQuestion.contains("reply") {
                return "Send one clean, low-pressure message only if it gives them room to answer clearly."
            }
            return "Say yes to one concrete invitation or new room this week, then watch who follows up twice."
        case .commitment:
            return "Measure consistency for two weeks before asking for reassurance. Repeated action is the answer."
        case .familyPath:
            return "Name the version of home you actually want, then make one practical move that supports it."
        case .careerSuccess:
            return "Pick the one visible move with the highest upside and put it where someone can notice."
        case .moneyDirection:
            return "Clean up one recurring leak, then choose one skill or offer that can compound."
        case .privateQuestion:
            return "Write the question in one sentence, then choose the smallest action you would still respect tomorrow."
        case .messageOutcome:
            return "Give the thread enough space to show you whether interest is being matched."
        }
    }

    private func localSafetyNote(for category: FutureQuestionCategory) -> String? {
        switch category {
        case .familyPath:
            return "This is not medical or fertility advice, and it should not be read as a fixed child count."
        case .moneyDirection:
            return "This is not financial, investing, tax, or legal advice."
        case .commitment:
            return "This is a timing pattern, not a guaranteed marriage date."
        case .privateQuestion:
            return "This is reflective guidance, not medical, legal, financial, fertility, or crisis advice."
        default:
            return nil
        }
    }

    private func localTone(for sign: ZodiacSign, seed: Int) -> SimulationTone {
        let options: [SimulationTone]
        switch sign.element {
        case .fire: options = [.confident, .playful, .flirty]
        case .earth: options = [.warm, .guarded, .confident]
        case .air: options = [.playful, .distant, .warm]
        case .water: options = [.warm, .guarded, .anxious]
        }
        return options[seed % options.count]
    }

    private func moonClause(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "feelings spike fast and settle once something can be done"
        case .taurus: "they open up only after the pace feels steady"
        case .gemini: "they metabolize emotion by talking it through"
        case .cancer: "silence tends to read as distance to them"
        case .leo: "warmth is what makes it safe for them to soften"
        case .virgo: "they look for a detail they can fix before they relax"
        case .libra: "they want the tone balanced before the topic"
        case .scorpio: "they track intensity and what is left unsaid"
        case .sagittarius: "they need room before they can be honest"
        case .capricorn: "composure is their default shield"
        case .aquarius: "they step back to think before naming a feeling"
        case .pisces: "they absorb the mood of the thread before the facts"
        }
    }

    private func risingClause(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "they answer quickly, sometimes before deciding"
        case .taurus: "they steady the conversation before engaging"
        case .gemini: "they open with a question or a joke"
        case .cancer: "they check emotional safety first"
        case .leo: "they lead with warmth and presence"
        case .virgo: "they sort the details before replying"
        case .libra: "they manage tone and fairness first"
        case .scorpio: "they scan for the real motive before answering"
        case .sagittarius: "they default to candor"
        case .capricorn: "they hold back until the reply feels controlled"
        case .aquarius: "they answer from a step of distance"
        case .pisces: "they respond to the feeling before the words"
        }
    }

    /// Parse Claude's text response into structured prediction data.
    private func parseClaudeResponse(_ text: String) -> (
        predictedMessage: String,
        directAnswer: String?,
        timingWindow: String?,
        breakdown: String,
        practicalNextMove: String?,
        safetyNote: String?,
        confidence: Int,
        tone: SimulationTone?
    ) {
        // Try JSON parsing first (if Claude returns structured JSON)
        if let jsonData = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let directAnswer = cleanParsedText(json["direct_answer"] as? String)
            let message = cleanParsedText(json["predicted_message"] as? String) ?? directAnswer ?? ""
            let timingWindow = cleanParsedText(json["timing_window"] as? String)
            let breakdown = json["astrological_breakdown"] as? String ?? ""
            let practicalNextMove = cleanParsedText(json["practical_next_move"] as? String)
            let safetyNote = cleanParsedText(json["safety_note"] as? String)
            let confidence = json["confidence"] as? Int ?? 75
            let toneStr = json["tone"] as? String
            let tone = toneStr.flatMap { SimulationTone(rawValue: $0.lowercased()) }
            return (message, directAnswer, timingWindow, breakdown, practicalNextMove, safetyNote, confidence, tone)
        }

        // Fallback: parse sections from plain text
        var message = ""
        var breakdown = ""
        var confidence = 75
        var tone: SimulationTone? = nil

        let sections = text.components(separatedBy: "\n\n")
        if sections.count >= 2 {
            message = sections[0].trimmingCharacters(in: .whitespacesAndNewlines)
            breakdown = sections[1...].joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            message = text.trimmingCharacters(in: .whitespacesAndNewlines)
            breakdown = "Based on the astrological compatibility between these signs."
        }

        // Extract confidence if mentioned
        if let range = text.range(of: #"(\d{1,3})%"#, options: .regularExpression) {
            let numStr = text[range].dropLast()
            confidence = Int(numStr) ?? 75
        }

        // Detect tone
        let lowerText = text.lowercased()
        if lowerText.contains("playful") || lowerText.contains("flirty") { tone = .playful }
        else if lowerText.contains("guarded") || lowerText.contains("defensive") { tone = .guarded }
        else if lowerText.contains("warm") || lowerText.contains("friendly") { tone = .warm }
        else if lowerText.contains("cold") || lowerText.contains("distant") { tone = .cold }
        else if lowerText.contains("confident") || lowerText.contains("direct") { tone = .confident }
        else if lowerText.contains("anxious") || lowerText.contains("nervous") { tone = .anxious }

        return (message, message, nil, breakdown, nil, nil, confidence, tone)
    }

    private func cleanParsedText(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
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

    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    private func save(_ result: PredictionResult) {
        var history = loadHistory().filter { $0.id != result.id }
        history.insert(result, at: 0)
        persist(Array(history.prefix(10)))
    }

    private func persist(_ results: [PredictionResult]) {
        guard let data = try? encoder.encode(results) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func makeSystemPrompt(for request: PredictionRequest) -> String {
        if request.category == .messageOutcome {
            return makeMessageOutcomeSystemPrompt(for: request)
        }

        return makeFutureAnswerSystemPrompt(for: request)
    }

    private func makeMessageOutcomeSystemPrompt(for request: PredictionRequest) -> String {
        let targetSunSign = request.targetSunSign ?? .libra
        let sunDescription = AstrologyTemplates.sunSign[targetSunSign.rawValue] ?? ""
        let moonDescription = request.targetMoonSign.flatMap { AstrologyTemplates.moonSign[$0.rawValue] }
        let risingDescription = request.targetRisingSign.flatMap { AstrologyTemplates.risingSign[$0.rawValue] }

        var prompt = """
        You are Simastry's prediction engine. Predict how someone would respond in a text conversation.

        The person you are predicting has these zodiac placements:
        - Sun in \(targetSunSign.displayName): \(sunDescription)
        """

        if let targetMoonSign = request.targetMoonSign, let moonDescription {
            prompt += "\n- Moon in \(targetMoonSign.displayName): \(moonDescription)"
        }

        if let targetRisingSign = request.targetRisingSign, let risingDescription {
            prompt += "\n- Rising in \(targetRisingSign.displayName): \(risingDescription)"
        }

        if let personality = AstrologyTemplates.companionPersonality[targetSunSign.rawValue] {
            prompt += "\n\nPersonality style: \(personality)"
        }

        prompt += """


        Your task:
        1. Read the conversation closely
        2. Analyze tone, pacing, emotional dynamics, and texting style
        3. Generate the predicted next response from the other person
        4. Explain why they would respond this way through astrology

        Rules:
        - The predicted message must sound like a real text message
        - Keep it concise and natural
        - The astrological breakdown should be specific, short, and placement-aware
        - Channel their zodiac energy - don't just describe their sign, embody their texting personality
        \(Self.auraImageSafetyRules)
        - Return your response as valid JSON with exactly these fields:
          {"predicted_message": "the predicted text message", "direct_answer": "short answer to the user's question", "timing_window": "likely timing window if relevant", "astrological_breakdown": "2-3 sentences explaining why based on their signs", "practical_next_move": "one action the user can take", "safety_note": "short caution if needed, otherwise null", "confidence": 75, "tone": "warm"}
        - tone must be one of: playful, guarded, warm, cold, anxious, confident, flirty, distant
        - confidence is 0-100 representing how predictable this response is
        - Return ONLY the JSON object, no other text
        """

        return prompt
    }

    private func makeFutureAnswerSystemPrompt(for request: PredictionRequest) -> String {
        """
        You are Simastry's future-answer engine. Give quick astrology-grounded answers to common future questions.

        Category: \(request.category.title)

        Rules:
        - Frame the answer as probability, timing, and pattern - never fixed fate.
        - Use likely, opening, window, pattern, or signal. Do not say will definitely.
        - Do not give a guaranteed marriage date.
        - Do not give an exact child count as fate.
        - Do not give medical, fertility, legal, investing, tax, or financial advice.
        - If the user asks about money, discuss prosperity patterns, career behavior, and practical structure only.
        - If the user asks about children or pregnancy, avoid medical claims and keep it about family/home themes.
        \(Self.auraImageSafetyRules)
        - Keep the answer concise, warm, practical, and a little magical.
        - Return valid JSON with exactly these fields:
          {"predicted_message": "one-line shareable answer", "direct_answer": "Short answer", "timing_window": "Most likely window", "astrological_breakdown": "Why this shows up astrologically in 2-3 sentences", "practical_next_move": "What to do next in one specific action", "safety_note": "short caution if needed, otherwise null", "confidence": 68, "tone": "warm"}
        - tone must be one of: playful, guarded, warm, cold, anxious, confident, flirty, distant
        - confidence is 0-100 and should stay conservative for broad life questions.
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
        preparedHypotheticalReply: ConversationPrivacyResult?
    ) -> String {
        var sections: [String] = []

        if let privacySummary = combinedPrivacySummary(
            conversation: preparedConversation,
            question: preparedQuestion,
            hypotheticalReply: preparedHypotheticalReply
        ) {
            sections.append("Privacy handling:\n\(privacySummary)")
        }

        sections.append("Prediction category:\n\(request.category.title)")

        if !preparedConversation.redactedText.isEmpty {
            sections.append("Conversation:\n\(preparedConversation.redactedText)")
        }

        if let preparedQuestion {
            sections.append("What the user wants to know:\n\(preparedQuestion.redactedText)")
        } else {
            sections.append("What the user wants to know:\n\(request.category.defaultQuestion)")
        }

        let userChart = chartLine(
            label: "User chart",
            sun: request.userSunSign,
            moon: request.userMoonSign,
            rising: request.userRisingSign
        )
        if let userChart {
            sections.append(userChart)
        }

        let targetChart = chartLine(
            label: request.category == .messageOutcome ? "Other person's chart" : "Optional other person's chart",
            sun: request.targetSunSign,
            moon: request.targetMoonSign,
            rising: request.targetRisingSign
        )
        if let targetChart {
            sections.append(targetChart)
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
        if request.category.requiresConversation && request.trimmedConversationText.isEmpty {
            throw PredictionServiceError.invalidRequest
        }

        if request.category.requiresTargetSign && request.targetSunSign == nil {
            throw PredictionServiceError.invalidRequest
        }
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
        hypotheticalReply: ConversationPrivacyResult?
    ) -> String? {
        let summaries = [
            conversation.privacySummary,
            question?.privacySummary,
            hypotheticalReply?.privacySummary
        ].compactMap { $0 }

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
