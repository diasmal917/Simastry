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
        launchSeededApp(
            arguments: ["-SimastryPreviewScreen", "astrologists"],
            environment: ["SIMASTRY_EXPERT_PREVIEW_DELAY_MS": "1800"]
        )

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["expertAstrologers.screen"].waitForExistence(timeout: 6))

        app.buttons["expertAstrologers.chip.Love"].tap()
        XCTAssertTrue(app.staticTexts["Who would you like to hear from?"].waitForExistence(timeout: 4))

        app.buttons["expertAstrologers.everyoneButton"].tap()
        XCTAssertTrue(element("expertAstrologers.progressSummary.leyla-western").waitForExistence(timeout: 3))
        XCTAssertTrue(element("expertAstrologers.progressSummary.mateo-vedic").waitForExistence(timeout: 3))
        XCTAssertTrue(element("expertAstrologers.progressSummary.naomi-chinese").waitForExistence(timeout: 3))
        XCTAssertTrue(element("expertAstrologers.progressSummary.elias-ancient").waitForExistence(timeout: 3))
        XCTAssertTrue(element("expertAstrologers.progressSummary.nadia-evolutionary").waitForExistence(timeout: 3))
        XCTAssertTrue(element("expertAstrologers.response.leyla-western").waitForExistence(timeout: 8))
        XCTAssertTrue(element("expertAstrologers.response.mateo-vedic").waitForExistence(timeout: 8))
        XCTAssertTrue(element("expertAstrologers.response.naomi-chinese").waitForExistence(timeout: 8))
        XCTAssertTrue(element("expertAstrologers.response.elias-ancient").waitForExistence(timeout: 8))
        XCTAssertTrue(element("expertAstrologers.response.nadia-evolutionary").waitForExistence(timeout: 8))

        XCTAssertFalse(app.buttons["expertAstrologers.specialist.leyla-western"].exists)
        XCTAssertFalse(app.buttons["expertAstrologers.specialist.mateo-vedic"].exists)
        XCTAssertFalse(app.buttons["expertAstrologers.specialist.naomi-chinese"].exists)
        XCTAssertFalse(app.buttons["expertAstrologers.specialist.elias-ancient"].exists)
        XCTAssertFalse(app.buttons["expertAstrologers.specialist.nadia-evolutionary"].exists)
    }

    func testExpertAstrologersIndividualRosterOpensBeforeEveryoneMode() throws {
        launchSeededApp(arguments: ["-SimastryPreviewScreen", "astrologists"])

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["expertAstrologers.screen"].waitForExistence(timeout: 6))

        app.buttons["expertAstrologers.chip.Love"].tap()
        let western = app.buttons["expertAstrologers.specialist.leyla-western"]
        XCTAssertTrue(reveal(western, maxSwipes: 6), "Expected Leyla Western Astrologer card")
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

        let jyotishResponse = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "weighed through karma")).firstMatch
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
        XCTAssertTrue(app.staticTexts["Readiness checklist"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Methods Naomi uses"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Four Pillars"].waitForExistence(timeout: 4))
        XCTAssertTrue(reveal(app.staticTexts["Methods Naomi avoids"], maxSwipes: 5))
        XCTAssertTrue(reveal(app.staticTexts["Western zodiac signs"], maxSwipes: 2))
    }

    func testExpertAstrologersReadinessAndMissingInfoCTA() throws {
        launchSeededApp(arguments: ["-SimastryPreviewScreen", "astrologists"])

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 10))
        app.buttons["expertAstrologers.chip.Love"].tap()

        let leylaInfo = app.buttons["expertAstrologers.info.leyla-western"]
        XCTAssertTrue(reveal(leylaInfo, maxSwipes: 4), "Expected Leyla info button")
        leylaInfo.tap()

        XCTAssertTrue(app.staticTexts["Readiness checklist"].waitForExistence(timeout: 4))
        let addMissing = app.buttons["expertAstrologers.readiness.addMissing"]
        XCTAssertTrue(reveal(addMissing, maxSwipes: 4), "Expected missing-info CTA")
        addMissing.tap()

        XCTAssertTrue(app.navigationBars["Add Missing Info"].waitForExistence(timeout: 4))
        XCTAssertTrue(reveal(app.staticTexts["User-supplied tradition fields"], maxSwipes: 8))
        app.buttons["Cancel"].tap()
        app.buttons["Done"].tap()

        let mateoInfo = app.buttons["expertAstrologers.info.mateo-vedic"]
        XCTAssertTrue(reveal(mateoInfo, maxSwipes: 4), "Expected Mateo info button")
        mateoInfo.tap()
        XCTAssertTrue(app.staticTexts["Readiness checklist"].waitForExistence(timeout: 4))
        XCTAssertTrue(reveal(app.staticTexts["Birth time"], maxSwipes: 4))
        app.buttons["Done"].tap()

        let sorenInfo = app.buttons["expertAstrologers.info.elias-ancient"]
        XCTAssertTrue(reveal(sorenInfo, maxSwipes: 8), "Expected Soren info button")
        sorenInfo.tap()
        XCTAssertTrue(app.staticTexts["Readiness checklist"].waitForExistence(timeout: 4))
        XCTAssertTrue(reveal(app.staticTexts["Birth time"], maxSwipes: 4))
        app.buttons["Done"].tap()
    }

    func testExpertAstrologersIntakePersistsUserSuppliedFields() throws {
        launchSeededApp(arguments: ["-SimastryPreviewScreen", "astrologists"])

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 10))
        app.buttons["expertAstrologers.chip.Love"].tap()

        let mateoInfo = app.buttons["expertAstrologers.info.mateo-vedic"]
        XCTAssertTrue(reveal(mateoInfo, maxSwipes: 4), "Expected Mateo info button")
        mateoInfo.tap()

        XCTAssertTrue(app.staticTexts["Readiness checklist"].waitForExistence(timeout: 4))
        let addMissing = app.buttons["expertAstrologers.readiness.addMissing"]
        XCTAssertTrue(reveal(addMissing, maxSwipes: 4), "Expected missing-info CTA")
        addMissing.tap()
        XCTAssertTrue(app.navigationBars["Add Missing Info"].waitForExistence(timeout: 4))

        // The partner section exposes a dedicated "don't know their birth time"
        // toggle that mirrors the user's, populating partner_birth_time_unknown.
        let partnerUnknownTime = app.switches["expertAstrologers.addMissingInfo.partnerUnknownTime"]
        XCTAssertTrue(reveal(partnerUnknownTime, maxSwipes: 8), "Expected partner unknown-time toggle")
        partnerUnknownTime.tap()

        // Manual tradition fields are user-supplied and must round-trip locally.
        let nakshatra = element("expertAstrologers.addMissingInfo.field.knownVedicNakshatra")
        XCTAssertTrue(reveal(nakshatra, maxSwipes: 8), "Expected Vedic nakshatra field")
        nakshatra.tap()
        nakshatra.typeText("Rohini")

        app.buttons["Save"].tap()

        // Back on Mateo's profile: the saved nakshatra is now labeled user-supplied.
        XCTAssertTrue(app.staticTexts["Readiness checklist"].waitForExistence(timeout: 4))
        XCTAssertTrue(reveal(app.staticTexts["Vedic nakshatra"], maxSwipes: 8),
                      "Expected the saved nakshatra to appear in the readiness checklist")
        let userSuppliedLabel = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "user-supplied, not app-calculated")
        ).firstMatch
        XCTAssertTrue(reveal(userSuppliedLabel, maxSwipes: 4),
                      "Expected manual tradition fields to be labeled user-supplied")

        // Reopen the intake sheet: the saved value and toggle persisted.
        let reopen = app.buttons["expertAstrologers.readiness.addMissing"]
        XCTAssertTrue(reveal(reopen, maxSwipes: 4), "Expected missing-info CTA to reopen")
        reopen.tap()
        XCTAssertTrue(app.navigationBars["Add Missing Info"].waitForExistence(timeout: 4))

        let reopenedNakshatra = element("expertAstrologers.addMissingInfo.field.knownVedicNakshatra")
        XCTAssertTrue(reveal(reopenedNakshatra, maxSwipes: 8), "Expected nakshatra field on reopen")
        XCTAssertEqual(reopenedNakshatra.value as? String, "Rohini",
                       "Expected the user-supplied nakshatra to persist across sheet open/close")

        let reopenedPartnerUnknown = app.switches["expertAstrologers.addMissingInfo.partnerUnknownTime"]
        XCTAssertTrue(reveal(reopenedPartnerUnknown, maxSwipes: 8), "Expected partner unknown-time toggle on reopen")
        XCTAssertEqual(reopenedPartnerUnknown.value as? String, "1",
                       "Expected partner unknown-time to persist across sheet open/close")
    }

    func testExpertAstrologersChartScreenshotConfirmFlow() throws {
        // Seed an uploaded chart import so the review/confirm flow is reachable
        // without driving the out-of-process system photo picker.
        launchSeededApp(arguments: ["-SimastryPreviewScreen", "astrologists", "-SimastryPreviewSeedChartImport"])

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 10))
        app.buttons["expertAstrologers.chip.Love"].tap()

        let leylaInfo = app.buttons["expertAstrologers.info.leyla-western"]
        XCTAssertTrue(reveal(leylaInfo, maxSwipes: 4), "Expected Leyla info button")
        leylaInfo.tap()

        XCTAssertTrue(app.staticTexts["Readiness checklist"].waitForExistence(timeout: 4))
        let addMissing = app.buttons["expertAstrologers.readiness.addMissing"]
        XCTAssertTrue(reveal(addMissing, maxSwipes: 4), "Expected missing-info CTA")
        addMissing.tap()
        XCTAssertTrue(app.navigationBars["Add Missing Info"].waitForExistence(timeout: 4))

        // The seeded upload renders its status + Review action in the self sheet.
        XCTAssertTrue(reveal(app.staticTexts["Screenshot uploaded"], maxSwipes: 12),
                      "Expected the seeded chart import status in the intake sheet")
        let reviewButton = app.buttons["Review"].firstMatch
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 2), "Expected Review affordance for the seeded chart import")
        reviewButton.tap()

        XCTAssertTrue(app.navigationBars["Confirm Chart"].waitForExistence(timeout: 4))
        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS[c] %@", "user-supplied, not app-calculated")
            ).firstMatch.waitForExistence(timeout: 4),
            "Confirm screen must label values user-supplied, not app-calculated"
        )

        // Confirm a single whitelisted field; this writes to confirmed_data.
        let sunField = element("expertAstrologers.chartConfirm.field.western.sunSign")
        XCTAssertTrue(reveal(sunField, maxSwipes: 6), "Expected the whitelisted Sun-sign confirm field")
        sunField.tap()
        sunField.typeText("Leo")

        // Both the underlying intake sheet and this one expose a nav-bar Save;
        // scope to the Confirm Chart bar to disambiguate.
        app.navigationBars["Confirm Chart"].buttons["Save"].tap()

        // Back on the intake sheet, the import now reads as confirmed.
        XCTAssertTrue(reveal(app.staticTexts["Chart details confirmed"], maxSwipes: 8),
                      "Expected the import to read as confirmed after saving")
    }

    func testCompareAllFiveStartsEveryoneModeFromTalk() throws {
        launchSeededApp(environment: ["SIMASTRY_EXPERT_PREVIEW_DELAY_MS": "1800"])

        XCTAssertTrue(app.tabBars.buttons["Talk"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Talk"].tap()

        let compare = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Compare all five")).firstMatch
        XCTAssertTrue(compare.waitForExistence(timeout: 6))
        compare.tap()

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 6))
        XCTAssertTrue(element("expertAstrologers.response.leyla-western").waitForExistence(timeout: 6))
        XCTAssertTrue(element("expertAstrologers.response.mateo-vedic").waitForExistence(timeout: 6))
        XCTAssertTrue(element("expertAstrologers.response.naomi-chinese").waitForExistence(timeout: 6))
        XCTAssertTrue(element("expertAstrologers.response.elias-ancient").waitForExistence(timeout: 6))
        XCTAssertTrue(element("expertAstrologers.response.nadia-evolutionary").waitForExistence(timeout: 6))
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
        XCTAssertTrue(app.buttons["people.addPerson.importContactsButton"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.switches["people.addPerson.openChartUploadToggle"].waitForExistence(timeout: 4))
        app.buttons["people.addPerson.cancelButton"].tap()

        let teamRead = app.buttons["people.teamReadEntryButton"]
        XCTAssertTrue(reveal(teamRead), "Expected People to expose Team Read")
        teamRead.tap()
        XCTAssertTrue(app.otherElements["people.teamReadSheet"].waitForExistence(timeout: 4))
        app.buttons["Done"].tap()

        app.tabBars.buttons["Talk"].tap()

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

    func testAddPersonCanRouteToChartUploadAfterSave() throws {
        launchSeededApp(arguments: ["-SimastryPreviewTab", "1"])

        XCTAssertTrue(app.tabBars.buttons["People"].waitForExistence(timeout: 10))
        app.buttons["people.toolbar.addPersonButton"].tap()
        XCTAssertTrue(app.otherElements["people.addPersonSheet"].waitForExistence(timeout: 4))

        let chartUploadToggle = app.switches["people.addPerson.openChartUploadToggle"]
        XCTAssertTrue(chartUploadToggle.waitForExistence(timeout: 4))
        chartUploadToggle.tap()

        app.buttons["people.addPerson.saveButton"].tap()

        XCTAssertTrue(app.navigationBars["Smoke Person"].waitForExistence(timeout: 6))
        XCTAssertTrue(element("expertAstrologers.chartImport.person").waitForExistence(timeout: 4),
                      "Expected saved person detail to expose chart screenshot upload")
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

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
