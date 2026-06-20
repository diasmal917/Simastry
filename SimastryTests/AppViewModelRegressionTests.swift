import Foundation
import Testing
@testable import Simastry

@MainActor
struct AppViewModelRegressionTests {
    private let pendingChartKey = "simastry_pending_onboarding_chart"

    @Test func betaAccessDoesNotExhaustPredictionQuotaWhenPurchasesAreUnavailable() async {
        let viewModel = AppViewModel()
        var profile = UserProfile.createDefault(id: UUID())
        profile.weeklyPredictionsUsed = 2
        profile.weeklyPredictionsResetDate = Date()
        viewModel.profile = profile

        #expect(viewModel.canUsePrediction())

        await viewModel.consumePrediction()

        #expect(!viewModel.isRevenueCatAvailable)
        #expect(viewModel.profile?.weeklyPredictionsUsed == 2)
        #expect(viewModel.weeklyPredictionLimit == .max)
        #expect(viewModel.remainingWeeklyPredictions == .max)
        #expect(viewModel.canUsePrediction())
    }

    @Test func betaAccessKeepsStalePredictionQuotaFromBlockingUse() async {
        let viewModel = AppViewModel()
        var profile = UserProfile.createDefault(id: UUID())
        profile.weeklyPredictionsUsed = 3
        profile.weeklyPredictionsResetDate = Date(timeIntervalSinceNow: -(8 * 24 * 60 * 60))
        viewModel.profile = profile

        #expect(viewModel.canUsePrediction())
        #expect(viewModel.remainingWeeklyPredictions == .max)

        await viewModel.consumePrediction()

        #expect(viewModel.profile?.weeklyPredictionsUsed == 3)
        #expect(viewModel.remainingWeeklyPredictions == .max)
    }

    @Test func betaAccessDoesNotExhaustDailyMessageQuotaWhenPurchasesAreUnavailable() async {
        let viewModel = AppViewModel()
        var profile = UserProfile.createDefault(id: UUID())
        profile.dailyMessagesUsed = 9
        profile.dailyMessagesResetDate = Date()
        viewModel.profile = profile

        #expect(viewModel.canSendMessage())

        await viewModel.consumeMessage()

        #expect(!viewModel.isRevenueCatAvailable)
        #expect(viewModel.profile?.dailyMessagesUsed == 9)
        #expect(viewModel.dailyMessageLimit == .max)
        #expect(viewModel.remainingDailyMessages == .max)
        #expect(viewModel.canSendMessage())
    }

