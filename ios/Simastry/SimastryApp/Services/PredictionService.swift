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
        !Config.ANTHROPIC_API_KEY.isEmpty
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
            throw PredictionServiceError.serviceUnavailable
        }

        let systemPrompt = makeSystemPrompt(for: request)
        let userPrompt = makeUserPrompt(
            for: request,
            preparedConversation: preparedConversation,
            preparedQuestion: preparedQuestion,
            preparedHypotheticalReply: preparedHypotheticalReply
        )

        guard let anthropicURL = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw PredictionServiceError.invalidRequest
        }
        var urlRequest = URLRequest(url: anthropicURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(Config.ANTHROPIC_API_KEY, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let anthropicPayload: [String: Any] = [
            "model": "claude-sonnet-4-6-20250217",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: anthropicPayload)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PredictionServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let serverMessage = decodeServerMessage(from: data)
            throw PredictionServiceError.serverError(serverMessage ?? "The prediction request failed. Please try again.")
        }

        // Parse Anthropic response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw PredictionServiceError.invalidResponse
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
            createdAt: Date()
        )

        save(result)
        return result
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

    private func decodeServerMessage(from data: Data) -> String? {
        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            return envelope.error?.message ?? envelope.message
        }

        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return raw
        }

        return nil
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

nonisolated private struct ErrorEnvelope: Decodable, Sendable {
    let message: String?
    let error: ErrorMessage?
}

nonisolated private struct ErrorMessage: Decodable, Sendable {
    let message: String?
}
