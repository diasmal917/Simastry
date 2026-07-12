import SwiftUI
import PhotosUI

private enum CompassSheetDestination: Identifiable {
    case result(PredictionResult)
    case topUp

    var id: String {
        switch self {
        case .result(let result): "result-\(result.id.uuidString)"
        case .topUp: "top-up"
        }
    }
}

/// Consumer-facing Compass. The internal type and `.predict` tab identifier stay
/// unchanged so existing routes, shortcuts, drafts, and history continue to work.
struct SimulateView: View {
    @Bindable var viewModel: AppViewModel
    private let showsTabHeader: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = CompassDraft()
    @State private var selectedPersonID: UUID?
    @State private var targetSunSign: ZodiacSign?
    @State private var targetMoonSign: ZodiacSign?
    @State private var targetRisingSign: ZodiacSign?
    @State private var screenshotPickerItem: PhotosPickerItem?
    @State private var isRecognizingScreenshot = false
    @State private var isGenerating = false
    @State private var history: [PredictionResult] = []
    @State private var activeSheet: CompassSheetDestination?
    @State private var transitReading: DailyTransitReading?
    @State private var submissionCoordinator = PredictionSubmissionCoordinator.shared

    init(viewModel: AppViewModel, showsTabHeader: Bool = false) {
        self.viewModel = viewModel
        self.showsTabHeader = showsTabHeader
    }