    @Test func betaAccessKeepsStaleDailyMessageQuotaFromBlockingUse() async {
        let viewModel = AppViewModel()
        var profile = UserProfile.createDefault(id: UUID())
        profile.dailyMessagesUsed = 10
        profile.dailyMessagesResetDate = Date(timeIntervalSinceNow: -(2 * 24 * 60 * 60))
        viewModel.profile = profile

        #expect(viewModel.canSendMessage())
        #expect(viewModel.remainingDailyMessages == .max)

        await viewModel.consumeMessage()

        #expect(viewModel.profile?.dailyMessagesUsed == 10)
        #expect(viewModel.remainingDailyMessages == .max)
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

    @Test func firstReadDraftSavesDismissesAndClears() {
        UserDefaults.standard.removeObject(forKey: FirstReadDraftStore.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: FirstReadDraftStore.defaultsKey) }

        let viewModel = AppViewModel()
        let nextMove = FirstReadBestNextMove(
            type: .clarify,
            summary: "Ask one clean question.",
            timingNote: "One direct reply is enough."
        )
        let draft = FirstReadDraft(
            messageText: "haha yeah maybe, this week is kind of crazy though",
            sign: .taurus,
            tone: .confident,
            likelyMeaning: "A slow, complete reply means they thought about it.",
            notAssume: "No emoji doesn't mean no feeling.",
            suggestedReplies: ["Take your time."],
            bestNextMove: nextMove,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        viewModel.saveFirstReadDraft(draft)
        #expect(viewModel.firstReadDraft == draft)
        #expect(FirstReadDraftStore().load() == draft)
        #expect(FirstReadDraftStore().load()?.bestNextMove == nextMove)

        viewModel.dismissFirstReadDraft()
        #expect(viewModel.firstReadDraft?.isDismissed == true)
        #expect(FirstReadDraftStore().load()?.isDismissed == true)

        viewModel.clearFirstReadDraft()
        #expect(viewModel.firstReadDraft == nil)
        #expect(FirstReadDraftStore().load() == nil)
    }

    @Test func guideFeedbackSavesDedupesClearsAndBuildsPromptSummary() {
        UserDefaults.standard.removeObject(forKey: GuideFeedbackStore.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: GuideFeedbackStore.defaultsKey) }

        let viewModel = AppViewModel()
        let readId = UUID()
        let usageEventId = UUID()

        viewModel.recordGuideFeedback(
            readId: readId,
            aiUsageEventId: usageEventId,
            guideId: "taurus-theo",
            surface: .panelChat,
            helpfulness: .partlyHelpful,
            reasons: [.tooVague]
        )
        #expect(viewModel.guideFeedbackEvents.count == 1)
        #expect(viewModel.guideFeedbackEvents.first?.aiUsageEventId == usageEventId)
        let originalFeedbackId = viewModel.guideFeedbackEvents.first?.id
        #expect(GuideFeedbackStore().load().count == 1)

        viewModel.recordGuideFeedback(
            readId: readId,
            guideId: "taurus-theo",
            surface: .panelChat,
            helpfulness: .notHelpful,
            reasons: [.tooIntense]
        )
        #expect(viewModel.guideFeedbackEvents.count == 1)
        #expect(viewModel.guideFeedbackEvents.first?.id == originalFeedbackId)
        #expect(viewModel.guideFeedbackEvents.first?.aiUsageEventId == usageEventId)
        #expect(viewModel.guideFeedbackEvents.first?.reasons == [.tooIntense])

        let summary = viewModel.guideFeedbackPromptSummary(for: "taurus-theo")
        #expect(summary?.contains("lower the intensity") == true)

        viewModel.clearGuideFeedback()
        #expect(viewModel.guideFeedbackEvents.isEmpty)
        #expect(GuideFeedbackStore().load().isEmpty)
    }

    @Test func guideFeedbackSyncPayloadStoresMetadataOnly() throws {
        let readId = UUID()
        let usageEventId = UUID()
        let feedback = GuideFeedback(
            id: UUID(),
            readId: readId,
            aiUsageEventId: usageEventId,
            guideId: "sagittarius-nadia",
            surface: .panelChat,
            helpfulness: .partlyHelpful,
            reasons: [.tooLong],
            freeformNote: nil,
            createdAt: Date(),
            syncedAt: nil
        )

        let payload = GuideFeedbackSyncPayload(feedback: feedback)
        let data = try JSONEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encoded = String(data: data, encoding: .utf8) ?? ""

        #expect(object["user_id"] == nil)
        #expect(object["p_ai_usage_event_id"] as? String == usageEventId.uuidString)
        #expect(object["p_read_id"] as? String == readId.uuidString)
        #expect(object["p_guide_id"] as? String == "sagittarius-nadia")
        #expect(object["p_surface"] as? String == FeedbackSurface.panelChat.rawValue)
        #expect(object["p_helpfulness"] as? String == HelpfulnessRating.partlyHelpful.rawValue)
        #expect(object["p_reasons"] as? [String] == [GuideFeedbackReason.tooLong.rawValue])
        #expect(!encoded.contains("prompt"))
        #expect(!encoded.contains("reply_text"))
        #expect(!encoded.contains("message_content"))
    }

