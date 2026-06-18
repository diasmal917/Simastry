import Foundation
import Testing
@testable import Simastry

@MainActor
struct AppViewModelRegressionTests {
    private let pendingChartKey = "simastry_pending_onboarding_chart"

    @Test func freeTierPredictionQuotaExhaustsAfterThirdUse() async {
        let viewModel = AppViewModel()
        var profile = UserProfile.createDefault(id: UUID())
        profile.weeklyPredictionsUsed = 2
        profile.weeklyPredictionsResetDate = Date()
        viewModel.profile = profile

        #expect(viewModel.canUsePrediction())

        await viewModel.consumePrediction()

        #expect(viewModel.profile?.weeklyPredictionsUsed == 3)
        #expect(viewModel.remainingWeeklyPredictions == 0)
        #expect(!viewModel.canUsePrediction())
    }

    @Test func stalePredictionQuotaResetsBeforeConsumption() async {
        let viewModel = AppViewModel()
        var profile = UserProfile.createDefault(id: UUID())
        profile.weeklyPredictionsUsed = 3
        profile.weeklyPredictionsResetDate = Date(timeIntervalSinceNow: -(8 * 24 * 60 * 60))
        viewModel.profile = profile

        #expect(viewModel.canUsePrediction())
        #expect(viewModel.remainingWeeklyPredictions == 3)

        await viewModel.consumePrediction()

        #expect(viewModel.profile?.weeklyPredictionsUsed == 1)
        #expect(viewModel.remainingWeeklyPredictions == 2)
    }

    @Test func freeTierDailyMessageQuotaExhaustsAfterTenthUse() async {
        let viewModel = AppViewModel()
        var profile = UserProfile.createDefault(id: UUID())
        profile.dailyMessagesUsed = 9
        profile.dailyMessagesResetDate = Date()
        viewModel.profile = profile

        #expect(viewModel.canSendMessage())

        await viewModel.consumeMessage()

        #expect(viewModel.profile?.dailyMessagesUsed == 10)
        #expect(viewModel.remainingDailyMessages == 0)
        #expect(!viewModel.canSendMessage())
    }

    @Test func staleDailyMessageQuotaResetsBeforeConsumption() async {
        let viewModel = AppViewModel()
        var profile = UserProfile.createDefault(id: UUID())
        profile.dailyMessagesUsed = 10
        profile.dailyMessagesResetDate = Date(timeIntervalSinceNow: -(2 * 24 * 60 * 60))
        viewModel.profile = profile

        #expect(viewModel.canSendMessage())
        #expect(viewModel.remainingDailyMessages == 10)

        await viewModel.consumeMessage()

        #expect(viewModel.profile?.dailyMessagesUsed == 1)
        #expect(viewModel.remainingDailyMessages == 9)
    }

    @Test func stagingBirthChartPersistsUntilSignOut() async throws {
        UserDefaults.standard.removeObject(forKey: pendingChartKey)
        defer { UserDefaults.standard.removeObject(forKey: pendingChartKey) }

        let viewModel = AppViewModel()
        let chart = BirthChartService.BirthChart(
            sunSign: .aries,
            moonSign: .cancer,
            risingSign: .leo,
            sunDegree: 10,
            moonDegree: 120,
            risingDegree: 145
        )

        viewModel.stageOnboardingBirthChart(chart)

        #expect(viewModel.userSunSign == .aries)
        #expect(viewModel.userMoonSign == .cancer)
        #expect(viewModel.userRisingSign == .leo)

        let data = try #require(UserDefaults.standard.data(forKey: pendingChartKey))
        let stored = try JSONDecoder().decode(StoredPendingOnboardingChart.self, from: data)

        #expect(stored.sunSign == ZodiacSign.aries.rawValue)
        #expect(stored.moonSign == ZodiacSign.cancer.rawValue)
        #expect(stored.risingSign == ZodiacSign.leo.rawValue)

        await viewModel.signOut()

        #expect(UserDefaults.standard.data(forKey: pendingChartKey) == nil)
    }

