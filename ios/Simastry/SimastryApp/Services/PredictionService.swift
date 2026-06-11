import Foundation

nonisolated enum PredictionServiceError: LocalizedError, Sendable {
    case serviceUnavailable
    case invalidRequest
    case invalidResponse
    case emptyResponse
    case blockedByPrivacy(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            "The prediction channel is not connected yet."
        case .invalidRequest:
            "Your simulation needs a conversation and a sign to continue."
        case .invalidResponse:
            "The stars answered in an unexpected format."
        case .emptyResponse:
            "The prediction came back empty. Try again in a moment."
        case .blockedByPrivacy(let message):
            message
        case .serverError(let message):
            message
        }
    }
}

nonisolated final class PredictionService {
    private let session: URLSession
    private let privacyService: ConversationPrivacyService
    private let historyKey: String = "simastry_prediction_history"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Server-proxied generation channel (the companion-reply edge function).
    /// The Anthropic key lives only in edge-function secrets — never in the
    /// app binary. Injected by AppViewModel; nil in isolation (tests).
    var replyChannel: (@Sendable (_ system: String, _ user: String) async throws -> String)?
    var isRemoteChannelAvailable: (@Sendable () -> Bool)?

    init(session: URLSession = .shared, privacyService: ConversationPrivacyService = ConversationPrivacyService()) {
        self.session = session
        self.privacyService = privacyService

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
        guard !request.trimmedConversationText.isEmpty else {
            throw PredictionServiceError.invalidRequest
        }

        let preparedConversation = privacyService.prepare(request.trimmedConversationText)
        let preparedQuestion = request.trimmedQuestion.map { privacyService.prepare($0) }
        let preparedHypotheticalReply = request.trimmedHypotheticalReply.map { privacyService.prepare($0) }

        try validatePrivacy(preparedConversation)
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
        do {
            text = try await replyChannel(systemPrompt, userPrompt)
        } catch {
            throw PredictionServiceError.serverError(
                (error as? LocalizedError)?.errorDescription
                    ?? "The prediction request failed. Please try again."
            )
        }

        // Parse the structured response from Claude
        let parsed = parseClaudeResponse(text)

        guard !parsed.predictedMessage.isEmpty, !parsed.breakdown.isEmpty else {
            throw PredictionServiceError.emptyResponse
        }

        let result = PredictionResult(
            id: UUID(),
            mode: request.mode,
            question: preparedQuestion?.redactedText ?? "",
            conversationText: preparedConversation.redactedText,
            targetSunSign: request.targetSunSign,
            targetMoonSign: request.targetMoonSign,
            targetRisingSign: request.targetRisingSign,
            predictedMessage: parsed.predictedMessage,
            astrologicalBreakdown: parsed.breakdown,
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
        let sun = request.targetSunSign
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
            question: preparedQuestion?.redactedText ?? "",
            conversationText: preparedConversation.redactedText,
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

    private func localConfidence(for request: PredictionRequest, conversationLength: Int) -> Int {
        var confidence = 58
        switch request.targetSunSign.element {
        case .fire, .earth: confidence += 8   // steadier texting patterns
        case .air: confidence += 4
        case .water: confidence += 2
        }
        if request.targetMoonSign != nil { confidence += 7 }
        if request.targetRisingSign != nil { confidence += 5 }
        if conversationLength > 240 { confidence += 6 } else if conversationLength > 80 { confidence += 3 }
        return min(confidence, 86)
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

    /// Parse Claude's text response into structured prediction data
    private func parseClaudeResponse(_ text: String) -> (predictedMessage: String, breakdown: String, confidence: Int, tone: SimulationTone?) {
        // Try JSON parsing first (if Claude returns structured JSON)
        if let jsonData = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let message = json["predicted_message"] as? String ?? ""
            let breakdown = json["astrological_breakdown"] as? String ?? ""
            let confidence = json["confidence"] as? Int ?? 75
            let toneStr = json["tone"] as? String
            let tone = toneStr.flatMap { SimulationTone(rawValue: $0.lowercased()) }
            return (message, breakdown, confidence, tone)
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

        return (message, breakdown, confidence, tone)
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
        let sunDescription = AstrologyTemplates.sunSign[request.targetSunSign.rawValue] ?? ""
        let moonDescription = request.targetMoonSign.flatMap { AstrologyTemplates.moonSign[$0.rawValue] }
        let risingDescription = request.targetRisingSign.flatMap { AstrologyTemplates.risingSign[$0.rawValue] }

        var prompt = """
        You are Simastry's prediction engine. Predict how someone would respond in a text conversation.

        The person you are predicting has these zodiac placements:
        - Sun in \(request.targetSunSign.displayName): \(sunDescription)
        """

        if let targetMoonSign = request.targetMoonSign, let moonDescription {
            prompt += "\n- Moon in \(targetMoonSign.displayName): \(moonDescription)"
        }

        if let targetRisingSign = request.targetRisingSign, let risingDescription {
            prompt += "\n- Rising in \(targetRisingSign.displayName): \(risingDescription)"
        }

        if let personality = AstrologyTemplates.companionPersonality[request.targetSunSign.rawValue] {
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
        - Channel their zodiac energy — don't just describe their sign, embody their texting personality
        - Return your response as valid JSON with exactly these fields:
          {"predicted_message": "the predicted text message", "astrological_breakdown": "2-3 sentences explaining why based on their signs", "confidence": 75, "tone": "casual"}
        - tone must be one of: playful, guarded, warm, cold, anxious, confident, flirty, distant
        - confidence is 0-100 representing how predictable this response is
        - Return ONLY the JSON object, no other text
        """

        return prompt
    }

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

        sections.append("Conversation:\n\(preparedConversation.redactedText)")

        if let preparedQuestion {
            sections.append("What the user wants to know:\n\(preparedQuestion.redactedText)")
        } else {
            sections.append("What the user wants to know:\nPredict the other person's most likely next text.")
        }

        if let preparedHypotheticalReply {
            sections.append("Alternative reply the user is considering sending:\n\(preparedHypotheticalReply.redactedText)\n\nUse that message as the user's next move, then predict how the other person would answer.")
        }

        return sections.joined(separator: "\n\n")
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

