import SwiftUI
import UIKit

struct SimulationResultView: View {
    let result: PredictionResult
    var userSunSign: ZodiacSign?
    var onSaveFollowUp: ((ReadingFollowUp) -> Void)?
    var onSetHelpfulness: ((ReadingHelpfulness?) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showShareCard = false
    @State private var appeared = false
    @State private var copiedSuggestion = false
    @State private var replyReceived: Bool?
    @State private var elapsedMinutes: Int?
    @State private var toneSimilarity: ReplyToneSimilarity?
    @State private var helpfulness: ReadingHelpfulness?
    @AccessibilityFocusState private var takeawayFocused: Bool

    private var verifiedTiming: String? {
        guard result.evidence?.contains(where: {
            $0.basis == .calculated && $0.supportsTiming
        }) == true else { return nil }
        return result.timingWindow?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private var readingEvidence: [ReadingEvidence] {
        guard let evidence = result.evidence, !evidence.isEmpty else {
            return [ReadingEvidence(
                basis: .generalLens,
                label: "Legacy reading",
                detail: "Evidence labels were not stored with this earlier reading."
            )]
        }
        return evidence
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SimastrySpacing.lg) {
                    reveal(takeawaySection, step: 0)
                    reveal(practicalSections, step: 1)
                    reveal(evidenceAndReasoning, step: 2)

                    if let safetyNote = result.safetyNote?.nilIfEmpty {
                        Label(safetyNote, systemImage: "exclamationmark.shield")
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if result.isMessageOutcome, onSaveFollowUp != nil {
                        objectiveFollowUpSection
                    }

                    if onSetHelpfulness != nil {
                        helpfulnessSection
                    }

                    disclosureFooter
                }
                .padding(.horizontal, SimastrySpacing.lg)
                .padding(.top, SimastrySpacing.lg)
                .padding(.bottom, SimastrySpacing.xxl)
            }
            .background { CelestialBackground() }
            .navigationTitle("Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.buttonPress()
                        AnalyticsService.shared.track(.predictionShared)
                        showShareCard = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share reading")
                }
            }
            .sheet(isPresented: $showShareCard) {
                SimulationShareCardView(result: result, userSunSign: userSunSign)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .accessibilityAction(.escape) { dismiss() }
        .task {
            replyReceived = result.followUp?.replyReceived
            elapsedMinutes = result.followUp?.elapsedMinutes
            toneSimilarity = result.followUp?.toneSimilarity
            helpfulness = result.helpfulness
            appeared = true
            try? await Task.sleep(for: .milliseconds(250))
            takeawayFocused = true
        }
    }

    private func reveal(_ view: some View, step: Int) -> some View {
        view
            .opacity(appeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (appeared ? 0 : 10))
            .animation(
                .easeOut(duration: reduceMotion ? 0.15 : 0.20)
                    .delay(Double(step) * 0.05),
                value: appeared
            )
    }

    private var takeawaySection: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            HStack {
                Text("TAKEAWAY")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(1.3)
                Spacer()
                Text(result.contextQuality?.title ?? "Legacy context")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            Text(result.displayAnswer)
                .font(SimastryFont.titleLarge)
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let verifiedTiming {
                Label(verifiedTiming, systemImage: "clock.badge.checkmark")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.gold)
            }
        }
        .padding(SimastrySpacing.lg)
        .contentSurface(cornerRadius: SimastryRadius.card, accent: SimastryColor.gold)
        .accessibilityElement(children: .combine)
        .accessibilityFocused($takeawayFocused)
    }

    private var practicalSections: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            if let nextMove = result.practicalNextMove?.nilIfEmpty {
                ResultInsightCard(
                    title: "Next move",
                    content: nextMove,
                    systemImage: "arrow.up.forward.circle.fill",
                    tint: SimastryColor.sageGreen
                )
            }

            if let alternative = result.plausibleAlternative?.nilIfEmpty {
                ResultInsightCard(
                    title: "Another possibility",
                    content: alternative,
                    systemImage: "arrow.triangle.branch",
                    tint: SimastryColor.celestialBlue
                )
            }

            if let suggestedReply = result.suggestedReply?.nilIfEmpty {
                suggestedReplyCard(suggestedReply)
            }
        }
    }

    private func suggestedReplyCard(_ suggestion: String) -> some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            HStack {
                Label("Suggested reply", systemImage: "arrowshape.turn.up.left.fill")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Spacer()
                Button {
                    UIPasteboard.general.string = suggestion
                    copiedSuggestion = true
                    HapticManager.buttonPress()
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copiedSuggestion = false
                    }
                } label: {
                    Label(copiedSuggestion ? "Copied" : "Copy", systemImage: copiedSuggestion ? "checkmark" : "doc.on.doc")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.gold)
                        .frame(minHeight: 44)
                }
                .buttonStyle(CompassPressStyle())
            }

            Text(suggestion)
                .font(SimastryFont.bodyLarge)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SimastrySpacing.md)
        .contentSurface(cornerRadius: SimastryRadius.large, accent: SimastryColor.gold.opacity(0.7))
    }

    private var evidenceAndReasoning: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            Text("EVIDENCE")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.3)

            ForEach(readingEvidence) { evidence in
                HStack(alignment: .top, spacing: SimastrySpacing.sm) {
                    Image(systemName: evidenceIcon(evidence.basis))
                        .foregroundStyle(evidenceColor(evidence.basis))
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: SimastrySpacing.xxs) {
                        Text(evidence.basis.title)
                            .font(SimastryFont.overline)
                            .foregroundStyle(evidenceColor(evidence.basis))
                        Text(evidence.label)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                        Text(evidence.detail)
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(SimastrySpacing.sm)
                .background(SimastryColor.surfaceSunken, in: RoundedRectangle(cornerRadius: SimastryRadius.small))
            }

            DisclosureGroup {
                Text(result.astrologicalBreakdown)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, SimastrySpacing.sm)
            } label: {
                Text("Why this reading")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                    .frame(minHeight: 44)
            }
            .tint(SimastryColor.gold)
        }
        .padding(SimastrySpacing.md)
        .contentSurface(cornerRadius: SimastryRadius.large)
    }

    private var objectiveFollowUpSection: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.md) {
            VStack(alignment: .leading, spacing: SimastrySpacing.xxs) {
                Text("What happened?")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text("This records an outcome. It is separate from whether the guidance felt helpful.")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Did a reply arrive?")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)

            HStack(spacing: SimastrySpacing.xs) {
                outcomeChoice("Yes", selected: replyReceived == true) { replyReceived = true }
                outcomeChoice("Not yet", selected: replyReceived == false) { replyReceived = false }
            }

            if replyReceived == true {
                Menu {
                    ForEach(ElapsedReplyOption.allCases) { option in
                        Button(option.title) { elapsedMinutes = option.minutes }
                    }
                } label: {
                    resultMenuLabel(
                        title: "Elapsed time",
                        value: ElapsedReplyOption(minutes: elapsedMinutes)?.title ?? "Add if known"
                    )
                }

                Text("Was the tone similar?")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                HStack(spacing: SimastrySpacing.xs) {
                    ForEach(ReplyToneSimilarity.allCases, id: \.rawValue) { similarity in
                        outcomeChoice(
                            similarity.title,
                            selected: toneSimilarity == similarity
                        ) { toneSimilarity = similarity }
                    }
                }
            }

            Button {
                let followUp = ReadingFollowUp(
                    replyReceived: replyReceived,
                    elapsedMinutes: elapsedMinutes,
                    toneSimilarity: toneSimilarity
                )
                onSaveFollowUp?(followUp)
                HapticManager.soulFlash()
            } label: {
                Text("Save check-in")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(SimastryColor.gold, in: Capsule())
            }
            .buttonStyle(CompassPressStyle())
            .disabled(replyReceived == nil)
            .opacity(replyReceived == nil ? 0.45 : 1)
        }
        .padding(SimastrySpacing.md)
        .contentSurface(cornerRadius: SimastryRadius.large, accent: SimastryColor.celestialBlue.opacity(0.7))
    }

    private var helpfulnessSection: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            Text("Was this useful?")
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)
            Text("Your answer is saved with this reading. Simastry does not claim it retrains or improves prediction accuracy.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: SimastrySpacing.xs) {
                helpfulnessChoice(.helpful, icon: "hand.thumbsup")
                helpfulnessChoice(.notHelpful, icon: "hand.thumbsdown")
            }
        }
        .padding(SimastrySpacing.md)
        .contentSurface(cornerRadius: SimastryRadius.large)
    }

    private func helpfulnessChoice(_ value: ReadingHelpfulness, icon: String) -> some View {
        Button {
            helpfulness = helpfulness == value ? nil : value
            onSetHelpfulness?(helpfulness)
            HapticManager.zodiacSelection()
        } label: {
            Label(value.title, systemImage: icon)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(helpfulness == value ? SimastryColor.midnight : SimastryColor.offWhite)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(helpfulness == value ? SimastryColor.gold : SimastryColor.surfaceSunken, in: Capsule())
        }
        .buttonStyle(CompassPressStyle())
        .accessibilityAddTraits(helpfulness == value ? .isSelected : [])
    }

    private func outcomeChoice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(selected ? SimastryColor.midnight : SimastryColor.offWhite)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? SimastryColor.gold : SimastryColor.surfaceSunken, in: Capsule())
        }
        .buttonStyle(CompassPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func resultMenuLabel(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(SimastryColor.mutedSilver)
            Spacer()
            Text(value)
                .foregroundStyle(SimastryColor.offWhite)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(SimastryColor.deepMuted)
        }
        .font(SimastryFont.labelLarge)
        .padding(.horizontal, SimastrySpacing.sm)
        .frame(minHeight: 44)
        .background(SimastryColor.surfaceSunken, in: RoundedRectangle(cornerRadius: SimastryRadius.small))
    }

    private var disclosureFooter: some View {
        Label(
            result.isLocalComposition == true
                ? "On-device reflective fallback. No forecast was calculated."
                : "AI-generated interpretation based only on the labeled evidence and context above.",
            systemImage: "info.circle"
        )
        .font(SimastryFont.captionSmall)
        .foregroundStyle(SimastryColor.deepMuted)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private func evidenceIcon(_ basis: ReadingEvidenceBasis) -> String {
        switch basis {
        case .calculated: "function"
        case .userConfirmed: "person.badge.shield.checkmark"
        case .generalLens: "text.magnifyingglass"
        }
    }

    private func evidenceColor(_ basis: ReadingEvidenceBasis) -> Color {
        switch basis {
        case .calculated: SimastryColor.sageGreen
        case .userConfirmed: SimastryColor.celestialBlue
        case .generalLens: SimastryColor.mutedSilver
        }
    }
}

private struct ResultInsightCard: View {
    let title: String
    let content: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: SimastrySpacing.sm) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: SimastrySpacing.xxs) {
                Text(title)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text(content)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SimastrySpacing.md)
        .contentSurface(cornerRadius: SimastryRadius.large, accent: tint.opacity(0.7))
    }
}

private enum ElapsedReplyOption: CaseIterable, Identifiable {
    case minutes5, minutes15, hour1, hours4, day1, longer

    var id: Int { minutes }
    var minutes: Int {
        switch self {
        case .minutes5: 5
        case .minutes15: 15
        case .hour1: 60
        case .hours4: 240
        case .day1: 1_440
        case .longer: 2_880
        }
    }

    var title: String {
        switch self {
        case .minutes5: "Within 5 minutes"
        case .minutes15: "Within 15 minutes"
        case .hour1: "Within an hour"
        case .hours4: "Within 4 hours"
        case .day1: "Within a day"
        case .longer: "Longer than a day"
        }
    }

    init?(minutes: Int?) {
        guard let minutes,
              let value = Self.allCases.first(where: { $0.minutes == minutes }) else { return nil }
        self = value
    }
}

extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
