import SwiftUI

private struct FirstReadEntryOption: Identifiable {
    let id: FirstReadOnboardingIntent
    let titleKey: String
    let subtitleKey: String
    let detailKey: String
    let icon: String
    let accent: Color
    let tagsKey: String
}

private let firstReadEntryOptions: [FirstReadEntryOption] = [
    FirstReadEntryOption(
        id: .predict,
        titleKey: "firstReadChoice.predict.title",
        subtitleKey: "firstReadChoice.predict.subtitle",
        detailKey: "firstReadChoice.predict.detail",
        icon: SimastryIcon.predict,
        accent: SimastryColor.risingViolet,
        tagsKey: "firstReadChoice.predict.tags"
    ),
    FirstReadEntryOption(
        id: .astrologer,
        titleKey: "firstReadChoice.astrologer.title",
        subtitleKey: "firstReadChoice.astrologer.subtitle",
        detailKey: "firstReadChoice.astrologer.detail",
        icon: SimastryIcon.astrologers,
        accent: SimastryColor.gold,
        tagsKey: "firstReadChoice.astrologer.tags"
    ),
    FirstReadEntryOption(
        id: .decode,
        titleKey: "firstReadChoice.decode.title",
        subtitleKey: "firstReadChoice.decode.subtitle",
        detailKey: "firstReadChoice.decode.detail",
        icon: SimastryIcon.lens,
        accent: SimastryColor.celestialBlue,
        tagsKey: "firstReadChoice.decode.tags"
    )
]

private struct FirstPredictionPrompt: Identifiable, Equatable {
    let id: String
    let questionKey: String
    let category: FutureQuestionCategory
}

private let firstPredictionPrompts: [FirstPredictionPrompt] = [
    FirstPredictionPrompt(
        id: "next",
        questionKey: "firstPrediction.prompt.next",
        category: .loveTiming
    ),
    FirstPredictionPrompt(
        id: "text",
        questionKey: "firstPrediction.prompt.text",
        category: .loveTiming
    ),
    FirstPredictionPrompt(
        id: "love",
        questionKey: "firstPrediction.prompt.love",
        category: .commitment
    ),
    FirstPredictionPrompt(
        id: "success",
        questionKey: "firstPrediction.prompt.success",
        category: .careerSuccess
    )
]

