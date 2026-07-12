import SwiftUI

/// "What each expert knows about me": the per-tradition readiness checklists
/// as one inspectable trust surface — what is on file, where it came from,
/// what stays unavailable, and where to add or remove data.
struct ExpertKnowledgeView: View {
    @Bindable var viewModel: AppViewModel
    let embeddedInNavigationStack: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var intakeSpecialist: AstrologySpecialist?

    init(viewModel: AppViewModel, embeddedInNavigationStack: Bool = false) {
        self.viewModel = viewModel
        self.embeddedInNavigationStack = embeddedInNavigationStack
    }

    var body: some View {
        Group {
            if embeddedInNavigationStack {
                knowledgeContent
            } else {
                NavigationStack {
                    knowledgeContent
                }
            }
        }
        .presentationBackground { CelestialBackground() }
        .sheet(item: $intakeSpecialist) { specialist in
            AddMissingAstrologyInfoSheet(
                viewModel: viewModel,
                specialist: specialist,
                preferredRoute: checklist(for: specialist).ctaRoute
            )
        }
        .accessibilityIdentifier("expertKnowledge.screen")
    }

    private var knowledgeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                intro

                ForEach(ExpertAstrologerRegistry.specialists) { specialist in
                    expertSection(specialist)
                }

                footer
            }
            .padding(20)
        }
        .lockHorizontalScroll()
        .background { CelestialBackground() }
        .navigationTitle("What The Experts Know")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if !embeddedInNavigationStack {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
        }
    }

    private func checklist(for specialist: AstrologySpecialist) -> ExpertReadinessChecklist {
        ExpertReadinessBuilder.checklist(
            for: specialist,
            question: nil,
            context: viewModel.currentAstrologyContext(),
            manualData: viewModel.expertManualAstrologyData
        )
    }

    private var intro: some View {
        Text("Each expert works only from what is listed here. Anything missing is treated as unavailable in every reading — never guessed.")
            .font(SimastryFont.bodySmall)
            .foregroundStyle(SimastryColor.mutedSilver)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func expertSection(_ specialist: AstrologySpecialist) -> some View {
        let readiness = checklist(for: specialist)
        // "A clear question" is consultation-scoped, not stored knowledge.
        let known = readiness.knownItems.filter { $0.dataPoint != .userQuestion }
        let missing = (readiness.missingRequiredItems + readiness.missingOptionalItems)
            .filter { $0.dataPoint != .userQuestion }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                avatar(specialist)

                VStack(alignment: .leading, spacing: 1) {
                    Text(specialist.characterName)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text(specialist.publicTitle)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.gold.opacity(0.88))
                }

                Spacer()
            }

            knowledgeGroup(
                title: "On file",
                empty: "Nothing yet — readings stay general.",
                lines: known.map { item in
                    item.source == .userSupplied
                        ? "\(item.title)\(valueSuffix(item)) · you supplied this"
                        : "\(item.title)\(valueSuffix(item))"
                }
            )

            knowledgeGroup(
                title: "Not available to \(specialist.characterName)",
                empty: "Nothing missing for this tradition.",
                lines: missing.map(\.title)
            )

            Button {
                HapticManager.buttonPress()
                intakeSpecialist = specialist
            } label: {
                Label("Add or edit details", systemImage: "plus.circle")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .goldGlassPill(interactive: true)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityIdentifier("expertKnowledge.addDetails.\(specialist.id)")
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.4))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("expertKnowledge.section.\(specialist.id)")
    }

    private func valueSuffix(_ item: AstrologyReadinessItem) -> String {
        guard let value = item.value, !value.isEmpty else { return "" }
        return ": \(value)"
    }

    private func knowledgeGroup(title: String, empty: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold.opacity(0.9))
                .tracking(1)

            if lines.isEmpty {
                Text(empty)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.deepMuted)
            } else {
                ForEach(lines.prefix(6), id: \.self) { line in
                    Text("· \(line)")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if lines.count > 6 {
                    Text("+\(lines.count - 6) more")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.deepMuted)
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("You stay in control", systemImage: "lock.shield")
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Only availability and clearly labeled user-supplied fields are sent with a consultation. Export or clear everything from Settings → Privacy & Data.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .surfaceCard(cornerRadius: 18)
    }

    @ViewBuilder
    private func avatar(_ specialist: AstrologySpecialist) -> some View {
        if let profile = specialist.archivedProfile {
            Image(profile.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40, alignment: .top)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(SimastryColor.gold.opacity(0.5), lineWidth: 0.8) }
                .accessibilityHidden(true)
        } else {
            ZStack {
                Circle().fill(SimastryColor.surfaceSunken.opacity(0.5))
                Image(systemName: specialist.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
        }
    }
}
