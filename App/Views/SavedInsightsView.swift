import SwiftUI

/// The private journal: lines the user chose to keep, attributed to the
/// expert who wrote them. Stored on this device only; rows delete
/// individually and the whole store clears with local data.
struct SavedInsightsView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    private var prompts: [SavedDailyPrompt] {
        viewModel.todayStore.savedDailyPrompts
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kept on this device only. Ask an expert to pick a line back up, or remove it for good.")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.deepMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    if prompts.isEmpty {
                        emptyState
                    } else {
                        ForEach(prompts) { prompt in
                            row(prompt)
                        }
                    }
                }
                .padding(20)
            }
            .lockHorizontalScroll()
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
        }
        .presentationBackground { CelestialBackground() }
        .accessibilityIdentifier("journal.screen")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image("EmptyJournal")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .accessibilityHidden(true)

            Text("Nothing saved yet")
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Tap the bookmark on a daily note or an expert's reply to keep the lines worth rereading.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private func row(_ prompt: SavedDailyPrompt) -> some View {
        let specialist = ExpertAstrologerRegistry.specialist(id: prompt.guideId)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                avatar(specialist)

                VStack(alignment: .leading, spacing: 1) {
                    Text(specialist?.characterName ?? "Simastry")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(1)
                    Text(prompt.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.deepMuted)
                }

                Spacer()

                Button {
                    HapticManager.buttonPress()
                    viewModel.todayStore.removeSavedPrompt(id: prompt.id)
                } label: {
                    Image(systemName: "trash")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove this saved line")
            }

            Text(prompt.text)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let specialist {
                Button {
                    HapticManager.buttonPress()
                    dismiss()
                    viewModel.openAIAstrologists(
                        question: "I saved this line from you earlier: \u{201C}\(prompt.text)\u{201D} — help me apply it today.",
                        autoRunEveryone: false,
                        specialistId: specialist.id
                    )
                } label: {
                    Label("Ask \(specialist.characterName) about this", systemImage: "sparkles")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .goldGlassPill(interactive: true)
                }
                .buttonStyle(SpringPressStyle())
            }
        }
        .padding(14)
        .surfaceCard(cornerRadius: 18, accent: SimastryColor.gold.opacity(0.3))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.entry")
    }

    @ViewBuilder
    private func avatar(_ specialist: AstrologySpecialist?) -> some View {
        if let profile = specialist?.archivedProfile {
            Image(profile.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32, alignment: .top)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(SimastryColor.gold.opacity(0.5), lineWidth: 0.8) }
                .accessibilityHidden(true)
        } else {
            ZStack {
                Circle().fill(SimastryColor.surfaceSunken.opacity(0.5))
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
            }
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)
        }
    }
}
