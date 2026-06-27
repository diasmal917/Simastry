import SwiftUI
import Foundation
import PhotosUI

struct SimulateView: View {
    @Bindable var viewModel: AppViewModel

    @State private var conversationText: String = ""
    @State private var questionText: String = ""
    @State private var selectedCategory: FutureQuestionCategory = .messageOutcome
    @State private var screenshotPickerItem: PhotosPickerItem?
    @State private var isRecognizingScreenshot: Bool = false
    @State private var selectedSunSign: ZodiacSign?
    @State private var selectedMoonSign: ZodiacSign?
    @State private var selectedRisingSign: ZodiacSign?
    @State private var isGenerating: Bool = false
    @State private var isRegenerating: Bool = false
    @State private var progressPhaseIndex: Int = 0
    @State private var history: [PredictionResult] = []
    @State private var selectedResult: PredictionResult?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var phaseTask: Task<Void, Never>?
    @State private var showTopUpSheet = false
    @State private var showAuraSnapshotSheet = false
    @State private var hasAdvancedPastCategory: Bool = false

    private var suggestionChips: [String] {
        selectedCategory.suggestedQuestions
    }

    private var progressPhases: [String] {
        if selectedCategory == .messageOutcome {
            return [
                "Reading the conversation...",
                "Mapping chart signals...",
                "Checking emotional pattern...",
                "Composing a possible reply..."
            ]
        }

        return [
            "Reading your question...",
            "Mapping chart signals...",
            "Checking timing patterns...",
            "Composing your next move..."
        ]
    }

    private let progressDurations: [Double] = [1.2, 1.8, 1.8, 1.4]

    private var canGenerate: Bool {
        guard !isGenerating else { return false }
        if selectedCategory.requiresConversation {
            return !conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && selectedSunSign != nil
        }
        return true
    }

