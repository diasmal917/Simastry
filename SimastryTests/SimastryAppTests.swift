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

    @Test func publicProfileNormalizesAndValidatesUsernames() {
        #expect(PublicProfile.normalizedUsername("  Nadia.Star  ") == "nadia.star")
        #expect(PublicProfile.isValidUsername("nadia.star"))
        #expect(PublicProfile.isValidUsername("nadia_star24"))
        #expect(!PublicProfile.isValidUsername("na"))
        #expect(!PublicProfile.isValidUsername("nadia star"))
        #expect(!PublicProfile.isValidUsername("nadia-star"))
    }

    @Test func publicProfileDecodesNewAndLegacyDiscoveryFlags() throws {
        let id = UUID()
        let payload = """
        {
          "id": "\(id.uuidString)",
          "username": "  Nadia.Star  ",
          "display_name": "Nadia",
          "sun_sign": "sagittarius",
          "communication_hint": "Lead with warmth, then be direct.",
          "ice_breakers": ["What kind of timing feels right today?"],
          "is_visible": true
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(PublicProfile.self, from: payload)

        #expect(profile.username == "nadia.star")
        #expect(profile.displayName == "Nadia")
        #expect(profile.isDiscoverable)
        #expect(profile.communicationHint == "Lead with warmth, then be direct.")
        #expect(profile.iceBreakers == ["What kind of timing feels right today?"])
    }

    @Test func publicProfileEncodesSupabaseDiscoveryFields() throws {
        let id = UUID()
        let profile = PublicProfile(
            id: id,
            username: "Nadia.Star",
            displayName: "Nadia",
            avatarURL: "https://example.com/nadia.jpg",
            sunSign: "sagittarius",
            communicationHint: "Keep it bright and specific.",
            iceBreakers: ["Want to compare timing?"],
            isDiscoverable: true,
            createdAt: Date(timeIntervalSince1970: 0)
        )

        let data = try JSONEncoder().encode(profile)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["username"] as? String == "nadia.star")
        #expect(object["display_name"] as? String == "Nadia")
        #expect(object["avatar_url"] as? String == "https://example.com/nadia.jpg")
        #expect(object["communication_hint"] as? String == "Keep it bright and specific.")
        #expect(object["is_discoverable"] as? Bool == true)
        #expect(object["is_visible"] == nil)
    }

    @Test func deepLinksSupportTodayPredictMessagesPeopleAndGuideProfiles() throws {
        let personId = UUID()

        #expect(DeepLink.from(url: URL(string: "simastry://today")!) == .home)
        #expect(DeepLink.from(url: URL(string: "simastry://predict")!) == .predict)
        #expect(DeepLink.from(url: URL(string: "simastry://messages")!) == .messages)
        #expect(DeepLink.from(url: URL(string: "simastry://person/\(personId.uuidString)")!) == .person(id: personId))
        #expect(DeepLink.from(url: URL(string: "simastry://guide/nadia")!) == .guideProfile(id: "nadia"))
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
