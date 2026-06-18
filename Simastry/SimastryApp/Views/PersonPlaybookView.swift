import SwiftUI

/// Situation-based communication playbook for one person — the
/// "communication styles, not predictions" feature.
struct PersonPlaybookSection: View {
    @Bindable var viewModel: AppViewModel
    let person: RelationshipPerson

    @State private var selectedSituation: PlaybookSituation?
    @State private var copiedScript: Bool = false
    @State private var llmScript: String?
    @State private var llmTask: Task<Void, Never>?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    private var variantSeed: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
    }

    private var playbook: Playbook? {
        guard let selectedSituation else { return nil }
        return PlaybookComposer.playbook(
            situation: selectedSituation,
            personName: person.displayName,
            sun: person.sunSign,
            moon: person.moonSign,
            relationshipType: person.relationshipType,
            userSun: viewModel.userSunSign,
            variantSeed: variantSeed
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    Text("PLAYBOOK")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.5)
                }

                Text("Communication styles, not predictions")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.deepMuted)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(PlaybookSituation.allCases) { situation in
                    situationChip(situation)
                }
            }

            if let playbook {
                playbookCard(playbook)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text("The same playbook an NBA captain runs on his locker room — signs as a memory system for how people communicate.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.gold.opacity(0.6))
        .animation(.spring(SimastrySpring.smooth), value: selectedSituation)
        .onAppear {
            #if DEBUG
            if viewModel.isDebugPreviewStateActive, selectedSituation == nil {
                selectedSituation = .giveFeedback
            }
            #endif
        }
        .onChange(of: selectedSituation) {
            copiedScript = false
            llmScript = nil
            llmTask?.cancel()
            if let selectedSituation {
                llmTask = Task {
                    let generated = await viewModel.generatePlaybookViaLLM(
                        person: person,
                        situation: selectedSituation
                    )
                    if !Task.isCancelled, let generated {
                        llmScript = generated
                    }
                }
            }
        }
        .onDisappear {
            llmTask?.cancel()
        }
    }

    private func situationChip(_ situation: PlaybookSituation) -> some View {
        let isSelected = selectedSituation == situation

        return Button {
            HapticManager.buttonPress()
            selectedSituation = isSelected ? nil : situation
        } label: {
            HStack(spacing: 6) {
                Image(systemName: situation.systemImage)
                    .font(.system(size: 11, weight: .semibold))

                Text(situation.title)
                    .font(SimastryFont.labelSmall)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.86))
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? AnyShapeStyle(SimastryGradient.gold)
                    : AnyShapeStyle(Color.white.opacity(0.06)),
                in: Capsule()
            )
            .overlay {
                Capsule().strokeBorder(
                    isSelected ? .white.opacity(0.22) : .white.opacity(0.08),
                    lineWidth: 0.6
                )
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(situation.title) playbook")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func playbookCard(_ playbook: Playbook) -> some View {
        let script = llmScript ?? playbook.script

        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("SAY SOMETHING LIKE")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.2)

                Spacer()

                Button {
                    HapticManager.buttonPress()
                    UIPasteboard.general.string = script
                    copiedScript = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        copiedScript = false
                    }
                } label: {
                    Label(copiedScript ? "Copied" : "Copy", systemImage: copiedScript ? "checkmark" : "doc.on.doc")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(SimastryColor.gold.opacity(0.12), in: Capsule())
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel(copiedScript ? "Script copied" : "Copy script")
            }

            Text(script)
                .font(.system(.body, design: .serif))
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)

            VStack(alignment: .leading, spacing: 5) {
                Text("WHY THIS WORKS")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(1)

                Text(playbook.whyItWorks)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.82))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SimastryColor.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("AVOID")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.amber)
                    .tracking(1)

                Text(playbook.avoid)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.74))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SimastryColor.amber.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 5) {
                Image(systemName: llmScript == nil ? "iphone" : "sparkles")
                    .font(.system(size: 9, weight: .medium))
                Text(llmScript == nil ? "Placement logic, on device" : "AI-assisted, chart-grounded")
                    .font(SimastryFont.captionSmall)
            }
            .foregroundStyle(SimastryColor.textTertiary)
        }
        .padding(16)
        .glossyCard(cornerRadius: 20)
        .animation(.spring(SimastrySpring.smooth), value: llmScript)
    }
}
