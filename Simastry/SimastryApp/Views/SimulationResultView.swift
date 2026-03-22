import SwiftUI

struct SimulationResultView: View {
    let result: PredictionResult
    let isRegenerating: Bool
    let onRegenerate: (String) -> Void
    var onOpenGuide: ((ZodiacSign) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var alternativeReply: String = ""

    private var accentColor: Color {
        result.targetSunSign?.color ?? SimastryColor.risingViolet
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    predictionBubble
                    breakdownSection
                    if let sign = result.targetSunSign {
                        guideFollowUpCard(sign: sign)
                    }
                    whatIfSection
                    confidenceFooter
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
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .onChange(of: result.id) { _, _ in
            alternativeReply = ""
        }
    }

    private var predictionBubble: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The stars say they'll text:")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.4)
                .textCase(.uppercase)

            HStack(alignment: .bottom, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Text(result.targetSunSign?.glyph ?? "✦")
                        .font(.system(size: 18))
                        .foregroundStyle(SimastryColor.offWhite)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(result.predictedMessage)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let tone = result.tone {
                        Text(tone.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(accentColor.opacity(0.14), in: .capsule)
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
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why they'd say this")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SimastryColor.offWhite)

            Text(result.astrologicalBreakdown)
                .font(.system(.body, design: .serif))
                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                .lineSpacing(4)
        }
        .padding(18)
        .goldGlassRect(cornerRadius: 20)
    }

    private func guideFollowUpCard(sign: ZodiacSign) -> some View {
        let guide = CommunicationTemplates.guides[sign]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.celestialBlue)

                Text("Communication tip for \(sign.displayName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)
            }

            if let tip = guide?.tips.first {
                Text(tip)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let avoid = guide?.avoid {
                Text(avoid)
                    .font(.system(size: 13))
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
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
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

    private var whatIfSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What if I said…")
                .font(.system(size: 17, weight: .semibold))
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
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Text(isRegenerating ? "Re-reading the timeline" : "See New Response")
                        .font(.system(size: 15, weight: .semibold))
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
    }

    private var confidenceFooter: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.medium")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)

            Text("\(result.confidence)% confidence — based on conversational patterns and astrological alignment")
                .font(.system(size: 13))
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }
}