    private var trimmedQuestion: String {
        draft.question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filledOptions: [String] {
        draft.options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var timingIsAvailable: Bool { transitReading != nil }

    private var canSubmit: Bool {
        guard !isGenerating, !trimmedQuestion.isEmpty else { return false }
        switch draft.intent {
        case .general, .timing:
            return draft.intent != .timing || timingIsAvailable
        case .conversation:
            return !draft.conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .compareOptions:
            return filledOptions.count >= 2
        }
    }

    private var actionTitle: String {
        switch draft.intent {
        case .general: "Get guidance"
        case .conversation: "Read conversation"
        case .compareOptions: "Compare options"
        case .timing: "Read today’s timing"
        }
    }

    private var submissionHint: String {
        if trimmedQuestion.isEmpty { return "Enter a question first" }
        if draft.intent == .conversation,
           draft.conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Paste the conversation first"
        }
        if draft.intent == .compareOptions, filledOptions.count < 2 {
            return "Enter at least two options first"
        }
        return "Creates one reading"
    }

    private var category: FutureQuestionCategory {
        if draft.intent == .conversation { return .messageOutcome }
        switch draft.topic {
        case .relationships: return draft.intent == .timing ? .loveTiming : .privateQuestion
        case .work: return .careerSuccess
        case .money: return .moneyDirection
        case .family: return .familyPath
        case .personal, .none: return .privateQuestion
        }
    }

    private var pendingCheckIn: PredictionResult? {
        history.first { $0.followUp == nil && $0.isMessageOutcome }
    }

    private var canonicalDailyGuidance: DailyGuidance? {
        guard let specialist = viewModel.dailyNoteSpecialist else { return nil }
        return DailyGuidanceComposer.guidance(
            for: specialist.id,
            sourceName: specialist.characterName,
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SimastrySpacing.lg) {
                if !showsTabHeader {
                    CompassHeader()
                }

                if viewModel.predictFollowUpPending, let pendingCheckIn {
                    CompassPendingCheckInCard(result: pendingCheckIn) {
                        activeSheet = .result(pendingCheckIn)
                    }
                }

                if let canonicalDailyGuidance {
                    CompassDailyGuidanceCard(guidance: canonicalDailyGuidance)
                }

                CompassComposerCard(
                    draft: $draft,
                    timingIsAvailable: timingIsAvailable,
                    selectedPersonID: $selectedPersonID,
                    targetSunSign: $targetSunSign,
                    targetMoonSign: $targetMoonSign,
                    targetRisingSign: $targetRisingSign,
                    people: viewModel.relationshipPeople,
                    screenshotPickerItem: $screenshotPickerItem,
                    isRecognizingScreenshot: isRecognizingScreenshot,
                    isGenerating: isGenerating,
                    canSubmit: canSubmit,
                    onSelectPerson: selectPerson,
                    onSubmit: beginSubmission
                )

                CompassRecentReadingsSection(
                    viewModel: viewModel,
                    readings: Array(history.prefix(3)),
                    onOpen: { activeSheet = .result($0) }
                )

                CompassPrivacyNote()
            }
            .padding(.horizontal, SimastrySpacing.lg)
            .padding(.top, SimastrySpacing.lg)
            .padding(.bottom, SimastrySpacing.tabBarEndClearance)
        }
        .scrollIndicators(.hidden)
        // A swipe after typing should both dismiss the keyboard and expose the
        // single primary CTA, especially on the compact simulator viewport.
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CompassPrimaryAction(
                title: actionTitle,
                isGenerating: isGenerating,
                canSubmit: canSubmit,
                onSubmit: beginSubmission,
                submissionHint: submissionHint
            )
        }
        .background { CelestialBackground() }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsTabHeader {
                AppTabFloatingHeader(viewModel: viewModel)
            }
        }
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case .result(let result):
                SimulationResultView(
                    result: result,
                    userSunSign: viewModel.userSunSign,
                    onSaveFollowUp: { followUp in
                        saveFollowUp(followUp, for: result.id)
                    },
                    onSetHelpfulness: { helpfulness in
                        viewModel.predictionService.setHelpfulness(helpfulness, for: result.id)
                        loadHistory()
                    }
                )
            case .topUp:
                PredictionTopUpView(viewModel: viewModel)
            }
        }
        .task {
            viewModel.loadRelationshipPeople()
            viewModel.todayStore.reloadDailyDecisions()
            loadHistory()
            refreshTransitEvidence()
            applyLegacyDraftIfNeeded()
        }
        .onChange(of: viewModel.predictionDraft?.id) { _, _ in
            applyLegacyDraftIfNeeded()
        }
        .onChange(of: screenshotPickerItem) { _, item in
            guard let item else { return }
            screenshotPickerItem = nil
            importScreenshot(item)
        }
        .onChange(of: draft.intent) { _, intent in
            if intent != .conversation {
                selectedPersonID = nil
            }
        }
    }

    private func selectPerson(_ id: UUID?) {
        selectedPersonID = id
        guard let id, let person = viewModel.relationshipPeople.first(where: { $0.id == id }) else {
            targetSunSign = nil
            targetMoonSign = nil
            targetRisingSign = nil
            return
        }
        targetSunSign = person.sunSign
        targetMoonSign = person.moonSign
        targetRisingSign = person.risingSign
    }

    private func refreshTransitEvidence() {
        switch viewModel.birthChartProvenance {
        case .calculated, .userConfirmed:
            break
        case .previouslySaved, .generalLens:
            transitReading = nil
            return
        }
        transitReading = TransitEngine.dailyReading(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    private func applyLegacyDraftIfNeeded() {
        guard let legacy = viewModel.predictionDraft else { return }

        draft.intent = legacy.category == .messageOutcome ? .conversation : .general
        draft.topic = topic(for: legacy.category)
        draft.question = legacy.question?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? legacy.question ?? ""
            : legacy.category.defaultQuestion
        draft.conversationText = legacy.conversationText ?? ""
        targetSunSign = legacy.targetSunSign
        targetMoonSign = legacy.targetMoonSign
        targetRisingSign = legacy.targetRisingSign

        if let name = legacy.targetName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
           let person = viewModel.relationshipPeople.first(where: {
               $0.displayName.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
           }) {
            selectedPersonID = person.id
        }

        viewModel.predictionDraft = nil
    }

    private func topic(for category: FutureQuestionCategory) -> CompassTopic? {
        switch category {
        case .loveTiming, .commitment, .messageOutcome: .relationships
        case .careerSuccess: .work
        case .moneyDirection: .money
        case .familyPath: .family
        case .privateQuestion: .personal
        }
    }

    private func importScreenshot(_ item: PhotosPickerItem) {
        isRecognizingScreenshot = true
        Task {
            defer { isRecognizingScreenshot = false }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ConversationOCRError.unreadableImage
                }
                let recognized = try await ConversationOCRService.recognizeText(in: data)
                let existing = draft.conversationText.trimmingCharacters(in: .whitespacesAndNewlines)
                draft.conversationText = existing.isEmpty ? recognized : existing + "\n" + recognized
                HapticManager.signConfirmed()
            } catch {
                viewModel.showToast(
                    "Couldn’t read that screenshot",
                    subtitle: error.localizedDescription,
                    isError: true
                )
            }
        }
    }

    private func beginSubmission() {
        guard canSubmit else { return }
        isGenerating = true
        HapticManager.buttonPress()
        Task { await submitReading() }
    }

    @MainActor
    private func submitReading() async {
        let token: PredictionSubmissionToken
        do {
            token = try await submissionCoordinator.acquire(using: viewModel.predictionRateLimiter)
        } catch {
            isGenerating = false
            viewModel.showToast(
                "Compass is already working",
                subtitle: error.localizedDescription,
                isError: true
            )
            return
        }

        let moderationInput = ([draft.question, draft.conversationText, draft.additionalContext] + draft.options)
            .joined(separator: "\n")
        let moderation = ContentModerationService.moderateConversation(moderationInput)
        guard moderation.isAllowed else {
            await submissionCoordinator.cancel(token, using: viewModel.predictionRateLimiter)
            isGenerating = false
            viewModel.showToast(
                "Unable to process",
                subtitle: moderation.reason ?? "Unable to process this content",
                isError: true
            )
            return
        }

        let usesBonusPrediction: Bool
        if viewModel.canUsePrediction() {
            usesBonusPrediction = false
        } else if viewModel.hasBonusPredictions {
            usesBonusPrediction = true
        } else {
            await submissionCoordinator.cancel(token, using: viewModel.predictionRateLimiter)
            isGenerating = false
            activeSheet = .topUp
            return
        }

        let request = PredictionRequest(
            idempotencyKey: token.idempotencyKey,
            mode: .whatWillTheySay,
            category: category,
            intent: draft.intent,
            topic: draft.topic,
            conversationText: draft.conversationText,
            comparisonOptions: filledOptions,
            additionalContext: draft.additionalContext,
            evidence: readingEvidence,
            userSunSign: viewModel.userSunSign,
            userMoonSign: viewModel.userMoonSign,
            userRisingSign: viewModel.userRisingSign,
            targetSunSign: targetSunSign,
            targetMoonSign: targetMoonSign,
            targetRisingSign: targetRisingSign,
            question: trimmedQuestion,
            hypotheticalReply: nil,
            auraSnapshot: viewModel.auraSnapshot?.descriptor
        )

        do {
            let result = try await viewModel.predictionService.generatePrediction(
                request: request,
                tier: viewModel.profile?.tier ?? "free"
            )
            try Task.checkCancellation()

            guard await submissionCoordinator.commit(token, using: viewModel.predictionRateLimiter) else {
                throw PredictionSubmissionError.alreadySubmitting
            }

            if usesBonusPrediction {
                viewModel.bonusPredictions -= 1
            } else {
                await viewModel.consumePrediction()
            }
            StreakManager.shared.recordMeaningfulAction(.readingCompleted)

            isGenerating = false
            HapticManager.soulFlash()
            AnalyticsService.shared.track(.predictionGenerated, key: "intent", value: draft.intent.rawValue)
            ReviewPromptService.shared.recordPositiveAction()
            loadHistory()
            activeSheet = .result(result)
            viewModel.predictFollowUpPending = result.isMessageOutcome
            if result.isMessageOutcome, viewModel.privateNotificationsEnabled {
                viewModel.notificationService.schedulePredictionOutcomeFollowUp()
            }
        } catch {
            await submissionCoordinator.cancel(token, using: viewModel.predictionRateLimiter)
            isGenerating = false
            CrashReporter.log(error, context: "compassSubmit")
            viewModel.showToast(
                "Reading interrupted",
                subtitle: (error as? LocalizedError)?.errorDescription ?? "Try again in a moment.",
                isError: true
            )
        }
    }

    private var readingEvidence: [ReadingEvidence] {
        var items: [ReadingEvidence] = []

        if let transitReading {
            items.append(ReadingEvidence(
                basis: .calculated,
                label: "Current whole-sign transit",
                detail: transitReading.detailLine + " Scope: today only.",
                supportsTiming: true
            ))
        }

        let userPlacements = placementLine(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
        if let userPlacements {
            items.append(ReadingEvidence(
                basis: userChartEvidenceBasis,
                label: userChartEvidenceLabel,
                detail: userPlacements
            ))
        }

        if let targetPlacements = placementLine(
            sun: targetSunSign,
            moon: targetMoonSign,
            rising: targetRisingSign
        ) {
            items.append(ReadingEvidence(
                basis: .userConfirmed,
                label: "Other person’s chart context",
                detail: targetPlacements
            ))
        }

        if items.isEmpty {
            items.append(ReadingEvidence(
                basis: .generalLens,
                label: "Question and supplied context",
                detail: "No birth chart is required for this reading."
            ))
        }
        return items
    }

    private func placementLine(sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) -> String? {
        let parts = [
            sun.map { "\($0.displayName) Sun" },
            moon.map { "\($0.displayName) Moon" },
            rising.map { "\($0.displayName) Rising" }
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private var userChartEvidenceBasis: ReadingEvidenceBasis {
        switch viewModel.birthChartProvenance {
        case .calculated: .calculated
        case .userConfirmed: .userConfirmed
        case .previouslySaved, .generalLens: .generalLens
        }
    }

    private var userChartEvidenceLabel: String {
        switch viewModel.birthChartProvenance {
        case .calculated: "Your calculated chart context"
        case .userConfirmed: "Your confirmed chart context"
        case .previouslySaved: "Previously saved chart context"
        case .generalLens: "General chart lens"
        }
    }

    private func saveFollowUp(_ followUp: ReadingFollowUp, for id: UUID) {
        viewModel.predictionService.setFollowUp(followUp, for: id)
        viewModel.notificationService.cancelPredictionOutcomeFollowUp()
        viewModel.predictFollowUpPending = false
        StreakManager.shared.recordMeaningfulAction(.outcomeCheckIn)
        loadHistory()
    }

    private func loadHistory() {
        history = viewModel.predictionService.loadHistory()
    }
}
