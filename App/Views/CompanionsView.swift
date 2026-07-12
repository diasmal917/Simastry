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
    @State private var currentCastIndex: Int = 0
    @State private var dragOffset: CGSize = .zero

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

    private var castProfiles: [FactoryCompanionProfile] {
        AppConfig.expertAstrologersEnabled
            ? ExpertAstrologerRegistry.archivedProfiles
            : FactoryCompanionCatalog.all
    }

    var body: some View {
        if AppConfig.expertAstrologersEnabled {
            ExpertAstrologersView(viewModel: viewModel)
        } else {
            legacyCompanionsDeck
        }
    }

    private var legacyCompanionsDeck: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                castDeck
            }
            .navigationTitle(AppConfig.expertAstrologersEnabled ? "Expert Astrologers" : "Guides")
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
                Text("This removes \(pendingDeleteCompanion?.name ?? "this guide") from your circle.")
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

    private var castDeck: some View {
        let profiles = castProfiles

        return GeometryReader { proxy in
            let cardHeight = min(max(proxy.size.height - SimastrySpacing.tabBarClearance - 172, 468), 570)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppConfig.expertAstrologersEnabled ? "Expert Astrologers" : "Guides")
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(AppConfig.expertAstrologersEnabled ? "Five named AI astrologers, each grounded in a distinct tradition." : "Browse the guide lens you want for Talk, Profile, and Compass.")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ZStack {
                    ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                        let relativeIndex = normalizedRelativeIndex(index, active: currentCastIndex, count: profiles.count)
                        if relativeIndex >= 0 && relativeIndex < 3 {
                            castCard(profile, height: cardHeight)
                                .scaleEffect(relativeIndex == 0 ? 1 : 1 - CGFloat(relativeIndex) * 0.045)
                                .offset(y: CGFloat(relativeIndex) * 12)
                                .opacity(relativeIndex == 0 ? 1 : 0.58)
                                .zIndex(Double(3 - relativeIndex))
                                .offset(relativeIndex == 0 ? dragOffset : .zero)
                                .rotationEffect(.degrees(relativeIndex == 0 ? Double(dragOffset.width / 24) : 0))
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            dragOffset = value.translation
                                        }
                                        .onEnded { value in
                                            let threshold: CGFloat = 95
                                            if abs(value.translation.width) > threshold {
                                                moveToNextCard()
                                            } else {
                                                withAnimation(.spring(SimastrySpring.snappy)) {
                                                    dragOffset = .zero
                                                }
                                            }
                                        }
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight + 18)
                .padding(.horizontal, 18)

                HStack(spacing: 18) {
                    castActionButton(systemImage: "xmark", label: "Next", tint: SimastryColor.mutedSilver) {
                        moveToNextCard()
                    }

                    castActionButton(systemImage: "message.fill", label: "Message", tint: SimastryColor.gold) {
                        HapticManager.buttonPress()
                        viewModel.selectedTab = .messages
                    }

                    castActionButton(systemImage: "sparkles", label: "Choose", tint: SimastryColor.sunCoral) {
                        moveToNextCard()
                    }
                }
                .padding(.bottom, SimastrySpacing.tabBarClearance + 2)
            }
        }
    }

    private func castCard(_ profile: FactoryCompanionProfile, height: CGFloat) -> some View {
        let specialist = ExpertAstrologerRegistry.specialist(for: profile)
        let title = specialist?.characterName ?? profile.name
        let role = specialist?.publicTitle ?? profile.metadataLine
        let description = specialist?.longDescription ?? profile.personalityBio
        let tags = specialist?.focusAreas.prefix(3).map(\.self) ?? profile.tags.prefix(3).map(\.self)

        return ZStack(alignment: .bottomLeading) {
            Image(profile.cardImageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height, alignment: .top)
                .clipped()

            LinearGradient(
                colors: [
                    .black.opacity(0.05),
                    .black.opacity(0.20),
                    SimastryColor.midnight.opacity(0.72),
                    SimastryColor.midnight.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(SimastryFont.displayMedium)
                        .foregroundStyle(.white)

                    if let specialist {
                        Image(systemName: specialist.symbol)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)
                    } else {
                        ZodiacIconView(sign: profile.sign, size: 32, showsGlow: true)
                    }
                }

                Text(role)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(.white.opacity(0.84))

                Text(specialist?.tradition ?? profile.headline)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(description)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineSpacing(3)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.midnight)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(SimastryColor.gold.opacity(0.92), in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    castSignalPill(systemImage: "scope", text: specialist?.publicTitle ?? "\(profile.sign.displayName) lens", tint: SimastryColor.gold)
                    castSignalPill(systemImage: "photo.fill", text: "Profile art", tint: SimastryColor.gold)
                }
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.32), radius: 22, x: 0, y: 14)
        .accessibilityLabel("\(title), \(role). \(description)")
    }

    private func castSignalPill(systemImage: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(SimastryFont.microSemibold)
                .foregroundStyle(tint)

            Text(text)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.28), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
    }

    private func castActionButton(systemImage: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.07), in: Circle())
                    .overlay(Circle().stroke(tint.opacity(0.34), lineWidth: 1))

                Text(label)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
        }
        .buttonStyle(SpringPressStyle())
    }

    private func normalizedRelativeIndex(_ index: Int, active: Int, count: Int) -> Int {
        let normalizedActive = active % count
        return index >= normalizedActive ? index - normalizedActive : count - normalizedActive + index
    }

    private func moveToNextCard() {
        HapticManager.buttonPress()
        withAnimation(.spring(SimastrySpring.snappy)) {
            dragOffset = .zero
            currentCastIndex = (currentCastIndex + 1) % max(castProfiles.count, 1)
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
                Text("Your guide is waiting")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(personalizedCompanionsEmptyText)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            GoldButton(viewModel.hasCompletedSigns ? "Choose a Guide" : "Set Up Your Signs") {
                viewModel.selectedTab = .today
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
                if FeatureTipManager.shared.shouldShow(.companionDetail) {
                    FeatureTipView(
                        icon: "chart.bar.fill",
                        title: "Tap for Details",
                        message: "Tap any companion to see why you\u{2019}re compatible, with a breakdown of your Sun, Moon, and Rising connections.",
                        tip: .companionDetail
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                }

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
                sectionLabel(viewModel.companions.count > 1 ? "Your Circle" : "Your Guide")
            }

            Section {
                Button {
                    viewModel.selectedTab = .today
                    viewModel.homeSetupPhase = .modeSelection
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(SimastryColor.gold)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Choose a New Guide")
                                .font(SimastryFont.titleSmall)
                                .foregroundStyle(SimastryColor.offWhite)

                            Text("Shape a new guide, friend, or simulation lens")
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
        .simastryGlass(cornerRadius: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            SimastryColor.gold.opacity(0.36),
                            SimastryColor.gold.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
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
                    title: "Open Messages",
                    subtitle: "Continue with \(companion.name) in your private inbox.",
                    systemImage: "message.fill",
                    tint: SimastryColor.celestialBlue
                ) {
                    viewModel.selectedTab = .messages
                }
                .frame(width: 230)

                quickActionCard(
                    title: "Show Lens",
                    subtitle: "See the sign logic behind \(companion.name)'s tone and timing.",
                    systemImage: "moon.stars.fill",
                    tint: SimastryColor.celestialBlue
                ) {
                    activeSheet = .detail(companion)
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

    private var personalizedCompanionsEmptyText: String {
        if let signKey = viewModel.userSunSign?.rawValue,
           let personalized = AstrologyTemplates.personalizedEmptyStates[signKey]?["companions"] {
            return personalized
        }
        return viewModel.hasCompletedSigns ? "Create your first companion to begin" : "Complete your signs to begin"
    }

    private func sendSpark(to companion: CompanionData) async {
        await viewModel.recordCompanionInteraction(
            with: companion,
            title: "Spark sent",
            subtitle: ritualLine(for: companion)
        )
    }
}
