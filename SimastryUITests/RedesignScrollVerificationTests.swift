import XCTest

/// Captures the seeded app at successive scroll positions as attachments so
/// the redesigned below-the-fold surfaces can be reviewed from the
/// `.xcresult` bundle.
final class RedesignScrollVerificationTests: XCTestCase {
    @MainActor
    func testScrollHomeForVisualVerification() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-SimastryPreviewSeeded",
            "-SimastryUITestPasteWallet",
            "0x1234567890abcdef1234567890abcdef12345678"
        ]
        app.launch()
        sleep(3)

        attachShot(app, name: "home-1-top")

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "home-2-panel")

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "home-3-metrics")

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "home-4-bottom")
    }

    @MainActor
    func testTodayShowsNadiaGuidePanelAtTop() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded"]
        app.launch()

        XCTAssertTrue(app.staticTexts["YOUR GUIDES"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Nadia"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["View Astrologers. Opens the complete guides directory."].waitForExistence(timeout: 4))
    }

    @MainActor
    func testPeopleAddPersonSheetPresentsFromEmptyState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "peopleEmpty"]
        app.launchEnvironment["SIMASTRY_UI_PREFILL_ADD_PERSON_NAME"] = "Alex"
        app.launch()

        let addPerson = app.buttons["people.empty.addPersonButton"].firstMatch
        XCTAssertTrue(addPerson.waitForExistence(timeout: 4))
        addPerson.tap()

        assertAddPersonSheetPresented(in: app)
    }

    @MainActor
    func testPeopleToolbarAddPersonSheetPresents() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "peopleEmpty"]
        app.launch()

        let addPerson = app.buttons["people.toolbar.addPersonButton"].firstMatch
        XCTAssertTrue(addPerson.waitForExistence(timeout: 4))
        addPerson.tap()

        assertAddPersonSheetPresented(in: app)
    }

    @MainActor
    func testAddPersonControlsSelectSignsAndSave() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "peopleEmpty"]
        app.launch()

        let addPerson = app.buttons["people.toolbar.addPersonButton"].firstMatch
        XCTAssertTrue(addPerson.waitForExistence(timeout: 4))
        addPerson.tap()
        assertAddPersonSheetPresented(in: app)

        let nameField = app.textFields["people.addPerson.nameField"].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 4))
        XCTAssertEqual(nameField.value as? String, "Alex")

        let partner = app.buttons["people.addPerson.option.relationship.partner"].firstMatch
        XCTAssertTrue(partner.waitForExistence(timeout: 4))
        partner.tap()
        assertControlSelected("people.addPerson.option.relationship.partner", in: app)

        let aries = app.descendants(matching: .any)["people.addPerson.option.sun.aries"].firstMatch
        XCTAssertTrue(scrollUntilHittable(aries, in: app, maxScrolls: 8))
        aries.tap()
        assertControlSelected("people.addPerson.option.sun.aries", in: app)

        let cancer = app.descendants(matching: .any)["people.addPerson.option.moon.cancer"].firstMatch
        XCTAssertTrue(scrollUntilHittable(cancer, in: app, maxScrolls: 8))
        cancer.tap()
        assertControlSelected("people.addPerson.option.moon.cancer", in: app)

        let enfpOption = app.descendants(matching: .any)["people.addPerson.option.personality.enfp"].firstMatch
        XCTAssertTrue(scrollUntilHittable(enfpOption, in: app, maxScrolls: 8))
        enfpOption.tap()
        let personalityMenu = app.buttons["people.addPerson.personalityMenu"].firstMatch
        XCTAssertTrue(personalityMenu.waitForExistence(timeout: 2))
        XCTAssertTrue(personalityMenu.label.contains("ENFP"), "Expected personality menu to summarize ENFP after selection, got \(personalityMenu.label)")

        let save = app.buttons["people.addPerson.saveButton"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 4))
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testAuraWalletSettingsButtonsSaveToggleAndRemove() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-SimastryPreviewSeeded",
            "-SimastryUITestPasteWallet",
            "0x1234567890abcdef1234567890abcdef12345678"
        ]
        app.launch()

        let meTab = app.tabBars.buttons["Me"]
        XCTAssertTrue(meTab.waitForExistence(timeout: 4))
        meTab.tap()

        let settings = app.buttons["profile.settingsButton"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 4))
        settings.tap()

        let paste = app.buttons["settings.auraWallet.pasteButton"].firstMatch
        XCTAssertTrue(scrollUntilHittable(paste, in: app, maxScrolls: 6))
        paste.tap()

        let save = app.buttons["settings.auraWallet.saveButton"].firstMatch
        XCTAssertTrue(scrollUntilHittable(save, in: app, maxScrolls: 2))
        XCTAssertTrue(save.isEnabled)
        save.tap()

        let savedWallet = app.staticTexts["Saved wallet"].firstMatch
        XCTAssertTrue(scrollUntilVisible(savedWallet, in: app, maxScrolls: 6))

        let reflect = app.descendants(matching: .any)["settings.auraWallet.reflectToggle"].firstMatch
        XCTAssertTrue(scrollUntilHittable(reflect, in: app, maxScrolls: 4))
        reflect.tap()

        let remove = app.buttons["settings.auraWallet.removeButton"].firstMatch
        XCTAssertTrue(scrollUntilHittable(remove, in: app, maxScrolls: 4))
        remove.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    func testTodayDoesNotShiftSidewaysAfterHorizontalDrag() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded"]
        app.launch()

        let marker = app.staticTexts["YOUR GUIDES"].firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 4))
        let before = marker.frame

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.42))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.42))
        start.press(forDuration: 0.05, thenDragTo: end)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        XCTAssertTrue(marker.exists)
        XCTAssertLessThan(abs(marker.frame.minX - before.minX), 12)
        XCTAssertGreaterThanOrEqual(marker.frame.minX, -1)
    }

    @MainActor
    func testMeTabOpensProfileWithoutCrash() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded"]
        app.launch()

        let meTab = app.tabBars.buttons["Me"]
        XCTAssertTrue(meTab.waitForExistence(timeout: 4))
        meTab.tap()

        XCTAssertTrue(app.staticTexts["About You"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Aura"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Share your Simastry card"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["Dark appearance"].exists)
        XCTAssertFalse(app.staticTexts["Light appearance"].exists)
    }

    @MainActor
    func testMeTabOpensWithPartialProfileWithoutCrash() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "profilePartial"]
        app.launch()

        let meTab = app.tabBars.buttons["Me"]
        XCTAssertTrue(meTab.waitForExistence(timeout: 4))
        meTab.tap()

        XCTAssertTrue(app.staticTexts["Your Stars Await"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testPredictCategoryTapRevealsNextAction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "predict"]
        app.launch()

        let love = app.buttons["Ask about Love timing"].firstMatch
        XCTAssertTrue(love.waitForExistence(timeout: 4))
        love.tap()

        let stickyAction = app.buttons["predict.stickyAction"].firstMatch
        XCTAssertTrue(stickyAction.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Ask the future"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testScrollProfileForMomentsAndInvite() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "moments"]
        app.launch()
        sleep(3)

        attachShot(app, name: "profile-1-top")

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "profile-2")

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "profile-3-moments")

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "profile-4")

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "profile-5-invite")
    }

    @MainActor
    func testScrollPredictForImportAffordance() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "predict"]
        app.launch()
        sleep(4)

        attachShot(app, name: "predict-1-top")

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "predict-2-conversation")

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "predict-3-signs")

        // Select a sign to capture the liquid-glass selected chip state.
        let taurusChip = app.buttons["Choose Taurus as Sun sign"]
        if taurusChip.waitForExistence(timeout: 3) {
            taurusChip.tap()
            sleep(1)
            attachShot(app, name: "predict-3b-sign-selected")
        }

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "predict-4-action-privacy")
    }

    @MainActor
    func testFirstReadAhaFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "firstRead"]
        app.launch()
        sleep(3)

        attachShot(app, name: "first-read-1-prefilled")

        let decodeButton = app.buttons["Decode my first read"].firstMatch
        XCTAssertTrue(decodeButton.waitForExistence(timeout: 3))
        decodeButton.tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["WHAT IT LIKELY MEANS"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["BEST NEXT MOVE"].waitForExistence(timeout: 3))
        attachShot(app, name: "first-read-2-result")

        let continueButton = app.buttons["Save this with my chart"].firstMatch
        if !continueButton.isHittable {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        XCTAssertTrue(continueButton.isHittable)
        continueButton.tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["What should your guides call you?"].waitForExistence(timeout: 3))
        attachShot(app, name: "first-read-3-birth-details")
    }

    @MainActor
    func testFirstReadMemoryCardOpensPanel() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "firstReadHome"]
        app.launch()
        sleep(3)

        XCTAssertTrue(app.staticTexts["YOUR FIRST READ"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Best next move"].waitForExistence(timeout: 3))
        attachShot(app, name: "first-read-home-1-card")

        let continueButton = app.buttons["Continue this with your guides"].firstMatch
        if !continueButton.isHittable {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        XCTAssertTrue(continueButton.isHittable)
        continueButton.tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["Your Panel"].waitForExistence(timeout: 3))
        let seededMessage = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'I saved your first read'")
        ).firstMatch
        XCTAssertTrue(seededMessage.waitForExistence(timeout: 3))
        attachShot(app, name: "first-read-home-2-panel")
    }

    /// Today's Tips row sits one swipe below the fold, after the Predict
    /// hero; the Method course card follows the daily read.
    @MainActor
    func testScrollHomeForTipsRow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded"]
        app.launch()
        sleep(3)

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "home-tips-row")

        app.swipeUp()
        sleep(2)
        attachShot(app, name: "home-course-card")
    }

    /// Couple Read opens from a partner-type person's detail page.
    @MainActor
    func testCoupleReadFromPersonDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "playbook"]
        app.launch()
        sleep(4)

        attachShot(app, name: "person-playbook-career-chips")

        let coupleRead = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Open Couple Read'")
        ).firstMatch
        if !coupleRead.exists {
            app.swipeUp()
            sleep(1)
        }
        if coupleRead.waitForExistence(timeout: 3) {
            coupleRead.tap()
            sleep(2)
        }
        attachShot(app, name: "couple-read")
    }

    /// Mode chips in a 1:1 guide thread; switching to Check-in posts the
    /// one-time non-therapy disclosure.
    @MainActor
    func testGuideModeChipsAndCheckInDisclosure() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewTab", "2"]
        app.launch()
        sleep(4)

        let thread = app.staticTexts["Nadia"].firstMatch
        if thread.waitForExistence(timeout: 4) {
            thread.tap()
            sleep(2)
        }
        attachShot(app, name: "guide-mode-chips")

        let checkIn = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Check-in mode'")
        ).firstMatch
        if checkIn.waitForExistence(timeout: 3) {
            checkIn.tap()
            sleep(2)
        }
        attachShot(app, name: "guide-checkin-disclosure")
    }

    /// Today with the Situation card and Sealed Drafts row, plus the
    /// morning-eyes reread sheet for a released draft.
    @MainActor
    func testSituationCardAndSealedDrafts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "sealedDrafts"]
        app.launch()
        sleep(4)

        app.swipeUp()
        sleep(1)
        app.swipeUp()
        sleep(2)
        attachShot(app, name: "today-situation-and-drafts")

        let released = app.buttons["Unsealed draft, ready to reread"].firstMatch
        if released.waitForExistence(timeout: 3) {
            released.tap()
            sleep(2)
            attachShot(app, name: "sealed-draft-reread")
        }
    }

    /// Decode-a-text result stack (debug preview auto-fills a message).
    @MainActor
    func testDecodeTextResult() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded"]
        app.launch()
        sleep(3)

        app.swipeUp()
        sleep(1)

        let decodeLink = app.buttons["Decode one received text"].firstMatch
        if decodeLink.waitForExistence(timeout: 3) {
            decodeLink.tap()
            sleep(2)
        }
        attachShot(app, name: "decode-top")

        let decodeButton = app.buttons["Decode it"].firstMatch
        if decodeButton.waitForExistence(timeout: 3) {
            decodeButton.tap()
            sleep(2)
        }
        app.swipeUp()
        sleep(1)
        attachShot(app, name: "decode-result")
    }

    /// Simulation Room on the person page: practice chat with the pinned
    /// rehearsal disclosure, plus the persona-tuning chips.
    @MainActor
    func testSimulationRoomAndPracticeChat() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "playbook"]
        app.launch()
        sleep(4)

        attachShot(app, name: "simulation-room")

        let practice = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Practice the conversation'")
        ).firstMatch
        if practice.waitForExistence(timeout: 4) {
            practice.tap()
            sleep(2)
        }
        attachShot(app, name: "practice-chat-empty")

        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 3) {
            field.tap()
            field.typeText("I need to talk about last weekend.")
            app.buttons["Send"].firstMatch.tap()
            sleep(4)
        }
        attachShot(app, name: "practice-chat-reply")
    }

    /// The Instagram flow: featured guide pane → full profile → Message
    /// opens a real DM thread with that guide.
    @MainActor
    func testGuideProfileToMessageFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded"]
        app.launch()
        sleep(3)

        let featured = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Theo, Taurus Guide'")
        ).firstMatch
        if featured.waitForExistence(timeout: 4) {
            featured.tap()
            sleep(2)
        }
        attachShot(app, name: "guide-profile-top")

        app.swipeUp()
        sleep(1)
        attachShot(app, name: "guide-profile-grid")

        app.swipeDown()
        sleep(1)
        let message = app.buttons["Message Theo"].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 3))
        message.tap()
        sleep(3)

        let tuneFeedback = app.buttons["messages.guideFeedback.tune"].firstMatch
        XCTAssertTrue(tuneFeedback.waitForExistence(timeout: 4))
        tuneFeedback.tap()
        XCTAssertTrue(app.buttons["messages.guideFeedback.shorter"].firstMatch.waitForExistence(timeout: 2))
        attachShot(app, name: "guide-dm-thread")
    }

    /// Lesson one of the Method course posted into the panel thread.
    @MainActor
    func testMethodCourseLessonInPanel() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "methodCourse"]
        app.launch()
        sleep(6)

        attachShot(app, name: "method-course-lesson")
    }

    /// Streak now lives at the very bottom of the Me page, above the footer.
    @MainActor
    func testScrollProfileToStreakAtBottom() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "moments"]
        app.launch()
        sleep(3)

        for _ in 0..<9 {
            app.swipeUp()
        }
        sleep(2)
        attachShot(app, name: "profile-bottom-streak")
    }

    /// The Aura share card now leads with the same glyph trio as the main card.
    @MainActor
    func testAuraShareCardUnifiedDesign() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "aura"]
        app.launch()
        sleep(4)

        for _ in 0..<3 {
            app.swipeUp()
        }
        sleep(1)

        let shareButton = app.buttons["Share Aura Card"].firstMatch
        if shareButton.waitForExistence(timeout: 3) {
            shareButton.tap()
            sleep(2)
        }
        attachShot(app, name: "aura-share-card")
    }

    /// Both formats of the consolidated share card, fully untruncated.
    @MainActor
    func testShareCardStoryAndPostFormats() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded", "-SimastryPreviewScreen", "shareCard"]
        app.launch()
        sleep(4)

        XCTAssertTrue(app.staticTexts["Simastry.com"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["How to Talk to a Sagittarius with Libra Rising and Cancer Moon"].waitForExistence(timeout: 4))
        attachShot(app, name: "share-1-story")

        let postSegment = app.buttons["Post"]
        if postSegment.waitForExistence(timeout: 3) {
            postSegment.tap()
            sleep(1)
        }
        attachShot(app, name: "share-2-post")
    }

    @MainActor
    private func assertAddPersonSheetPresented(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let sheet = app.otherElements["people.addPersonSheet"]
        let navigationBar = app.navigationBars["New person"]
        let didPresent = sheet.waitForExistence(timeout: 4) || navigationBar.waitForExistence(timeout: 1)
        XCTAssertTrue(didPresent, "Expected the New person sheet to present.", file: file, line: line)
    }

    @MainActor
    private func assertControlSelected(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 2), "Expected \(identifier) before checking selected state.", file: file, line: line)
        let value = element.value as? String ?? ""
        XCTAssertEqual(value, "selected", "Expected \(identifier) to be selected, got \(value)", file: file, line: line)
    }

    @MainActor
    private func dismissKeyboardIfPresent(in app: XCUIApplication) {
        if app.keyboards.buttons["Done"].waitForExistence(timeout: 1) {
            app.keyboards.buttons["Done"].tap()
        } else if app.keyboards.buttons["Next"].waitForExistence(timeout: 1) {
            app.keyboards.buttons["Next"].tap()
            if app.keyboards.buttons["Done"].waitForExistence(timeout: 1) {
                app.keyboards.buttons["Done"].tap()
            }
        } else if app.keyboards.buttons["Return"].waitForExistence(timeout: 1) {
            app.keyboards.buttons["Return"].tap()
        }
    }

    @MainActor
    private func firstExistingElement(_ elements: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let element = elements.first(where: { $0.exists }) {
                return element
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return elements.first(where: { $0.exists })
    }

    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, maxScrolls: Int) -> Bool {
        if element.waitForExistence(timeout: 1), isComfortablyHittable(element, in: app) {
            return true
        }
        for _ in 0..<maxScrolls {
            smallSwipeUp(in: app)
            if element.waitForExistence(timeout: 1), isComfortablyHittable(element, in: app) {
                return true
            }
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, maxScrolls: Int) -> Bool {
        if element.waitForExistence(timeout: 1), isComfortablyVisible(element, in: app) {
            return true
        }
        for _ in 0..<maxScrolls {
            smallSwipeUp(in: app)
            if element.waitForExistence(timeout: 1), isComfortablyVisible(element, in: app) {
                return true
            }
        }
        return element.exists
    }

    @MainActor
    private func isComfortablyHittable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, element.isHittable else { return false }
        return isComfortablyVisible(element, in: app)
    }

    @MainActor
    private func isComfortablyVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        let topInset: CGFloat = 96
        let bottomInset: CGFloat = 124
        return frame.minY >= topInset && frame.maxY <= app.frame.maxY - bottomInset
    }

    @MainActor
    private func smallSwipeUp(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
        start.press(forDuration: 0.01, thenDragTo: end)
    }

    @MainActor
    private func attachShot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
