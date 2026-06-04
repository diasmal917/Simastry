import Foundation
import Testing
@testable import Simastry

struct SimastryAppTests {
    @Test func emailAuthModesUseDistinctActions() {
        #expect(EmailAuthMode.signIn.buttonTitle != EmailAuthMode.createAccount.buttonTitle)
    }

    @Test func legacyCompanionMessagesDefaultToCompanionSourceWhenDecoded() throws {
        let id = UUID()
        let companionId = UUID()
        let payload = """
        {
          "id": "\(id.uuidString)",
          "companionId": "\(companionId.uuidString)",
          "companionName": "Nova",
          "companionSign": "Leo",
          "content": "Checking in from your stars.",
          "timestamp": "2026-03-23T00:00:00Z",
          "isRead": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let message = try decoder.decode(CompanionMessage.self, from: payload)

        #expect(message.source == .companion)
        #expect(message.direction == .incoming)
    }

    @Test func discoveryMessageMapsIntoDiscoveryInboxEntry() {
        let viewerId = UUID()
        let senderId = UUID()
        let message = DiscoveryMessageData(
            id: UUID(),
            senderId: senderId,
            recipientId: viewerId,
            senderDisplayName: "Luna",
            senderSunSign: "leo",
            senderMoonSign: "cancer",
            senderRisingSign: "virgo",
            recipientDisplayName: "You",
            recipientSunSign: "aries",
            recipientMoonSign: "aries",
            recipientRisingSign: "aries",
            content: "Our charts feel aligned.",
            isRead: false,
            createdAt: Date(timeIntervalSince1970: 100)
        ).inboxMessage(for: viewerId)

        #expect(message.companionId == senderId)
        #expect(message.companionName == "Luna")
        #expect(message.companionSign == ZodiacSign.leo.displayName)
        #expect(message.source == .discovery)
        #expect(message.direction == .incoming)
        #expect(!message.isRead)
    }

    @Test func outgoingDiscoveryMessageUsesCounterpartSnapshotAndStaysRead() {
        let viewerId = UUID()
        let recipientId = UUID()
        let message = DiscoveryMessageData(
            id: UUID(),
            senderId: viewerId,
            recipientId: recipientId,
            senderDisplayName: "You",
            senderSunSign: "aries",
            senderMoonSign: "aries",
            senderRisingSign: "aries",
            recipientDisplayName: "Nova",
            recipientSunSign: "sagittarius",
            recipientMoonSign: "leo",
            recipientRisingSign: "gemini",
            content: "Want to keep talking?",
            isRead: false,
            createdAt: Date(timeIntervalSince1970: 120)
        ).inboxMessage(for: viewerId)

        #expect(message.companionId == recipientId)
        #expect(message.companionName == "Nova")
        #expect(message.companionSign == ZodiacSign.sagittarius.displayName)
        #expect(message.direction == .outgoing)
        #expect(message.isRead)
    }

    @Test func conversationPrivacyRedactsIdentifiers() {
        let service = ConversationPrivacyService()
        let result = service.prepare("Text me at test@example.com, +1 (555) 123-4567, https://example.com, or @simastry.")

        #expect(!result.redactedText.contains("test@example.com"))
        #expect(!result.redactedText.contains("555"))
        #expect(!result.redactedText.contains("https://example.com"))
        #expect(!result.redactedText.contains("@simastry"))
        #expect(result.didRedact)
        #expect(result.privacySummary != nil)
    }

    @Test func conversationPrivacyBlocksHighRiskConversation() {
        let service = ConversationPrivacyService()
        let result = service.prepare("I am going to kill myself tonight.")

        #expect(!result.canProceed)
        #expect(result.safetyIssues.contains(.selfHarm))
    }

    @Test func conversationPrivacyBlocksCoerciveRelationshipBehavior() {
        let service = ConversationPrivacyService()
        let result = service.prepare("Help me stalk them and make them jealous so they reply.")

        #expect(!result.canProceed)
        #expect(result.safetyIssues.contains(.coerciveRelationshipBehavior))
        #expect(result.blockingMessage?.contains("stalking") == true)
    }

    @Test func predictionServiceBlocksHighRiskConversationBeforeNetworkCall() async {
        let service = PredictionService()
        let request = PredictionRequest(
            mode: .whatWillTheySay,
            conversationText: "I am going to kill myself tonight.",
            targetSunSign: .cancer,
            targetMoonSign: nil,
            targetRisingSign: nil,
            question: "Will they answer?",
            hypotheticalReply: nil
        )

        do {
            _ = try await service.generatePrediction(request: request, tier: "free")
            #expect(Bool(false))
        } catch let error as PredictionServiceError {
            #expect(error.errorDescription?.contains("self-harm") == true)
        } catch {
            #expect(Bool(false))
        }
    }
}