struct FirstReadChoiceView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let cardCornerRadius: CGFloat = 22
    private let cardPadding: CGFloat = SimastrySpacing.md
    private let iconContainerSize: CGFloat = 46
    private let arrowColumnWidth: CGFloat = 24

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SimastrySpacing.lg) {
                Spacer().frame(height: SimastrySpacing.sm)

                header

                VStack(spacing: SimastrySpacing.sm) {
                    ForEach(firstReadEntryOptions) { option in
                        entryCard(option)
                    }
                }

                privacyFooter

                Spacer().frame(height: 42)
            }
            .padding(.horizontal, SimastrySpacing.lg)
            .padding(.bottom, 58)
        }
        .scrollIndicators(.hidden)
        // `.background` keeps the header below the nav bar (no ZStack clip).
        .background { CelestialBackground() }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(SimastrySpring.smooth).delay(0.08)) {
                    appeared = true
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            SimastryWordmark(font: .system(.title, weight: .bold).italic())

            Text(localization.string("firstReadChoice.title"))
                .font(SimastryFont.displayMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(localization.string("firstReadChoice.subtitle"))
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func entryCard(_ option: FirstReadEntryOption) -> some View {
        Button {
            HapticManager.buttonPress()
            viewModel.chooseFirstReadIntent(option.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    SimastryConceptIconView(
                        name: option.icon,
                        size: option.id == .predict ? 42 : iconContainerSize,
                        symbolSize: 18,
                        accent: option.accent,
                        animatedPrediction: option.id == .predict && appeared
                    )
                        .frame(width: iconContainerSize, height: iconContainerSize)
                        .background(
                            option.id == .predict
                                ? AnyShapeStyle(option.accent.opacity(0.14))
                                : AnyShapeStyle(option.accent.opacity(0.14)),
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(localization.string(option.titleKey))
                            .font(option.id == .predict ? SimastryFont.titleMedium : SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.offWhite)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(localization.string(option.subtitleKey))
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(option.accent)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(option.id == .predict ? SimastryColor.gold : SimastryColor.mutedSilver)
                        .frame(width: arrowColumnWidth, height: arrowColumnWidth, alignment: .center)
                        .padding(.top, 2)
                }

                Text(localization.string(option.detailKey))
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(localization.list(option.tagsKey), id: \.self) { tag in
                        Text(tag)
                            .font(SimastryFont.captionSmall.weight(.semibold))
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.86))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(option.accent.opacity(0.12), in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(cardPadding)
            .heroGlass(option.accent, cornerRadius: cardCornerRadius)
            .overlay {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(option.accent.opacity(option.id == .predict ? 0.32 : 0.18), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(localization.string(option.titleKey))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private var privacyFooter: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: SimastryIcon.privacy)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SimastryColor.gold.opacity(0.78))

            Text(localization.string("firstReadChoice.privacy"))
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .opacity(appeared ? 1 : 0)
    }
}

struct FirstPredictionView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var questionText = ""
    @State private var selectedPrompt = firstPredictionPrompts[0]
    @State private var result: PredictionResult?
    @State private var errorMessage: String?
    @State private var isGenerating = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let localPredictionService = PredictionService()

    private var trimmedQuestion: String {
        questionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAsk: Bool {
        !isGenerating && !trimmedQuestion.isEmpty
    }

    private func promptQuestion(_ prompt: FirstPredictionPrompt) -> String {
        localization.string(prompt.questionKey)
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Spacer().frame(height: 12)

                    header
                    questionCard

                    if isGenerating {
                        loadingCard
                    } else if let result {
                        resultCard(result)
                    } else {
                        GoldButton(localization.string("firstPrediction.button"), isEnabled: canAsk) {
                            generatePrediction()
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    SecondaryButton(title: localization.string("firstPrediction.chooseDifferent")) {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            viewModel.currentScreen = .firstReadChoice
                        }
                    }
                    .frame(maxWidth: .infinity)

                    privacyLine
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            if questionText.isEmpty {
                questionText = promptQuestion(selectedPrompt)
            }
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(SimastrySpring.smooth).delay(0.08)) {
                    appeared = true
                }
            }
        }
        .onChange(of: localization.currentLanguage) {
            questionText = promptQuestion(selectedPrompt)
            result = nil
            errorMessage = nil
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            SimastryWordmark(font: .system(.title, weight: .bold).italic())

            PredictionOrbIcon(size: 56, animated: appeared)
                .padding(.top, 2)

            Text(localization.string("firstPrediction.title"))
                .font(SimastryFont.displayMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .multilineTextAlignment(.center)

            Text(localization.string("firstPrediction.subtitle"))
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localization.string("firstPrediction.ask"))
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            TextField(localization.string("firstPrediction.placeholder"), text: $questionText)
                .textInputAutocapitalization(.sentences)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .tint(SimastryColor.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(SimastryColor.risingViolet.opacity(0.22), lineWidth: 0.8)
                }

            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    ForEach(firstPredictionPrompts) { prompt in
                        Button {
                            HapticManager.buttonPress()
                            selectedPrompt = prompt
                            questionText = promptQuestion(prompt)
                            result = nil
                            errorMessage = nil
                        } label: {
                            Text(promptQuestion(prompt))
                                .font(SimastryFont.labelSmall)
                                .foregroundStyle(selectedPrompt == prompt ? SimastryColor.midnight : SimastryColor.offWhite)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    selectedPrompt == prompt ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.07)),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.risingViolet.opacity(0.6))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .onChange(of: questionText) {
            result = nil
            errorMessage = nil
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(SimastryColor.gold)
            Text(localization.string("firstPrediction.loading"))
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
    }

    private func resultCard(_ result: PredictionResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            resultRow(title: localization.string("firstPrediction.row.shortAnswer"), body: localizedPredictionAnswer(result))

            if let timingWindow = result.timingWindow, !timingWindow.isEmpty {
                resultRow(title: localization.string("firstPrediction.row.window"), body: localizedTimingWindow(timingWindow))
            }

            if result.practicalNextMove?.isEmpty == false {
                resultRow(title: localization.string("firstPrediction.row.nextMove"), body: localizedPredictionNextMove(result))
            }

            Text(localizedPredictionSafety(result))
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            GoldButton(localization.string("firstPrediction.personalize")) {
                viewModel.continueToBirthDetails(after: .predict)
            }

            SecondaryButton(title: localization.string("firstPrediction.askAnother")) {
                withAnimation(.spring(SimastrySpring.snappy)) {
                    self.result = nil
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .heroGlass(result.categoryOrDefault.accentColor, cornerRadius: 24)
    }

    private func resultRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(SimastryFont.overline)
                .tracking(1.2)
                .foregroundStyle(SimastryColor.textSecondary)

            Text(body)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func localizedPredictionAnswer(_ result: PredictionResult) -> String {
        localization.string(
            "firstPrediction.answer.\(predictionLocalizationSuffix(for: result))",
            replacements: ["window": localizedTimingWindow(result.timingWindow ?? "")]
        )
    }

    private func localizedPredictionNextMove(_ result: PredictionResult) -> String {
        localization.string("firstPrediction.next.\(predictionLocalizationSuffix(for: result))")
    }

    private func localizedPredictionSafety(_ result: PredictionResult) -> String {
        switch result.categoryOrDefault {
        case .commitment:
            localization.string("firstPrediction.safety.commitment")
        case .familyPath:
            localization.string("firstPrediction.safety.family")
        case .moneyDirection:
            localization.string("firstPrediction.safety.money")
        default:
            localization.string("firstPrediction.safety")
        }
    }

    private func predictionLocalizationSuffix(for result: PredictionResult) -> String {
        if selectedPrompt.id == "text" || result.categoryOrDefault == .messageOutcome {
            return "text"
        }

        switch result.categoryOrDefault {
        case .commitment:
            return "commitment"
        case .familyPath:
            return "family"
        case .careerSuccess:
            return "career"
        case .moneyDirection:
            return "money"
        case .loveTiming, .privateQuestion, .messageOutcome:
            return "love"
        }
    }

    private func localizedTimingWindow(_ timingWindow: String) -> String {
        switch timingWindow {
        case "the next 6 to 10 weeks":
            localization.string("firstPrediction.window.6to10")
        case "late this season":
            localization.string("firstPrediction.window.lateSeason")
        case "the next 3 months":
            localization.string("firstPrediction.window.3months")
        case "the next 9 to 18 months":
            localization.string("firstPrediction.window.9to18")
        case "after one more consistency test":
            localization.string("firstPrediction.window.consistency")
        case "the next serious relationship chapter":
            localization.string("firstPrediction.window.seriousChapter")
        case "the next 12 to 24 months":
            localization.string("firstPrediction.window.12to24")
        case "after your home base feels steadier":
            localization.string("firstPrediction.window.homeBase")
        case "the next chapter where care and stability become louder":
            localization.string("firstPrediction.window.familyChapter")
        case "the next 4 to 8 weeks":
            localization.string("firstPrediction.window.4to8")
        case "the next quarter":
            localization.string("firstPrediction.window.quarter")
        case "the next visible work cycle":
            localization.string("firstPrediction.window.workCycle")
        case "the next 3 to 6 months":
            localization.string("firstPrediction.window.3to6")
        case "after one cleaner structure is in place":
            localization.string("firstPrediction.window.structure")
        case "the next practical earning cycle":
            localization.string("firstPrediction.window.earningCycle")
        case "the next reply window":
            localization.string("firstPrediction.window.reply")
        default:
            timingWindow
        }
    }

    private var privacyLine: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: SimastryIcon.privacy)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SimastryColor.gold.opacity(0.78))

            Text(localization.string("firstPrediction.privacy"))
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
    }

    private func generatePrediction() {
        guard canAsk else { return }
        isGenerating = true
        errorMessage = nil
        result = nil

        let request = PredictionRequest(
            mode: .whatWillTheySay,
            category: selectedPrompt.category,
            conversationText: "",
            userSunSign: viewModel.userSunSign,
            userMoonSign: viewModel.userMoonSign,
            userRisingSign: viewModel.userRisingSign,
            targetSunSign: nil,
            targetMoonSign: nil,
            targetRisingSign: nil,
            question: trimmedQuestion,
            hypotheticalReply: nil
        )

        Task { @MainActor in
            defer { isGenerating = false }
            do {
                let generated = try await localPredictionService.generatePrediction(request: request, tier: "free")
                withAnimation(.spring(SimastrySpring.smooth)) {
                    result = generated
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Predict's little sister and the most frequent moment: paste the one
/// message you just received and get the tone, the subtext by their sign —
/// and what NOT to read into it. Fully on-device.
struct DecodeTextView: View {
    @Bindable var viewModel: AppViewModel

    @State private var messageText: String = ""
    @State private var theirSign: ZodiacSign?
    @State private var decoded: Bool = false
    @State private var privacyBlockMessage: String?
    @State private var copiedReplyIndex: Int?

    private let privacyService = ConversationPrivacyService()

    private var canDecode: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && theirSign != nil
    }

    /// Deterministic per (text, day) like the local Predict composer.
    private var seed: Int {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return abs(messageText.count &+ dayOfYear)
    }

    private var tone: SimulationTone? {
        guard let theirSign else { return nil }
        let options: [SimulationTone] = switch theirSign.element {
        case .fire: [.confident, .playful, .flirty]
        case .earth: [.warm, .guarded, .confident]
        case .air: [.playful, .distant, .warm]
        case .water: [.warm, .guarded, .anxious]
        }
        return options[seed % options.count]
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    inputCard
                    signPicker

                    GoldButton("Decode it", isEnabled: canDecode) {
                        decode()
                    }

                    if let privacyBlockMessage {
                        Text(privacyBlockMessage)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if decoded, let theirSign {
                        resultStack(sign: theirSign)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Text("Decoded on this iPhone — the message is never sent or stored.")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, SimastrySpacing.tabBarEndClearance)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Decode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .accessibilityIdentifier("decode.screen")
        .animation(.spring(SimastrySpring.smooth), value: decoded)
        .onChange(of: messageText) { decoded = false; privacyBlockMessage = nil }
        .onChange(of: theirSign) { decoded = false }
        .onAppear {
            // Person-page handoff: arrive with their sign already selected.
            if let handoffSign = viewModel.decodeDraftSign {
                theirSign = handoffSign
                viewModel.decodeDraftSign = nil
            }
            #if DEBUG
            // Prefill only — the preview taps Decode like a user would,
            // since onChange(of: messageText) clears stale results.
            if viewModel.isDebugPreviewStateActive, messageText.isEmpty {
                messageText = "haha yeah maybe, this week is kind of crazy though"
                theirSign = theirSign ?? .taurus
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("What did they mean?")
                .font(SimastryFont.titleLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Paste the one message you keep rereading.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THEIR MESSAGE")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            TextEditor(text: $messageText)
                .scrollContentBackground(.hidden)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .frame(minHeight: 88)
                .padding(10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if messageText.isEmpty {
                        Text("Paste their message…")
                            .font(SimastryFont.bodyMedium)
                            .foregroundStyle(SimastryColor.textTertiary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    private var signPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THEIR SIGN")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ZodiacSign.allCases) { sign in
                        VStack(spacing: 5) {
                            ZodiacBadgeView(sign: sign, isSelected: theirSign == sign, size: 40) {
                                withAnimation(.spring(SimastrySpring.snappy)) {
                                    theirSign = theirSign == sign ? nil : sign
                                }
                            }
                            .accessibilityLabel("Decode as a \(sign.displayName)")

                            Text(sign.displayName)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(theirSign == sign ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                        }
                        .frame(width: 52)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    private func decode() {
        let prepared = privacyService.prepare(messageText)
        guard prepared.canProceed else {
            privacyBlockMessage = prepared.blockingMessage
                ?? "This message includes content Simastry can't safely read."
            return
        }
        HapticManager.signConfirmed()
        decoded = true
    }

    // MARK: - Results

    private func resultStack(sign: ZodiacSign) -> some View {
        let element = sign.element.rawValue
        let subtextLines = AstrologyTemplates.decodeSubtext[element] ?? []
        let dontLines = AstrologyTemplates.decodeDontReadInto[element] ?? []
        let replies = AstrologyTemplates.suggestedReplies[sign.displayName] ?? []

        return VStack(alignment: .leading, spacing: 14) {
            // Tone
            if let tone {
                HStack(spacing: 8) {
                    Text("READS AS")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.3)

                    Text(tone.rawValue.capitalized)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.midnight)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SimastryGradient.gold, in: Capsule())

                    Spacer()

                    ZodiacIconView(sign: sign, size: 24, showsGlow: false)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .heroGlass(sign.color, cornerRadius: 20)
            }

            // Subtext
            if !subtextLines.isEmpty {
                decodeCard(
                    title: "WHAT IT LIKELY MEANS",
                    icon: "text.magnifyingglass",
                    tint: SimastryColor.celestialBlue,
                    body: subtextLines[seed % subtextLines.count]
                )
            }

            // The anti-spiral line — the signature of this screen.
            if !dontLines.isEmpty {
                decodeCard(
                    title: "WHAT NOT TO READ INTO IT",
                    icon: "heart.slash.circle.fill",
                    tint: SimastryColor.amber,
                    body: dontLines[seed % dontLines.count]
                )
            }

            // Reply directions
            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)

                        Text("WAYS TO REPLY")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.textSecondary)
                            .tracking(1.3)
                    }

                    ForEach(Array(replies.prefix(3).enumerated()), id: \.offset) { index, reply in
                        HStack(alignment: .top, spacing: 8) {
                            Text(reply)
                                .font(.system(.footnote, design: .serif))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 6)

                            Button {
                                HapticManager.buttonPress()
                                UIPasteboard.general.string = reply
                                withAnimation(.spring(SimastrySpring.snappy)) {
                                    copiedReplyIndex = index
                                }
                                Task {
                                    try? await Task.sleep(for: .seconds(1.6))
                                    if copiedReplyIndex == index {
                                        withAnimation(.spring(SimastrySpring.snappy)) {
                                            copiedReplyIndex = nil
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: copiedReplyIndex == index ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(SimastryColor.gold)
                                    .padding(7)
                                    .background(SimastryColor.gold.opacity(0.12), in: Circle())
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(SpringPressStyle())
                            .accessibilityLabel(copiedReplyIndex == index ? "Reply copied" : "Copy this reply")
                        }
                        .padding(10)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
            }
        }
    }

    private func decodeCard(title: String, icon: String, tint: Color, body: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            Text(body)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: tint.opacity(0.6))
    }
}

/// Pre-auth activation moment: the user gets one practical, on-device read
/// before birth details or account creation.
struct FirstReadView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared

    @State private var messageText: String = ""
    @State private var theirSign: ZodiacSign?
    @State private var decoded: Bool = false
    @State private var privacyBlockMessage: String?
    @State private var copiedReplyIndex: Int?
    @State private var tunedReplies: [Int: ReplyTuneAction] = [:]
    @State private var feedbackRating: HelpfulnessRating?
    @State private var feedbackReasons: Set<GuideFeedbackReason> = []

    private let privacyService = ConversationPrivacyService()

    private var canDecode: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && theirSign != nil
    }

    private var seed: Int {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return abs(messageText.count &+ dayOfYear)
    }

    private var tone: SimulationTone? {
        guard let theirSign else { return nil }
        let options: [SimulationTone] = switch theirSign.element {
        case .fire: [.confident, .playful, .flirty]
        case .earth: [.warm, .guarded, .confident]
        case .air: [.playful, .distant, .warm]
        case .water: [.warm, .guarded, .anxious]
        }
        return options[seed % options.count]
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    inputCard
                    signPicker

                    GoldButton(localization.string("firstRead.decodeButton"), isEnabled: canDecode) {
                        decode()
                    }

                    if let privacyBlockMessage {
                        Text(privacyBlockMessage)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if decoded, let theirSign {
                        resultStack(sign: theirSign)
                            .transition(.opacity.combined(with: .move(edge: .top)))

                        GoldButton(localization.string("firstRead.saveButton")) {
                            saveFirstReadAndContinue()
                        }
                    }

                    skipButton
                    privacyLine
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)
        }
        .animation(.spring(SimastrySpring.smooth), value: decoded)
        .onChange(of: messageText) {
            resetResultState()
            privacyBlockMessage = nil
        }
        .onChange(of: theirSign) {
            resetResultState()
            if let theirSign {
                viewModel.analytics.track(
                    .firstReadSignSelected,
                    params: ["selectedSign": theirSign.rawValue]
                )
            }
        }
        .onAppear {
            viewModel.analytics.track(.firstReadStarted)
            #if DEBUG
            if viewModel.isDebugPreviewStateActive, messageText.isEmpty {
                messageText = "haha yeah maybe, this week is kind of crazy though"
                theirSign = .taurus
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            SimastryWordmark(font: .system(.title, weight: .bold).italic())

            VStack(spacing: 6) {
                Text(localization.string("firstRead.title"))
                    .font(SimastryFont.displayMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .multilineTextAlignment(.center)

                Text(localization.string("firstRead.subtitle"))
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.string("firstRead.messageLabel"))
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            TextEditor(text: $messageText)
                .scrollContentBackground(.hidden)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .frame(minHeight: 92)
                .padding(10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if messageText.isEmpty {
                        Text(localization.string("firstRead.placeholder"))
                            .font(SimastryFont.bodyMedium)
                            .foregroundStyle(SimastryColor.textTertiary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    private var signPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.string("firstRead.signLabel"))
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ZodiacSign.allCases) { sign in
                        VStack(spacing: 5) {
                            ZodiacBadgeView(sign: sign, isSelected: theirSign == sign, size: 40) {
                                withAnimation(.spring(SimastrySpring.snappy)) {
                                    theirSign = theirSign == sign ? nil : sign
                                }
                            }
                            .accessibilityLabel(localization.string("firstRead.decodeAs", replacements: ["sign": sign.displayName]))

                            Text(sign.displayName)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(theirSign == sign ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                        }
                        .frame(width: 52)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    private var skipButton: some View {
        Button {
            HapticManager.buttonPress()
            continueToBirthDetails()
        } label: {
            Text(localization.string("firstRead.skip"))
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.mutedSilver)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint(localization.string("firstRead.skipHint"))
    }

    private var privacyLine: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: SimastryIcon.privacy)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SimastryColor.gold.opacity(0.78))

            Text(localization.string("firstRead.privacy"))
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }

    private func decode() {
        let prepared = privacyService.prepare(messageText)
        guard prepared.canProceed else {
            privacyBlockMessage = prepared.blockingMessage
                ?? localization.string("firstRead.privacyError")
            viewModel.analytics.track(
                .firstReadFailed,
                params: ["reason": "privacy", "messageLengthBucket": messageLengthBucket(prepared.redactedText)]
            )
            return
        }
        HapticManager.signConfirmed()
        viewModel.analytics.track(
            .firstReadMessageEntered,
            params: ["messageLengthBucket": messageLengthBucket(prepared.redactedText)]
        )
        viewModel.analytics.track(
            .firstReadGeneratedTemplate,
            params: [
                "selectedSign": theirSign?.rawValue ?? "unknown",
                "messageLengthBucket": messageLengthBucket(prepared.redactedText),
                "usedFallback": "false"
            ]
        )
        decoded = true
    }

    private func continueToBirthDetails() {
        viewModel.continueToBirthDetails(after: .decode)
    }

    private func saveFirstReadAndContinue() {
        if decoded, let theirSign, let draft = makeDraft(for: theirSign) {
            viewModel.saveFirstReadDraft(draft)
            viewModel.analytics.track(
                .firstReadSaved,
                params: [
                    "selectedSign": theirSign.rawValue,
                    "messageLengthBucket": messageLengthBucket(draft.messageText),
                    "bestNextMove": draft.bestNextMove?.type.rawValue ?? "none"
                ]
            )
        }
        continueToBirthDetails()
    }

    private func resultStack(sign: ZodiacSign) -> some View {
        let draft = makeDraft(for: sign)

        return VStack(alignment: .leading, spacing: 14) {
            if let tone {
                HStack(spacing: 8) {
                    Text(localization.string("firstRead.readsAs"))
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.3)

                    Text(localizedTone(tone))
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.midnight)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SimastryGradient.gold, in: Capsule())

                    Spacer()

                    ZodiacIconView(sign: sign, size: 24, showsGlow: false)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .heroGlass(sign.color, cornerRadius: 20)
            }

            if let draft {
                if let bestNextMove = draft.bestNextMove {
                    bestNextMoveCard(bestNextMove, sign: sign)
                }

                firstReadCard(
                    title: localization.string("firstRead.likelyMeans"),
                    icon: "text.magnifyingglass",
                    tint: SimastryColor.celestialBlue,
                    body: draft.likelyMeaning
                )

                firstReadCard(
                    title: localization.string("firstRead.notAssume"),
                    icon: "heart.slash.circle.fill",
                    tint: SimastryColor.amber,
                    body: draft.notAssume
                )

                if !draft.suggestedReplies.isEmpty {
                    replyCard(replies: draft.suggestedReplies)
                }

                feedbackCard(for: draft)
            }
        }
    }

    private func makeDraft(for sign: ZodiacSign) -> FirstReadDraft? {
        guard let tone else { return nil }
        let prepared = privacyService.prepare(messageText)
        guard prepared.canProceed else { return nil }

        let element = sign.element.rawValue
        let subtextLines = AstrologyTemplates.decodeSubtext[element] ?? []
        let dontLines = AstrologyTemplates.decodeDontReadInto[element] ?? []
        guard !subtextLines.isEmpty, !dontLines.isEmpty else { return nil }

        let replies = AstrologyTemplates.suggestedReplies[sign.displayName] ?? []
        let isLocalized = localization.currentLanguage != .english
        let localizedReplies = localization.list("firstRead.reply.\(element)")
        let likelyMeaning = isLocalized
            ? localization.string("firstRead.meaning.\(element)")
            : subtextLines[seed % subtextLines.count]
        let notAssume = isLocalized
            ? localization.string("firstRead.notAssume.\(element)")
            : dontLines[seed % dontLines.count]
        let suggestedReplies = isLocalized && !localizedReplies.isEmpty
            ? Array(localizedReplies.prefix(3))
            : Array(replies.prefix(3))
        let bestNextMove = localizedBestNextMove(makeBestNextMove(sign: sign, tone: tone))
        let continuationSeed = [
            "Message read as \(tone.displayName) through \(sign.displayName).",
            "Best next move: \(bestNextMove.summary)",
            "Likely meaning: \(likelyMeaning)"
        ].joined(separator: " ")

        return FirstReadDraft(
            messageText: prepared.redactedText.trimmingCharacters(in: .whitespacesAndNewlines),
            sign: sign,
            tone: tone,
            likelyMeaning: likelyMeaning,
            notAssume: notAssume,
            suggestedReplies: suggestedReplies,
            bestNextMove: bestNextMove,
            guideContinuationSeed: continuationSeed,
            safetyLevel: .ok,
            confidence: 72
        )
    }

    private func bestNextMoveCard(_ move: FirstReadBestNextMove, sign: ZodiacSign) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: move.type.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(sign.color)

                Text(localization.string("firstRead.bestNextMove"))
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)

                Spacer()

                Text(localizedMoveTitle(move.type))
                    .font(SimastryFont.captionSmall.weight(.bold))
                    .foregroundStyle(SimastryColor.midnight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(SimastryGradient.gold, in: Capsule())
            }

            Text(move.summary)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let timingNote = move.timingNote {
                Text(timingNote)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: sign.color.opacity(0.7))
    }

    private func firstReadCard(title: String, icon: String, tint: Color, body: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            Text(body)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: tint.opacity(0.6))
    }

    private func replyCard(replies: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text(localization.string("firstRead.replyWays"))
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            ForEach(Array(replies.enumerated()), id: \.offset) { index, reply in
                let displayedReply = tunedReply(for: reply, action: tunedReplies[index])

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(displayedReply)
                            .font(.system(.footnote, design: .serif))
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 6)

                        Button {
                            HapticManager.buttonPress()
                            UIPasteboard.general.string = displayedReply
                            viewModel.analytics.track(
                                .replyOptionCopied,
                                params: [
                                    "surface": "firstRead",
                                    "replyIndex": "\(index)",
                                    "tuneAction": tunedReplies[index]?.rawValue ?? "none"
                                ]
                            )
                            withAnimation(.spring(SimastrySpring.snappy)) {
                                copiedReplyIndex = index
                            }
                            Task {
                                try? await Task.sleep(for: .seconds(1.6))
                                if copiedReplyIndex == index {
                                    withAnimation(.spring(SimastrySpring.snappy)) {
                                        copiedReplyIndex = nil
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: copiedReplyIndex == index ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(SimastryColor.gold)
                                .padding(7)
                                .background(SimastryColor.gold.opacity(0.12), in: Circle())
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(SpringPressStyle())
                        .accessibilityLabel(copiedReplyIndex == index ? localization.string("firstRead.replyCopied") : localization.string("firstRead.copyReply"))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(ReplyTuneAction.allCases) { action in
                                tuneButton(action, isActive: tunedReplies[index] == action) {
                                    if tunedReplies[index] == action {
                                        tunedReplies[index] = nil
                                    } else {
                                        tunedReplies[index] = action
                                        viewModel.analytics.track(
                                            .replyOptionTuned,
                                            params: [
                                                "surface": "firstRead",
                                                "replyIndex": "\(index)",
                                                "tuneAction": action.rawValue
                                            ]
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
    }

    private func tuneButton(_ action: ReplyTuneAction, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.snappy)) {
                onTap()
            }
        } label: {
            Label(localizedTuneTitle(action), systemImage: action.systemImage)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(isActive ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.84))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    isActive ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.06)),
                    in: Capsule()
                )
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func feedbackCard(for draft: FirstReadDraft) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text(localization.string("firstRead.tuneGuides"))
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            Text(localization.string("firstRead.wasHelpful"))
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.offWhite)

            HStack(spacing: 8) {
                ForEach(HelpfulnessRating.allCases) { rating in
                    feedbackRatingButton(rating, draft: draft)
                }
            }

            if let feedbackRating, feedbackRating != .helpful {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(feedbackReasonOptions) { reason in
                            feedbackReasonButton(reason, draft: draft)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if feedbackRating != nil {
                Text(localization.string("firstRead.savedGuides"))
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.textTertiary)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.45))
        .animation(.spring(SimastrySpring.smooth), value: feedbackRating)
        .animation(.spring(SimastrySpring.smooth), value: feedbackReasons)
    }

    private var feedbackReasonOptions: [GuideFeedbackReason] {
        [.tooVague, .wrongTone, .notPractical, .tooIntense, .tooMystical, .replyDidntSoundLikeMe]
    }

    private func feedbackRatingButton(_ rating: HelpfulnessRating, draft: FirstReadDraft) -> some View {
        let isActive = feedbackRating == rating
        return Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.snappy)) {
                feedbackRating = rating
                if rating == .helpful {
                    feedbackReasons = []
                }
                submitFeedback(for: draft)
            }
        } label: {
            Text(localizedRatingTitle(rating))
                .font(SimastryFont.labelSmall)
                .foregroundStyle(isActive ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isActive ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.06)),
                    in: Capsule()
                )
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func feedbackReasonButton(_ reason: GuideFeedbackReason, draft: FirstReadDraft) -> some View {
        let isActive = feedbackReasons.contains(reason)
        return Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.snappy)) {
                if isActive {
                    feedbackReasons.remove(reason)
                } else {
                    feedbackReasons.insert(reason)
                }
                submitFeedback(for: draft)
            }
        } label: {
            Text(localizedReasonTitle(reason))
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(isActive ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.84))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    isActive ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.06)),
                    in: Capsule()
                )
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func submitFeedback(for draft: FirstReadDraft) {
        guard let feedbackRating else { return }
        viewModel.recordGuideFeedback(
            readId: draft.id,
            guideId: nil,
            surface: .firstRead,
            helpfulness: feedbackRating,
            reasons: Array(feedbackReasons).sorted { $0.rawValue < $1.rawValue }
        )
    }

    private func resetResultState() {
        decoded = false
        copiedReplyIndex = nil
        tunedReplies = [:]
        feedbackRating = nil
        feedbackReasons = []
    }

    private func localizedTone(_ tone: SimulationTone) -> String {
        let key = "firstRead.tone.\(tone.rawValue)"
        let localized = localization.string(key)
        return localized == key ? tone.displayName : localized
    }

    private func localizedMoveTitle(_ type: FirstReadBestNextMoveType) -> String {
        let key = "firstRead.move.\(type.rawValue)"
        let localized = localization.string(key)
        return localized == key ? type.title : localized
    }

    private func localizedBestNextMove(_ move: FirstReadBestNextMove) -> FirstReadBestNextMove {
        let summaryKey = "firstRead.moveSummary.\(move.type.rawValue)"
        let timingKey = "firstRead.moveTiming.\(move.type.rawValue)"
        let localizedSummary = localization.string(summaryKey)
        let localizedTiming = localization.string(timingKey)

        return FirstReadBestNextMove(
            type: move.type,
            summary: localizedSummary == summaryKey ? move.summary : localizedSummary,
            timingNote: localizedTiming == timingKey ? move.timingNote : localizedTiming
        )
    }

    private func localizedRatingTitle(_ rating: HelpfulnessRating) -> String {
        let key = "firstRead.rating.\(rating.rawValue)"
        let localized = localization.string(key)
        return localized == key ? rating.title : localized
    }

    private func localizedReasonTitle(_ reason: GuideFeedbackReason) -> String {
        let key = "firstRead.reason.\(reason.rawValue)"
        let localized = localization.string(key)
        return localized == key ? reason.title : localized
    }

    private func localizedTuneTitle(_ action: ReplyTuneAction) -> String {
        let key = "firstRead.tune.\(action.rawValue)"
        let localized = localization.string(key)
        return localized == key ? action.title : localized
    }

    private func makeBestNextMove(sign: ZodiacSign, tone: SimulationTone) -> FirstReadBestNextMove {
        switch tone {
        case .playful, .flirty:
            return FirstReadBestNextMove(
                type: .replyNow,
                summary: "Match the lightness, but keep one clear thread so the conversation has somewhere to land.",
                timingNote: "Send one warm reply now. Do not stack extra meaning onto a playful message."
            )
        case .warm:
            return FirstReadBestNextMove(
                type: .replyNow,
                summary: "Respond simply and warmly. Let the next message invite more, not prove more.",
                timingNote: "Now is fine if you want the thread to stay open."
            )
        case .confident:
            return FirstReadBestNextMove(
                type: sign.element == .fire ? .replyNow : .clarify,
                summary: "Answer the actual words and keep your self-respect in the center. If it feels unclear, ask one clean question.",
                timingNote: "One direct reply is stronger than several careful hints."
            )
        case .guarded, .distant, .cold:
            return FirstReadBestNextMove(
                type: .replyLater,
                summary: "Give the message a little room, then send one low-pressure check-in only if the connection still feels worth your energy.",
                timingNote: "Wait a few hours, or until tomorrow if you feel activated."
            )
        case .anxious:
            return FirstReadBestNextMove(
                type: .wait,
                summary: "Pause before replying. Regulate first, then choose the simplest message instead of answering the anxiety.",
                timingNote: "Wait at least 20 minutes and reread it once."
            )
        }
    }

    private func tunedReply(for reply: String, action: ReplyTuneAction?) -> String {
        guard let action else { return reply }
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        switch action {
        case .warmer:
            return "\(trimmed) \(localization.string("firstRead.tuned.warmerAppend"))"
        case .moreDirect:
            return trimmed.hasSuffix("?") ? trimmed : "\(trimmed) \(localization.string("firstRead.tuned.directQuestion"))"
        case .shorter:
            let sentence = trimmed.split(separator: ".").first.map(String.init) ?? trimmed
            return sentence.count < trimmed.count ? "\(sentence)." : String(trimmed.prefix(96))
        case .lessIntense:
            return trimmed
                .replacingOccurrences(of: "really ", with: "")
                .replacingOccurrences(of: "definitely ", with: "")
                .replacingOccurrences(of: "always ", with: "")
        }
    }

    private func messageLengthBucket(_ text: String) -> String {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).count {
        case 0...40: "short"
        case 41...160: "medium"
        case 161...500: "long"
        default: "very_long"
        }
    }
}
