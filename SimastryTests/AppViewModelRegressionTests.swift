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
}

private struct StoredPendingOnboardingChart: Decodable {
    let sunSign: String?
    let moonSign: String?
    let risingSign: String?
}
