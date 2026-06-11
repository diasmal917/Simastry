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
    }

    @MainActor
    private func attachShot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
