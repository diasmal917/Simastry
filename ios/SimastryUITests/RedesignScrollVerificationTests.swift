import XCTest

/// Captures the seeded app at successive scroll positions as attachments so
/// the redesigned below-the-fold surfaces can be reviewed from the
/// `.xcresult` bundle.
final class RedesignScrollVerificationTests: XCTestCase {
    @MainActor
    func testScrollHomeForVisualVerification() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-SimastryPreviewSeeded"]
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

        attachShot(app, name: "share-1-story")

        let postSegment = app.buttons["Post"]
        if postSegment.waitForExistence(timeout: 3) {
            postSegment.tap()
            sleep(1)
        }
        attachShot(app, name: "share-2-post")
    }

    @MainActor
    private func attachShot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
