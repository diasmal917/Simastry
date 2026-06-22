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
    @State private var showCrisisAlert = false
    @Environment(\.openURL) private var openURL
    @Namespace private var chipGlass

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

            ScrollView {
                VStack(spacing: 24) {
                    header
                    categorySection
                    modeCard
                    methodLayerCard
                    if selectedCategory.requiresConversation {
                        conversationSection
                    }
                    if selectedCategory.allowsTargetSign {
                        signSection
                    }
                    textingStyleTip
                    questionSection
                    actionSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, SimastrySpacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Simulate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showTopUpSheet) {
            PredictionTopUpView(viewModel: viewModel)
        }
        .alert("If you're in crisis", isPresented: $showCrisisAlert) {
            Button("Call 988") {
                if let url = URL(string: "tel://988") { openURL(url) }
            }
            Button("Text 988") {
                if let url = URL(string: "sms:988") { openURL(url) }
            }
            Button("Close", role: .cancel) {}
        } message: {
            Text("Simastry is an AI astrology app and can't help with this. The 988 Suicide & Crisis Lifeline has trained counselors available free, confidential, 24/7. Call or text 988.")
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
            if let selectedSunSign {
                ZodiacIconView(sign: selectedSunSign, size: 36, showsGlow: true)
                    .accessibilityHidden(true)
                    .transition(.scale.combined(with: .opacity))
            }

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
                if questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !category.suggestedQuestions.contains(questionText) {
                    questionText = category.defaultQuestion
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: category.systemImage)
                        .font(.system(size: SimastryIconSize.md, weight: .semibold))
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
                            .font(.system(size: SimastryIconSize.md, weight: .semibold))
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
                in: RoundedRectangle(cornerRadius: SimastryRadius.large, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: SimastryRadius.large, style: .continuous)
                    .stroke(isSelected ? category.accentColor.opacity(0.58) : SimastryColor.hairline, lineWidth: 1)
            }
            .selectionElevation(isSelected, accent: category.accentColor)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Ask about \(category.title)")
    }

    private var modeCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: selectedCategory.systemImage)
                .font(.system(size: SimastryIconSize.lg, weight: .semibold))
                .foregroundStyle(selectedCategory.accentColor)
                .frame(width: 42, height: 42)
                .background(selectedCategory.accentColor.opacity(0.14), in: .rect(cornerRadius: SimastryRadius.medium))

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
            .surfaceCard(cornerRadius: SimastryRadius.large, accent: SimastryColor.risingViolet.opacity(0.6))
            .accessibilityLabel("Paste your conversation")

            HStack(spacing: 5) {
                Image(systemName: SimastryIcon.privacy)
                    .font(SimastryFont.microMedium)
                Text("Screenshots are read with Apple Vision on this device — the image never leaves your iPhone.")
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
                        .font(.system(size: SimastryIconSize.sm, weight: .semibold))
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
                    .font(.system(size: SimastryIconSize.md, weight: .semibold))
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
                .surfaceCard(cornerRadius: SimastryRadius.large, accent: selectedCategory.accentColor.opacity(0.6))

            ScrollView(.horizontal) {
                suggestionChipRow
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 22)
    }

    /// Suggestion chips as a Liquid Glass cluster on iOS 26 — each chip shares
    /// a `GlassEffectContainer` and carries a `glassEffectID`, so the glass
    /// blends across the row and the highlight morphs as selection moves.
    /// Pre-26 keeps the flat capsule fill.
    @ViewBuilder
    private var suggestionChipRow: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(suggestionChips, id: \.self) { chip in
                        suggestionChip(chip)
                            .glassEffect(
                                .regular
                                    .tint(questionText == chip ? SimastryColor.gold.opacity(0.9) : Color.clear)
                                    .interactive(true),
                                in: .capsule
                            )
                            .glassEffectID(chip, in: chipGlass)
                    }
                }
            }
        } else {
            HStack(spacing: 10) {
                ForEach(suggestionChips, id: \.self) { chip in
                    suggestionChip(chip)
                        .background(questionText == chip ? SimastryColor.gold : SimastryColor.fillFaint, in: .capsule)
                }
            }
        }
    }

    private func suggestionChip(_ chip: String) -> some View {
        Button {
            HapticManager.buttonPress()
            questionText = chip
        } label: {
            Text(chip)
                .font(SimastryFont.labelMedium)
                .foregroundStyle(questionText == chip ? SimastryColor.midnight : SimastryColor.offWhite)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(SpringPressStyle())
    }

    @ViewBuilder
    private var bonusPredictionBadge: some View {
        if viewModel.bonusPredictions > 0 {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
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
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(SimastryColor.mutedSilver.opacity(0.16), lineWidth: 10)
                        .frame(width: 82, height: 82)

                    Circle()
                        .trim(from: 0.08, to: 0.76)
                        .stroke(
                            LinearGradient(
                                colors: [SimastryColor.risingViolet, SimastryColor.celestialBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 82, height: 82)
                        .rotationEffect(.degrees(Double(progressPhaseIndex) * 92))
                        .animation(.spring(SimastrySpring.smooth), value: progressPhaseIndex)

                    Image(systemName: "wand.and.stars")
                        .font(.system(size: SimastryIconSize.lg, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                }

                Text(currentPhaseText)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite)

                    Text(selectedCategory == .messageOutcome ? "Reading the thread through placement logic." : "Reading timing through chart patterns.")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .surfaceCard(cornerRadius: 22, accent: selectedCategory.accentColor.opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(selectedCategory.accentColor.opacity(0.16), lineWidth: 1)
            }
        } else {
            VStack(spacing: 10) {
                bonusPredictionBadge

                Button {
                    Task {
                        await generatePrediction()
                    }
                } label: {
                    Text(selectedCategory.actionTitle)
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

    // Honest on purpose: readings aren't kept on any server, but a short
    // redacted history DOES stay on this device — say both.
    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "lock.fill")
                .font(SimastryFont.microSemibold)
                .foregroundStyle(SimastryColor.mutedSilver)
                .padding(.top, 2)

            Text("Your conversations are never stored on our servers — readings happen in the moment. Recent readings stay only on this iPhone, and you can clear them anytime.")
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
                        .font(.system(size: SimastryIconSize.lg, weight: .semibold))
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
                                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
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
                        VStack(spacing: 6) {
                            ZodiacBadgeView(sign: sign, isSelected: selection.wrappedValue == sign, size: 44) {
                                selection.wrappedValue = sign
                            }
                            .accessibilityLabel("Choose \(sign.displayName) as \(title) sign")
                            Text(sign.displayName)
                                .font(SimastryFont.labelSmall)
                                .foregroundStyle(selection.wrappedValue == sign ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                        }
                        .frame(width: 56)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
        .padding(16)
        .simastryGlass(cornerRadius: SimastryRadius.large)
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
                        .font(.system(size: SimastryIconSize.md, weight: .semibold))
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

                    Text("\(item.confidence)%")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(confidenceColor(item.confidence))
                }
                .padding(16)
                .simastryGlass(cornerRadius: SimastryRadius.large)
            }
            .buttonStyle(SpringPressStyle())

            Button(role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.predictionService.deleteHistoryItem(id: item.id)
                    loadHistory()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: SimastryIconSize.md, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .simastryGlass(cornerRadius: SimastryRadius.medium)
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
            viewModel.showToast("Choose their Sun sign", subtitle: "The simulation needs at least one sign.", isError: true)
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
            if moderation.isCrisis {
                showCrisisAlert = true
            } else {
                viewModel.showToast("Unable to process", subtitle: moderation.reason ?? "Unable to process this content", isError: true)
            }
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
            hypotheticalReply: nil
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
            if moderation.isCrisis {
                showCrisisAlert = true
            } else {
                viewModel.showToast("Unable to process", subtitle: moderation.reason ?? "Unable to process this content", isError: true)
            }
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
            hypotheticalReply: alternativeReply
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
        case .messageOutcome:
            SimastryColor.celestialBlue
        }
    }
}
