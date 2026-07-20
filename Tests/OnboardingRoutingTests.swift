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
        let cases: [(OnboardingGoal, AppTab)] = [(.decodeMessage, .today), (.clarityToday, .predict)]

        for (goal, expectedTab) in cases {
            let viewModel = makeReadyViewModel(goal: goal)

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
        viewModel.companionPivotState = CompanionPivotState()
        viewModel.currentScreen = .home
        var progress = OnboardingProgress()
        progress.goal = .decodeMessage
        progress.chartDecided = true
        progress.supportStyle = .tellMeStraight
        viewModel.onboardingProgress = progress

        XCTAssertFalse(
            viewModel.consumeOnboardingFirstTaskIfReady(),
            "No goal routing may happen before the user explicitly chooses a companion"
        )
        guard case .onboarding = viewModel.currentScreen else {
            return XCTFail("A missing exact companion must return to setup")
        }
        XCTAssertEqual(viewModel.onboardingProgress.goal, .decodeMessage, "Incomplete progress must not be cleared")
        XCTAssertEqual(viewModel.onboardingProgress.resumeStage, .companion)
    }

    func testDecodeGoalBumpsDecodeRoute() {
        let viewModel = makeReadyViewModel(goal: .decodeMessage)
        let before = viewModel.decodeRouteRequest

        XCTAssertTrue(viewModel.consumeOnboardingFirstTaskIfReady())
        XCTAssertEqual(viewModel.decodeRouteRequest, before + 1, "Decode must open via its route request")
    }

    func testPersonGoalCarriesThePersonIntoRehearsal() {
        let person = makePerson(name: "Maya", sign: .leo)
        let viewModel = makeReadyViewModel(goal: .prepareConversation, person: person)

        XCTAssertTrue(viewModel.consumeOnboardingFirstTaskIfReady())
        XCTAssertEqual(viewModel.pendingRehearsalPersonId, person.id)
        XCTAssertEqual(viewModel.selectedTab, .messages)
    }

    func testPrepareConversationWithoutPersonOpensTalkWithUsefulDraft() {
        let viewModel = makeReadyViewModel(goal: .prepareConversation)
        let practiceRequest = viewModel.practiceRouteRequest

        XCTAssertTrue(viewModel.consumeOnboardingFirstTaskIfReady())
        XCTAssertEqual(viewModel.selectedTab, .messages)
        XCTAssertEqual(viewModel.practiceRouteRequest, practiceRequest, "No-person setup must not open a dead-end Rehearsal sheet")
        XCTAssertTrue(viewModel.primaryCompanionDraft?.contains("prepare for a conversation") == true)
    }

    func testUnderstandSomeoneWithoutPersonOpensPeopleWithoutAddSheet() {
        let viewModel = makeReadyViewModel(goal: .understandSomeone)
        let addRequest = viewModel.peopleAddPersonRouteRequest

        XCTAssertTrue(viewModel.consumeOnboardingFirstTaskIfReady())
        XCTAssertEqual(viewModel.selectedTab, .people)
        XCTAssertEqual(viewModel.peopleAddPersonRouteRequest, addRequest)
        XCTAssertNil(viewModel.peopleDetailRequestPersonId)
    }

    func testExplicitCompanionIDWinsAfterHydration() {
        let viewModel = AppViewModel()
        viewModel.companionPivotState = CompanionPivotState()
        _ = viewModel.companionPivotState.selectPrimary(.amara, userId: nil)
        var progress = completedProgress(goal: .decodeMessage, companionID: .zev)
        progress.personDecided = true
        viewModel.onboardingProgress = progress

        XCTAssertTrue(viewModel.reconstructOnboardingSelections())
        XCTAssertEqual(viewModel.primaryCompanionRelationship?.companionId, .zev)
        XCTAssertEqual(viewModel.onboardingProgress.companionID, .zev)
    }

    func testLegacyBooleanRecoversOnlyFromActualPrimaryRelationship() {
        let viewModel = AppViewModel()
        viewModel.companionPivotState = CompanionPivotState()
        _ = viewModel.companionPivotState.selectPrimary(.theo, userId: nil)
        var progress = completedProgress(goal: .decodeMessage, companionID: nil)
        progress.companionChosen = true
        viewModel.onboardingProgress = progress

        XCTAssertTrue(viewModel.reconstructOnboardingSelections())
        XCTAssertEqual(viewModel.onboardingProgress.companionID, .theo)
    }

    func testMissingPersonIsReconstructedFromFullPersistedDraft() {
        let person = makePerson(name: "Kai", sign: .scorpio)
        let viewModel = makeReadyViewModel(goal: .understandSomeone)
        viewModel.relationshipPeople = []
        var progress = completedProgress(goal: .understandSomeone, companionID: .amara)
        progress.personId = person.id
        progress.personDraft = person
        progress.personDecided = true
        viewModel.onboardingProgress = progress

        XCTAssertTrue(viewModel.reconstructOnboardingSelections())
        XCTAssertEqual(viewModel.relationshipPeople.first, person)
    }

    func testMissingPersonWithoutDraftReturnsToPersonStepWithoutClearingGoal() {
        let viewModel = makeReadyViewModel(goal: .understandSomeone)
        var progress = completedProgress(goal: .understandSomeone, companionID: .amara)
        progress.personId = UUID()
        progress.personDraft = nil
        progress.personDecided = true
        viewModel.onboardingProgress = progress

        XCTAssertFalse(viewModel.reconstructOnboardingSelections())
        XCTAssertEqual(viewModel.onboardingProgress.goal, .understandSomeone)
        XCTAssertEqual(viewModel.onboardingProgress.resumeStage, .person)
    }

    func testSignUpBackReopensLastEditableDecisionWithoutAccountLoop() {
        let person = makePerson(name: "Noor", sign: .cancer)
        let personFlow = makeReadyViewModel(goal: .prepareConversation, person: person)
        personFlow.currentScreen = .signUp

        personFlow.reopenOnboardingBeforeAccount()

        guard case .onboarding = personFlow.currentScreen else {
            return XCTFail("Back must return to onboarding")
        }
        XCTAssertEqual(personFlow.onboardingProgress.resumeStage, .person)
        XCTAssertEqual(personFlow.onboardingProgress.personDraft, person, "Back preserves the editable draft")

        let compassFlow = makeReadyViewModel(goal: .clarityToday)
        compassFlow.currentScreen = .signUp
        compassFlow.reopenOnboardingBeforeAccount()
        XCTAssertEqual(compassFlow.onboardingProgress.resumeStage, .companion)
        XCTAssertNil(compassFlow.onboardingProgress.companionID)
    }

    func testAnonymousChartSkipClearsOnlyStagedBirthContext() {
        let viewModel = AppViewModel()
        viewModel.isAuthenticated = false
        viewModel.userSunSign = .aries
        viewModel.userMoonSign = .taurus
        viewModel.onboardingBirthday = Date()
        viewModel.onboardingBirthplace = "Bangkok"
        viewModel.onboardingProgress.goal = .clarityToday
        viewModel.beginOnboardingBirthDetails()

        viewModel.skipOnboardingChart()

        XCTAssertNil(viewModel.userSunSign)
        XCTAssertNil(viewModel.userMoonSign)
        XCTAssertNil(viewModel.onboardingBirthday)
        XCTAssertNil(viewModel.onboardingBirthplace)
        XCTAssertTrue(viewModel.onboardingProgress.chartDecided)
        XCTAssertNil(viewModel.onboardingProgress.birthDetailsDraft)
    }

    func testAuthenticatedChartSkipNeverDeletesSavedChartContext() {
        let viewModel = AppViewModel()
        viewModel.isAuthenticated = true
        viewModel.userSunSign = .libra
        viewModel.userMoonSign = .pisces
        viewModel.userRisingSign = .gemini
        viewModel.onboardingBirthday = Date(timeIntervalSince1970: 631_152_000)
        viewModel.onboardingBirthplace = "London"
        viewModel.onboardingProgress.goal = .clarityToday
        viewModel.beginOnboardingBirthDetails()

        viewModel.skipOnboardingChart()

        XCTAssertEqual(viewModel.userSunSign, .libra)
        XCTAssertEqual(viewModel.userMoonSign, .pisces)
        XCTAssertEqual(viewModel.userRisingSign, .gemini)
        XCTAssertEqual(viewModel.onboardingBirthplace, "London")
        XCTAssertTrue(viewModel.onboardingProgress.chartDecided)
    }

    func testBirthDetailsDraftRestoresIntoViewModelStaging() {
        let original = AppViewModel()
        original.onboardingProgress.goal = .clarityToday
        original.stageOnboardingBirthDetails(
            step: 2,
            displayName: "Sam",
            birthday: Date(timeIntervalSince1970: 631_152_000),
            birthTime: Date(timeIntervalSince1970: 631_195_200),
            birthplace: "Seoul",
            precision: .approximate,
            uncertaintyMinutes: 120
        )

        let relaunched = AppViewModel()
        relaunched.onboardingProgress = original.onboardingProgress
        relaunched.restoreOnboardingBirthDetailsForResume()

        XCTAssertEqual(relaunched.onboardingProgress.resumeStage, .birthDetails)
        XCTAssertEqual(relaunched.onboardingDisplayName, "Sam")
        XCTAssertEqual(relaunched.onboardingBirthplace, "Seoul")
        XCTAssertEqual(relaunched.onboardingBirthTimePrecision, .approximate)
        XCTAssertEqual(relaunched.onboardingBirthTimeUncertaintyMinutes, 120)
    }

    private func makeReadyViewModel(
        goal: OnboardingGoal,
        companionID: CompanionPersonaID = .amara,
        person: RelationshipPerson? = nil
    ) -> AppViewModel {
        let viewModel = AppViewModel()
        viewModel.companionPivotState = CompanionPivotState()
        _ = viewModel.companionPivotState.selectPrimary(companionID, userId: nil)
        viewModel.relationshipPeople = person.map { [$0] } ?? []
        viewModel.currentScreen = .home
        var progress = completedProgress(goal: goal, companionID: companionID)
        if goal.involvesAPerson {
            progress.personDecided = true
            progress.personId = person?.id
            progress.personDraft = person
        }
        viewModel.onboardingProgress = progress
        return viewModel
    }

    private func completedProgress(
        goal: OnboardingGoal,
        companionID: CompanionPersonaID?
    ) -> OnboardingProgress {
        var progress = OnboardingProgress()
        progress.goal = goal
        progress.chartDecided = true
        progress.supportStyle = .tellMeStraight
        progress.companionChosen = companionID != nil
        progress.companionID = companionID
        return progress
    }

    private func makePerson(name: String, sign: ZodiacSign) -> RelationshipPerson {
        RelationshipPerson(
            id: UUID(),
            name: name,
            privateLabel: nil,
            relationshipType: .other,
            birthDate: nil,
            birthTime: nil,
            birthPlace: nil,
            sunSign: sign,
            moonSign: nil,
            risingSign: nil,
            notes: nil,
            imageData: nil,
            isChartCalculated: false,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