    @Test func startPredictionCreatesCompanionDraft() {
        let viewModel = AppViewModel()
        let companion = CompanionData(
            id: UUID(),
            userId: UUID(),
            name: "Seren",
            mode: CompanionMode.soulmate.rawValue,
            sunSign: ZodiacSign.libra.rawValue,
            moonSign: ZodiacSign.cancer.rawValue,
            risingSign: ZodiacSign.aries.rawValue,
            appearanceStyle: nil,
            conversationCount: 0,
            firstConversationAt: nil,
            compatibilityScore: 76,
            companionMemory: nil,
            relationshipLevel: 1,
            createdAt: nil
        )

        viewModel.startPrediction(
            for: companion,
            conversationText: "Seren: I need a little room before I answer."
        )

        #expect(viewModel.selectedTab == 0)
        #expect(viewModel.predictRouteRequest == 1)
        #expect(viewModel.predictionDraft?.targetName == "Seren")
        #expect(viewModel.predictionDraft?.targetSunSign == .libra)
        #expect(viewModel.predictionDraft?.targetMoonSign == .cancer)
        #expect(viewModel.predictionDraft?.targetRisingSign == .aries)
        #expect(viewModel.predictionDraft?.question == "What will Seren say next?")
        #expect(viewModel.predictionDraft?.conversationText == "Seren: I need a little room before I answer.")
    }

    @Test func startPredictionCreatesSignDraft() {
        let viewModel = AppViewModel()

        viewModel.startPrediction(
            for: .sagittarius,
            conversationText: "Nadia: I need air tonight, not a fight."
        )

        #expect(viewModel.selectedTab == 0)
        #expect(viewModel.predictRouteRequest == 1)
        #expect(viewModel.predictionDraft?.targetName == nil)
        #expect(viewModel.predictionDraft?.targetSunSign == .sagittarius)
        #expect(viewModel.predictionDraft?.targetMoonSign == nil)
        #expect(viewModel.predictionDraft?.targetRisingSign == nil)
        #expect(viewModel.predictionDraft?.question == "What would a Sagittarius say next?")
        #expect(viewModel.predictionDraft?.conversationText == "Nadia: I need air tonight, not a fight.")
    }

    @Test func startPredictionRejectsMissingCompanionSign() {
        let viewModel = AppViewModel()
        let companion = CompanionData(
            id: UUID(),
            userId: UUID(),
            name: "Noa",
            mode: CompanionMode.soulmate.rawValue,
            sunSign: "unknown",
            moonSign: ZodiacSign.cancer.rawValue,
            risingSign: ZodiacSign.aries.rawValue,
            appearanceStyle: nil,
            conversationCount: 0,
            firstConversationAt: nil,
            compatibilityScore: 50,
            companionMemory: nil,
            relationshipLevel: 1,
            createdAt: nil
        )

        viewModel.startPrediction(for: companion)

        #expect(viewModel.selectedTab == 0)
        #expect(viewModel.predictionDraft == nil)
        #expect(viewModel.toastMessage?.title == "Missing sign")
    }

    @Test func simulateDeepLinkRoutesToHomeHostedPredict() {
        let viewModel = AppViewModel()
        viewModel.isAuthenticated = true

        viewModel.handleDeepLink(URL(string: "simastry://simulate")!)

        #expect(viewModel.selectedTab == 0)
        #expect(viewModel.predictRouteRequest == 1)
    }

    @Test func legacyGuideDeepLinksDoNotRouteToRemovedTab() {
        let viewModel = AppViewModel()
        viewModel.isAuthenticated = true

        viewModel.handleDeepLink(URL(string: "simastry://guides")!)
        #expect(viewModel.selectedTab == 0)
        #expect(viewModel.guideFocusSign == nil)

        viewModel.handleDeepLink(URL(string: "simastry://guide/sagittarius")!)
        #expect(viewModel.selectedTab == 0)
        #expect(viewModel.guideFocusSign == nil)
    }

    @Test func legacyCompatibilityDeepLinkRoutesToPeopleWorkspace() {
        let viewModel = AppViewModel()
        viewModel.isAuthenticated = true

        viewModel.handleDeepLink(URL(string: "simastry://compatibility/aries/leo")!)

        #expect(viewModel.selectedTab == 1)
        #expect(viewModel.guideFocusSign == nil)
    }

    @Test func clearLocalDeviceDataDoesNotDeleteAccountSession() {
        let viewModel = AppViewModel()
        let profile = UserProfile.createDefault(id: UUID())
        viewModel.isAuthenticated = true
        viewModel.profile = profile
        viewModel.auraWalletPublicAddress = "0x1234567890abcdef1234567890abcdef12345678"
        viewModel.relationshipPeople = RelationshipPeopleStore.previewPeople()

        viewModel.clearLocalDeviceData()

        #expect(viewModel.isAuthenticated)
        #expect(viewModel.profile?.id == profile.id)
        #expect(viewModel.auraWalletPublicAddress.isEmpty)
        #expect(viewModel.relationshipPeople.isEmpty)
        #expect(viewModel.toastMessage?.title == "Local data cleared")
    }
}

private struct StoredPendingOnboardingChart: Decodable {
    let sunSign: String?
    let moonSign: String?
    let risingSign: String?
}
