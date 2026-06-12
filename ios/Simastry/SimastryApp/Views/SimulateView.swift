import SwiftUI
import Foundation
import PhotosUI

struct SimulateView: View {
    @Bindable var viewModel: AppViewModel

    @State private var conversationText: String = ""
    @State private var questionText: String = ""
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

    private let suggestionChips: [String] = [
        "Will they reply?",
        "What are they feeling?",
        "Should I double text?",
        "Are they interested?"
    ]

    private let progressPhases: [String] = [
        "Reading the conversation...",
        "Mapping chart signals...",
        "Checking emotional pattern...",
        "Composing a possible reply..."
    ]

    private let progressDurations: [Double] = [1.5, 2.0, 2.0, 1.5]

    private var canGenerate: Bool {
        !conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedSunSign != nil
            && !isGenerating
    }

    private var currentPhaseText: String {
        progressPhases[progressPhaseIndex]
    }

    private var currentTier: String {
        viewModel.profile?.tier ?? "free"
    }

    private var methodLayerSummary: String {
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
                label: "Message context",
                detail: conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Needed" : "Included",
                systemImage: "text.bubble.fill",
                tint: SimastryColor.celestialBlue
            )
        ]

        if let selectedSunSign {
            signals.append(
                MethodSignal(
                    label: "Their Sun",
                    detail: "\(selectedSunSign.displayName) \(selectedSunSign.element.rawValue)",
                    systemImage: "sun.max.fill",
                    tint: selectedSunSign.color
                )
            )
        } else {
            signals.append(
                MethodSignal(
                    label: "Their Sun",
                    detail: "Required",
                    systemImage: "sun.max.fill",
                    tint: SimastryColor.gold
                )
            )
        }

        if let selectedMoonSign {
            signals.append(
                MethodSignal(
                    label: "Their Moon",
                    detail: "\(selectedMoonSign.displayName) emotion",
                    systemImage: "moon.stars.fill",
                    tint: selectedMoonSign.color
                )
            )
        }

        if let selectedRisingSign {
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
                    modeCard
                    methodLayerCard
                    conversationSection
                    signSection
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
        .navigationTitle("Predict")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showTopUpSheet) {
            PredictionTopUpView(viewModel: viewModel)
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

            Text("What Will They Say?")
                .font(SimastryFont.titleLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Paste a real conversation and read it through chart signals.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(SimastrySpring.snappy), value: selectedSunSign)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var modeCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: SimulationMode.whatWillTheySay.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(SimastryColor.risingViolet)
                .frame(width: 42, height: 42)
                .background(SimastryColor.risingViolet.opacity(0.14), in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(SimulationMode.whatWillTheySay.title)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text("Use their sign lens, your context, and the message thread to model the next reply.")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            Spacer()
        }
        .padding(18)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.risingViolet.opacity(0.7))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(SimastryColor.risingViolet.opacity(0.22), lineWidth: 1)
        }
        .featureTip(
            icon: "text.bubble",
            title: "How It Works",
            body: "Pick someone's sign, paste the conversation, and see which chart signals drive the reading.",
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
            accent: selectedSunSign?.color ?? SimastryColor.risingViolet
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
            .surfaceCard(cornerRadius: 18, accent: SimastryColor.risingViolet.opacity(0.6))
            .accessibilityLabel("Paste your conversation")

            HStack(spacing: 5) {
                Image(systemName: SimastryIcon.privacy)
                    .font(.system(size: 9, weight: .medium))
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
            sectionLabel("Their sign(s)")

            signPickerRow(title: "Sun", selection: $selectedSunSign, required: true)
            signPickerRow(title: "Moon", selection: $selectedMoonSign, required: false)
            signPickerRow(title: "Rising", selection: $selectedRisingSign, required: false)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    @ViewBuilder
    private var textingStyleTip: some View {
        if let sign = selectedSunSign,
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

            TextField("e.g. Will they text back? What are they thinking?", text: $questionText)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(SimastryColor.offWhite)
                .surfaceCard(cornerRadius: 18, accent: SimastryColor.risingViolet.opacity(0.6))

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
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                }

                Text(currentPhaseText)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("Reading the thread through placement logic.")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .surfaceCard(cornerRadius: 22, accent: SimastryColor.risingViolet.opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(SimastryColor.risingViolet.opacity(0.16), lineWidth: 1)
            }
        } else {
            VStack(spacing: 10) {
                bonusPredictionBadge

                Button {
                    Task {
                        await generatePrediction()
                    }
                } label: {
                    Text(SimulationMode.whatWillTheySay.actionTitle)
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
                .font(.system(size: 10, weight: .semibold))
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
                Text("Past Predictions")
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
                VStack(spacing: 12) {
                    ForEach(history) { item in
                        historyRow(item)
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
        HStack(spacing: 12) {
            Button {
                selectedResult = item
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.mode.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SimastryColor.risingViolet)
                        .frame(width: 38, height: 38)
                        .background(SimastryColor.risingViolet.opacity(0.16), in: .rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.historyTitle)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                            .lineLimit(1)
                        Text(relativeDateString(for: item.createdAt))
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }

                    Spacer()

                    Text("\(item.confidence)%")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(confidenceColor(item.confidence))
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
        guard let selectedSunSign else {
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
        let moderation = ContentModerationService.moderateConversation(conversationText)
        if !moderation.isAllowed {
            viewModel.showToast("Unable to process", subtitle: moderation.reason ?? "Unable to process this content", isError: true)
            return
        }

        if !viewModel.canUsePrediction() {
            if viewModel.hasBonusPredictions {
                viewModel.bonusPredictions -= 1
            } else {
                showTopUpSheet = true
                return
            }
        }

        let request = PredictionRequest(
            mode: .whatWillTheySay,
            conversationText: conversationText,
            targetSunSign: selectedSunSign,
            targetMoonSign: selectedMoonSign,
            targetRisingSign: selectedRisingSign,
            question: questionText,
            hypotheticalReply: nil
        )

        isGenerating = true
        startProgressCycle()

        do {
            let result = try await viewModel.predictionService.generatePrediction(request: request, tier: currentTier)
            await viewModel.predictionRateLimiter.recordAction()
            await viewModel.consumePrediction()
            stopProgressCycle()
            isGenerating = false
            HapticManager.soulFlash()
            AnalyticsService.shared.track(.predictionGenerated, key: "targetSign", value: selectedSunSign.displayName)
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

        if !viewModel.canUsePrediction() {
            if viewModel.hasBonusPredictions {
                viewModel.bonusPredictions -= 1
            } else {
                showTopUpSheet = true
                return
            }
        }

        isRegenerating = true

        let request = PredictionRequest(
            mode: result.mode,
            conversationText: result.conversationText ?? "",
            targetSunSign: targetSunSign,
            targetMoonSign: result.targetMoonSign,
            targetRisingSign: result.targetRisingSign,
            question: result.question,
            hypotheticalReply: alternativeReply
        )

        do {
            let updatedResult = try await viewModel.predictionService.generatePrediction(request: request, tier: currentTier)
            await viewModel.predictionRateLimiter.recordAction()
            await viewModel.consumePrediction()
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
        return "Your recent predictions will gather here once you test a conversation."
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
