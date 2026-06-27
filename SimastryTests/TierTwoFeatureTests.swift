import Foundation
import Testing
import UIKit
@testable import Simastry

private actor PromptCapture {
    private var capturedSystem = ""
    private var capturedUser = ""

    func record(system: String, user: String) {
        capturedSystem = system
        capturedUser = user
    }

    func values() -> (system: String, user: String) {
        (capturedSystem, capturedUser)
    }
}

@MainActor
struct TierTwoFeatureTests {
    // MARK: - Conversation OCR

    @Test func ocrRecognizesRenderedConversationTopToBottom() async throws {
        let size = CGSize(width: 900, height: 460)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            ("Are we still on for tonight" as NSString)
                .draw(at: CGPoint(x: 48, y: 90), withAttributes: attributes)
            ("Yes see you at seven" as NSString)
                .draw(at: CGPoint(x: 48, y: 260), withAttributes: attributes)
        }

        let data = try #require(image.jpegData(compressionQuality: 0.92))
        let recognized = try await ConversationOCRService.recognizeText(in: data)
        let lowered = recognized.lowercased()

        #expect(lowered.contains("still on for tonight"))
        #expect(lowered.contains("seven"))

        // Lines come back in conversation order (top of screenshot first).
        if let first = lowered.range(of: "tonight"), let second = lowered.range(of: "seven") {
            #expect(first.lowerBound < second.lowerBound)
        }
    }

    // MARK: - Transit Engine

    @Test func wholeSignAspectClassification() {
        #expect(WholeSignAspect.between(.aries, .aries) == .conjunction)
        #expect(WholeSignAspect.between(.aries, .gemini) == .sextile)
        #expect(WholeSignAspect.between(.aries, .cancer) == .square)
        #expect(WholeSignAspect.between(.aries, .leo) == .trine)
        #expect(WholeSignAspect.between(.aries, .libra) == .opposition)
        #expect(WholeSignAspect.between(.aries, .taurus) == nil)
        #expect(WholeSignAspect.between(.aries, .virgo) == nil)
        // Symmetry and wrap-around.
        #expect(WholeSignAspect.between(.pisces, .aries) == nil)
        #expect(WholeSignAspect.between(.capricorn, .aries) == .square)
        #expect(WholeSignAspect.between(.sagittarius, .aries) == .trine)
    }

    @Test func transitingSunMatchesZodiacSeason() {
        // 2020-01-01 12:00 UTC — the Sun was in Capricorn.
        var components = DateComponents()
        components.year = 2020
        components.month = 1
        components.day = 1
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            Issue.record("Failed to build test date")
            return
        }

        BirthChartService.setup()
        #expect(TransitEngine.transitingSign(of: .sun, on: date) == .capricorn)
    }

    @Test func dailyReadingIsDeterministicAndRespectsMissingChart() {
        BirthChartService.setup()
        let date = Date()

        let first = TransitEngine.dailyReading(sun: .sagittarius, moon: .cancer, rising: .libra, on: date)
        let second = TransitEngine.dailyReading(sun: .sagittarius, moon: .cancer, rising: .libra, on: date)
        #expect(first == second)

        if let reading = first {
            #expect(!reading.guidance.isEmpty)
            #expect(!reading.headline.isEmpty)
        }

        #expect(TransitEngine.dailyReading(sun: nil, moon: nil, rising: nil, on: date) == nil)
    }

    // MARK: - Aura Snapshot

    @Test func auraSnapshotExtractsPaletteLocallyFromSyntheticImage() throws {
        let image = solidImage(color: UIColor(red: 0.10, green: 0.18, blue: 0.90, alpha: 1))
        let service = AuraSnapshotService()
        let descriptor = try #require(service.descriptor(from: image, mood: .focused, date: Date(timeIntervalSince1970: 10)))

        #expect(descriptor.auraColor == "blue")
        #expect(descriptor.imageWarmth == .cool)
        #expect(descriptor.selectedMood == .focused)
        #expect(!descriptor.compactSummary.contains("base64"))
        #expect(!descriptor.compactSummary.localizedCaseInsensitiveContains("embedding"))
    }

    @Test func auraSnapshotStorePersistsDescriptorsOnlyAndExpiresToday() throws {
        let suiteName = "AuraSnapshotStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let morning = Date(timeIntervalSince1970: 1_700_000_000)
        let descriptor = AuraSnapshotDescriptor(
            auraColor: "violet",
            imageWarmth: .cool,
            brightness: .balanced,
            contrast: .crisp,
            selectedMood: .romantic,
            createdAt: morning
        )
        let snapshot = AuraSnapshot(
            descriptor: descriptor,
            result: AuraSnapshotResult(
                todayVibe: "Violet and romantic.",
                bestMove: "Keep it soft.",
                wearEatFocus: "Wear violet.",
                textingHint: "Send the sweet line.",
                predictionTuningNote: "Tune toward romance."
            )
        )

        let sameDayStore = AuraSnapshotStore(defaults: defaults, calendar: calendar, now: { morning.addingTimeInterval(60) })
        sameDayStore.save(snapshot)
        #expect(sameDayStore.load() == snapshot)

        let raw = try #require(defaults.data(forKey: AuraSnapshotStore.defaultsKey))
        let rawString = String(data: raw, encoding: .utf8) ?? ""
        for banned in ["UIImage", "jpeg", "png", "base64", "EXIF", "face", "embedding", "landmark", "template"] {
            #expect(!rawString.localizedCaseInsensitiveContains(banned))
        }

        let tomorrowStore = AuraSnapshotStore(defaults: defaults, calendar: calendar, now: { morning.addingTimeInterval(90_000) })
        #expect(tomorrowStore.load() == nil)
        #expect(defaults.data(forKey: AuraSnapshotStore.defaultsKey) == nil)
    }

    @Test func auraSnapshotSensitiveRequestsRedirectSafely() {
        let redirect = AuraSnapshotService.sensitiveRedirect(for: "Can this selfie tell my age and if I look attractive?")

        #expect(redirect?.contains("color") == true)
        #expect(redirect?.contains("identity") == true)
        #expect(AuraSnapshotService.sensitiveRedirect(for: "Tune today's colors") == nil)
    }

    @Test func ocrThrowsOnBlankImage() async {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        let blank = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
        guard let data = blank.jpegData(compressionQuality: 0.9) else {
            Issue.record("Failed to encode blank image")
            return
        }

        await #expect(throws: ConversationOCRError.self) {
            _ = try await ConversationOCRService.recognizeText(in: data)
        }
    }

    // MARK: - LLM Channel Prep

    @Test func personaPromptCarriesMethodChartAndHonesty() {
        guard let profile = FactoryCompanionCatalog.all.first(where: { $0.id == "taurus-ada" }) else {
            Issue.record("Expected cast member missing from catalog")
            return
        }

        let prompt = GuideReplyService.personaSystemPrompt(
            profile: profile,
            role: .sun,
            user: .init(name: "Maya", sun: .sagittarius, moon: .cancer, rising: .libra, communicationType: "Diplomatic Explorer"),
            isPanel: true,
            previousGuideName: "Nadia"
        )

        #expect(prompt.contains("Ada"))
        #expect(prompt.contains(ZodiacSign.taurus.methodLine))
        #expect(prompt.contains("Sun in Sagittarius"))
        #expect(prompt.contains("Diplomatic Explorer"))
        #expect(prompt.contains("Nadia"))
        #expect(prompt.contains("Never claim to be human"))
    }

    @Test func threadPromptKeepsRecentMessagesInOrder() {
        let transcript = (1...14).map {
            GuideReplyService.TranscriptEntry(senderName: $0 % 2 == 0 ? "Maya" : "Ada", content: "message \($0)")
        }
        let prompt = GuideReplyService.threadUserPrompt(transcript: transcript, replyingAs: "Ada")

        #expect(!prompt.contains("message 4"))   // trimmed to the last 10
        #expect(prompt.contains("message 5"))
        #expect(prompt.contains("message 14"))
        #expect(prompt.contains("Reply as Ada"))
    }

    @Test func panelGuideRemotePromptRedactsPII() throws {
        let viewModel = AppViewModel()
        viewModel.userSunSign = .sagittarius
        let entry = try #require(viewModel.panelGuideEntries.first)
        viewModel.panelMessages = [
            PanelMessage(
                senderId: PanelParticipant.localUserId,
                content: "Text me at maya@example.com or 555-123-4567, and check https://example.com/@maya.",
                isRead: true
            )
        ]

        let prompt = try #require(viewModel.makePanelReplyPromptForLLM(entry: entry, previousGuideName: nil))

        #expect(prompt.user.contains("Privacy handling:"))
        #expect(prompt.user.contains("[email redacted]"))
        #expect(prompt.user.contains("[phone redacted]"))
        #expect(prompt.user.contains("[link redacted]"))
        #expect(!prompt.user.contains("maya@example.com"))
        #expect(!prompt.user.contains("555-123-4567"))
        #expect(!prompt.user.contains("https://example.com"))
    }

    @Test func companionGuideRemotePromptRedactsPII() throws {
        let viewModel = AppViewModel()
        let guide = FactoryCompanionCatalog.featured
        let threadId = UUID()
        viewModel.companionMessages = [
            CompanionMessage(
                companionId: threadId,
                companionName: guide.name,
                companionSign: guide.sign.rawValue,
                content: "Email me at private@example.com or call +1 (415) 555-0199 @privatehandle.",
                isRead: true,
                source: .companion,
                direction: .outgoing
            )
        ]

        let prompt = try #require(
            viewModel.makeCompanionReplyPromptForLLM(
                companionId: threadId,
                companionName: guide.name,
                companionSign: guide.sign.rawValue
            )
        )

        #expect(prompt.user.contains("Privacy handling:"))
        #expect(prompt.user.contains("[email redacted]"))
        #expect(prompt.user.contains("[phone redacted]"))
        #expect(prompt.user.contains("[handle redacted]"))
        #expect(!prompt.user.contains("private@example.com"))
        #expect(!prompt.user.contains("(415) 555-0199"))
        #expect(!prompt.user.contains("@privatehandle"))
    }

    @Test func withTimeoutReturnsValueThenNilOnSlowOperation() async {
        let fast = await GuideReplyService.withTimeout(seconds: 2) { "ok" }
        #expect(fast == "ok")

        let slow = await GuideReplyService.withTimeout(seconds: 0.2) {
            try await Task.sleep(for: .seconds(5))
            return "late"
        }
        #expect(slow == nil)
    }

    @Test func predictionFallsBackToLocalComposerWhenUnconfigured() async throws {
        let service = makeIsolatedPredictionService()   // no reply channel injected
        defer { service.clearHistory() }

        let request = PredictionRequest(
            mode: .whatWillTheySay,
            conversationText: "hey, are we still on for friday?",
            targetSunSign: .taurus,
            targetMoonSign: .cancer,
            targetRisingSign: nil,
            question: nil,
            hypotheticalReply: nil
        )

        let result = try await service.generatePrediction(request: request, tier: "free")
        #expect(result.isLocalComposition == true)
        #expect(!result.predictedMessage.isEmpty)
        #expect(!result.astrologicalBreakdown.isEmpty)
    }

    @Test func predictionRemoteTimeoutFallsBackToLocalComposer() async throws {
        let service = makeIsolatedPredictionService()
        defer { service.clearHistory() }

        service.isRemoteChannelAvailable = { true }
        service.remotePredictionTimeout = 0.05
        service.replyChannel = { _, _ in
            try await Task.sleep(for: .seconds(5))
            return """
            {"predicted_message":"Late remote answer.","direct_answer":"Late.","timing_window":null,"astrological_breakdown":"Too late.","practical_next_move":null,"safety_note":null,"confidence":70,"tone":"warm"}
            """
        }
        let request = PredictionRequest(
            mode: .whatWillTheySay,
            conversationText: "hey, are we still on for friday?",
            targetSunSign: .taurus,
            targetMoonSign: .cancer,
            targetRisingSign: nil,
            question: nil,
            hypotheticalReply: nil
        )

        let result = try await service.generatePrediction(request: request, tier: "free")

        #expect(result.isLocalComposition == true)
        #expect(result.predictedMessage != "Late remote answer.")
        #expect(!service.loadHistory().isEmpty)
    }

    @Test func futureQuestionCategoriesWorkWithoutConversationPaste() async throws {
        let service = makeIsolatedPredictionService()
        defer { service.clearHistory() }


        for category in FutureQuestionCategory.allCases where category != .messageOutcome {
            let request = PredictionRequest(
                mode: .whatWillTheySay,
                category: category,
                conversationText: "",
                userSunSign: .leo,
                userMoonSign: .taurus,
                userRisingSign: .libra,
                targetSunSign: category.allowsTargetSign ? .sagittarius : nil,
                targetMoonSign: nil,
                targetRisingSign: nil,
                question: category.defaultQuestion,
                hypotheticalReply: nil
            )

            let result = try await service.generatePrediction(request: request, tier: "free")
            #expect(result.categoryOrDefault == category)
            #expect(result.conversationText == nil)
            #expect(!result.displayAnswer.isEmpty)
            #expect(result.timingWindow?.isEmpty == false)
            #expect(result.practicalNextMove?.isEmpty == false)
            #expect(result.confidence <= 78)
        }
    }

    @Test func firstReadTextingPromptUsesLocalFutureFallbackWithoutConversation() async throws {
        let service = makeIsolatedPredictionService()
        defer { service.clearHistory() }

        let request = PredictionRequest(
            mode: .whatWillTheySay,
            category: .loveTiming,
            conversationText: "",
            userSunSign: nil,
            userMoonSign: nil,
            userRisingSign: nil,
            targetSunSign: nil,
            targetMoonSign: nil,
            targetRisingSign: nil,
            question: "Will they text me?",
            hypotheticalReply: nil
        )

        let result = try await service.generatePrediction(request: request, tier: "free")

        #expect(result.isLocalComposition == true)
        #expect(result.conversationText == nil)
        #expect(result.displayAnswer.lowercased().contains("reply"))
        #expect(result.practicalNextMove?.lowercased().contains("message") == true)
    }

    @Test func futureSensitiveCategoriesCarrySafetyNotes() async throws {
        let service = makeIsolatedPredictionService()
        defer { service.clearHistory() }

        let categories: [FutureQuestionCategory] = [.commitment, .familyPath, .moneyDirection, .privateQuestion]

        for category in categories {
            let request = PredictionRequest(
                mode: .whatWillTheySay,
                category: category,
                conversationText: "",
                userSunSign: .cancer,
                userMoonSign: nil,
                userRisingSign: nil,
                targetSunSign: nil,
                targetMoonSign: nil,
                targetRisingSign: nil,
                question: category.defaultQuestion,
                hypotheticalReply: nil
            )

            let result = try await service.generatePrediction(request: request, tier: "free")
            #expect(result.safetyNote?.isEmpty == false)
            #expect(!result.displayAnswer.lowercased().contains("will definitely"))
        }
    }

    @Test func dailyDecisionFallbackCoversEveryCategorySafely() async {
        let service = DailyDecisionService()
        let context = DailyDecisionContext(
            userSunSign: .sagittarius,
            userMoonSign: .cancer,
            userRisingSign: .libra,
            communicationTypeTitle: "Diplomatic Explorer",
            transitHeadline: "Mercury trine your Sun",
            transitGuidance: "Say the clear thing."
        )

        for category in DailyDecisionCategory.allCases {
            let decision = await service.generateDecision(category: category, context: context)
            #expect(decision.category == category)
            #expect(decision.isFallback)
            #expect(!decision.pick.isEmpty)
            #expect(!decision.whyToday.isEmpty)
            #expect(!decision.tinyNextMove.isEmpty)

            if category == .eat {
                #expect(decision.safetyNote?.lowercased().contains("medical") == true)
            }
            if category == .wear {
                #expect(!decision.pick.lowercased().contains("hide"))
            }
        }
    }

    @Test func liveDailyDecisionPromptCarriesCategoryChartAndParsesJson() async {
        let service = DailyDecisionService()
        service.isRemoteChannelAvailable = { true }

        let promptCapture = PromptCapture()
        service.replyChannel = { system, user in
            await promptCapture.record(system: system, user: user)
            return """
            {"pick":"Wear navy with one silver detail.","why_today":"Mercury supports clean choices today, and your Libra rising wants polish without fuss.","tiny_next_move":"Choose the silver detail first.","safety_note":null}
            """
        }

        let decision = await service.generateDecision(
            category: .wear,
            context: DailyDecisionContext(
                userSunSign: .leo,
                userMoonSign: .taurus,
                userRisingSign: .libra,
                communicationTypeTitle: "Magnetic Builder",
                transitHeadline: "Mercury sextile your Rising",
                transitGuidance: "Keep the signal clean."
            )
        )

        #expect(!decision.isFallback)
        #expect(decision.pick == "Wear navy with one silver detail.")
        #expect(decision.tinyNextMove == "Choose the silver detail first.")
        let capturedPrompt = await promptCapture.values()
        #expect(capturedPrompt.system.contains("Daily Decider"))
        #expect(capturedPrompt.system.contains("Do not give medical, diet, weight-loss, allergy, fertility, or nutrition advice."))
        #expect(capturedPrompt.user.contains("Decision category:"))
        #expect(capturedPrompt.user.contains("User chart:"))
        #expect(capturedPrompt.user.contains("Sun in Leo"))
        #expect(capturedPrompt.user.contains("Private message text:\nnot provided"))
    }

    @Test func dailyDecisionParsesFencedJsonWithoutShowingCode() async {
        let service = DailyDecisionService()
        service.isRemoteChannelAvailable = { true }
        service.replyChannel = { _, _ in
            """
            ```json
            {
              "pick": "Wear the clean black sweater.",
              "why_today": "It keeps the signal simple and lets your Libra rising do the polishing.",
              "tiny_next_move": "Put it on before reopening the closet.",
              "safety_note": null
            }
            ```
            """
        }

        let decision = await service.generateDecision(
            category: .wear,
            context: DailyDecisionContext(
                userSunSign: .sagittarius,
                userMoonSign: .cancer,
                userRisingSign: .libra
            )
        )

        #expect(!decision.isFallback)
        #expect(decision.pick == "Wear the clean black sweater.")
        #expect(!decision.pick.contains("```"))
        #expect(!decision.pick.contains("\"pick\""))
    }

    @Test func predictionParsesFencedJsonWithoutShowingCode() async throws {
        let service = makeIsolatedPredictionService()
        service.isRemoteChannelAvailable = { true }
        service.replyChannel = { _, _ in
            """
            Here you go:
            ```json
            {"predicted_message":"Yes, but choose the visible lane.","direct_answer":"Yes, success is likely if you choose the visible lane.","timing_window":"the next quarter","astrological_breakdown":"Leo Sun wants visibility while Taurus Moon needs repeatable structure.","practical_next_move":"Put one useful result in front of a decision maker this week.","safety_note":null,"confidence":69,"tone":"confident"}
            ```
            """
        }

        let request = PredictionRequest(
            mode: .whatWillTheySay,
            category: .careerSuccess,
            conversationText: "",
            userSunSign: .leo,
            userMoonSign: .taurus,
            userRisingSign: nil,
            targetSunSign: nil,
            targetMoonSign: nil,
            targetRisingSign: nil,
            question: "Will I be successful?",
            hypotheticalReply: nil
        )

        let result = try await service.generatePrediction(request: request, tier: "free")
        #expect(result.directAnswer == "Yes, success is likely if you choose the visible lane.")
        #expect(result.predictedMessage == "Yes, but choose the visible lane.")
        #expect(!result.predictedMessage.contains("```"))
    }

    @Test func auraSnapshotTunesDailyDecisionPromptAndFallback() async {
        let descriptor = AuraSnapshotDescriptor(
            auraColor: "gold",
            imageWarmth: .warm,
            brightness: .luminous,
            contrast: .balanced,
            selectedMood: .bold,
            createdAt: Date()
        )
        let context = DailyDecisionContext(
            userSunSign: .leo,
            userMoonSign: nil,
            userRisingSign: nil,
            auraSnapshot: descriptor
        )
        let fallback = await DailyDecisionService().generateDecision(category: .wear, context: context)
        #expect(fallback.whyToday.contains("Aura Snapshot"))
        #expect(fallback.whyToday.contains("gold"))

        let service = DailyDecisionService()
        service.isRemoteChannelAvailable = { true }
        let promptCapture = PromptCapture()
        service.replyChannel = { system, user in
            await promptCapture.record(system: system, user: user)
            return """
            {"pick":"Wear gold with a clean base.","why_today":"The warm palette supports visible confidence.","tiny_next_move":"Choose the gold piece first.","safety_note":null}
            """
        }
        _ = await service.generateDecision(category: .wear, context: context)
        let capturedPrompt = await promptCapture.values()
        #expect(capturedPrompt.user.contains("Aura Snapshot compact descriptors:"))
        #expect(capturedPrompt.user.contains("auraColor: gold"))
        #expect(capturedPrompt.user.contains("selectedMood: bold"))
        for banned in ["raw image", "base64", "EXIF", "face", "embedding", "landmark", "template", "attractiveness", "ethnicity"] {
            #expect(!capturedPrompt.user.localizedCaseInsensitiveContains(banned))
        }
    }

    @Test func dailyDecisionStoreKeepsOnePerCategoryPerDay() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DailyDecisionStore.defaultsKey)
        defer { defaults.removeObject(forKey: DailyDecisionStore.defaultsKey) }

        let store = DailyDecisionStore(defaults: defaults)
        store.save(DailyDecision(category: .wear, pick: "First", whyToday: "Now", tinyNextMove: "Start"))
        store.save(DailyDecision(category: .wear, pick: "Second", whyToday: "Now", tinyNextMove: "Start"))
        store.save(DailyDecision(category: .eat, pick: "Warm", whyToday: "Ground", tinyNextMove: "Choose"))

        let decisions = store.load()
        #expect(decisions.count == 2)
        #expect(decisions.first { $0.category == .wear }?.pick == "Second")
        #expect(store.latestForToday() != nil)
    }

    @Test func remoteFuturePromptCarriesCategoryAndParsesStructuredAnswer() async throws {
        let service = makeIsolatedPredictionService()
        defer { service.clearHistory() }

        service.isRemoteChannelAvailable = { true }
        let promptCapture = PromptCapture()
        service.replyChannel = { system, user in
            await promptCapture.record(system: system, user: user)
            return """
            {"predicted_message":"Career opens through visible proof.","direct_answer":"Yes, success is likely if you choose the visible lane.","timing_window":"the next quarter","astrological_breakdown":"Leo Sun wants visibility while Taurus Moon needs repeatable structure.","practical_next_move":"Put one useful result in front of a decision maker this week.","safety_note":null,"confidence":69,"tone":"confident"}
            """
        }

        let request = PredictionRequest(
            mode: .whatWillTheySay,
            category: .careerSuccess,
            conversationText: "",
            userSunSign: .leo,
            userMoonSign: .taurus,
            userRisingSign: nil,
            targetSunSign: nil,
            targetMoonSign: nil,
            targetRisingSign: nil,
            question: "Will I be successful?",
            hypotheticalReply: nil
        )

        let result = try await service.generatePrediction(request: request, tier: "free")
        let capturedPrompt = await promptCapture.values()
        #expect(capturedPrompt.system.contains("Category: Career success"))
        #expect(capturedPrompt.system.contains("Do not give medical, fertility, legal, investing, tax, or financial advice."))
        #expect(capturedPrompt.user.contains("Prediction category:"))
        #expect(capturedPrompt.user.contains("User chart:"))
        #expect(result.categoryOrDefault == .careerSuccess)
        #expect(result.directAnswer == "Yes, success is likely if you choose the visible lane.")
        #expect(result.timingWindow == "the next quarter")
        #expect(result.practicalNextMove?.contains("decision maker") == true)
        #expect(result.tone == .confident)
    }

    @Test func auraSnapshotTunesFuturePredictionPromptOnlyWithDescriptors() async throws {
        let service = makeIsolatedPredictionService()
        defer { service.clearHistory() }

        service.isRemoteChannelAvailable = { true }
        let promptCapture = PromptCapture()
        service.replyChannel = { system, user in
            await promptCapture.record(system: system, user: user)
            return """
            {"predicted_message":"The next move is clearer after one brave signal.","direct_answer":"Likely yes, but move slowly.","timing_window":"the next honest opening","astrological_breakdown":"Leo Sun likes visible courage while Libra Rising needs grace.","practical_next_move":"Send one clear sentence.","safety_note":null,"confidence":66,"tone":"warm"}
            """
        }

        let request = PredictionRequest(
            mode: .whatWillTheySay,
            category: .privateQuestion,
            conversationText: "",
            userSunSign: .leo,
            userMoonSign: nil,
            userRisingSign: .libra,
            targetSunSign: nil,
            targetMoonSign: nil,
            targetRisingSign: nil,
            question: "What should I do next?",
            hypotheticalReply: nil,
            auraSnapshot: AuraSnapshotDescriptor(
                auraColor: "violet",
                imageWarmth: .cool,
                brightness: .balanced,
                contrast: .soft,
                selectedMood: .overthinking,
                createdAt: Date()
            )
        )

        let result = try await service.generatePrediction(request: request, tier: "free")
        let capturedPrompt = await promptCapture.values()
        #expect(capturedPrompt.user.contains("Aura Snapshot compact descriptors:"))
        #expect(capturedPrompt.user.contains("auraColor: violet"))
        #expect(capturedPrompt.user.contains("imageWarmth: cool"))
        #expect(capturedPrompt.user.contains("selectedMood: overthinking"))
        for banned in ["raw image", "base64", "EXIF", "face", "biometric", "embedding", "landmark", "template", "ethnicity", "attractiveness"] {
            #expect(!capturedPrompt.user.localizedCaseInsensitiveContains(banned))
        }
        #expect(!capturedPrompt.user.localizedCaseInsensitiveContains("age:"))
        #expect(result.practicalNextMove == "Send one clear sentence.")
    }

    @Test func messageOutcomeAuraPromptCarriesImageSafetyRestrictionsOnlyAsDescriptors() async throws {
        let service = makeIsolatedPredictionService()
        defer { service.clearHistory() }

        service.isRemoteChannelAvailable = { true }
        let promptCapture = PromptCapture()
        service.replyChannel = { system, user in
            await promptCapture.record(system: system, user: user)
            return """
            {"predicted_message":"I saw this and want to answer carefully.","direct_answer":"They are likely to reply thoughtfully.","timing_window":"later today","astrological_breakdown":"Taurus Sun slows the pace while Cancer Moon protects the feeling underneath.","practical_next_move":"Send one grounded follow-up only if needed.","safety_note":null,"confidence":68,"tone":"warm"}
            """
        }

        let request = PredictionRequest(
            mode: .whatWillTheySay,
            category: .messageOutcome,
            conversationText: "Me: Are we okay? Them: I need a little time before I answer.",
            userSunSign: .leo,
            userMoonSign: nil,
            userRisingSign: nil,
            targetSunSign: .taurus,
            targetMoonSign: .cancer,
            targetRisingSign: nil,
            question: "What will they say next?",
            hypotheticalReply: nil,
            auraSnapshot: AuraSnapshotDescriptor(
                auraColor: "teal",
                imageWarmth: .cool,
                brightness: .balanced,
                contrast: .crisp,
                selectedMood: .focused,
                createdAt: Date()
            )
        )

        _ = try await service.generatePrediction(request: request, tier: "free")
        let capturedPrompt = await promptCapture.values()

        #expect(capturedPrompt.system.contains("raw image data"))
        #expect(capturedPrompt.system.contains("base64"))
        #expect(capturedPrompt.system.contains("EXIF"))
        #expect(capturedPrompt.system.contains("face landmarks"))
        #expect(capturedPrompt.system.contains("face geometry"))
        #expect(capturedPrompt.system.contains("biometric traits"))
        #expect(capturedPrompt.system.contains("mental-health status"))
        #expect(capturedPrompt.user.contains("Aura Snapshot compact descriptors:"))
        #expect(capturedPrompt.user.contains("auraColor: teal"))
        #expect(capturedPrompt.user.contains("brightness: balanced"))
        #expect(capturedPrompt.user.contains("contrast: crisp"))
        #expect(capturedPrompt.user.contains("selectedMood: focused"))

        for banned in ["raw image", "base64", "EXIF", "embedding", "face", "biometric", "landmark", "geometry", "identity", "ethnicity", "age:", "gender", "attractiveness", "fertility", "health"] {
            #expect(!capturedPrompt.user.localizedCaseInsensitiveContains(banned))
        }
    }

    @Test func predictionFallsBackToLocalComposerWhenRemoteFails() async throws {
        let service = makeIsolatedPredictionService()
        defer { service.clearHistory() }

        service.isRemoteChannelAvailable = { true }
        service.replyChannel = { _, _ in
            throw PredictionServiceError.serverError("offline")
        }
        let request = PredictionRequest(
            mode: .whatWillTheySay,
            conversationText: "hey, are we still on for friday?",
            targetSunSign: .taurus,
            targetMoonSign: .cancer,
            targetRisingSign: nil,
            question: nil,
            hypotheticalReply: nil
        )

        let result = try await service.generatePrediction(request: request, tier: "free")
        #expect(result.isLocalComposition == true)
        #expect(!result.predictedMessage.isEmpty)
        #expect(!result.astrologicalBreakdown.isEmpty)
    }

    @Test func predictionPropagatesRemoteLimitWithoutLocalFallback() async throws {
        let service = makeIsolatedPredictionService()
        defer { service.clearHistory() }

        service.isRemoteChannelAvailable = { true }
        service.replyChannel = { _, _ in
            throw PredictionServiceError.aiUsageLimit("You have reached today's AI guide limit.")
        }
        let request = PredictionRequest(
            mode: .whatWillTheySay,
            conversationText: "hey, are we still on for friday?",
            targetSunSign: .taurus,
            targetMoonSign: .cancer,
            targetRisingSign: nil,
            question: nil,
            hypotheticalReply: nil
        )

        do {
            _ = try await service.generatePrediction(request: request, tier: "free")
            #expect(Bool(false))
        } catch let error as PredictionServiceError {
            #expect(error.errorDescription?.contains("AI guide limit") == true)
            #expect(service.loadHistory().isEmpty)
        } catch {
            #expect(Bool(false))
        }
    }

    @Test func confidenceDisplayTierKeepsNumericConfidenceInternal() {
        #expect(PredictionConfidenceTier.tier(for: 45) == .soft)
        #expect(PredictionConfidenceTier.tier(for: 66) == .moderate)
        #expect(PredictionConfidenceTier.tier(for: 82) == .strong)

        let result = PredictionResult(
            id: UUID(),
            mode: .whatWillTheySay,
            question: "Will they reply?",
            conversationText: nil,
            targetSunSign: .taurus,
            targetMoonSign: nil,
            targetRisingSign: nil,
            predictedMessage: "Likely, but slowly.",
            astrologicalBreakdown: "Taurus pacing is steady.",
            confidence: 66,
            tone: .warm,
            privacySummary: nil,
            createdAt: Date()
        )

        #expect(result.confidence == 66)
        #expect(result.confidenceTier == .moderate)
        #expect(result.confidenceDisplayTier == "Moderate")
        #expect(result.confidenceSignalDisplay == "Signal strength: Moderate")
    }

    @Test func confidenceSignalDisplayReadsAsSignalStrengthNotPercent() {
        func result(confidence: Int) -> PredictionResult {
            PredictionResult(
                id: UUID(),
                mode: .whatWillTheySay,
                question: "Will they reply?",
                conversationText: nil,
                targetSunSign: .taurus,
                targetMoonSign: nil,
                targetRisingSign: nil,
                predictedMessage: "Likely, but slowly.",
                astrologicalBreakdown: "Steady pacing.",
                confidence: confidence,
                tone: .warm,
                privacySummary: nil,
                createdAt: Date()
            )
        }

        #expect(result(confidence: 45).confidenceSignalDisplay == "Signal strength: Soft")
        #expect(result(confidence: 66).confidenceSignalDisplay == "Signal strength: Moderate")
        #expect(result(confidence: 82).confidenceSignalDisplay == "Signal strength: Strong")
        // The visible label never surfaces a false-precision percentage.
        #expect(!result(confidence: 82).confidenceSignalDisplay.contains("%"))
    }

    @Test func companionReplyPayloadEncodesFeatureNames() throws {
        #expect(CompanionReplyFeature.dailyDecision.rawValue == "daily_decision")

        for feature in CompanionReplyFeature.allCases {
            let payload = CompanionReplyPayload(
                kind: CompanionReplyKind.chat.rawValue,
                feature: feature.rawValue,
                system: "system",
                user: "user",
                maxTokens: 123
            )
            let data = try JSONEncoder().encode(payload)
            let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(object["feature"] as? String == feature.rawValue)
        }
    }

    @Test func companionReplyResponseDecodesUsageEventId() throws {
        let usageEventId = UUID()
        let data = try JSONEncoder().encode([
            "text": "Use one short warm line.",
            "usageEventId": usageEventId.uuidString
        ])

        let decoded = try JSONDecoder().decode(CompanionReplyResponse.self, from: data)
        #expect(decoded.text == "Use one short warm line.")
        #expect(decoded.usageEventId == usageEventId)
    }

    private func makeIsolatedPredictionService() -> PredictionService {
        PredictionService(historyKey: "simastry_prediction_history.\(UUID().uuidString)")
    }

    private func solidImage(color: UIColor, size: CGSize = CGSize(width: 120, height: 120)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
