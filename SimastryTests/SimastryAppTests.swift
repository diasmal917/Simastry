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
}
