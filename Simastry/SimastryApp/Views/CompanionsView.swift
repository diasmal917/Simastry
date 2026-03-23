import SwiftUI

nonisolated private enum CompanionsSheet: Identifiable {
    case detail(CompanionData)
    case share(CompanionData)

    var id: String {
        switch self {
        case .detail(let companion):
            "detail_\(companion.id.uuidString)"
        case .share(let companion):
            "share_\(companion.id.uuidString)"
        }
    }
}

struct CompanionsView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var activeSheet: CompanionsSheet?
    @State private var pendingDeleteCompanion: CompanionData?

    private var deleteDialogIsPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteCompanion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteCompanion = nil
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                if viewModel.companions.isEmpty {
                    companionPlaceholder
                } else {
                    companionDashboard
                }
            }
            .navigationTitle("Companions")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .detail(let companion):
                    CompanionDetailSheet(companion: companion, viewModel: viewModel)
                case .share(let companion):
                    ShareableCardView(viewModel: viewModel, cardType: .compatibility, companion: companion)
                }
            }
            .confirmationDialog(
                "Remove Companion",
                isPresented: deleteDialogIsPresented,
                titleVisibility: .visible
            ) {
                if let pendingDeleteCompanion {
                    Button("Delete \(pendingDeleteCompanion.name)", role: .destructive) {
                        Task {
                            await viewModel.deleteCompanion(pendingDeleteCompanion)
                            self.pendingDeleteCompanion = nil
                        }
                    }
                }

                Button("Cancel", role: .cancel) {
                    pendingDeleteCompanion = nil
                }
            } message: {
                Text("This removes \(pendingDeleteCompanion?.name ?? "this companion") from your circle.")
            }
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.spring(SimastrySpring.smooth).delay(0.1)) {
                        appeared = true
                    }
                }
            }
        }
    }

    private var companionPlaceholder: some View {
        VStack(spacing: 24) {
            Spacer()

            GlossyOrbView(
                signColors: [
                    SimastryColor.placeholderLight,
                    SimastryColor.placeholderDark
                ],
                state: .idle,
                size: 90
            )
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)

            VStack(spacing: 8) {
                Text("Your companion is waiting")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(viewModel.hasCompletedSigns ? "Create your first companion to begin" : "Complete your signs to begin")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            GoldButton(viewModel.hasCompletedSigns ? "Create Companion" : "Set Up Your Signs") {
                viewModel.selectedTab = 0
                if viewModel.hasCompletedSigns {
                    viewModel.homeSetupPhase = .modeSelection
                }
            }
            .padding(.horizontal, 40)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)

            Spacer()
        }
    }

    private var companionDashboard: some View {
        List {
            if let primaryCompanion = viewModel.primaryCompanion {
                Section {
                    featuredCompanionCard(primaryCompanion)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                }

                Section {
                    quickActions(primaryCompanion)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                } header: {
                    sectionLabel("Tonight's Orbit")
                }
            }

            Section {
                ForEach(viewModel.companions) { companion in
                    companionRow(companion)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                Task {
                                    await sendSpark(to: companion)
                                }
                            } label: {
                                Label("Spark", systemImage: "sparkles")
                            }
                            .tint(SimastryColor.gold)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                activeSheet = .share(companion)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                pendingDeleteCompanion = companion
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                sectionLabel(viewModel.companions.count > 1 ? "Your Circle" : "Your Companion")
            }

            Section {
                Button {
                    viewModel.selectedTab = 0
                    viewModel.homeSetupPhase = .modeSelection
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(SimastryColor.gold)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Create New Companion")
                                .font(SimastryFont.titleSmall)
                                .foregroundStyle(SimastryColor.offWhite)

                            Text("Shape a new soulmate, bestie, or simulation")
                                .font(SimastryFont.labelMedium)
                                .foregroundStyle(SimastryColor.mutedSilver)
                        }

                        Spacer()
                    }
                    .padding(18)
                    .simastryGlass(cornerRadius: 18)
                }
                .buttonStyle(SpringPressStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: SimastrySpacing.tabBarClearance, trailing: 20))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            await viewModel.refreshDashboardData()
        }
    }

    private func featuredCompanionCard(_ companion: CompanionData) -> some View {
        let level = RelationshipLevel.from(messageCount: companion.conversationCount)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                GlossyOrbView(
                    signColors: [
                        ZodiacSign(rawValue: companion.sunSign)?.color ?? SimastryColor.gold,
                        ZodiacSign(rawValue: companion.moonSign)?.color ?? SimastryColor.celestialBlue
                    ],
                    state: .idle,
                    size: 72
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(companion.name)
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(companion.mode.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.gold)
                        .tracking(1.4)
                        .textCase(.uppercase)

                    Text(companionStatusLine(companion))
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                CompatibilityRingView(score: companion.compatibilityScore, size: 68)
                    .accessibilityLabel("\(companion.compatibilityScore) percent compatible")
            }

            HStack(spacing: 10) {
                statPill(title: level.name, systemImage: "heart.fill")
                statPill(title: "\(companion.conversationCount) sparks", systemImage: "message.fill")
                statPill(title: nextMilestoneText(companion), systemImage: "arrow.up.forward")
            }

            Text(ritualLine(for: companion))
                .font(SimastryFont.bodyLarge)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            GoldButton("Send a Spark") {
                Task {
                    await sendSpark(to: companion)
                }
            }

            HStack {
                Button {
                    activeSheet = .detail(companion)
                } label: {
                    Label("Open Details", systemImage: "chart.xyaxis.line")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                }
                .buttonStyle(SpringPressStyle())

                Spacer()

                Button {
                    activeSheet = .share(companion)
                } label: {
                    Label("Share Match", systemImage: "square.and.arrow.up")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.gold)
                }
                .buttonStyle(SpringPressStyle())
            }
        }
        .padding(20)
        .goldGlassRect(cornerRadius: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(SimastryColor.gold.opacity(0.16), lineWidth: 1)
        }
        .accessibilityLabel("\(companion.name), featured companion")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    private func quickActions(_ companion: CompanionData) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                quickActionCard(
                    title: "Send a Spark",
                    subtitle: "Give \(companion.name) a little attention right now.",
                    systemImage: "sparkles",
                    tint: SimastryColor.gold
                ) {
                    Task {
                        await sendSpark(to: companion)
                    }
                }
                .frame(width: 220)

                quickActionCard(
                    title: "Pull a Reading",
                    subtitle: ritualLine(for: companion),
                    systemImage: "moon.stars.fill",
                    tint: SimastryColor.celestialBlue
                ) {
                    viewModel.showToast("Tonight's reading", subtitle: ritualLine(for: companion), isError: false)
                }
                .frame(width: 240)

                quickActionCard(
                    title: "Share Match",
                    subtitle: "Turn your current compatibility into a polished share card.",
                    systemImage: "square.and.arrow.up",
                    tint: SimastryColor.risingViolet
                ) {
                    activeSheet = .share(companion)
                }
                .frame(width: 230)
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 0)
    }

    private func quickActionCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.18), in: .rect(cornerRadius: 12))

                Text(title)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(subtitle)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 168)
            .padding(18)
            .simastryGlass(cornerRadius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
    }

    private func companionRow(_ companion: CompanionData) -> some View {
        let level = RelationshipLevel.from(messageCount: companion.conversationCount)

        return Button {
            activeSheet = .detail(companion)
        } label: {
            HStack(spacing: 14) {
                GlossyOrbView(
                    signColors: [
                        ZodiacSign(rawValue: companion.sunSign)?.color ?? SimastryColor.gold,
                        ZodiacSign(rawValue: companion.moonSign)?.color ?? SimastryColor.celestialBlue
                    ],
                    state: .idle,
                    size: 52
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(companion.name)
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text(level.name)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.midnight)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(SimastryColor.gold, in: .capsule)
                    }

                    Text(companionStatusLine(companion))
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let sun = ZodiacSign(rawValue: companion.sunSign) {
                            ZodiacBadgeView(sign: sun, isSelected: false, size: 22)
                        }
                        if let moon = ZodiacSign(rawValue: companion.moonSign) {
                            ZodiacBadgeView(sign: moon, isSelected: false, size: 22)
                        }
                        if let rising = ZodiacSign(rawValue: companion.risingSign) {
                            ZodiacBadgeView(sign: rising, isSelected: false, size: 22)
                        }
                    }
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 8) {
                    CompatibilityRingView(score: companion.compatibilityScore, size: 52)
                        .accessibilityLabel("\(companion.compatibilityScore) percent compatible")

                    Text("\(companion.conversationCount) sparks")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .padding(18)
            .simastryGlass(cornerRadius: 20)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(companion.name), \(level.name), \(companion.compatibilityScore) percent compatible, \(companion.conversationCount) sparks")
    }

    private func statPill(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(SimastryFont.labelSmall)
                .lineLimit(1)
        }
        .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.06), in: .capsule)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(SimastryFont.overline)
            .foregroundStyle(SimastryColor.mutedSilver)
            .tracking(2)
            .textCase(.uppercase)
    }

    private func companionStatusLine(_ companion: CompanionData) -> String {
        let level = RelationshipLevel.from(messageCount: companion.conversationCount)
        if companion.conversationCount == 0 {
            return "Freshly created and ready for your first spark."
        }

        if let firstConversationAt = companion.firstConversationAt {
            return "\(level.name) bond • active since \(firstConversationAt.formatted(.dateTime.month(.abbreviated).day()))"
        }

        return "\(level.name) bond • \(companion.conversationCount) sparks exchanged"
    }

    private func nextMilestoneText(_ companion: CompanionData) -> String {
        let level = RelationshipLevel.from(messageCount: companion.conversationCount)
        guard let nextThreshold = level.nextThreshold,
              let nextLevel = RelationshipLevel(rawValue: level.rawValue + 1) else {
            return "Soulbound"
        }

        let remaining = max(nextThreshold - companion.conversationCount, 0)
        return remaining == 0 ? nextLevel.name : "\(remaining) to \(nextLevel.name)"
    }

    private func ritualLine(for companion: CompanionData) -> String {
        let sunLine = AstrologyTemplates.sunSign[companion.sunSign] ?? "A vivid personality is beginning to take shape."
        let moonLine = AstrologyTemplates.moonSign[companion.moonSign] ?? "Their emotional world is opening gently."
        return "\(sunLine). \(moonLine)"
    }

    private func sendSpark(to companion: CompanionData) async {
        await viewModel.recordCompanionInteraction(
            with: companion,
            title: "Spark sent",
            subtitle: ritualLine(for: companion)
        )
    }
}
