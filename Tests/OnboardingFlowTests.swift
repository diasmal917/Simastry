import XCTest
@testable import Simastry

/// The setup flow's model layer: resume stages, support-style calibration,
/// recommendation gating, and persisted progress round-trips.
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

        XCTAssertEqual(
            progress.resumeStage, .account,
            "Compass clarity is not about a specific person; no person question"
        )
    }

    func testProgressRoundTripsThroughPersistence() {
        var progress = OnboardingProgress()
        progress.goal = .understandSomeone
        progress.supportStyle = .tellMeStraight
        progress.chartDecided = true
        progress.personId = UUID()

        OnboardingProgressStore.save(progress, defaults: defaults)
        let restored = OnboardingProgressStore.load(defaults: defaults)

        XCTAssertEqual(restored, progress, "An interrupted setup must resume with identical state")
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
}
