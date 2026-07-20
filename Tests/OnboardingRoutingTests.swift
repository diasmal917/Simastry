import XCTest
@testable import Simastry

@MainActor
final class OnboardingRoutingTests: XCTestCase {
    override func tearDown() {
        OnboardingProgressStore.clear()
        UserDefaults.standard.removeObject(forKey: AppViewModel.firstReadOnboardingIntentDefaultsKey)
        super.tearDown()
    }

    func testAgeConfirmationContinuesToGuestCompass() {
        let viewModel = AppViewModel()

        viewModel.confirmAdultAge(then: .guestCompass)

        XCTAssertTrue(viewModel.isAgeVerified)
        guard case .firstPrediction = viewModel.currentScreen else {
            return XCTFail("Guest Compass must follow the age sheet on the guest path")
        }
    }

    func testAgeConfirmationContinuesToSetupFlow() {
        let viewModel = AppViewModel()

        viewModel.confirmAdultAge(then: .setupFlow)

        XCTAssertTrue(viewModel.isAgeVerified)
        guard case .onboarding = viewModel.currentScreen else {
            return XCTFail("The setup flow must follow the age sheet on the Get Started path")
        }
    }

    func testAgeConfirmationWritesVersionedAttestation() {
        let viewModel = AppViewModel()

        viewModel.confirmAdultAge(then: .setupFlow)

        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: "simastry_age_verification_version"),
            2,
            "The versioned attestation must keep its existing key and version"
        )
    }

    func testGuestChartContinuationEntersFlowWithClarityGoal() {
        let viewModel = AppViewModel()
        viewModel.onboardingProgress = OnboardingProgress()

        viewModel.continueGuestIntoSetupFlow()

        XCTAssertEqual(viewModel.onboardingProgress.goal, .clarityToday)
        guard case .onboarding = viewModel.currentScreen else {
            return XCTFail("The guest chart continuation must enter the setup flow")
        }
        XCTAssertEqual(
            viewModel.onboardingProgress.resumeStage, .chart,
            "The guest already chose today's clarity; the flow resumes at the chart step"
        )
    }

    func testFirstTaskRoutingLandsInsideTheChosenCapability() {
        let cases: [(OnboardingGoal, AppTab)] = [
            (.prepareConversation, .messages),
            (.understandSomeone, .people),
            (.decodeMessage, .today),
            (.clarityToday, .predict),
        ]

        for (goal, expectedTab) in cases {
            let viewModel = AppViewModel()
            viewModel.currentScreen = .home
            var progress = OnboardingProgress()
            progress.goal = goal
            progress.supportStyle = .tellMeStraight
            progress.chartDecided = true
            progress.companionChosen = true
            progress.personDecided = true
            viewModel.onboardingProgress = progress

            XCTAssertTrue(
                viewModel.consumeOnboardingFirstTaskIfReady(),
                "\(goal) must route into a real capability"
            )
            XCTAssertEqual(viewModel.selectedTab, expectedTab, "\(goal) landed on the wrong tab")
            XCTAssertNil(viewModel.onboardingProgress.goal, "Progress must clear after the first task launches")
        }
    }

    func testFirstTaskConsumptionRequiresAnExplicitCompanionChoice() {
        let viewModel = AppViewModel()
        viewModel.currentScreen = .home
        var progress = OnboardingProgress()
        progress.goal = .decodeMessage
        progress.companionChosen = false
        viewModel.onboardingProgress = progress

        XCTAssertFalse(
            viewModel.consumeOnboardingFirstTaskIfReady(),
            "No goal routing may happen before the user explicitly chooses a companion"
        )
    }

    func testDecodeGoalBumpsDecodeRoute() {
        let viewModel = AppViewModel()
        viewModel.currentScreen = .home
        var progress = OnboardingProgress()
        progress.goal = .decodeMessage
        progress.companionChosen = true
        viewModel.onboardingProgress = progress
        let before = viewModel.decodeRouteRequest

        XCTAssertTrue(viewModel.consumeOnboardingFirstTaskIfReady())
        XCTAssertEqual(viewModel.decodeRouteRequest, before + 1, "Decode must open via its route request")
    }

    func testPersonGoalCarriesThePersonIntoRehearsal() {
        let viewModel = AppViewModel()
        viewModel.currentScreen = .home
        let personId = UUID()
        var progress = OnboardingProgress()
        progress.goal = .prepareConversation
        progress.companionChosen = true
        progress.personId = personId
        progress.personDecided = true
        viewModel.onboardingProgress = progress

        XCTAssertTrue(viewModel.consumeOnboardingFirstTaskIfReady())
        XCTAssertEqual(viewModel.pendingRehearsalPersonId, personId)
        XCTAssertEqual(viewModel.selectedTab, .messages)
    }
}
