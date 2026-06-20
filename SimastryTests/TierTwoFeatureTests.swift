import Foundation
import Testing
import UIKit
@testable import Simastry

@MainActor
struct TierTwoFeatureTests {
    // MARK: - Conversation OCR

    @Test func ocrRecognizesRenderedConversationTopToBottom() async throws {
        let size = CGSize(width: 900, height: 460)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            ("Are we still on for tonight" as NSString)
                .draw(at: CGPoint(x: 48, y: 90), withAttributes: attributes)
            ("Yes see you at seven" as NSString)
                .draw(at: CGPoint(x: 48, y: 260), withAttributes: attributes)
        }

        let data = try #require(image.jpegData(compressionQuality: 0.92))
        let recognized = try await ConversationOCRService.recognizeText(in: data)
        let lowered = recognized.lowercased()

        #expect(lowered.contains("still on for tonight"))
        #expect(lowered.contains("seven"))

        // Lines come back in conversation order (top of screenshot first).
        if let first = lowered.range(of: "tonight"), let second = lowered.range(of: "seven") {
            #expect(first.lowerBound < second.lowerBound)
        }
    }

    // MARK: - Transit Engine

    @Test func wholeSignAspectClassification() {
        #expect(WholeSignAspect.between(.aries, .aries) == .conjunction)
        #expect(WholeSignAspect.between(.aries, .gemini) == .sextile)
        #expect(WholeSignAspect.between(.aries, .cancer) == .square)
        #expect(WholeSignAspect.between(.aries, .leo) == .trine)
        #expect(WholeSignAspect.between(.aries, .libra) == .opposition)
        #expect(WholeSignAspect.between(.aries, .taurus) == nil)
        #expect(WholeSignAspect.between(.aries, .virgo) == nil)
        // Symmetry and wrap-around.
        #expect(WholeSignAspect.between(.pisces, .aries) == nil)
        #expect(WholeSignAspect.between(.capricorn, .aries) == .square)
        #expect(WholeSignAspect.between(.sagittarius, .aries) == .trine)
    }

    @Test func transitingSunMatchesZodiacSeason() {
        // 2020-01-01 12:00 UTC — the Sun was in Capricorn.
        var components = DateComponents()
        components.year = 2020
        components.month = 1
        components.day = 1
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            Issue.record("Failed to build test date")
            return
        }

        BirthChartService.setup()
        #expect(TransitEngine.transitingSign(of: .sun, on: date) == .capricorn)
    }

    @Test func dailyReadingIsDeterministicAndRespectsMissingChart() {
        BirthChartService.setup()
        let date = Date()

        let first = TransitEngine.dailyReading(sun: .sagittarius, moon: .cancer, rising: .libra, on: date)
        let second = TransitEngine.dailyReading(sun: .sagittarius, moon: .cancer, rising: .libra, on: date)
        #expect(first == second)

        if let reading = first {
            #expect(!reading.guidance.isEmpty)
            #expect(!reading.headline.isEmpty)
        }

        #expect(TransitEngine.dailyReading(sun: nil, moon: nil, rising: nil, on: date) == nil)
    }

    @Test func ocrThrowsOnBlankImage() async {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        let blank = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
        guard let data = blank.jpegData(compressionQuality: 0.9) else {
            Issue.record("Failed to encode blank image")
            return
        }

        await #expect(throws: ConversationOCRError.self) {
            _ = try await ConversationOCRService.recognizeText(in: data)
        }
    }

    // MARK: - LLM Channel Prep

    @Test func personaPromptCarriesMethodChartAndHonesty() {
        guard let profile = FactoryCompanionCatalog.all.first(where: { $0.id == "taurus-ada" }) else {
            Issue.record("Expected cast member missing from catalog")
            return
        }

        let prompt = GuideReplyService.personaSystemPrompt(
            profile: profile,
            role: .sun,
            user: .init(name: "Maya", sun: .sagittarius, moon: .cancer, rising: .libra, communicationType: "Diplomatic Explorer"),
            isPanel: true,
            previousGuideName: "Nadia"
        )

        #expect(prompt.contains("Ada"))
        #expect(prompt.contains(ZodiacSign.taurus.methodLine))
        #expect(prompt.contains("Sun in Sagittarius"))
        #expect(prompt.contains("Diplomatic Explorer"))
        #expect(prompt.contains("Nadia"))
        #expect(prompt.contains("Never claim to be human"))
    }

    @Test func threadPromptKeepsRecentMessagesInOrder() {
        let transcript = (1...14).map {
            GuideReplyService.TranscriptEntry(senderName: $0 % 2 == 0 ? "Maya" : "Ada", content: "message \($0)")
        }
        let prompt = GuideReplyService.threadUserPrompt(transcript: transcript, replyingAs: "Ada")

        #expect(!prompt.contains("message 4"))   // trimmed to the last 10
        #expect(prompt.contains("message 5"))
        #expect(prompt.contains("message 14"))
        #expect(prompt.contains("Reply as Ada"))
    }

    @Test func withTimeoutReturnsValueThenNilOnSlowOperation() async {
        let fast = await GuideReplyService.withTimeout(seconds: 2) { "ok" }
        #expect(fast == "ok")

        let slow = await GuideReplyService.withTimeout(seconds: 0.2) {
            try await Task.sleep(for: .seconds(5))
            return "late"
        }
        #expect(slow == nil)
    }

    @Test func predictionFallsBackToLocalComposerWhenUnconfigured() async throws {
        defer { UserDefaults.standard.removeObject(forKey: "simastry_prediction_history") }

        let service = PredictionService()   // no reply channel injected
        let request = PredictionRequest(
            mode: .whatWillTheySay,
            conversationText: "hey, are we still on for friday?",
            targetSunSign: .taurus,
            targetMoonSign: .cancer,
            targetRisingSign: nil,
            question: nil,
            hypotheticalReply: nil
        )

        let result = try await service.generatePrediction(request: request, tier: "free")
        #expect(result.isLocalComposition == true)
        #expect(!result.predictedMessage.isEmpty)
        #expect(!result.astrologicalBreakdown.isEmpty)
    }

    @Test func predictionFallsBackToLocalComposerWhenRemoteFails() async throws {
        defer { UserDefaults.standard.removeObject(forKey: "simastry_prediction_history") }

        let service = PredictionService()
        service.isRemoteChannelAvailable = { true }
        service.replyChannel = { _, _ in
            throw PredictionServiceError.serverError("offline")
        }
        let request = PredictionRequest(
            mode: .whatWillTheySay,
            conversationText: "hey, are we still on for friday?",
            targetSunSign: .taurus,
            targetMoonSign: .cancer,
            targetRisingSign: nil,
            question: nil,
            hypotheticalReply: nil
        )

        let result = try await service.generatePrediction(request: request, tier: "free")
        #expect(result.isLocalComposition == true)
        #expect(!result.predictedMessage.isEmpty)
        #expect(!result.astrologicalBreakdown.isEmpty)
    }

    @Test func predictionPropagatesRemoteLimitWithoutLocalFallback() async throws {
        defer { UserDefaults.standard.removeObject(forKey: "simastry_prediction_history") }

        let service = PredictionService()
        service.isRemoteChannelAvailable = { true }
        service.replyChannel = { _, _ in
            throw PredictionServiceError.aiUsageLimit("You have reached today's AI guide limit.")
        }
        let request = PredictionRequest(
            mode: .whatWillTheySay,
            conversationText: "hey, are we still on for friday?",
            targetSunSign: .taurus,
            targetMoonSign: .cancer,
            targetRisingSign: nil,
            question: nil,
            hypotheticalReply: nil
        )

        do {
            _ = try await service.generatePrediction(request: request, tier: "free")
            #expect(Bool(false))
        } catch let error as PredictionServiceError {
            #expect(error.errorDescription?.contains("AI guide limit") == true)
            #expect(service.loadHistory().isEmpty)
        } catch {
            #expect(Bool(false))
        }
    }

    @Test func companionReplyPayloadEncodesFeatureNames() throws {
        for feature in CompanionReplyFeature.allCases {
            let payload = CompanionReplyPayload(
                kind: CompanionReplyKind.chat.rawValue,
                feature: feature.rawValue,
                system: "system",
                user: "user",
                maxTokens: 123
            )
            let data = try JSONEncoder().encode(payload)
            let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(object["feature"] as? String == feature.rawValue)
        }
    }

    @Test func companionReplyResponseDecodesUsageEventId() throws {
        let usageEventId = UUID()
        let data = try JSONEncoder().encode([
            "text": "Use one short warm line.",
            "usageEventId": usageEventId.uuidString
        ])

        let decoded = try JSONDecoder().decode(CompanionReplyResponse.self, from: data)
        #expect(decoded.text == "Use one short warm line.")
        #expect(decoded.usageEventId == usageEventId)
    }
}
