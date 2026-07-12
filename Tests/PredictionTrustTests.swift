import XCTest
@testable import Simastry

@MainActor
final class PredictionSubmissionCoordinatorTests: XCTestCase {
    func testOnlyOneSubmissionCanBeActiveAndCommitIsExactOnce() async throws {
        let limiter = RateLimiter(config: .init(maxPerMinute: 1, maxPerHour: 1, maxPerDay: 1))
        let coordinator = PredictionSubmissionCoordinator()

        let token = try await coordinator.acquire(using: limiter)

        do {
            _ = try await coordinator.acquire(using: limiter)
            XCTFail("A second active submission should not be acquired")
        } catch let error as PredictionSubmissionError {
            guard case .alreadySubmitting = error else {
                return XCTFail("Expected alreadySubmitting, got \(error)")
            }
        }

        let firstCommit = await coordinator.commit(token, using: limiter)
        let duplicateCommit = await coordinator.commit(token, using: limiter)
        XCTAssertTrue(firstCommit)
        XCTAssertFalse(duplicateCommit)

        do {
            _ = try await coordinator.acquire(using: limiter)
            XCTFail("A committed reservation should count against the limiter")
        } catch let error as PredictionSubmissionError {
            guard case .rateLimited = error else {
                return XCTFail("Expected rateLimited, got \(error)")
            }
        }
    }

    func testCancellationReleasesReservedUsage() async throws {
        let limiter = RateLimiter(config: .init(maxPerMinute: 1, maxPerHour: 1, maxPerDay: 1))
        let coordinator = PredictionSubmissionCoordinator()

        let cancelled = try await coordinator.acquire(using: limiter)
        await coordinator.cancel(cancelled, using: limiter)

        let replacement = try await coordinator.acquire(using: limiter)
        XCTAssertNotEqual(cancelled.idempotencyKey, replacement.idempotencyKey)
        let committed = await coordinator.commit(replacement, using: limiter)
        XCTAssertTrue(committed)
    }
}

@MainActor
final class PredictionTrustTests: XCTestCase {
    private func request(
        intent: CompassIntent = .general,
        evidence: [ReadingEvidence] = []
    ) -> PredictionRequest {
        PredictionRequest(
            mode: .whatWillTheySay,
            category: .privateQuestion,
            intent: intent,
            conversationText: "",
            evidence: evidence,
            targetSunSign: nil,
            targetMoonSign: nil,
            targetRisingSign: nil,
            question: "What should I do next?",
            hypotheticalReply: nil
        )
    }

    func testNoChartGeneralQuestionReturnsPracticalLocalFallbackWithoutTiming() async throws {
        let key = "prediction-trust-local-\(UUID().uuidString)"
        let service = PredictionService(historyKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let result = try await service.generatePrediction(request: request(), tier: "free")

        XCTAssertEqual(result.isLocalComposition, true)
        XCTAssertNil(result.timingWindow)
        XCTAssertNotNil(result.practicalNextMove)
        XCTAssertNotNil(result.plausibleAlternative)
        XCTAssertEqual(result.contextQuality, .questionOnly)
        XCTAssertEqual(result.evidence?.first?.basis, .generalLens)
    }

    func testRemoteResponseCannotInventTimingWithoutCalculatedEvidence() async throws {
        let key = "prediction-trust-remote-\(UUID().uuidString)"
        let service = PredictionService(historyKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        service.isRemoteChannelAvailable = { true }
        service.replyChannel = { _, _ in
            """
            {"predicted_message":"Take one small step.","direct_answer":"Take one small step.","timing_window":"next Friday","astrological_breakdown":"invented","practical_next_move":"Ask one direct question.","plausible_alternative":"You may need more context.","tone":"warm"}
            """
        }

        let generalRequest = PredictionRequest(
            mode: .whatWillTheySay,
            category: .privateQuestion,
            intent: .general,
            conversationText: "",
            targetSunSign: nil,
            targetMoonSign: nil,
            targetRisingSign: nil,
            question: "What should I do next?",
            hypotheticalReply: nil
        )
        XCTAssertEqual(generalRequest.intent, .general)
        XCTAssertEqual(generalRequest.trimmedQuestion, "What should I do next?")

        let result = try await service.generatePrediction(request: generalRequest, tier: "free")

        XCTAssertNil(result.timingWindow)
        XCTAssertFalse(result.evidence?.contains(where: { $0.supportsTiming }) ?? true)
    }

    func testCalculatedTimingEvidenceIsPreservedAndLabeled() async throws {
        let key = "prediction-trust-evidence-\(UUID().uuidString)"
        let service = PredictionService(historyKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let timingEvidence = ReadingEvidence(
            basis: .calculated,
            label: "Reviewed transit window",
            detail: "A calculated transit is active today.",
            supportsTiming: true
        )

        let result = try await service.generatePrediction(
            request: request(intent: .timing, evidence: [timingEvidence]),
            tier: "free"
        )

        XCTAssertEqual(result.evidence, [timingEvidence])
        XCTAssertNil(result.timingWindow, "The local fallback must not turn timing evidence into a forecast")
        XCTAssertEqual(result.contextQuality, .someContext)
    }

    func testLegacyPredictionHistoryStillDecodes() throws {
        let key = "prediction-trust-legacy-\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let id = UUID()
        let legacy: [[String: Any]] = [[
            "id": id.uuidString,
            "mode": "what_will_they_say",
            "question": "Will they reply?",
            "predictedMessage": "They may reply after they have space.",
            "astrologicalBreakdown": "Legacy interpretation",
            "confidence": 72,
            "createdAt": "2026-01-02T03:04:05Z"
        ]]
        UserDefaults.standard.set(try JSONSerialization.data(withJSONObject: legacy), forKey: key)

        let result = try XCTUnwrap(PredictionService(historyKey: key).loadHistory().first)

        XCTAssertEqual(result.id, id)
        XCTAssertEqual(result.categoryOrDefault, .messageOutcome)
        XCTAssertNil(result.evidence)
        XCTAssertNil(result.contextQuality)
        XCTAssertEqual(result.displayAnswer, "They may reply after they have space.")
    }
}
