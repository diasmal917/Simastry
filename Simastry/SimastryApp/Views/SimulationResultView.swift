import SwiftUI
import UIKit

struct SimulationResultView: View {
    let result: PredictionResult
    let isRegenerating: Bool
    let onRegenerate: (String) -> Void
    var onOpenGuide: ((ZodiacSign) -> Void)?
    var userSunSign: ZodiacSign?
    var onSetOutcome: ((PredictionOutcome?) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var alternativeReply: String = ""
    @State private var showShareCard: Bool = false
    @State private var appeared: Bool = false
    @State private var copiedSuggestion: Bool = false
    @State private var localOutcome: PredictionOutcome?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accentColor: Color {
        result.targetSunSign?.color ?? result.categoryOrDefault.accentColor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    cascaded(predictionBubble, step: 0)
                    cascaded(timingAndNextMoveSection, step: 1)
                    cascaded(suggestedReplySection, step: 2)
                    cascaded(resultMethodLayer, step: 3)
                    cascaded(breakdownSection, step: 4)
                    cascaded(shareResultButton, step: 5)
                    if result.isMessageOutcome, let sign = result.targetSunSign {
                        cascaded(guideFollowUpCard(sign: sign), step: 6)
                    }
                    whatIfSection
                    confidenceFooter

                    if onSetOutcome != nil {
                        outcomeSection
                    }

                    // Real conversation nudge
                    Text(result.isMessageOutcome ? "Use this as preparation, then have the real conversation." : "Use this as a timing read, then choose the next practical move.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    aiDisclosureBadge
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("Prediction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.buttonPress()
                        showShareCard = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: SimastryIconSize.md, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)
                    }
                }
            }
            .sheet(isPresented: $showShareCard) {
                SimulationShareCardView(
                    result: result,
                    userSunSign: userSunSign
                )
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .onChange(of: result.id) { _, _ in
            alternativeReply = ""
            localOutcome = result.outcome
        }
        .task {
            localOutcome = result.outcome
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(SimastrySpring.smooth).delay(0.2)) {
                    appeared = true
                }
            }
        }
    }

    /// Step-staggered rise-in so the reading discloses progressively —
    /// prediction first, then the reply, then the reasoning.
    private func cascaded(_ view: some View, step: Int) -> some View {
        view
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(
                reduceMotion ? nil : .spring(SimastrySpring.smooth).delay(Double(step) * 0.09),
                value: appeared
            )
    }

    /// Closes the meaning loop: rate the prediction against what happened.
    private var outcomeSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            OutcomeChipRow(currentOutcome: localOutcome) { outcome in
                withAnimation(.spring(SimastrySpring.snappy)) {
                    localOutcome = outcome
                }
                onSetOutcome?(outcome)
            }

            if localOutcome == nil {
                Text("Come back after they reply — this trains your panel's accuracy stat.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.textTertiary)
            }
        }
        .padding(13)
        .surfaceCard(cornerRadius: 16)
    }

    private var predictionBubble: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.categoryOrDefault.resultTitle)
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.4)
                .textCase(.uppercase)

            HStack(alignment: .bottom, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 38, height: 38)

                    if let sign = result.targetSunSign {
                        ZodiacIconView(sign: sign, size: 25, showsGlow: false)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: SimastryIconSize.md, weight: .semibold))
                            .foregroundStyle(SimastryColor.offWhite)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(result.displayAnswer)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let tone = result.tone {
                        Text(tone.displayName)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(accentColor.opacity(0.14), in: .capsule)
                    }

                    if let timing = result.timingWindow, !timing.isEmpty {
                        Label(timing, systemImage: "clock.fill")
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.gold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(SimastryColor.gold.opacity(0.12), in: Capsule())
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tintedGlass(accentColor, cornerRadius: 22)
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(accentColor.opacity(0.18), lineWidth: 1)
                }
            }

            Text(result.safetyNote ?? "This is a pattern-based prediction, not a guarantee. Real life is shaped by context, consent, choices, and timing.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    @ViewBuilder
    private var suggestedReplySection: some View {
        if let suggestion = suggestedReplyText {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    Text("Suggested reply")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .tracking(1.4)
                        .textCase(.uppercase)

                    Spacer()

                    Button {
                        HapticManager.buttonPress()
                        UIPasteboard.general.string = suggestion
                        copiedSuggestion = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            copiedSuggestion = false
                        }
                    } label: {
                        Label(copiedSuggestion ? "Copied" : "Copy", systemImage: copiedSuggestion ? "checkmark" : "doc.on.doc")
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.gold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(SimastryColor.gold.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityLabel(copiedSuggestion ? "Suggested reply copied" : "Copy suggested reply")
                }

                Text(suggestion)
                    .font(SimastryFont.bodyLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let approach = result.targetSunSign.flatMap({ CommunicationTemplates.guides[$0]?.bestApproach }) {
                    Text(approach)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .tintedGlass(SimastryColor.gold, cornerRadius: 20)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
    }

    private var suggestedReplyText: String? {
        guard result.isMessageOutcome,
              let sign = result.targetSunSign,
              let options = AstrologyTemplates.suggestedReplies[sign.displayName],
              !options.isEmpty else { return nil }
        let seed = abs((result.conversationText?.count ?? 0) &+ result.predictedMessage.count)
        return options[seed % options.count]
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.categoryOrDefault.reasoningTitle)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)

            Text(result.astrologicalBreakdown)
                .font(.system(.body, design: .serif))
                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                .lineSpacing(4)
        }
        .padding(18)
        .goldGlassRect(cornerRadius: 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var resultMethodLayer: some View {
        MethodLayerPanel(
            title: "Why this reading",
            summary: resultMethodSummary,
            signals: resultMethodSignals,
            footer: "A prediction is signal strength, not certainty. Context, consent, and lived history still matter.",
            accent: accentColor
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var resultMethodSummary: String {
        if !result.isMessageOutcome {
            let category = result.categoryOrDefault
            if let userSunSign = result.userSunSign ?? userSunSign {
                return "This reads \(category.title.lowercased()) through your \(userSunSign.displayName) chart lens, then turns it into a probability, timing window, and next move."
            }
            return "This reads \(category.title.lowercased()) as a probability, timing window, and next move. Adding chart details makes future answers sharper."
        }

        guard let targetSign = result.targetSunSign else {
            return "This reading uses the pasted message, the selected chart signals, and traditional astrology to model a possible reply."
        }

        return "This reads the conversation through \(targetSign.displayName)'s \(targetSign.element.rawValue) \(targetSign.modality) lens. Moon and Rising add emotional pattern and first instinct when present."
    }

    private var resultMethodSignals: [MethodSignal] {
        var signals: [MethodSignal] = [
            MethodSignal(
                label: result.isMessageOutcome ? "Message context" : "Question type",
                detail: result.isMessageOutcome
                    ? (result.conversationText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "Included" : "Limited")
                    : result.categoryOrDefault.title,
                systemImage: result.isMessageOutcome ? "text.bubble.fill" : result.categoryOrDefault.systemImage,
                tint: result.categoryOrDefault.accentColor
            )
        ]

        if let targetSunSign = result.targetSunSign {
            signals.append(
                MethodSignal(
                    label: "Their Sun",
                    detail: "\(targetSunSign.displayName) \(targetSunSign.element.rawValue)",
                    systemImage: "sun.max.fill",
                    tint: targetSunSign.color
                )
            )
        }

        if let targetMoonSign = result.targetMoonSign {
            signals.append(
                MethodSignal(
                    label: "Their Moon",
                    detail: "\(targetMoonSign.displayName) emotion",
                    systemImage: "moon.stars.fill",
                    tint: targetMoonSign.color
                )
            )
        }

        if let targetRisingSign = result.targetRisingSign {
            signals.append(
                MethodSignal(
                    label: "Their Rising",
                    detail: "\(targetRisingSign.displayName) instinct",
                    systemImage: "sparkles",
                    tint: targetRisingSign.color
                )
            )
        }

        if let userSunSign {
            signals.append(
                MethodSignal(
                    label: "Your lens",
                    detail: "\(userSunSign.displayName) Sun",
                    systemImage: "person.crop.circle.fill",
                    tint: userSunSign.color
                )
            )
        }

        if result.privacySummary != nil {
            signals.append(
                MethodSignal(
                    label: "Privacy",
                    detail: "Sensitive text reduced",
                    systemImage: "lock.shield.fill",
                    tint: SimastryColor.mutedSilver
                )
            )
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

    private func guideFollowUpCard(sign: ZodiacSign) -> some View {
        let guide = CommunicationTemplates.guides[sign]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: SimastryIconSize.md, weight: .semibold))
                    .foregroundStyle(SimastryColor.celestialBlue)

                Text("Communication tip for \(sign.displayName)")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
            }

            if let tip = guide?.tips.first {
                Text(tip)
                    .font(SimastryFont.bodyLarge)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let avoid = guide?.avoid {
                Text(avoid)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.sunCoral.opacity(0.9))
                    .lineLimit(2)
            }

            if onOpenGuide != nil {
                Button {
                    HapticManager.buttonPress()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onOpenGuide?(sign)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Read the full \(sign.displayName) guide")
                            .font(SimastryFont.labelLarge)
                        Image(systemName: "arrow.right")
                            .font(.system(size: SimastryIconSize.sm, weight: .bold))
                    }
                    .foregroundStyle(SimastryColor.celestialBlue)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .tintedGlass(SimastryColor.celestialBlue.opacity(0.10), cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(SimastryColor.celestialBlue.opacity(0.14), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var timingAndNextMoveSection: some View {
        if !result.isMessageOutcome,
           (result.timingWindow?.isEmpty == false || result.practicalNextMove?.isEmpty == false) {
            VStack(alignment: .leading, spacing: 14) {
                if let timing = result.timingWindow, !timing.isEmpty {
                    resultInsightRow(
                        title: "Most likely window",
                        body: timing,
                        systemImage: "clock.fill",
                        tint: SimastryColor.gold
                    )
                }

                if let nextMove = result.practicalNextMove, !nextMove.isEmpty {
                    resultInsightRow(
                        title: "What to do next",
                        body: nextMove,
                        systemImage: "arrow.up.forward.circle.fill",
                        tint: accentColor
                    )
                }
            }
            .padding(18)
            .simastryGlass(cornerRadius: 20)
        }
    }

    private func resultInsightRow(title: String, body: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: systemImage)
                .font(.system(size: SimastryIconSize.md, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(title.uppercased())
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.2)

                Text(body)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var whatIfSection: some View {
        if result.isMessageOutcome {
            VStack(alignment: .leading, spacing: 12) {
                Text("What if I said...")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)

                TextField(
                    "Type the message you're considering sending",
                    text: $alternativeReply,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .padding(16)
                .foregroundStyle(SimastryColor.offWhite)
                .tintedGlass(SimastryColor.risingViolet.opacity(0.2), cornerRadius: 16)

                Button {
                    HapticManager.buttonPress()
                    onRegenerate(alternativeReply)
                } label: {
                    HStack(spacing: 8) {
                        if isRegenerating {
                            ProgressView()
                                .tint(SimastryColor.midnight)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: SimastryIconSize.md, weight: .semibold))
                        }

                        Text(isRegenerating ? "Updating prediction" : "See New Response")
                            .font(SimastryFont.titleSmall)
                    }
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .goldGlassPill()
                }
                .buttonStyle(SpringPressStyle())
                .disabled(alternativeReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRegenerating)
                .opacity(alternativeReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRegenerating ? 0.5 : 1)
            }
            .padding(18)
            .simastryGlass(cornerRadius: 20)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
    }

    private var shareResultButton: some View {
        Button {
            HapticManager.buttonPress()
            AnalyticsService.shared.track(.predictionShared)
            showShareCard = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: SimastryIconSize.md, weight: .semibold))
                Text("Share Result")
                    .font(SimastryFont.titleSmall)
            }
            .foregroundStyle(SimastryColor.midnight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .goldGlassPill()
        }
        .buttonStyle(SpringPressStyle())
        .featureTip(
            icon: "square.and.arrow.up",
            title: "Share Your Reading",
            body: "Share your prediction card on Instagram or TikTok \u{2014} your friends will want their own.",
            tip: .shareCard,
            delay: 1.0
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var confidenceFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gauge.medium")
                    .font(.system(size: SimastryIconSize.md, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("\(result.confidence)% confidence - based on \(confidenceBasis)")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let reasoning = confidenceReasoningText {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: SimastryIconSize.sm, weight: .medium))
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .padding(.top, 1)

                    Text(reasoning)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 24)
            }
        }
        .padding(.bottom, 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var confidenceReasoningText: String? {
        guard result.isMessageOutcome else {
            return nil
        }
        guard let userSign = userSunSign,
              let targetSign = result.targetSunSign else {
            return nil
        }
        return AstrologyTemplates.confidenceReasoningText(
            userElement: userSign.element.rawValue,
            targetElement: targetSign.element.rawValue
        )
    }

    private var confidenceBasis: String {
        result.isMessageOutcome
            ? "message context and placement logic"
            : "chart context, question type, and timing pattern"
    }

    private var aiDisclosureBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: result.isLocalComposition == true ? "scope" : "cpu")
                .font(SimastryFont.microMedium)
                .foregroundStyle(SimastryColor.deepMuted)

            Text(result.isLocalComposition == true
                 ? "Placement logic, on device - \(AppConfig.astrologyTradition) - not a guarantee"
                 : "AI-assisted - \(AppConfig.astrologyTradition) - not a guarantee")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
    }
}
