import XCTest

final class SimastrySmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCrystalLandingPagerReachesFirstRead() throws {
        launchSeededApp(arguments: ["-SimastryPreviewScreen", "landing"])

        let cta = app.buttons["landing.crystal.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "Expected the value-first Compass CTA")
        XCTAssertTrue(app.staticTexts["LIVE BRIEFING"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["landing.crystal.chartCTA"].exists)

        cta.tap()
        let ageConfirmation = app.buttons["ageGate.over13"]
        XCTAssertTrue(ageConfirmation.waitForExistence(timeout: 6), "Expected the age gate before guest guidance")
        ageConfirmation.tap()

        XCTAssertTrue(app.textFields["firstPrediction.question"].waitForExistence(timeout: 6))
        let submit = app.buttons["firstPrediction.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 4))
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        XCTAssertTrue(app.staticTexts["GENERAL LENS"].waitForExistence(timeout: 8))
    }

    func testRehearsalRoomRunsAPracticeTurn() throws {
        launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["Talk"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Talk"].tap()

        let entry = app.buttons["talk.practiceButton"]
        XCTAssertTrue(reveal(entry, maxSwipes: 6), "Expected the Practice row on Talk")
        entry.tap()

        let nameField = app.textFields["rehearsal.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 6))
        nameField.tap()
        nameField.typeText("Dad")

        let goalField = app.textFields["rehearsal.goalField"]
        XCTAssertTrue(goalField.waitForExistence(timeout: 4))
        goalField.tap()
        goalField.typeText("Ask for space without a fight")

        let start = app.buttons["rehearsal.start"]
        XCTAssertTrue(reveal(start, maxSwipes: 3), "Expected the start button")
        start.tap()

        let input = app.textFields["rehearsal.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 6), "Expected the rehearsal composer")
        input.tap()
        input.typeText("Hey — can we talk about the weekend?")
        app.buttons["rehearsal.send"].tap()

        // Debug preview returns the canned partner turn.
        let partnerReply = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "what's going on")
        ).firstMatch
        XCTAssertTrue(partnerReply.waitForExistence(timeout: 8), "Expected the practice partner to reply")
    }

    func testTodayExpertAstrologersOpens() throws {
        launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))

        let openGuideChat = app.buttons["today.openGuideChatButton"]
        XCTAssertTrue(reveal(openGuideChat), "Expected Home to expose Expert Astrologers")
        openGuideChat.tap()

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["What would you like guidance on today?"].waitForExistence(timeout: 4))
    }

    func testTodayScrolledStateStaysClean() throws {
        launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        let todayContent = app.scrollViews.firstMatch
        XCTAssertTrue(todayContent.waitForExistence(timeout: 10))

        todayContent.swipeUp()
        todayContent.swipeUp()

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Home scrolled state"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTodayDailyExpertNoteOpensConsultation() throws {
        launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        let ask = app.buttons["today.expertNoteAskButton"]
        XCTAssertTrue(ask.waitForExistence(timeout: 6), "Expected the daily expert note card at the top of Home")
        ask.tap()

        // The container identifier propagates to child elements whose exact
        // types shift with the view tree, so match by identifier alone.
        let conversation = app.descendants(matching: .any)
            .matching(identifier: "expertAstrologers.conversation.leyla-western")
            .firstMatch
        XCTAssertTrue(
            conversation.waitForExistence(timeout: 8),
            "Expected the note's Ask button to open the chosen expert's consultation"
        )
    }

