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
    @AppStorage(GuidanceStyle.storageKey) private var guidanceStyleRawValue = GuidanceStyle.practical.rawValue
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
    @State private var dayWindows: DayWindowsResult?
    @State private var selectedWindowID: String?
    @State private var canonicalDailyGuidance: DailyGuidance?
    /// D3: the composer is demoted behind `CompassAskYourOwnRow`, collapsed
    /// by default. It expands explicitly (the row's toggle) or automatically
    /// when a legacy `PredictionDraft` needs the full form.
    @State private var isComposerExpanded = false
    /// Drives the one-time dial → strip → bearings stagger — see
    /// `instrumentReveal(_:step:)`. Flips false→true once in the initial
    /// `.task`, mirroring `SimulationResultView`'s `appeared` flag.
    @State private var instrumentAppeared = false

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
        resolveCategory(intent: draft.intent, topic: draft.topic)
    }

    /// The same intent+topic → category mapping `category` applies to the
    /// live draft, exposed so bearings can pick a suggested question before
    /// any draft mutation happens. Bearings deliberately reuse this bank
    /// rather than inventing new copy.
    private func resolveCategory(intent: CompassIntent, topic: CompassTopic?) -> FutureQuestionCategory {
        if intent == .conversation { return .messageOutcome }
        switch topic {
        case .relationships: return intent == .timing ? .loveTiming : .privateQuestion
        case .work: return .careerSuccess
        case .money: return .moneyDirection
        case .family: return .familyPath
        case .personal, .none: return .privateQuestion
        }
    }

    /// Day-of-year, mirroring `DayWindowsEngine`'s own helper — used to pick
    /// bearing question text deterministically from
    /// `FutureQuestionCategory.suggestedQuestions`, the same
    /// `pick(dayOfYear % variants)` idiom `DayWindowCopy` uses.
    private func dayOfYear(for date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    /// A deterministic, day-picked question from the derived category's
    /// suggested-questions bank. `salt` decorrelates bearings that happen to
    /// share a category (a topic bearing and a person chip both resolve to
    /// `.privateQuestion`, for example) so they don't echo identical text.
    /// `questionBank` lets a bearing preview a different category's bank
    /// than the one its `intent`/`topic` actually submits under — the Love
    /// bearing keeps `.general`/`.relationships` (still a private-question
    /// reading), but previews `.loveTiming`'s bank so a love-branded card
    /// shows love-flavored copy instead of the generic private-question one.
    private func bearingQuestion(
        intent: CompassIntent,
        topic: CompassTopic?,
        salt: Int,
        questionBank: FutureQuestionCategory? = nil
    ) -> String {
        let bearingCategory = questionBank ?? resolveCategory(intent: intent, topic: topic)
        let bank = bearingCategory.suggestedQuestions
        guard !bank.isEmpty else { return bearingCategory.defaultQuestion }
        let index = abs(dayOfYear(for: Date()) + salt) % bank.count
        return bank[index]
    }

    /// Deterministic order per the plan: work, love, money, then today's
    /// timing (natal-gated — the same rule as the composer's Timing chip),
    /// then up to two saved-person chips. No new persistence: every bearing
    /// reuses `CompassDraft` and `beginSubmission` exactly as the composer
    /// does, so moderation, the rate limiter, and the credit gate all stay
    /// intact.
    private var compassBearingItems: [CompassBearingItem] {
        let workQuestion = bearingQuestion(intent: .general, topic: .work, salt: 0)
        // Draft intent/topic stay general+relationships (still a
        // private-question reading under the hood) — only the preview text
        // is pulled from the love-specific bank so a heart-tinted card
        // doesn't show the same generic copy a person chip could show.
        let loveQuestion = bearingQuestion(intent: .general, topic: .relationships, salt: 1, questionBank: .loveTiming)
        let moneyQuestion = bearingQuestion(intent: .general, topic: .money, salt: 2)

        var items: [CompassBearingItem] = [
            CompassBearingItem(
                id: "compass.bearing.work",
                title: "Work read",
                question: workQuestion,
                systemImage: "briefcase.fill",
                tokenID: "career",
                action: { runTopicBearing(intent: .general, topic: .work, question: workQuestion) }
            ),
            CompassBearingItem(
                id: "compass.bearing.love",
                title: "Love read",
                question: loveQuestion,
                systemImage: "heart.fill",
                tokenID: "love",
                action: { runTopicBearing(intent: .general, topic: .relationships, question: loveQuestion) }
            ),
            CompassBearingItem(
                id: "compass.bearing.money",
                title: "Money read",
                question: moneyQuestion,
                systemImage: "banknote.fill",
                tokenID: "money",
                action: { runTopicBearing(intent: .general, topic: .money, question: moneyQuestion) }
            )
        ]

        if timingIsAvailable {
            let timingQuestion = bearingQuestion(intent: .timing, topic: nil, salt: 3)
            items.append(CompassBearingItem(
                id: "compass.bearing.timing",
                title: "Today’s timing",
                question: timingQuestion,
                systemImage: "clock.fill",
                tokenID: "personal",
                action: { runTopicBearing(intent: .timing, topic: nil, question: timingQuestion) }
            ))
        }

        for (index, person) in viewModel.relationshipPeople.prefix(2).enumerated() {
            // `.privateQuestion`'s 4-entry bank is also what "Today's
            // timing" (salt 3, topic `nil`) and any other relationship-topic
            // bearing draw from. Salts 8/9 keep every bearing that reads
            // from this bank pairwise non-congruent mod 4 — 8 and 9 each
            // differ from 3 (and from each other), so two person chips (or
            // a person chip and the timing bearing) never land on the same
            // day-picked index and echo identical text. Love is exempt: it
            // now previews `.loveTiming`'s bank instead (see above).
            let question = bearingQuestion(intent: .general, topic: .relationships, salt: 8 + index)
            items.append(CompassBearingItem(
                id: "compass.bearing.person-\(index)",
                title: person.displayName,
                question: question,
                systemImage: "person.crop.circle.fill",
                tokenID: "marriage",
                action: { prefillPersonBearing(person, question: question) }
            ))
        }

        return items
    }

    /// D7: the dial and strip stay free and unlimited; only bearings spend a
    /// credit, through the same gate the composer's primary action uses.
    /// Surfacing the remaining count here means tapping one is never a
    /// surprise — including at zero, where bearings stay tappable and land
    /// on the existing top-up sheet.
    private var bearingCreditCaption: String? {
        guard viewModel.isRevenueCatAvailable, (viewModel.profile?.tier ?? "free") == "free" else { return nil }
        let remaining = viewModel.remainingWeeklyPredictions
        var caption = "\(remaining) reading\(remaining == 1 ? "" : "s") left this week"
        if viewModel.hasBonusPredictions {
            caption += " + \(viewModel.bonusPredictions) bonus"
        }
        return caption
    }

    private var pendingCheckIn: PredictionResult? {
        history.first { $0.followUp == nil && $0.isMessageOutcome }
    }

    /// Re-runs the async guidance composition when the local day or the
    /// chosen specialist changes. Body re-renders at least on every
    /// day-windows recompute, so the key is re-evaluated across midnight.
    private var dailyGuidanceRefreshKey: String {
        "\(DailyGuidance.dateKey(for: Date()))|\(viewModel.dailyNoteSpecialist?.id ?? "none")"
    }

    private func refreshCanonicalDailyGuidance() async {
        guard let specialist = viewModel.dailyNoteSpecialist else {
            canonicalDailyGuidance = nil
            return
        }
        canonicalDailyGuidance = await DailyGuidanceComposer.guidance(
            for: specialist.id,
            sourceName: specialist.characterName,
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    private var selectedWindow: DayWindow? {
        guard let selectedWindowID, let dayWindows else { return nil }
        return dayWindows.windows.first { $0.id == selectedWindowID }
    }

    /// `ScrollViewReader` anchor id for `composerSection` — see the
    /// `isComposerExpanded` `onChange` in `body`.
    private let composerAnchorID = "compass.composer.anchor"

    /// One staggered reveal on first appearance: dial → strip → bearings
    /// row, 50ms steps, opacity + an 8pt y-offset, eased in via
    /// `SimastryMotion.instrumentEnter`. Mirrors `SimulationResultView`'s
    /// `appeared`-flag/step pattern. Reduce Motion drops the stagger and the
    /// offset entirely — every step just crossfades in together.
    private func instrumentReveal(_ view: some View, step: Int) -> some View {
        view
            .opacity(instrumentAppeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (instrumentAppeared ? 0 : 8))
            .animation(
                SimastryMotion.instrumentEnter.delay(reduceMotion ? 0 : Double(step) * 0.05),
                value: instrumentAppeared
            )
    }

    /// The glanceable hero: a Now dial + Today strip driven by a per-minute
    /// `TimelineView`, plus the inline detail card when a window is
    /// selected. Both entry paths (tab + Home push) render this — it is now
    /// the self-identifying header for Compass, superseding `CompassHeader`.
    @ViewBuilder
    private var compassInstrument: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.md) {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: SimastrySpacing.md) {
                    instrumentReveal(CompassNowDial(result: dayWindows, now: context.date), step: 0)
                    instrumentReveal(
                        CompassTodayStrip(result: dayWindows, selection: $selectedWindowID, now: context.date),
                        step: 1
                    )
                }
                .task(id: dayWindowsTaskKey(for: context.date)) {
                    await recomputeDayWindows(now: context.date)
                }
            }

            if let selectedWindow {
                CompassWindowDetailCard(window: selectedWindow) {
                    withAnimation(reduceMotion ? nil : SimastryMotion.instrumentExit) {
                        selectedWindowID = nil
                    }
                }
                // The segment tap that opens/retargets this card already
                // animates under `.segmentSelect` (the segment's own
                // highlight spring); attaching the animation directly to
                // each half of the transition keeps the card's own
                // enter/exit curve independent of that ambient transaction.
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top))
                            .animation(reduceMotion ? nil : SimastryMotion.instrumentEnter),
                        removal: .opacity
                            .animation(reduceMotion ? nil : SimastryMotion.instrumentExit)
                    )
                )
            }
        }
        .onChange(of: dayWindows) { _, newValue in
            guard let selectedWindowID else { return }
            if newValue?.windows.contains(where: { $0.id == selectedWindowID }) != true {
                self.selectedWindowID = nil
            }
        }
    }

    /// D3: the composer, demoted behind a collapsed toggle row. Expanding is
    /// either explicit (`CompassAskYourOwnRow`) or automatic when a legacy
    /// `PredictionDraft` hands off a question that needs the full form
    /// (`applyLegacyDraftIfNeeded`). Bearings never expand it for their own
    /// submission — only person bearings do, since prefilling a person
    /// benefits from letting the user add context before it runs.
    @ViewBuilder
    private var composerSection: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            CompassAskYourOwnRow(isExpanded: isComposerExpanded) {
                withAnimation(reduceMotion ? nil : SimastryMotion.stateChange) {
                    isComposerExpanded.toggle()
                }
            }

            if isComposerExpanded {
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
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SimastrySpacing.lg) {
                    compassInstrument

                    instrumentReveal(
                        CompassBearingsRow(items: compassBearingItems, creditCaption: bearingCreditCaption),
                        step: 2
                    )

                    // Anchored so an expand (toggle or a person bearing) can
                    // scroll the composer to the top of the viewport — see
                    // the `isComposerExpanded` onChange below. Content this
                    // tall can otherwise land partly behind the bottom CTA's
                    // safe-area inset the instant it appears, since that
                    // inset reserves scroll room rather than repositioning
                    // already-laid-out content.
                    composerSection
                        .id(composerAnchorID)

                    if viewModel.predictFollowUpPending, let pendingCheckIn {
                        CompassPendingCheckInCard(result: pendingCheckIn) {
                            activeSheet = .result(pendingCheckIn)
                        }
                    }

                    if let canonicalDailyGuidance {
                        CompassDailyGuidanceCard(guidance: canonicalDailyGuidance)
                    }

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
                // D3: the bottom CTA only makes sense once the composer is open
                // — bearings submit on their own tap and never need it.
                if isComposerExpanded {
                    CompassPrimaryAction(
                        title: actionTitle,
                        isGenerating: isGenerating,
                        canSubmit: canSubmit,
                        onSubmit: beginSubmission,
                        submissionHint: submissionHint
                    )
                }
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
                instrumentAppeared = true
                viewModel.loadRelationshipPeople()
                viewModel.todayStore.reloadDailyDecisions()
                loadHistory()
                await refreshTransitEvidence()
                applyLegacyDraftIfNeeded()
            }
            .task(id: dailyGuidanceRefreshKey) {
                await refreshCanonicalDailyGuidance()
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
            .onChange(of: isComposerExpanded) { _, expanded in
                guard expanded else { return }
                withAnimation(reduceMotion ? nil : SimastryMotion.stateChange) {
                    proxy.scrollTo(composerAnchorID, anchor: .top)
                }
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

    /// Topic and timing bearings: prefill the draft and submit immediately
    /// through the untouched `beginSubmission` gate (moderation, rate
    /// limiter, credit gate, top-up sheet all apply exactly as they do from
    /// the composer). The composer itself stays collapsed — there is
    /// nothing to add context to before a one-tap read fires.
    private func runTopicBearing(intent: CompassIntent, topic: CompassTopic?, question: String) {
        draft.intent = intent
        draft.topic = topic
        draft.question = question
        beginSubmission()
    }

    /// Person bearings: prefill the person, topic, and a starting question,
    /// then expand the composer instead of auto-running — unlike a topic
    /// read, a reading about a specific person benefits from the user
    /// adding context (or swapping the question) before it spends a credit.
    private func prefillPersonBearing(_ person: RelationshipPerson, question: String) {
        selectPerson(person.id)
        draft.intent = .general
        draft.topic = .relationships
        draft.question = question
        withAnimation(reduceMotion ? nil : SimastryMotion.stateChange) {
            isComposerExpanded = true
        }
    }

    private func refreshTransitEvidence() async {
        switch viewModel.birthChartProvenance {
        case .calculated, .userConfirmed:
            break
        case .previouslySaved, .generalLens:
            transitReading = nil
            return
        }
        transitReading = await TransitEngine.dailyReading(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    /// Mirrors `refreshTransitEvidence`'s gate: natal signs only travel to
    /// the day-windows engine (and its all-day context line) once the chart
    /// is calculated or user-confirmed, never for a general-lens/previously
    /// saved chart.
    private var provenanceGatedNatalSigns: (sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) {
        switch viewModel.birthChartProvenance {
        case .calculated, .userConfirmed:
            return (viewModel.userSunSign, viewModel.userMoonSign, viewModel.userRisingSign)
        case .previouslySaved, .generalLens:
            return (nil, nil, nil)
        }
    }

    /// Changes once per local day (midnight rollover) or when the guidance
    /// style changes; `context.date` comes from the minute-driven
    /// `TimelineView` so the day boundary is reliably observed without a
    /// separate timer.
    private func dayWindowsTaskKey(for date: Date) -> String {
        "\(DailyGuidance.dateKey(for: date))|\(guidanceStyleRawValue)"
    }

    @MainActor
    private func recomputeDayWindows(now: Date) async {
        let style = GuidanceStyle(rawValue: guidanceStyleRawValue) ?? .practical
        let gated = provenanceGatedNatalSigns
        let inputs = DayWindowsEngine.Inputs(
            date: now,
            timeZone: .current,
            natalSun: gated.sun,
            natalMoon: gated.moon,
            natalRising: gated.rising,
            style: style
        )
        dayWindows = await DayWindowsEngine.windows(for: inputs)
    }

    private func applyLegacyDraftIfNeeded() {
        guard let legacy = viewModel.predictionDraft else { return }
        // This handoff always carries a specific question (a reply-draft
        // from People, for example) that needs the full form, not a
        // one-tap bearing — auto-expand so the prefilled fields are
        // immediately visible instead of hidden behind the toggle.
        isComposerExpanded = true

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

        // D4: whenever a current window exists, attach it as evidence too —
        // this is natal-independent (moon-first windows work for every
        // user), so readings can echo real clock bounds honestly even when
        // `timingIsAvailable` (the natal-gated composer chip, untouched
        // above) is false.
        if let currentWindow = dayWindows?.window(at: Date()) {
            items.append(currentWindow.readingEvidenceRow)
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