    @Test func guideFeedbackTuneOptionsMapToPromptHints() {
        let expectedReasons: Set<GuideFeedbackReason> = [
            .tooHarsh,
            .tooSoft,
            .tooLong,
            .tooMystical,
            .notPractical
        ]
        #expect(Set(GuideFeedbackTuneOption.allCases.map(\.feedbackReason)) == expectedReasons)

        let events = GuideFeedbackTuneOption.allCases.map { option in
            GuideFeedback(
                id: UUID(),
                readId: UUID(),
                aiUsageEventId: nil,
                guideId: "sagittarius-nadia",
                surface: .panelChat,
                helpfulness: .partlyHelpful,
                reasons: [option.feedbackReason],
                freeformNote: nil,
                createdAt: Date(),
                syncedAt: nil
            )
        }
        let summary = GuideFeedbackPromptBuilder.promptSummary(from: events, guideId: "sagittarius-nadia")
        #expect(summary?.contains("Recent user feedback") == true)
        #expect(GuideFeedbackTuneOption.lessMystical.feedbackReason.promptHint == "use less astrology jargon")
        #expect(GuideFeedbackTuneOption.morePractical.feedbackReason.promptHint == "make the next step more practical")
        #expect(GuideFeedbackTuneOption.shorter.feedbackReason.promptHint == "keep replies shorter")
    }

    @Test func panelMessageRoundTripsAIUsageEventId() throws {
        let usageEventId = UUID()
        let message = PanelMessage(
            senderId: "sagittarius-nadia",
            content: "Short live reply",
            aiUsageEventId: usageEventId,
            isRead: true
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(PanelMessage.self, from: data)
        #expect(decoded.aiUsageEventId == usageEventId)
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

        #expect(viewModel.selectedTab == .today)
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

        #expect(viewModel.selectedTab == .today)
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

        #expect(viewModel.selectedTab == .today)
        #expect(viewModel.predictionDraft == nil)
        #expect(viewModel.toastMessage?.title == "Missing sign")
    }

    @Test func simulateDeepLinkRoutesToHomeHostedPredict() {
        let viewModel = AppViewModel()
        viewModel.isAuthenticated = true

        viewModel.handleDeepLink(URL(string: "simastry://simulate")!)

        #expect(viewModel.selectedTab == .today)
        #expect(viewModel.predictRouteRequest == 1)
    }

    @Test func legacyGuideDeepLinksDoNotRouteToRemovedTab() {
        let viewModel = AppViewModel()
        viewModel.isAuthenticated = true

        viewModel.handleDeepLink(URL(string: "simastry://guides")!)
        #expect(viewModel.selectedTab == .today)
        #expect(viewModel.guideFocusSign == nil)

        viewModel.handleDeepLink(URL(string: "simastry://guide/sagittarius")!)
        #expect(viewModel.selectedTab == .today)
        #expect(viewModel.guideFocusSign == nil)
    }

    @Test func legacyCompatibilityDeepLinkRoutesToPeopleWorkspace() {
        let viewModel = AppViewModel()
        viewModel.isAuthenticated = true

        viewModel.handleDeepLink(URL(string: "simastry://compatibility/aries/leo")!)

        #expect(viewModel.selectedTab == .people)
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

    @Test func dailyPromptStoreKeepsNewestUniquePrompts() throws {
        let suiteName = "DailyPromptStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DailyPromptStore(defaults: defaults)
        let guideId = FactoryCompanionCatalog.featured.id

        store.save(SavedDailyPrompt(text: "Ask Nadia what timing wants from me.", guideId: guideId, createdAt: Date(timeIntervalSince1970: 1)))
        store.save(SavedDailyPrompt(text: "Notice the soft opening.", guideId: guideId, createdAt: Date(timeIntervalSince1970: 2)))
        store.save(SavedDailyPrompt(text: "Ask Nadia what timing wants from me.", guideId: guideId, createdAt: Date(timeIntervalSince1970: 3)))

        let prompts = store.load()

        #expect(prompts.map(\.text) == [
            "Ask Nadia what timing wants from me.",
            "Notice the soft opening."
        ])
        #expect(prompts.first?.createdAt == Date(timeIntervalSince1970: 3))
    }
}

private struct StoredPendingOnboardingChart: Decodable {
    let sunSign: String?
    let moonSign: String?
    let risingSign: String?
}