    private var nextPredictActionTitle: String {
        if !hasAdvancedPastCategory {
            return "Continue"
        }
        if selectedCategory.requiresTargetSign && selectedSunSign == nil {
            return "Add their Sun"
        }
        if selectedCategory.requiresConversation,
           conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Paste conversation"
        }
        return selectedCategory.actionTitle
    }

    private var nextPredictActionSubtitle: String {
        if !hasAdvancedPastCategory {
            return "Step 2 of 3"
        }
        if selectedCategory.requiresTargetSign && selectedSunSign == nil {
            return "Required for reply predictions"
        }
        if selectedCategory.requiresConversation,
           conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add the thread before asking"
        }
        return "Ready for step 3"
    }

    private var currentPhaseText: String {
        progressPhases[progressPhaseIndex]
    }

    private var currentTier: String {
        viewModel.profile?.tier ?? "free"
    }

    private var methodLayerSummary: String {
        if selectedCategory != .messageOutcome {
            let chartLine: String
            if let type = CommunicationTypeProfile.make(
                sun: viewModel.userSunSign,
                moon: viewModel.userMoonSign,
                rising: viewModel.userRisingSign
            ) {
                chartLine = "Your \(type.title) communication type anchors the answer."
            } else if let userSunSign = viewModel.userSunSign {
                chartLine = "Your \(userSunSign.displayName) Sun anchors the answer."
            } else {
                chartLine = "Your chart context improves the answer when available."
            }
            return "\(chartLine) Simastry reads this as a timing window, a probability signal, and one next move."
        }

        if let type = CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        ) {
            return "Your \(type.title) communication type sets your side of the exchange. Their sign lens and the pasted message context shape the prediction."
        }
        if let selectedSunSign {
            return "This prediction reads the message context through \(selectedSunSign.displayName)'s conversation lens. Moon and Rising refine emotional pattern and first instinct when you add them."
        }
        return "Start with their Sun sign, then add Moon or Rising if you know them. The conversation text keeps the reading anchored to the actual message."
    }

    private var methodSignals: [MethodSignal] {
        var signals: [MethodSignal] = [
            MethodSignal(
                label: selectedCategory == .messageOutcome ? "Message context" : "Question type",
                detail: selectedCategory == .messageOutcome
                    ? (conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Needed" : "Included")
                    : selectedCategory.title,
                systemImage: selectedCategory == .messageOutcome ? "text.bubble.fill" : selectedCategory.systemImage,
                tint: selectedCategory.accentColor
            )
        ]

        if selectedCategory.allowsTargetSign, let selectedSunSign {
            signals.append(
                MethodSignal(
                    label: selectedCategory.requiresTargetSign ? "Their Sun" : "Other Sun",
                    detail: "\(selectedSunSign.displayName) \(selectedSunSign.element.rawValue)",
                    systemImage: "sun.max.fill",
                    tint: selectedSunSign.color
                )
            )
        } else if selectedCategory.requiresTargetSign {
            signals.append(
                MethodSignal(
                    label: "Their Sun",
                    detail: "Required",
                    systemImage: "sun.max.fill",
                    tint: SimastryColor.gold
                )
            )
        }

        if selectedCategory.allowsTargetSign, let selectedMoonSign {
            signals.append(
                MethodSignal(
                    label: "Their Moon",
                    detail: "\(selectedMoonSign.displayName) emotion",
                    systemImage: "moon.stars.fill",
                    tint: selectedMoonSign.color
                )
            )
        }

        if selectedCategory.allowsTargetSign, let selectedRisingSign {
            signals.append(
                MethodSignal(
                    label: "Their Rising",
                    detail: "\(selectedRisingSign.displayName) instinct",
                    systemImage: "sparkles",
                    tint: selectedRisingSign.color
                )
            )
        }

        if let userSunSign = viewModel.userSunSign {
            signals.append(
                MethodSignal(
                    label: "Your lens",
                    detail: "\(userSunSign.displayName) Sun",
                    systemImage: "person.crop.circle.fill",
                    tint: userSunSign.color
                )
            )
        }

        if let typeSignal = CommunicationTypeProfile.methodSignal(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        ) {
            signals.append(typeSignal)
        }

        signals.append(
            MethodSignal(
                label: "Method",
                detail: "Western tropical",
                systemImage: "scope",
                tint: SimastryColor.gold
            )
        )

        return signals
    }

    // NOTE: no inner NavigationStack — this view is always pushed into an
    // existing stack (Home routes, directory), and a nested stack makes the
    // value-based push silently fail.
    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        header
                            .id("predict.header")
                        predictStepRail
                        guidedPredictionFlow
                        historySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, SimastrySpacing.tabBarClearance + 92)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selectedCategory) { _, _ in
                    guard hasAdvancedPastCategory else { return }
                    scrollToNextPredictStep(proxy)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            predictBottomAction
        }
        .navigationTitle("Ask the Future")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showTopUpSheet) {
            PredictionTopUpView(viewModel: viewModel)
        }
        .sheet(isPresented: $showAuraSnapshotSheet) {
            AuraSnapshotSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedResult) { result in
            SimulationResultView(
                result: result,
                isRegenerating: isRegenerating,
                onRegenerate: { alternativeReply in
                    Task {
                        await regenerate(from: result, with: alternativeReply)
                    }
                },
                onOpenGuide: nil,
                userSunSign: viewModel.userSunSign,
                onSetOutcome: { outcome in
                    viewModel.predictionService.setOutcome(outcome, for: result.id)
                    viewModel.notificationService.cancelPredictionOutcomeFollowUp()
                    loadHistory()
                }
            )
        }
        .task {
            viewModel.reloadAuraSnapshot()
            loadHistory()
            applyPredictionDraftIfNeeded()
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(SimastrySpring.smooth)) {
                    appeared = true
                }
            }
        }
        .onDisappear {
            stopProgressCycle()
        }
        .onChange(of: viewModel.predictionDraft?.id) { _, _ in
            applyPredictionDraftIfNeeded()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                PredictionOrbIcon(size: 58, animated: appeared, glow: selectedCategory.accentColor)

                if let selectedSunSign {
                    ZodiacIconView(sign: selectedSunSign, size: 26, showsGlow: true)
                        .offset(x: 3, y: 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 62, height: 62)
            .accessibilityHidden(true)

            Text("Ask the Future")
                .font(SimastryFont.titleLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Love, timing, money, career, replies.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(SimastrySpring.snappy), value: selectedSunSign)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var predictStepRail: some View {
        HStack(spacing: 8) {
            predictStepPill(number: 1, title: "Choose", isActive: true, isDone: hasAdvancedPastCategory)
            predictStepConnector(isDone: hasAdvancedPastCategory)
            predictStepPill(number: 2, title: "Details", isActive: hasAdvancedPastCategory && !canGenerate, isDone: canGenerate)
            predictStepConnector(isDone: canGenerate)
            predictStepPill(number: 3, title: "Answer", isActive: canGenerate, isDone: false)
        }
        .padding(10)
        .background(Color.white.opacity(0.045), in: Capsule())
        .overlay {
            Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.7)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .accessibilityIdentifier("predict.stepFlow")
    }

    private func predictStepPill(number: Int, title: String, isActive: Bool, isDone: Bool) -> some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(SimastryFont.microBold)
                .foregroundStyle(isActive || isDone ? SimastryColor.midnight : SimastryColor.mutedSilver)
                .frame(width: 18, height: 18)
                .background(isActive || isDone ? SimastryColor.gold : Color.white.opacity(0.08), in: Circle())

            Text(title)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(isActive || isDone ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
    }

    private func predictStepConnector(isDone: Bool) -> some View {
        Capsule()
            .fill(isDone ? SimastryColor.gold.opacity(0.55) : Color.white.opacity(0.12))
            .frame(width: 16, height: 2)
            .accessibilityHidden(true)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Choose a question type")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(FutureQuestionCategory.allCases) { category in
                    categoryCard(category)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func categoryCard(_ category: FutureQuestionCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.snappy)) {
                selectedCategory = category
                hasAdvancedPastCategory = true
                if questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !category.suggestedQuestions.contains(questionText) {
                    questionText = category.defaultQuestion
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: category.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? SimastryColor.midnight : category.accentColor)
                        .frame(width: 30, height: 30)
                        .background(
                            isSelected
                                ? SimastryGradient.gold
                                : LinearGradient(colors: [category.accentColor.opacity(0.18)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)
                    }
                }

                Text(category.shortTitle)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1)

                Text(category.defaultQuestion)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .padding(13)
            .background(
                isSelected
                    ? category.accentColor.opacity(0.18)
                    : Color.white.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? category.accentColor.opacity(0.58) : Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Ask about \(category.title)")
    }

    private var guidedPredictionFlow: some View {
        VStack(alignment: .leading, spacing: 18) {
            guidedQuestionBlock(
                number: 1,
                title: "What are we reading?",
                subtitle: "Pick the shape of the question first."
            ) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(FutureQuestionCategory.allCases) { category in
                        categoryCard(category)
                    }
                }
            }
            .id("predict.category")

            guidedQuestionBlock(
                number: 2,
                title: "What do you want to know?",
                subtitle: selectedCategory.defaultQuestion
            ) {
                questionInputContent
            }
            .id("predict.question")

            if selectedCategory.allowsTargetSign {
                guidedQuestionBlock(
                    number: 3,
                    title: selectedCategory.requiresTargetSign ? "Who is this about?" : "Any other person involved?",
                    subtitle: selectedCategory.requiresTargetSign ? "Add their Sun sign. Moon and Rising make it sharper." : "Optional, but it gives the reading a person to hold onto."
                ) {
                    signSelectionContent
                }
                .id("predict.signs")
            }

            if selectedCategory.requiresConversation {
                guidedQuestionBlock(
                    number: 4,
                    title: "What happened in the thread?",
                    subtitle: "Paste the conversation or import a screenshot."
                ) {
                    conversationInputContent
                }
                .id("predict.conversation")
            }

            guidedQuestionBlock(
                number: selectedCategory.requiresConversation ? 5 : (selectedCategory.allowsTargetSign ? 4 : 3),
                title: "Ready for the crystal ball?",
                subtitle: "Simastry turns the chart signals into an answer, a likely window, and one next move."
            ) {
                actionSection
            }
            .id("predict.action")

            DisclosureGroup {
                VStack(spacing: 16) {
                    AuraSnapshotCard(
                        snapshot: viewModel.auraSnapshot,
                        compact: true,
                        onOpen: { showAuraSnapshotSheet = true },
                        onClear: { viewModel.clearAuraSnapshot() }
                    )
                    methodLayerCard
                }
                .padding(.top, 10)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                    Text("Signals used")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                }
            }
            .tint(SimastryColor.gold)
            .padding(16)
            .simastryGlass(cornerRadius: 18)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func guidedQuestionBlock<Content: View>(
        number: Int,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(number)")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(width: 28, height: 28)
                    .background(SimastryColor.gold, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text(subtitle)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
        .padding(16)
        .simastryGlass(cornerRadius: 22)
    }

    private var predictBottomAction: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedCategory.shortTitle)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(selectedCategory.accentColor)
                        .lineLimit(1)
                    Text(nextPredictActionSubtitle)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 10)

                Button {
                    advancePredictionFlow()
                } label: {
                    HStack(spacing: 8) {
                        Text(nextPredictActionTitle)
                            .font(SimastryFont.labelLarge)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Image(systemName: canGenerate ? "sparkles" : "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(canGenerate ? SimastryColor.midnight : SimastryColor.offWhite)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        canGenerate
                            ? AnyShapeStyle(SimastryGradient.gold)
                            : AnyShapeStyle(Color.white.opacity(0.08)),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule().stroke(canGenerate ? SimastryColor.goldLight.opacity(0.32) : Color.white.opacity(0.12), lineWidth: 0.7)
                    }
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityIdentifier("predict.stickyAction")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
    }

    private func advancePredictionFlow() {
        HapticManager.buttonPress()
        withAnimation(.spring(SimastrySpring.snappy)) {
            hasAdvancedPastCategory = true
        }

        if canGenerate {
            Task { await generatePrediction() }
            return
        }

        if selectedCategory.requiresTargetSign && selectedSunSign == nil {
            viewModel.showToast("Add their Sun", subtitle: "That is the one required sign for reply predictions.", isError: false)
            return
        }

        if selectedCategory.requiresConversation,
           conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.showToast("Paste the conversation", subtitle: "Add the thread, then ask for the read.", isError: false)
            return
        }
    }

    private func scrollToNextPredictStep(_ proxy: ScrollViewProxy) {
        let target: String
        if selectedCategory.requiresTargetSign && selectedSunSign == nil {
            target = "predict.signs"
        } else if selectedCategory.requiresConversation,
                  conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            target = "predict.conversation"
        } else {
            target = "predict.question"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(SimastrySpring.smooth)) {
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }

    private var modeCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: selectedCategory.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selectedCategory.accentColor)
                .frame(width: 42, height: 42)
                .background(selectedCategory.accentColor.opacity(0.14), in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedCategory.title)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text(selectedCategory.subtitle)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            Spacer()
        }
        .padding(18)
        .surfaceCard(cornerRadius: 20, accent: selectedCategory.accentColor.opacity(0.7))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(selectedCategory.accentColor.opacity(0.22), lineWidth: 1)
        }
        .featureTip(
            icon: "text.bubble",
            title: "How It Works",
            body: "Pick a question type, add the details it needs, and get a timing window plus one next move.",
            tip: .communicationGuide,
            delay: 0.8
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private var methodLayerCard: some View {
        MethodLayerPanel(
            title: "Signals used",
            summary: methodLayerSummary,
            signals: methodSignals,
            footer: "Astronomy calculates placements. Traditional astrology interprets them. Simastry turns that into communication guidance.",
            accent: selectedCategory == .messageOutcome
                ? (selectedSunSign?.color ?? selectedCategory.accentColor)
                : selectedCategory.accentColor
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private var conversationInputContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                importScreenshotButton
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $conversationText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 128, maxHeight: 220)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(12)
                    .background(.clear)

                if conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Paste the actual messages here.")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .surfaceCard(cornerRadius: 18, accent: SimastryColor.risingViolet.opacity(0.6))
            .accessibilityLabel("Paste your conversation")

            HStack(spacing: 5) {
                Image(systemName: SimastryIcon.privacy)
                    .font(SimastryFont.microMedium)
                Text("Screenshots are read on this iPhone before any AI generation.")
                    .font(SimastryFont.captionSmall)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(SimastryColor.deepMuted)
        }
        .onChange(of: screenshotPickerItem) {
            guard let item = screenshotPickerItem else { return }
            screenshotPickerItem = nil
            importScreenshot(item)
        }
    }

    private var signSelectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            signPickerRow(title: "Sun", selection: $selectedSunSign, required: selectedCategory.requiresTargetSign)
            signPickerRow(title: "Moon", selection: $selectedMoonSign, required: false)
            signPickerRow(title: "Rising", selection: $selectedRisingSign, required: false)
            textingStyleTip
        }
    }

    private var questionInputContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(selectedCategory.defaultQuestion, text: $questionText)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(SimastryColor.offWhite)
                .surfaceCard(cornerRadius: 18, accent: selectedCategory.accentColor.opacity(0.6))

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(suggestionChips, id: \.self) { chip in
                        Button {
                            HapticManager.buttonPress()
                            questionText = chip
                        } label: {
                            Text(chip)
                                .font(SimastryFont.labelMedium)
                                .foregroundStyle(questionText == chip ? SimastryColor.midnight : SimastryColor.offWhite)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(questionText == chip ? SimastryColor.gold : .white.opacity(0.06), in: .capsule)
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
    }

    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                sectionLabel("Paste your conversation")

                Spacer()

                importScreenshotButton
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $conversationText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120, maxHeight: 220)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(12)
                    .background(.clear)

                if conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Paste the text conversation here, or import a screenshot…")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .surfaceCard(cornerRadius: 18, accent: SimastryColor.risingViolet.opacity(0.6))
            .accessibilityLabel("Paste your conversation")

            HStack(spacing: 5) {
                Image(systemName: SimastryIcon.privacy)
                    .font(SimastryFont.microMedium)
                Text("Screenshots are read with Apple Vision on this device — the image never leaves your iPhone. Text recognition works best in English.")
                    .font(SimastryFont.captionSmall)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(SimastryColor.deepMuted)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .onChange(of: screenshotPickerItem) {
            guard let item = screenshotPickerItem else { return }
            screenshotPickerItem = nil
            importScreenshot(item)
        }
    }

    private var importScreenshotButton: some View {
        PhotosPicker(selection: $screenshotPickerItem, matching: .images) {
            HStack(spacing: 6) {
                if isRecognizingScreenshot {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(SimastryColor.gold)
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 11, weight: .semibold))
                }

                Text(isRecognizingScreenshot ? "Reading…" : "Import screenshot")
                    .font(SimastryFont.labelSmall)
            }
            .foregroundStyle(SimastryColor.goldLight)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(SimastryColor.gold.opacity(0.11), in: Capsule())
            .overlay {
                Capsule().strokeBorder(SimastryColor.gold.opacity(0.26), lineWidth: 0.6)
            }
        }
        .disabled(isRecognizingScreenshot)
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Import a conversation screenshot from your photo library")
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
                let existing = conversationText.trimmingCharacters(in: .whitespacesAndNewlines)
                conversationText = existing.isEmpty ? recognized : existing + "\n" + recognized
                HapticManager.signConfirmed()
            } catch {
                viewModel.showToast(
                    "Couldn't read that screenshot",
                    subtitle: error.localizedDescription,
                    isError: true
                )
            }
        }
    }

    private var signSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel(selectedCategory.requiresTargetSign ? "Their sign(s)" : "Optional person sign")

            signPickerRow(title: "Sun", selection: $selectedSunSign, required: selectedCategory.requiresTargetSign)
            signPickerRow(title: "Moon", selection: $selectedMoonSign, required: false)
            signPickerRow(title: "Rising", selection: $selectedRisingSign, required: false)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    @ViewBuilder
    private var textingStyleTip: some View {
        if selectedCategory.allowsTargetSign,
           let sign = selectedSunSign,
           let tip = AstrologyTemplates.textingStyle[sign.displayName] {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .padding(.top, 2)

                Text(tip)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .padding(14)
            .surfaceCard(cornerRadius: 16, accent: SimastryColor.gold.opacity(0.6))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(SimastryColor.gold.opacity(0.12), lineWidth: 0.5)
            }
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            .animation(reduceMotion ? nil : .spring(SimastrySpring.smooth), value: selectedSunSign)
        }
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("What do you want to know?")

            TextField(selectedCategory.defaultQuestion, text: $questionText)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(SimastryColor.offWhite)
                .surfaceCard(cornerRadius: 18, accent: selectedCategory.accentColor.opacity(0.6))

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(suggestionChips, id: \.self) { chip in
                        Button {
                            HapticManager.buttonPress()
                            questionText = chip
                        } label: {
                            Text(chip)
                                .font(SimastryFont.labelMedium)
                                .foregroundStyle(questionText == chip ? SimastryColor.midnight : SimastryColor.offWhite)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(questionText == chip ? SimastryColor.gold : .white.opacity(0.06), in: .capsule)
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 22)
    }

    @ViewBuilder
    private var bonusPredictionBadge: some View {
        if viewModel.bonusPredictions > 0 {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(viewModel.bonusPredictions) bonus prediction\(viewModel.bonusPredictions == 1 ? "" : "s")")
                    .font(SimastryFont.labelSmall)
            }
            .foregroundStyle(SimastryColor.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(SimastryColor.gold.opacity(0.12), in: .capsule)
            .accessibilityLabel("\(viewModel.bonusPredictions) bonus predictions remaining")
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        if isGenerating {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    selectedCategory.accentColor.opacity(0.24),
                                    SimastryColor.midnight.opacity(0.05)
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: 72
                            )
                        )
                        .frame(width: 142, height: 142)

                    Circle()
                        .stroke(SimastryColor.mutedSilver.opacity(0.16), lineWidth: 12)
                        .frame(width: 112, height: 112)

                    Circle()
                        .trim(from: 0.04, to: 0.72)
                        .stroke(
                            LinearGradient(
                                colors: [selectedCategory.accentColor, SimastryColor.celestialBlue, SimastryColor.gold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 112, height: 112)
                        .rotationEffect(.degrees(Double(progressPhaseIndex) * 110))
                        .animation(reduceMotion ? nil : .spring(SimastrySpring.smooth), value: progressPhaseIndex)

                    PredictionOrbIcon(size: 78, animated: !reduceMotion, glow: selectedCategory.accentColor)
                }
                .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("Crystal ball is reading")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(currentPhaseText)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.88))

                    Text(selectedCategory == .messageOutcome ? "Reading the thread through placement logic." : "Reading timing through chart patterns.")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    colors: [selectedCategory.accentColor.opacity(0.16), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(selectedCategory.accentColor.opacity(0.20), lineWidth: 1)
            }
        } else {
            VStack(spacing: 12) {
                bonusPredictionBadge

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: selectedCategory.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedCategory.accentColor)
                        Text(selectedCategory.title)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                        Spacer()
                    }

                    Text(canGenerate ? "You have enough context to ask." : nextPredictActionSubtitle)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    Task {
                        await generatePrediction()
                    }
                } label: {
                    PredictionOrbLabel(title: selectedCategory.actionTitle, iconSize: 21)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(canGenerate ? SimastryColor.midnight : SimastryColor.mutedSilver)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .goldGlassPill()
                }
                .buttonStyle(SpringPressStyle())
                .disabled(!canGenerate)
                .opacity(canGenerate ? 1 : 0.45)
                .accessibilityLabel("Generate prediction")

                privacyNote
            }
        }
    }

    // Honest on purpose: obvious personal details are redacted before any AI
    // generation, recent readings live only on this device, and when AI
    // guidance is on a redacted prompt may be sent to our AI service — say all three.
    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "lock.fill")
                .font(SimastryFont.microSemibold)
                .foregroundStyle(SimastryColor.mutedSilver)
                .padding(.top, 2)

            Text("We redact obvious personal details before AI generation. Your recent readings are saved on this iPhone, and you can clear them anytime. When AI guidance is enabled, a redacted prompt may be sent to Simastry's AI service to generate your reading.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Prediction History")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.mutedSilver)

                if let scoreLine = PredictionScorecard.from(history).line {
                    Text(scoreLine)
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.gold)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(SimastryColor.gold.opacity(0.11), in: Capsule())
                }

                Spacer()

                if !history.isEmpty {
                    Button("Clear All") {
                        viewModel.predictionService.clearHistory()
                        loadHistory()
                    }
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.gold)
                    .buttonStyle(SpringPressStyle())
                }
            }

            if history.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(SimastryColor.risingViolet)
                    Text("No predictions yet")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text(personalizedHistoryEmptyText)
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .simastryGlass(cornerRadius: 20)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(historyCategories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 7) {
                                Image(systemName: category.systemImage)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(category.accentColor)

                                Text(category.title.uppercased())
                                    .font(SimastryFont.overline)
                                    .foregroundStyle(SimastryColor.textSecondary)
                                    .tracking(1.2)
                            }

                            ForEach(history.filter { $0.categoryOrDefault == category }) { item in
                                historyRow(item)
                            }
                        }
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
    }

    private func signPickerRow(title: String, selection: Binding<ZodiacSign?>, required: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(required ? "Required" : "Optional")
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(required ? SimastryColor.gold : SimastryColor.mutedSilver)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((required ? SimastryColor.gold : SimastryColor.deepMuted).opacity(0.16), in: .capsule)

                Spacer()

                if selection.wrappedValue != nil {
                    Button("Clear") {
                        selection.wrappedValue = nil
                    }
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(ZodiacSign.allCases) { sign in
                        ZodiacBadgeView(sign: sign, isSelected: selection.wrappedValue == sign, size: 48) {
                            selection.wrappedValue = sign
                        }
                        .frame(width: 56, height: 56)
                        .accessibilityLabel("Choose \(sign.displayName) as \(title) sign")
                        .accessibilityIdentifier("predict.sign.\(title.lowercased()).\(sign.rawValue)")
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
        .padding(16)
        .simastryGlass(cornerRadius: 18)
    }

    private func historyRow(_ item: PredictionResult) -> some View {
        VStack(spacing: 8) {
            historyRowMain(item)
            outcomeStrip(item)
        }
        .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
    }

    private func historyRowMain(_ item: PredictionResult) -> some View {
        let category = item.categoryOrDefault

        return HStack(spacing: 12) {
            Button {
                selectedResult = item
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: category.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(category.accentColor)
                        .frame(width: 38, height: 38)
                        .background(category.accentColor.opacity(0.16), in: .rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.historyTitle)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(category.shortTitle)
                                .font(SimastryFont.captionSmall.weight(.semibold))
                                .foregroundStyle(category.accentColor)
                            Text(relativeDateString(for: item.createdAt))
                                .font(SimastryFont.caption)
                                .foregroundStyle(SimastryColor.mutedSilver)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("SIGNAL")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.textTertiary)
                            .tracking(0.8)
                        Text(item.confidenceDisplayTier)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(confidenceColor(item.confidence))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Signal strength: \(item.confidenceDisplayTier)")
                }
                .padding(16)
                .simastryGlass(cornerRadius: 18)
            }
            .buttonStyle(SpringPressStyle())

            Button(role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.predictionService.deleteHistoryItem(id: item.id)
                    loadHistory()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .simastryGlass(cornerRadius: 14)
            }
            .buttonStyle(SpringPressStyle())
        }
    }

    private func confidenceColor(_ value: Int) -> Color {
        if value >= 75 { return SimastryColor.gold }
        if value >= 50 { return SimastryColor.offWhite }
        return SimastryColor.mutedSilver
    }

    private func outcomeStrip(_ item: PredictionResult) -> some View {
        OutcomeChipRow(currentOutcome: item.outcome) { outcome in
            viewModel.predictionService.setOutcome(outcome, for: item.id)
            viewModel.notificationService.cancelPredictionOutcomeFollowUp()
            withAnimation(.spring(SimastrySpring.snappy)) {
                loadHistory()
            }
        }
        .padding(.horizontal, 6)
    }

    private var historyCategories: [FutureQuestionCategory] {
        FutureQuestionCategory.allCases.filter { category in
            history.contains { $0.categoryOrDefault == category }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(SimastryFont.titleSmall)
            .foregroundStyle(SimastryColor.offWhite)
    }

    private func loadHistory() {
        history = viewModel.predictionService.loadHistory()
    }

    private func applyPredictionDraftIfNeeded() {
        guard let draft = viewModel.predictionDraft else { return }

        selectedCategory = draft.category
        selectedSunSign = draft.targetSunSign
        selectedMoonSign = draft.targetMoonSign
        selectedRisingSign = draft.targetRisingSign
        if let draftConversation = draft.conversationText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !draftConversation.isEmpty {
            conversationText = draftConversation
        }
        if let question = draft.question?.trimmingCharacters(in: .whitespacesAndNewlines),
           !question.isEmpty {
            questionText = question
        }
        viewModel.predictionDraft = nil
    }

    private func startProgressCycle() {
        stopProgressCycle()
        progressPhaseIndex = 0

        phaseTask = Task { @MainActor in
            while !Task.isCancelled {
                for index in progressPhases.indices {
                    progressPhaseIndex = index
                    let duration = progressDurations[index]
                    try? await Task.sleep(for: .seconds(duration))
                    if Task.isCancelled {
                        return
                    }
                }
            }
        }
    }

    private func stopProgressCycle() {
        phaseTask?.cancel()
        phaseTask = nil
        progressPhaseIndex = 0
    }

    private func generatePrediction() async {
        if selectedCategory.requiresTargetSign && selectedSunSign == nil {
            viewModel.showToast("Choose their Sun sign", subtitle: "Ask the Future needs at least one sign to read.", isError: true)
            return
        }

        // Rate limit check
        let allowed = await viewModel.predictionRateLimiter.checkLimit()
        if !allowed {
            let message = await viewModel.predictionRateLimiter.waitMessage()
            viewModel.showToast("Rate limit reached", subtitle: message, isError: true)
            return
        }

        // Content moderation check
        let moderationInput = [conversationText, questionText]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let moderation = ContentModerationService.moderateConversation(moderationInput)
        if !moderation.isAllowed {
            viewModel.showToast("Unable to process", subtitle: moderation.reason ?? "Unable to process this content", isError: true)
            return
        }

        // Decide how this prediction is funded; nothing is charged until
        // generation succeeds, so a failed request can't burn a paid credit.
        let usesBonusPrediction: Bool
        if viewModel.canUsePrediction() {
            usesBonusPrediction = false
        } else if viewModel.hasBonusPredictions {
            usesBonusPrediction = true
        } else {
            selectedResult = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                showTopUpSheet = true
            }
            return
        }

        let trimmedQuestion = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = PredictionRequest(
            mode: .whatWillTheySay,
            category: selectedCategory,
            conversationText: selectedCategory.requiresConversation ? conversationText : "",
            userSunSign: viewModel.userSunSign,
            userMoonSign: viewModel.userMoonSign,
            userRisingSign: viewModel.userRisingSign,
            targetSunSign: selectedCategory.allowsTargetSign ? selectedSunSign : nil,
            targetMoonSign: selectedCategory.allowsTargetSign ? selectedMoonSign : nil,
            targetRisingSign: selectedCategory.allowsTargetSign ? selectedRisingSign : nil,
            question: trimmedQuestion.isEmpty ? selectedCategory.defaultQuestion : trimmedQuestion,
            hypotheticalReply: nil,
            auraSnapshot: viewModel.auraSnapshot?.descriptor
        )

        isGenerating = true
        startProgressCycle()

        do {
            let result = try await viewModel.predictionService.generatePrediction(request: request, tier: currentTier)
            await viewModel.predictionRateLimiter.recordAction()
            if usesBonusPrediction {
                viewModel.bonusPredictions -= 1
            } else {
                await viewModel.consumePrediction()
            }
            stopProgressCycle()
            isGenerating = false
            HapticManager.soulFlash()
            AnalyticsService.shared.track(.predictionGenerated, key: "category", value: selectedCategory.rawValue)
            ReviewPromptService.shared.recordPositiveAction()
            loadHistory()
            selectedResult = result
            if viewModel.privateNotificationsEnabled {
                viewModel.notificationService.schedulePredictionOutcomeFollowUp()
            }
        } catch {
            CrashReporter.log(error, context: "generatePrediction")
            stopProgressCycle()
            isGenerating = false
            let message = (error as? LocalizedError)?.errorDescription ?? "Try again in a moment."
            viewModel.showToast("Prediction interrupted", subtitle: message, isError: true)
        }
    }

    private func regenerate(from result: PredictionResult, with alternativeReply: String) async {
        guard !isRegenerating,
              result.isMessageOutcome,
              let targetSunSign = result.targetSunSign else {
            return
        }

        let allowed = await viewModel.predictionRateLimiter.checkLimit()
        if !allowed {
            let message = await viewModel.predictionRateLimiter.waitMessage()
            viewModel.showToast("Rate limit reached", subtitle: message, isError: true)
            return
        }

        let moderation = ContentModerationService.moderateConversation(alternativeReply)
        if !moderation.isAllowed {
            viewModel.showToast("Unable to process", subtitle: moderation.reason ?? "Unable to process this content", isError: true)
            return
        }

        // Decide how this prediction is funded; nothing is charged until
        // generation succeeds, so a failed request can't burn a paid credit.
        let usesBonusPrediction: Bool
        if viewModel.canUsePrediction() {
            usesBonusPrediction = false
        } else if viewModel.hasBonusPredictions {
            usesBonusPrediction = true
        } else {
            selectedResult = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                showTopUpSheet = true
            }
            return
        }

        isRegenerating = true

        let request = PredictionRequest(
            mode: result.mode,
            category: result.categoryOrDefault,
            conversationText: result.conversationText ?? "",
            userSunSign: result.userSunSign,
            userMoonSign: result.userMoonSign,
            userRisingSign: result.userRisingSign,
            targetSunSign: targetSunSign,
            targetMoonSign: result.targetMoonSign,
            targetRisingSign: result.targetRisingSign,
            question: result.question,
            hypotheticalReply: alternativeReply,
            auraSnapshot: viewModel.auraSnapshot?.descriptor
        )

        do {
            let updatedResult = try await viewModel.predictionService.generatePrediction(request: request, tier: currentTier)
            await viewModel.predictionRateLimiter.recordAction()
            if usesBonusPrediction {
                viewModel.bonusPredictions -= 1
            } else {
                await viewModel.consumePrediction()
            }
            HapticManager.soulFlash()
            loadHistory()
            selectedResult = updatedResult
        } catch {
            CrashReporter.log(error, context: "regeneratePrediction")
            let message = (error as? LocalizedError)?.errorDescription ?? "Try again in a moment."
            viewModel.showToast("Couldn't update the prediction", subtitle: message, isError: true)
        }

        isRegenerating = false
    }

    private var personalizedHistoryEmptyText: String {
        if let signKey = viewModel.userSunSign?.rawValue,
           let personalized = AstrologyTemplates.personalizedEmptyStates[signKey]?["history"] {
            return personalized
        }
        return "Your future answers will gather here once you ask your first question."
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension FutureQuestionCategory {
    var accentColor: Color {
        switch self {
        case .loveTiming:
            SimastryColor.sunCoral
        case .commitment:
            SimastryColor.gold
        case .familyPath:
            SimastryColor.celestialBlue
        case .careerSuccess:
            SimastryColor.risingViolet
        case .moneyDirection:
            SimastryColor.amber
        case .privateQuestion:
            SimastryColor.risingViolet
        case .messageOutcome:
            SimastryColor.celestialBlue
        }
    }
}