    func testTodaySaveNoteLandsInJournal() throws {
        launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        let save = app.buttons["today.expertNoteSaveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 6), "Expected the note card's save bookmark")
        save.tap()

        let journalPill = app.buttons["today.journalPill"]
        XCTAssertTrue(reveal(journalPill, maxSwipes: 5), "Expected the Journal pill after saving a line")
        journalPill.tap()

        XCTAssertTrue(app.otherElements["journal.screen"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.otherElements["journal.entry"].firstMatch.waitForExistence(timeout: 4))
    }

    func testPeoplePredictDraftLandsInReplyFlow() throws {
        launchSeededApp(arguments: ["-SimastryPreviewScreen", "playbook"])

        let predictReply = app.buttons["people.detail.predictReplyButton"]
        XCTAssertTrue(predictReply.waitForExistence(timeout: 8))
        predictReply.tap()

        XCTAssertTrue(app.tabBars.buttons["Compass"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["compass.intent.conversation"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.textFields["compass.conversation"].waitForExistence(timeout: 4))
        XCTAssertTrue(reveal(app.buttons["compass.submit"], maxSwipes: 5))
    }

    func testCompassGeneralQuestionWorksWithoutCalculatedChart() throws {
        launchSeededApp()

        let compassTab = app.tabBars.buttons["Compass"]
        XCTAssertTrue(compassTab.waitForExistence(timeout: 10))
        compassTab.tap()

        let question = app.textFields["compass.question"]
        XCTAssertTrue(question.waitForExistence(timeout: 6))
        question.tap()
        question.typeText("How should I handle a difficult conversation tomorrow?")

        app.swipeUp()
        let submit = app.buttons["compass.submit"]
        XCTAssertTrue(reveal(submit, maxSwipes: 5))
        XCTAssertTrue(submit.isEnabled)
        submit.tap()

        XCTAssertTrue(app.navigationBars["Reading"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "TAKEAWAY")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "EVIDENCE")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "confidence")).firstMatch.exists)
    }

    func testCompassProgressivelyRevealsIntentContext() throws {
        launchSeededApp()
        app.tabBars.buttons["Compass"].tap()

        let conversation = app.buttons["compass.intent.conversation"]
        XCTAssertTrue(conversation.waitForExistence(timeout: 8))
        conversation.tap()
        XCTAssertTrue(app.textFields["compass.conversation"].waitForExistence(timeout: 4))

        let compare = app.buttons["compass.intent.compare_options"]
        compare.tap()
        XCTAssertTrue(element("compass.option.1").waitForExistence(timeout: 4))
        XCTAssertTrue(element("compass.option.2").waitForExistence(timeout: 4))

        let timing = app.buttons["compass.intent.timing"]
        XCTAssertTrue(timing.waitForExistence(timeout: 4))
        XCTAssertFalse(timing.isEnabled, "Timing should stay disabled without calculated transit evidence")
    }

    func testCompassShowsGlanceableWindowsWithoutTyping() throws {
        launchSeededApp()

        let compassTab = app.tabBars.buttons["Compass"]
        XCTAssertTrue(compassTab.waitForExistence(timeout: 10))
        compassTab.tap()

        // The Now dial and Today strip must render before any typing — the
        // whole point of the glanceable hero. Windows differ daily, so these
        // assertions are existence-only.
        let dial = element("compass.now")
        XCTAssertTrue(dial.waitForExistence(timeout: 8), "Expected the Now dial to render without typing")
        let timeline = element("compass.timeline")
        XCTAssertTrue(timeline.waitForExistence(timeout: 8), "Expected the Today strip to render without typing")

        // The instrument sits at the very top of the screen, so no scrolling —
        // a swipe would move it AWAY. The strip shows a placeholder until the
        // day-windows engine finishes its first compute, so allow time for
        // the real segments to replace it.
        let firstSegment = app.buttons["compass.timeline.segment.0"]
        XCTAssertTrue(firstSegment.waitForExistence(timeout: 8), "Expected the first timeline segment to appear")
        XCTAssertTrue(firstSegment.isHittable, "Expected the first timeline segment to be tappable without scrolling")
        firstSegment.tap()

        let detail = element("compass.window.detail")
        XCTAssertTrue(detail.waitForExistence(timeout: 6), "Expected the window detail card to appear")
        // Scope to the card: the composer below also mentions "calculated",
        // so an app-wide query would not prove the evidence badge rendered.
        let calculatedLabel = detail.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Calculated"))
            .firstMatch
        XCTAssertTrue(calculatedLabel.waitForExistence(timeout: 4), "Expected the evidence badge to read Calculated")
        XCTAssertFalse(
            detail.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "confidence")).firstMatch.exists,
            "Windows must never surface a confidence claim"
        )

