import SwiftUI

/// The 1am protocol: read the message you're about to send, then seal it
/// until morning instead of sending it into the night. Compose mode when
/// `existingDraft` is nil; reread mode otherwise.
struct SealedDraftView: View {
    @Bindable var viewModel: AppViewModel
    var existingDraft: SealedDraft?
    var onChange: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String = ""
    @State private var targetSign: ZodiacSign?
    @State private var copied: Bool = false

    private let store = SealedDraftStore()

    private var isReread: Bool { existingDraft != nil }

    private var toneRead: String {
        let key = targetSign?.element.rawValue ?? "general"
        return AstrologyTemplates.draftToneRead[key] ?? AstrologyTemplates.draftToneRead["general"] ?? ""
    }

    private var cleanerTip: String {
        let key = targetSign?.element.rawValue ?? "general"
        return AstrologyTemplates.draftCleanerTips[key] ?? AstrologyTemplates.draftCleanerTips["general"] ?? ""
    }

    private var nightLine: String {
        if let moon = viewModel.userMoonSign {
            return "Your \(moon.displayName) Moon is loudest at night — morning eyes see clearer."
        }
        return "The Moon is loudest at night — morning eyes see clearer."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if isReread {
                            rereadContent
                        } else {
                            composeContent
                        }

                        Text("Drafts are stored only on this iPhone — nothing is sent or uploaded.")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(isReread ? "Morning Eyes" : "Before You Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
            .onAppear {
                if let existingDraft {
                    draftText = existingDraft.text
                    targetSign = existingDraft.targetSign
                }
            }
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Compose

    @ViewBuilder
    private var composeContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(SealedDraftStore.isLateNight() ? nightLine : "Read it once with company before it goes.")
                .font(.system(.subheadline, design: .serif))
                .italic()
                .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroGlass(SimastryColor.celestialBlue, cornerRadius: 20)

        VStack(alignment: .leading, spacing: 10) {
            Text("THE MESSAGE YOU'RE HOLDING")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            TextEditor(text: $draftText)
                .scrollContentBackground(.hidden)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .frame(minHeight: 110)
                .padding(10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: SimastryRadius.medium, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)

        signPicker

        if !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            toneReadCard
                .transition(.opacity.combined(with: .move(edge: .top)))

            GoldButton("Seal until morning") {
                seal()
            }

            Button {
                HapticManager.buttonPress()
                UIPasteboard.general.string = draftText
                copied = true
            } label: {
                Text(copied ? "Copied — send it with daylight standards" : "Copy and send anyway")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private var signPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THEIR SIGN (OPTIONAL)")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ZodiacSign.allCases) { sign in
                        VStack(spacing: 5) {
                            ZodiacBadgeView(sign: sign, isSelected: targetSign == sign, size: 40) {
                                withAnimation(.spring(SimastrySpring.snappy)) {
                                    targetSign = targetSign == sign ? nil : sign
                                }
                            }
                            .accessibilityLabel("Read the draft for a \(sign.displayName)")

                            Text(sign.displayName)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(targetSign == sign ? SimastryColor.offWhite : SimastryColor.mutedSilver)
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

    private var toneReadCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "waveform")
                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("WHAT IT READS AS")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            Text(toneRead)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("THE CLEANER VERSION")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(1)

                Text(cleanerTip)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.82))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SimastryColor.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
    }

    private func seal() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let releaseAt = SealedDraftStore.nextMorningRelease(after: Date())
        store.add(SealedDraft(text: trimmed, targetSign: targetSign, releaseAt: releaseAt))
        viewModel.notificationService.scheduleSealedDraftRelease(at: releaseAt)

        HapticManager.soulFlash()
        viewModel.showToast("Sealed until morning", subtitle: "Morning eyes see clearer", isError: false)
        onChange()
        dismiss()
    }

    // MARK: - Reread

    @ViewBuilder
    private var rereadContent: some View {
        if let existingDraft {
            VStack(alignment: .leading, spacing: 6) {
                Text(existingDraft.isReleased()
                     ? "Still true in daylight?"
                     : "Sealed — unseals at 8:30 tomorrow morning.")
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroGlass(SimastryColor.gold, cornerRadius: 20)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("YOUR DRAFT")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.3)

                    Spacer()

                    if let sign = existingDraft.targetSign {
                        ZodiacIconView(sign: sign, size: 20, showsGlow: false)
                    }
                }

                Text(existingDraft.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(cornerRadius: 20)

            if existingDraft.isReleased() {
                GoldButton("Copy — it held up") {
                    UIPasteboard.general.string = existingDraft.text
                    HapticManager.soulFlash()
                    viewModel.showToast("Copied", subtitle: "Send it with daylight standards", isError: false)
                }
            }

            Button {
                HapticManager.buttonPress()
                store.delete(id: existingDraft.id)
                onChange()
                viewModel.showToast("Draft let go", subtitle: "Night-you would be proud", isError: false)
                dismiss()
            } label: {
                Text("Let it go")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .simastryGlassPill()
            }
            .buttonStyle(SpringPressStyle())
        }
    }
}
