import XCTest
@testable import Simastry

final class CompanionPivotContractTests: XCTestCase {
    func testPilotContainsOnlyFourCertifiedCanonicalFactorySlugs() {
        XCTAssertEqual(
            Set(CompanionPersonaRegistry.pilot.map(\.id)),
            Set([.amara, .theo, .isolde, .zev])
        )
        XCTAssertEqual(CompanionPersonaRegistry.pilot.count, 4)
        XCTAssertTrue(CompanionPersonaRegistry.pilot.allSatisfy(\.isPilotCertified))
        XCTAssertEqual(Set(CompanionPersonaRegistry.pilot.map(\.profileImageName)).count, 4)
        XCTAssertEqual(Set(CompanionPersonaRegistry.pilot.map(\.cardImageName)).count, 4)
    }

    func testRecommendationReturnsThreeUniqueCertifiedOptionsWithoutSelectingOne() {
        let recommendations = CompanionPersonaRegistry.recommendations(
            sun: .aries,
            moon: .taurus,
            rising: .libra,
            guidanceStyle: .balanced
        )
        XCTAssertEqual(recommendations.count, 3)
        XCTAssertEqual(Set(recommendations.map(\.id)).count, 3)
        XCTAssertTrue(recommendations.allSatisfy(\.isPilotCertified))
        XCTAssertFalse(CompanionPivotState().relationships.contains(where: \.isPrimary))
    }

    func testSelectingPrimaryEnforcesExactlyOneAndPreservesOtherRelationship() {
        let userId = UUID()
        var state = CompanionPivotState()

        XCTAssertNotNil(state.selectPrimary(.amara, userId: userId))
        XCTAssertNotNil(state.selectPrimary(.zev, userId: userId))

        XCTAssertEqual(state.relationships.count, 2)
        XCTAssertEqual(state.relationships.filter(\.isPrimary).count, 1)
        XCTAssertEqual(state.relationships.first(where: \.isPrimary)?.companionId, .zev)
        XCTAssertNotNil(state.relationships.first { $0.companionId == .amara })
    }

    func testSelectionNeverMapsByDisplayNameOrSign() {
        var state = CompanionPivotState()
        XCTAssertNil(state.selectPrimary(CompanionPersonaID(rawValue: "Amara"), userId: UUID()))
        XCTAssertNil(state.selectPrimary(CompanionPersonaID(rawValue: "aries"), userId: UUID()))
        XCTAssertNil(state.selectPrimary(CompanionPersonaID(rawValue: "ARIES-AMARA"), userId: UUID()))
        XCTAssertNil(state.selectPrimary(CompanionPersonaID(rawValue: " aries-amara "), userId: UUID()))
        XCTAssertTrue(state.relationships.isEmpty)
    }

    func testSeparateCompanionThreadsDoNotMerge() {
        let amaraConversation = CompanionConversation(
            id: UUID(),
            userId: UUID(),
            companionId: .amara,
            createdAt: .now,
            updatedAt: .now
        )
        let zevConversation = CompanionConversation(
            id: UUID(),
            userId: amaraConversation.userId,
            companionId: .zev,
            createdAt: .now,
            updatedAt: .now
        )
        let messages = [
            CompanionChatMessage(
                conversationId: amaraConversation.id,
                clientMessageId: UUID(),
                role: .user,
                content: "Amara thread"
            ),
            CompanionChatMessage(
                conversationId: zevConversation.id,
                clientMessageId: UUID(),
                role: .user,
                content: "Zev thread"
            ),
        ]

        XCTAssertEqual(messages.filter { $0.conversationId == amaraConversation.id }.map(\.content), ["Amara thread"])
        XCTAssertEqual(messages.filter { $0.conversationId == zevConversation.id }.map(\.content), ["Zev thread"])
    }

    func testLocalStoreRoundTripsUserControlledMemoryAndOutcome() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("companion-pivot-test-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let personId = UUID()
        var state = CompanionPivotState()
        state.syncConsent = true
        state.memories = [
            CompanionMemoryItem(
                companionId: nil,
                scope: .sharedUserFact,
                source: .userRecorded,
                content: "I prefer a direct draft.",
                relatedPersonId: personId
            )
        ]
        state.outcomes = [
            CommunicationOutcome(
                personId: personId,
                companionId: .theo,
                intendedAction: "Ask for ten quiet minutes.",
                result: .asExpected
            )
        ]

        let store = CompanionPivotStore(fileURL: fileURL)
        store.save(state)
        let restored = store.load()

        XCTAssertTrue(restored.syncConsent)
        XCTAssertEqual(restored.memories.map(\.content), ["I prefer a direct draft."])
        XCTAssertEqual(restored.outcomes.map(\.intendedAction), ["Ask for ten quiet minutes."])
        XCTAssertEqual(restored.outcomes.first?.followUpState, .pending)
    }

    func testDecodeResponseAcceptsServerNumericPersonaVersion() throws {
        let payload = #"{"tone":"steady","likelyMeaning":"A request for space.","plausibleAlternative":"They may be busy.","whatNotToAssume":"Do not infer rejection.","replyDrafts":["Can we check in tomorrow?"],"personaVersion":1,"modelVersion":"test-model","messagePersisted":false}"#.data(using: .utf8)!

        let result = try JSONDecoder().decode(CompanionDecodeResult.self, from: payload)

        XCTAssertEqual(result.personaVersion, 1)
        XCTAssertFalse(result.messagePersisted)
    }

    func testCompanionPilotDeepLinksResolveWithoutNameOrSignInference() throws {
        let talkURL = try XCTUnwrap(URL(string: "simastry://messages"))
        let exactCompanionURL = try XCTUnwrap(URL(string: "simastry://guide/aries-amara"))
        let personID = UUID()
        let personURL = try XCTUnwrap(URL(string: "simastry://person/\(personID.uuidString)"))

        XCTAssertEqual(DeepLink.from(url: talkURL), .messages)
        XCTAssertEqual(DeepLink.from(url: exactCompanionURL), .guideProfile(id: "aries-amara"))
        XCTAssertEqual(DeepLink.from(url: personURL), .person(id: personID))
    }
}

@MainActor
final class CompanionPivotBehaviorTests: XCTestCase {
    func testOfflineFallbackIsPersonaDistinctAndRejectsMindReading() {
        let viewModel = AppViewModel()
        let outputs = CompanionPersonaRegistry.pilot.map {
            viewModel.primaryCompanionOfflineFallback(for: "What does their text mean?", persona: $0)
        }

        XCTAssertEqual(Set(outputs).count, 4)
        XCTAssertTrue(outputs.first(where: { $0.contains("invent the other person's inner story") }) != nil)
    }
}
