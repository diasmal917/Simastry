import XCTest

final class SimastrySmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testTodayExpertAstrologersOpens() throws {
        launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))

        let openGuideChat = app.buttons["today.openGuideChatButton"]
        XCTAssertTrue(reveal(openGuideChat), "Expected Today to expose Expert Astrologers")
        openGuideChat.tap()

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["What would you like guidance on today?"].waitForExistence(timeout: 4))
    }

    func testTodayScrolledStateStaysClean() throws {
        launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        let todayContent = app.scrollViews.firstMatch
        XCTAssertTrue(todayContent.waitForExistence(timeout: 10))

        todayContent.swipeUp()
        todayContent.swipeUp()

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Today scrolled state"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPeoplePredictDraftLandsInReplyFlow() throws {
        launchSeededApp(arguments: ["-SimastryPreviewScreen", "playbook"])

        let predictReply = app.buttons["people.detail.predictReplyButton"]
        XCTAssertTrue(predictReply.waitForExistence(timeout: 8))
        predictReply.tap()

        XCTAssertTrue(app.tabBars.buttons["Predict"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["What happened in the thread?"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.textViews["predict.conversationInput"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["predict.stickyAction"].waitForExistence(timeout: 4))
    }

    func testExpertAstrologersEveryoneAndIndividualFlow() throws {
        launchSeededApp(arguments: ["-SimastryPreviewScreen", "astrologists"])

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["expertAstrologers.screen"].waitForExistence(timeout: 6))

        app.buttons["expertAstrologers.chip.Love"].tap()
        XCTAssertTrue(app.staticTexts["Who would you like to hear from?"].waitForExistence(timeout: 4))

        app.buttons["expertAstrologers.everyoneButton"].tap()
        XCTAssertTrue(app.otherElements["expertAstrologers.response.leyla-western"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["expertAstrologers.response.mateo-vedic"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["expertAstrologers.response.naomi-chinese"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["expertAstrologers.response.elias-ancient"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["expertAstrologers.response.nadia-evolutionary"].waitForExistence(timeout: 8))

        let western = app.buttons["expertAstrologers.specialist.leyla-western"]
        XCTAssertTrue(reveal(western, maxSwipes: 12), "Expected Leyla Western Astrologer card")
        western.tap()

        XCTAssertTrue(app.navigationBars["Leyla - Western Astrologer"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Western Astrologer"].waitForExistence(timeout: 6))
    }

    func testExpertAstrologersRetryFailedEveryoneSpecialist() throws {
        launchSeededApp(
            arguments: ["-SimastryPreviewScreen", "astrologists"],
            environment: ["SIMASTRY_EXPERT_FAIL_ONCE_SPECIALIST_IDS": "mateo-vedic"]
        )

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 10))
        app.buttons["expertAstrologers.chip.Love"].tap()
        app.buttons["expertAstrologers.everyoneButton"].tap()

        let retryMateo = app.buttons["expertAstrologers.retry.mateo-vedic"]
        XCTAssertTrue(reveal(retryMateo, maxSwipes: 8), "Expected Mateo's failed Everyone card to expose Retry")
        retryMateo.tap()

        let jyotishResponse = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "From a Jyotish lens")).firstMatch
        XCTAssertTrue(jyotishResponse.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["expertAstrologers.retry.leyla-western"].exists)
    }

    func testExpertAstrologersInfoSheetExplainsBoundaries() throws {
        launchSeededApp(arguments: ["-SimastryPreviewScreen", "astrologists"])

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 10))
        app.buttons["expertAstrologers.chip.Love"].tap()

        let naomiInfo = app.buttons["expertAstrologers.info.naomi-chinese"]
        XCTAssertTrue(reveal(naomiInfo, maxSwipes: 4), "Expected Naomi info button")
        naomiInfo.tap()

        XCTAssertTrue(app.navigationBars["Naomi - Chinese Astrologer"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["How this expert works"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["BaZi / Four Pillars"].waitForExistence(timeout: 4))
        XCTAssertTrue(reveal(app.staticTexts["Stays away from"], maxSwipes: 5))
        XCTAssertTrue(reveal(app.staticTexts["Western zodiac signs"], maxSwipes: 2))
    }

    func testTalkExpertModeDoesNotShowLegacyPanelOverhangs() throws {
        launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["Talk"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Talk"].tap()

        XCTAssertTrue(app.staticTexts["Talk"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["What should I reply back?"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Ask an expert"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Compare all five"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Expert Astrologers"].waitForExistence(timeout: 4))

        XCTAssertFalse(app.staticTexts["Your Panel"].exists)
        XCTAssertFalse(app.staticTexts["Ask my guides"].exists)
        XCTAssertFalse(app.staticTexts["Talk to a sign"].exists)
        XCTAssertFalse(app.staticTexts["What should I say?"].exists)
    }

    func testLegacyGuidesDirectoryStillRestorable() throws {
        launchSeededApp(arguments: ["-SimastryPreviewScreen", "astrologists", "-SimastryLegacyGuides"])

        XCTAssertTrue(app.navigationBars["Guides"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["guides.directory.screen"].waitForExistence(timeout: 6))

        let directory = app.scrollViews["guides.directory.screen"]
        directory.swipeUp()

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Guides directory scrolled state"
        attachment.lifetime = .keepAlways
        add(attachment)

        directory.swipeDown()
        directory.swipeDown()

        let nadia = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Nadia")).firstMatch
        XCTAssertTrue(reveal(nadia, maxSwipes: 2), "Expected the Guides directory to expose Nadia")
        nadia.tap()

        XCTAssertTrue(app.navigationBars["@nadia.sagittarius"].waitForExistence(timeout: 6))
    }

    func testHighRiskSheetsOpenAndDismiss() throws {
        launchSeededApp(arguments: ["-SimastryPreviewTab", "1"])

        XCTAssertTrue(app.tabBars.buttons["People"].waitForExistence(timeout: 10))

        app.buttons["people.toolbar.addPersonButton"].tap()
        XCTAssertTrue(app.otherElements["people.addPersonSheet"].waitForExistence(timeout: 4))
        app.buttons["people.addPerson.cancelButton"].tap()

        let teamRead = app.buttons["people.teamReadEntryButton"]
        XCTAssertTrue(reveal(teamRead), "Expected People to expose Team Read")
        teamRead.tap()
        XCTAssertTrue(app.otherElements["people.teamReadSheet"].waitForExistence(timeout: 4))
        app.buttons["Done"].tap()

        app.tabBars.buttons["Talk"].tap()

        app.buttons["talk.toolbar.newRoomButton"].tap()
        XCTAssertTrue(app.otherElements["talk.newRoomSheet"].waitForExistence(timeout: 4))
        app.buttons["Cancel"].tap()

        app.buttons["talk.toolbar.newMessageButton"].tap()
        XCTAssertTrue(app.otherElements["talk.messageSearchSheet"].waitForExistence(timeout: 4))

        let leylaExpert = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Leyla")).firstMatch
        XCTAssertTrue(leylaExpert.waitForExistence(timeout: 4))
        leylaExpert.tap()

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 4))
        app.navigationBars["Expert Astrologers"].buttons["Done"].tap()
        XCTAssertTrue(app.otherElements["talk.messageSearchSheet"].waitForExistence(timeout: 4))
        app.otherElements["talk.messageSearchSheet"].buttons["Done"].tap()

        let readMessage = app.buttons["Read a message"]
        XCTAssertTrue(readMessage.waitForExistence(timeout: 4))
        readMessage.tap()
        XCTAssertTrue(app.navigationBars["Decode"].waitForExistence(timeout: 4))
        app.buttons["Close"].tap()
    }

    func testDiscoveryProfileStartsLocalConversationAndOpensTalk() throws {
        launchSeededApp(arguments: ["-SimastryPreviewTab", "3"])

        XCTAssertTrue(app.tabBars.buttons["Me"].waitForExistence(timeout: 10))

        let discoveryButton = app.buttons["profile.discoveryButton"]
        XCTAssertTrue(reveal(discoveryButton, maxSwipes: 10), "Expected Me to expose Discovery")
        discoveryButton.tap()

        XCTAssertTrue(app.navigationBars["Find Others Like You"].waitForExistence(timeout: 8))

        let rowan = app.buttons["discovery.profile.rowan.aries"]
        XCTAssertTrue(reveal(rowan, maxSwipes: 4), "Expected Discovery to show Rowan from seeded profiles")
        rowan.tap()

        XCTAssertTrue(app.otherElements["discovery.profileDetail.rowan.aries"].waitForExistence(timeout: 5))

        let chatButton = app.buttons["discovery.profileDetail.startChatButton"]
        XCTAssertTrue(chatButton.waitForExistence(timeout: 5))
        chatButton.tap()

        XCTAssertTrue(app.tabBars.buttons["Talk"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Rowan")).firstMatch.waitForExistence(timeout: 6))
    }

    private func launchSeededApp(arguments: [String] = [], environment: [String: String] = [:]) {
        app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded"] + arguments
        app.launchEnvironment["SIMASTRY_UI_PREFILL_ADD_PERSON_NAME"] = "Smoke Person"
        for (key, value) in environment {
            app.launchEnvironment[key] = value
        }
        app.launch()
    }

    private func reveal(_ element: XCUIElement, maxSwipes: Int = 6) -> Bool {
        for _ in 0..<maxSwipes {
            if element.waitForExistence(timeout: 0.6), element.isHittable {
                return true
            }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

}