        app.buttons["compass.window.close"].tap()
        XCTAssertTrue(detail.waitForNonExistence(timeout: 5), "Expected the detail card to dismiss on close")
    }

    func testAccountHubPreservesEverySelectedTab() throws {
        launchSeededApp()

        for tabName in ["Home", "Compass", "Talk", "People"] {
            let tab = app.tabBars.buttons[tabName]
            XCTAssertTrue(tab.waitForExistence(timeout: 8))
            tab.tap()

            let profile = app.buttons["app.header.profileButton"]
            XCTAssertTrue(profile.waitForExistence(timeout: 6), "Expected account button on \(tabName)")
            profile.tap()

            XCTAssertTrue(element("accountHub.screen").waitForExistence(timeout: 6))
            XCTAssertTrue(element("accountHub.fullProfile").waitForExistence(timeout: 4))
            XCTAssertTrue(element("accountHub.birthChart").waitForExistence(timeout: 4))

            app.buttons["Close Account Hub"].tap()
            XCTAssertTrue(element("accountHub.screen").waitForNonExistence(timeout: 5))
            XCTAssertTrue(tab.isSelected, "Closing Account should preserve the \(tabName) tab")
            XCTAssertEqual(app.staticTexts["app.header.tabTitle"].label, tabName)
        }
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

        let askExperts = app.buttons["talk.askExpertsButton"]
        XCTAssertTrue(askExperts.waitForExistence(timeout: 6))
        askExperts.tap()

        XCTAssertTrue(app.navigationBars["Expert Astrologers"].waitForExistence(timeout: 6))

        let replyBack = app.buttons["experts.suggestion.replyBack"]
        XCTAssertTrue(replyBack.waitForExistence(timeout: 6), "Expected the reply-back suggestion chip in the intake")
        replyBack.tap()
        app.buttons["expertAstrologers.submitQuestionButton"].tap()

        // Everyone/compare mode is the flow's default next step after Continue.
        XCTAssertTrue(app.staticTexts["Who would you like to hear from?"].waitForExistence(timeout: 4))
        app.buttons["expertAstrologers.everyoneButton"].tap()

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
        XCTAssertTrue(app.buttons["talk.askExpertsButton"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Expert Astrologers"].waitForExistence(timeout: 4))

        // The five retired Talk buttons must not exist on the experts path.
        XCTAssertFalse(app.staticTexts["What should I reply back?"].exists)
        XCTAssertFalse(app.staticTexts["Ask an expert"].exists)
        XCTAssertFalse(app.staticTexts["Compare all five"].exists)
        XCTAssertFalse(app.staticTexts["Your Panel"].exists)
        XCTAssertFalse(app.staticTexts["Ask my guides"].exists)
        XCTAssertFalse(app.staticTexts["Talk to a sign"].exists)
        XCTAssertFalse(app.staticTexts["What should I say?"].exists)

        let practiceButton = app.buttons["talk.practiceButton"]
        XCTAssertTrue(reveal(practiceButton, maxSwipes: 6), "Expected the Practice row at the bottom of the inbox")
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
    }

    func testPeopleSearchExpandFocusesAndCollapseClears() throws {
        launchSeededApp(arguments: ["-SimastryPreviewTab", "1"])

        XCTAssertTrue(app.tabBars.buttons["People"].waitForExistence(timeout: 10))
        app.swipeUp()

        let searchButton = app.buttons["people.toolbar.searchButton"]
        XCTAssertTrue(reveal(searchButton), "Expected the People header search button")
        searchButton.tap()

        let searchField = app.textFields["people.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 4), "Expected the search field to expand")

        // Focus lands a beat after mount (see toggleSearch's asyncAfter), so
        // poll rather than asserting immediately.
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: searchField, handler: nil)
        wait(for: [focused], timeout: 4)

        searchField.typeText("Ar")

        let clearButton = app.buttons["people.search.clearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 4))
        clearButton.tap()
        // XCUITest reports an empty text field's value as its placeholder.
        XCTAssertEqual(searchField.value as? String, "Search people or signs", "Expected the field to be empty after clearing")

        searchButton.tap()
        XCTAssertTrue(searchField.waitForNonExistence(timeout: 4), "Expected the search field to collapse")
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
        launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["People"].waitForExistence(timeout: 10))
        app.tabBars.buttons["People"].tap()

        let discoveryEntry = app.buttons["people.discoveryEntry"]
        XCTAssertTrue(discoveryEntry.waitForExistence(timeout: 6), "Expected People to expose optional discovery")
        discoveryEntry.tap()

        XCTAssertTrue(app.navigationBars["Find others like you"].waitForExistence(timeout: 8))

        let rowan = app.buttons["discovery.profile.rowan.aries"]
        XCTAssertTrue(reveal(rowan, maxSwipes: 4), "Expected Discovery to show Rowan from seeded profiles")
        rowan.tap()

        let chatButton = app.buttons["discovery.profileDetail.startChatButton"]
        XCTAssertTrue(chatButton.waitForExistence(timeout: 5))
        chatButton.tap()

        XCTAssertTrue(app.tabBars.buttons["Talk"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Rowan")).firstMatch.waitForExistence(timeout: 6))
    }

    func testTalkQuickSimulateStartsPracticeChat() throws {
        launchSeededApp()

        let talkTab = app.tabBars.buttons["Talk"]
        XCTAssertTrue(talkTab.waitForExistence(timeout: 10))
        talkTab.tap()

        // Entry point moved to the practice row in Task 4; Task 5 renames the flow.
        let quickSimulate = app.buttons["talk.practiceButton"]
        XCTAssertTrue(reveal(quickSimulate, maxSwipes: 6), "Expected the Practice row at the bottom of the inbox")
        quickSimulate.tap()

        let someoneNew = app.buttons["practice.someoneNewButton"]
        XCTAssertTrue(someoneNew.waitForExistence(timeout: 6))
        someoneNew.tap()

        let nameField = app.textFields["practice.new.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Smoke Persona")

        let startButton = app.buttons["practice.new.startButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 4))
        startButton.tap()

        XCTAssertTrue(app.navigationBars["Practice with Smoke Persona"].waitForExistence(timeout: 8))
    }

    func testHomePracticeTileOpensPracticeHub() throws {
        launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))

        // Task 6 rewired the Explore tile from openQuickSimulate to openPractice.
        let practiceTile = app.buttons["home.shortcut.practice"]
        XCTAssertTrue(reveal(practiceTile, maxSwipes: 6), "Expected the Practice tile in Home's Explore grid")
        practiceTile.tap()

        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 8),
                      "Expected the Practice tile to open the Practice hub")
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
