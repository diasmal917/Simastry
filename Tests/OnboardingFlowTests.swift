import XCTest
@testable import Simastry

/// The setup flow's model layer: resume stages, support-style calibration,
/// recommendation gating, and persisted progress round-trips.
@MainActor
final class OnboardingFlowTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "OnboardingFlowTests")
        defaults.removePersistentDomain(forName: "OnboardingFlowTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "OnboardingFlowTests")
        defaults = nil
        super.tearDown()
    }

    // MARK: - Resume stages

    func testResumeStageWalksTheFlowInOrder() {
        var progress = OnboardingProgress()
        XCTAssertEqual(progress.resumeStage, .goal)

        progress.goal = .prepareConversation
        XCTAssertEqual(progress.resumeStage, .chart)

        progress.chartDecided = true
        XCTAssertEqual(progress.resumeStage, .supportStyle)

        progress.supportStyle = .findTheWords
        XCTAssertEqual(progress.resumeStage, .companion)

        progress.companionChosen = true
        XCTAssertEqual(
            progress.resumeStage, .companion,
            "The legacy Boolean alone must never stand in for an exact identity"
        )

        progress.companionID = .amara
        XCTAssertEqual(progress.resumeStage, .person, "Person goals ask who this is about")

        progress.personDecided = true
        XCTAssertEqual(progress.resumeStage, .account)
    }

    func testResumeStageSkipsThePersonQuestionForNonPersonGoals() {
        var progress = OnboardingProgress()
        progress.goal = .clarityToday
        progress.chartDecided = true
        progress.supportStyle = .thinkItThrough
        progress.companionChosen = true
        progress.companionID = .theo

        XCTAssertEqual(
            progress.resumeStage, .account,
            "Compass clarity is not about a specific person; no person question"
        )
    }

    func testProgressRoundTripsThroughPersistence() {
        let person = makePerson(name: "Mina", sign: .virgo)
        let birthday = Date(timeIntervalSince1970: 631_152_000)
        var progress = OnboardingProgress()
        progress.goal = .understandSomeone
        progress.supportStyle = .tellMeStraight
        progress.birthDetailsInProgress = true
        progress.birthDetailsDraft = OnboardingBirthDetailsDraft(
            step: 2,
            displayName: "Alex",
            birthday: birthday,
            birthTime: birthday.addingTimeInterval(43_200),
            birthplace: "Bangkok",
            birthTimePrecision: .approximate,
            approximateUncertaintyMinutes: 60
        )
        progress.companionChosen = true
        progress.companionID = .isolde
        progress.personId = person.id
        progress.personDecided = true
        progress.personDraft = person

        OnboardingProgressStore.save(progress, defaults: defaults)
        let restored = OnboardingProgressStore.load(defaults: defaults)

        XCTAssertEqual(restored, progress, "An interrupted setup must resume with identical state")
    }

    func testPartialBirthDetailsResumeAtExactStep() {
        var progress = OnboardingProgress()
        progress.goal = .clarityToday
        progress.birthDetailsInProgress = true
        progress.birthDetailsDraft = OnboardingBirthDetailsDraft(
            step: 3,
            displayName: "Ari",
            birthday: Date(timeIntervalSince1970: 631_152_000),
            birthTime: Date(timeIntervalSince1970: 631_195_200),
            birthplace: "Lisbon",
            birthTimePrecision: .unknown,
            approximateUncertaintyMinutes: 120
        )

        XCTAssertEqual(progress.resumeStage, .birthDetails)
        OnboardingProgressStore.save(progress, defaults: defaults)
        XCTAssertEqual(OnboardingProgressStore.load(defaults: defaults), progress)
    }

    func testLegacyProgressDecodesWithoutFabricatingCompanionIdentity() throws {
        let legacyJSON = """
        {
          "goal": "decode_message",
          "supportStyle": "tell_me_straight",
          "chartDecided": true,
          "companionChosen": true,
          "personDecided": false
        }
        """.data(using: .utf8)!

        let progress = try JSONDecoder().decode(OnboardingProgress.self, from: legacyJSON)

        XCTAssertTrue(progress.companionChosen)
        XCTAssertNil(progress.companionID)
        XCTAssertNil(progress.birthDetailsDraft)
        XCTAssertEqual(progress.resumeStage, .companion)
    }

    func testChangingGoalResetsEveryLaterDecision() {
        let viewModel = AppViewModel()
        let person = makePerson(name: "Rin", sign: .leo)
        var progress = OnboardingProgress()
        progress.goal = .prepareConversation
        progress.chartDecided = true
        progress.supportStyle = .findTheWords
        progress.companionChosen = true
        progress.companionID = .zev
        progress.personId = person.id
        progress.personDecided = true
        progress.personDraft = person
        viewModel.onboardingProgress = progress

        viewModel.selectOnboardingGoal(.clarityToday)

        XCTAssertEqual(viewModel.onboardingProgress.goal, .clarityToday)
        XCTAssertFalse(viewModel.onboardingProgress.chartDecided)
        XCTAssertNil(viewModel.onboardingProgress.supportStyle)
        XCTAssertNil(viewModel.onboardingProgress.companionID)
        XCTAssertFalse(viewModel.onboardingProgress.personDecided)
        XCTAssertNil(viewModel.onboardingProgress.personDraft)
    }

    func testClearRemovesPersistedProgress() {
        var progress = OnboardingProgress()
        progress.goal = .decodeMessage
        OnboardingProgressStore.save(progress, defaults: defaults)

        OnboardingProgressStore.clear(defaults: defaults)

        XCTAssertEqual(OnboardingProgressStore.load(defaults: defaults), OnboardingProgress())
    }

    // MARK: - Support style calibration

    func testSupportStylesSeedTheExistingCalibrationDimensions() {
        let straight = OnboardingSupportStyle.tellMeStraight.seededPreferences
        XCTAssertEqual(straight.tone, .candid)
        XCTAssertEqual(straight.directness, .direct)
        XCTAssertEqual(straight.length, .concise)

        let think = OnboardingSupportStyle.thinkItThrough.seededPreferences
        XCTAssertEqual(think.tone, .steady)
        XCTAssertEqual(think.directness, .balanced)

        let words = OnboardingSupportStyle.findTheWords.seededPreferences
        XCTAssertEqual(words.tone, .warm)

        for style in OnboardingSupportStyle.allCases {
            XCTAssertTrue(
                style.seededPreferences.topics.isEmpty,
                "Seeded preferences never invent topic interests"
            )
        }
    }

    // MARK: - Recommendations

    func testSupportStyleRecommendationsReturnThreeCertifiedCompanions() {
        for style in OnboardingSupportStyle.allCases {
            let recommended = CompanionPersonaRegistry.recommendations(
                sun: nil, moon: nil, rising: nil, supportStyle: style
            )
            XCTAssertEqual(recommended.count, 3, "Three recommendations, the fourth stays reachable")
            XCTAssertTrue(
                recommended.allSatisfy(\.isPilotCertified),
                "Only pilot-certified companions may be recommended"
            )
        }
    }

    func testSupportStyleBiasSurfacesTheMatchingCompanions() {
        let straight = CompanionPersonaRegistry.recommendations(
            sun: nil, moon: nil, rising: nil, supportStyle: .tellMeStraight
        )
        XCTAssertTrue(straight.prefix(2).contains { $0.id == .amara })
        XCTAssertTrue(straight.prefix(2).contains { $0.id == .theo })

        let words = CompanionPersonaRegistry.recommendations(
            sun: nil, moon: nil, rising: nil, supportStyle: .findTheWords
        )
        XCTAssertTrue(words.prefix(2).contains { $0.id == .isolde })
        XCTAssertTrue(words.prefix(2).contains { $0.id == .zev })
    }

    func testChartPlacementsStillInfluenceStyleBiasedRecommendations() {
        let withChart = CompanionPersonaRegistry.recommendations(
            sun: .aries, moon: .aries, rising: .aries, supportStyle: .findTheWords
        )
        XCTAssertTrue(
            withChart.contains { $0.id == .amara },
            "A strong Aries chart must surface Amara even under a words-first style"
        )
    }

    // MARK: - Presentation copy

    func testEveryCertifiedCompanionHasOnboardingPresentation() {
        for persona in CompanionPersonaRegistry.pilot {
            let presentation = CompanionOnboardingPresentation.presentation(for: persona.id)
            XCTAssertNotNil(presentation, "\(persona.displayName) is missing choice-screen copy")
            XCTAssertFalse(presentation?.anchor.isEmpty ?? true)
            XCTAssertFalse(presentation?.bestWhen.isEmpty ?? true)
            XCTAssertFalse(presentation?.sampleResponse.isEmpty ?? true)
        }
    }

    func testPresentationAnchorsMatchCertifiedPersonalities() {
        XCTAssertEqual(
            CompanionOnboardingPresentation.presentation(for: .amara)?.anchor,
            "Courage, without recklessness."
        )
        XCTAssertEqual(
            CompanionOnboardingPresentation.presentation(for: .theo)?.anchor,
            "Calm clarity, without passivity."
        )
        XCTAssertEqual(
            CompanionOnboardingPresentation.presentation(for: .isolde)?.anchor,
            "Tactful fairness and firm boundaries."
        )
        XCTAssertEqual(
            CompanionOnboardingPresentation.presentation(for: .zev)?.anchor,
            "Emotional translation, without mind-reading."
        )
    }

    // MARK: - Goals

    func testOnlyPersonCenteredGoalsAskWhoThisIsAbout() {
        XCTAssertTrue(OnboardingGoal.prepareConversation.involvesAPerson)
        XCTAssertTrue(OnboardingGoal.understandSomeone.involvesAPerson)
        XCTAssertFalse(OnboardingGoal.decodeMessage.involvesAPerson)
        XCTAssertFalse(OnboardingGoal.clarityToday.involvesAPerson)
    }

    func testGoalCopyAvoidsAstrologyTerminology() {
        let astrologyTerms = ["astrology", "zodiac", "chart", "sign", "horoscope", "star"]
        for goal in OnboardingGoal.allCases {
            let copy = "\(goal.title) \(goal.subtitle)".lowercased()
            for term in astrologyTerms {
                XCTAssertFalse(
                    copy.contains(term),
                    "Goal copy for \(goal) must not use astrology terminology (found \"\(term)\")"
                )
            }
        }
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
