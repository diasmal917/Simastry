import Foundation

nonisolated enum PredictionServiceError: LocalizedError, Sendable {
    case serviceUnavailable
    case invalidRequest
    case invalidResponse
    case emptyResponse
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
        case .serverError(let message):
            message
        }
    }
}

nonisolated final class PredictionService {
    private let session: URLSession
    private let historyKey: String = "simastry_prediction_history"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    var isConfigured: Bool {
        predictionEndpoint != nil
    }

    func generatePrediction(request: PredictionRequest, tier: String) async throws -> PredictionResult {
        guard let endpoint = predictionEndpoint else {
            throw PredictionServiceError.serviceUnavailable
        }

        guard !request.trimmedConversationText.isEmpty else {
            throw PredictionServiceError.invalidRequest
        }

        let payload = PredictionProxyRequest(
            mode: request.mode,
            tier: tier,
            systemPrompt: makeSystemPrompt(for: request),
            userPrompt: makeUserPrompt(for: request)
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 45
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PredictionServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let serverMessage = decodeServerMessage(from: data)
            throw PredictionServiceError.serverError(serverMessage ?? "The prediction request failed. Please try again.")
        }

        let decoded: PredictionProxyResponse
        do {
            decoded = try decoder.decode(PredictionProxyResponse.self, from: data)
        } catch {
            throw PredictionServiceError.invalidResponse
        }

        let message = decoded.predictedMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let breakdown = decoded.astrologicalBreakdown.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !message.isEmpty, !breakdown.isEmpty else {
            throw PredictionServiceError.emptyResponse
        }

        let result = PredictionResult(
            id: UUID(),
            mode: request.mode,
            question: request.trimmedQuestion ?? "",
            conversationText: request.trimmedConversationText,
            targetSunSign: request.targetSunSign,
            targetMoonSign: request.targetMoonSign,
            targetRisingSign: request.targetRisingSign,
            predictedMessage: message,
            astrologicalBreakdown: breakdown,
            confidence: min(max(decoded.confidence, 0), 100),
            tone: decoded.normalizedTone,
            createdAt: Date()
        )

        save(result)
        return result
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

    private var predictionEndpoint: URL? {
        let rawBaseURL = Config.EXPO_PUBLIC_RORK_API_BASE_URL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawBaseURL.isEmpty, let baseURL = URL(string: rawBaseURL) else {
            return nil
        }

        let apiRoot: URL = baseURL.path.hasSuffix("/api")
            ? baseURL
            : baseURL.appendingPathComponent("api")

        return apiRoot
            .appendingPathComponent("simulate")
            .appendingPathComponent("predict")
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
        - Return only the fields requested by the calling schema
        - Channel their zodiac energy — don't just describe their sign, embody their texting personality
        """

        return prompt
    }

    private func makeUserPrompt(for request: PredictionRequest) -> String {
        var sections: [String] = []
        sections.append("Conversation:\n\(request.trimmedConversationText)")

        if let question = request.trimmedQuestion {
            sections.append("What the user wants to know:\n\(question)")
        } else {
            sections.append("What the user wants to know:\nPredict the other person's most likely next text.")
        }

        if let hypotheticalReply = request.trimmedHypotheticalReply {
            sections.append("Alternative reply the user is considering sending:\n\(hypotheticalReply)\n\nUse that message as the user's next move, then predict how the other person would answer.")
        }

        return sections.joined(separator: "\n\n")
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
