import SwiftUI
import Foundation

struct SimulateView: View {
    @Bindable var viewModel: AppViewModel

    @State private var conversationText: String = ""
    @State private var questionText: String = ""
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

    private let suggestionChips: [String] = [
        "Will they reply?",
        "What are they feeling?",
        "Should I double text?",
        "Are they interested?"
    ]

    private let progressPhases: [String] = [
        "Reading the conversation…",
        "Channeling their energy…",
        "Consulting the stars…",
        "Composing their response…"
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

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        modeCard
                        conversationSection
                        signSection
                        questionSection
                        actionSection
                        historySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Simulate")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedResult) { result in
                SimulationResultView(result: result, isRegenerating: isRegenerating) { alternativeReply in
                    Task {
                        await regenerate(from: result, with: alternativeReply)
                    }
                } onOpenGuide: { sign in
                    viewModel.guideFocusSign = sign
                    viewModel.selectedTab = 3
                }
            }
            .task {
                loadHistory()
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
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            GlossyOrbView(
                signColors: [SimastryColor.risingViolet, SimastryColor.celestialBlue],
                state: .active,
                size: 84
            )

            VStack(spacing: 6) {
                Text("What Will They Say?")
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("Paste a real conversation and let the stars predict their next text.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
            }
        }
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
                Text("Predict their next reply, then test your own alternate message.")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            Spacer()
        }
        .padding(18)
        .tintedGlass(SimastryColor.risingViolet.opacity(0.16), cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(SimastryColor.risingViolet.opacity(0.22), lineWidth: 1)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Paste your conversation")

            ZStack(alignment: .topLeading) {
                TextEditor(text: $conversationText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120, maxHeight: 220)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(12)
                    .background(.clear)

                if conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Paste the text conversation here…")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .tintedGlass(SimastryColor.risingViolet.opacity(0.08), cornerRadius: 18)
            .accessibilityLabel("Paste your conversation")
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
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

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("What do you want to know?")

            TextField("e.g. Will they text back? What are they thinking?", text: $questionText)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(SimastryColor.offWhite)
                .tintedGlass(SimastryColor.risingViolet.opacity(0.08), cornerRadius: 18)

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

                Text("Your simulation is taking shape.")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .tintedGlass(SimastryColor.risingViolet.opacity(0.18), cornerRadius: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(SimastryColor.risingViolet.opacity(0.16), lineWidth: 1)
            }
        } else {
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
        }
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Past Simulations")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Spacer()

                if !history.isEmpty {
                    Button("Clear All") {
                        viewModel.predictionService.clearHistory()
                        loadHistory()
                    }
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.gold)
                    .buttonStyle(.plain)
                }
            }

            if history.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(SimastryColor.risingViolet)
                    Text("No simulations yet")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("Your recent predictions will gather here once you ask the stars.")
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
                        .foregroundStyle(SimastryColor.gold)
                }
                .padding(16)
                .simastryGlass(cornerRadius: 18)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                viewModel.predictionService.deleteHistoryItem(id: item.id)
                loadHistory()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .simastryGlass(cornerRadius: 14)
            }
            .buttonStyle(.plain)
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

        guard viewModel.canUsePrediction() else {
            viewModel.showToast("Predictions used up", subtitle: "You've used all \(viewModel.weeklyPredictionLimit) predictions this week. Upgrade for unlimited.", isError: true)
            viewModel.showUpsell = true
            return
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
            await viewModel.consumePrediction()
            stopProgressCycle()
            isGenerating = false
            HapticManager.soulFlash()
            loadHistory()
            selectedResult = result
        } catch {
            stopProgressCycle()
            isGenerating = false
            let message = (error as? LocalizedError)?.errorDescription ?? "Try again in a moment."
            viewModel.showToast("Simulation interrupted", subtitle: message, isError: true)
        }
    }

    private func regenerate(from result: PredictionResult, with alternativeReply: String) async {
        guard !isRegenerating,
              let targetSunSign = result.targetSunSign else {
            return
        }

        guard viewModel.canUsePrediction() else {
            viewModel.showToast("Predictions used up", subtitle: "You've used all \(viewModel.weeklyPredictionLimit) predictions this week. Upgrade for unlimited.", isError: true)
            viewModel.showUpsell = true
            return
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
            await viewModel.consumePrediction()
            HapticManager.soulFlash()
            loadHistory()
            selectedResult = updatedResult
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "Try again in a moment."
            viewModel.showToast("Couldn't redraw the timeline", subtitle: message, isError: true)
        }

        isRegenerating = false
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
