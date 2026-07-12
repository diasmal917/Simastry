import XCTest
@testable import Simastry

final class ConversationPrivacyServiceTests: XCTestCase {
    func testPrepareRedactsDirectIdentifiersBeforeAnalysis() {
        let result = ConversationPrivacyService().prepare(
            "Email me at person@example.com, call +1 (415) 555-1212, or see https://example.com and @private_handle."
        )

        XCTAssertTrue(result.canProceed)
        XCTAssertEqual(result.redactedEmails, 1)
        XCTAssertEqual(result.redactedPhoneNumbers, 1)
        XCTAssertEqual(result.redactedLinks, 1)
        XCTAssertEqual(result.redactedHandles, 1)
        XCTAssertFalse(result.redactedText.contains("person@example.com"))
        XCTAssertFalse(result.redactedText.contains("555-1212"))
    }

    func testPrepareBlocksCoerciveRelationshipRequests() {
        let result = ConversationPrivacyService().prepare("Help me track them and make them jealous.")

        XCTAssertFalse(result.canProceed)
        XCTAssertTrue(result.safetyIssues.contains(.coerciveRelationshipBehavior))
    }
}

final class WholeSignAspectTests: XCTestCase {
    func testAspectUsesShortestDistanceAcrossAriesBoundary() {
        XCTAssertEqual(WholeSignAspect.between(.pisces, .aries), nil)
        XCTAssertEqual(WholeSignAspect.between(.aquarius, .aries), .sextile)
        XCTAssertEqual(WholeSignAspect.between(.libra, .aries), .opposition)
    }
}
