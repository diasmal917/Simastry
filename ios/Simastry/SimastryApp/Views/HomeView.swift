import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @StateObject private var streakManager = StreakManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var isLoading: Bool = true
    @State private var showStreakMilestone: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                Group {
                    switch viewModel.homeSetupPhase {
                    case .modeSelection:
                        ModeSelectionView(viewModel: viewModel)
                    case .signSelection:
                        SignSelectionView(viewModel: viewModel)
                    case .onboardingInsight:
                        OnboardingInsightView(viewModel: viewModel)
                    case .companionSetup:
                        CompanionSetupView(viewModel: viewModel)
                    case .soulCreation:
                        SoulCreationView(viewModel: viewModel)
                    case .complete:
                        homeContent
                    }
                }
                .animation(.spring(SimastrySpring.smooth), value: viewModel.homeSetupPhase == .complete)
            }
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 16)

                greetingSection

                streakPill

                if let companion = viewModel.primaryCompanion,
                   let companionSign = ZodiacSign(rawValue: companion.sunSign) {
                    communicationFocusCard(companionName: companion.name, companionSign: companionSign)
                }

                featureGrid

                didYouKnowCard

                if let companion = viewModel.primaryCompanion {
                    companionCard(companion)
                }

                if let sun = viewModel.userSunSign {
                    todayEnergyCard(sun: sun)
                }

                Spacer().frame(height: SimastrySpacing.tabBarClearance)
            }
            .padding(.horizontal, 20)
            .onAppear {
                streakManager.recordCheckIn()
                AnalyticsService.shared.track(.appOpened, key: "streak", value: "\(streakManager.currentStreak)")
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.spring(SimastrySpring.smooth).delay(0.05)) {
                        appeared = true
                    }
                }
                // Show milestone toast after a brief delay
                if streakManager.streakMessage != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            showStreakMilestone = true
                        }
                        // Auto-dismiss after 4 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showStreakMilestone = false
                            }
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .overlay {
            if isLoading {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 16)

                        // Greeting skeleton
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(SimastryColor.surface)
                                    .frame(width: 100, height: 14)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(SimastryColor.surface)
                                    .frame(width: 180, height: 26)
                            }
                            Spacer()
                            Circle()
                                .fill(SimastryColor.surface)
                                .frame(width: 48, height: 48)
                        }

                        // Communication card skeleton
                        RoundedRectangle(cornerRadius: 22)
                            .fill(SimastryColor.surface)
                            .frame(height: 140)

                        // Grid skeleton
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(SimastryColor.surface)
                                    .frame(height: 110)
                            }
                        }

                        // Did You Know skeleton
                        RoundedRectangle(cornerRadius: 22)
                            .fill(SimastryColor.surface)
                            .frame(height: 140)

                        // Companion skeleton
                        RoundedRectangle(cornerRadius: 20)
                            .fill(SimastryColor.surface)
                            .frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                    .skeletonShimmer()
                }
                .scrollIndicators(.hidden)
                .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.3)) {
                isLoading = false
            }
        }
    }

    private var greetingSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingText)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.goldDark)

                if let name = viewModel.profile?.displayName {
                    Text("Hey, \(name)")
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                } else {
                    Text("Welcome back")
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                }
            }

            Spacer()

            if let sun = viewModel.userSunSign {
                Text(sun.glyph)
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.gold)
                    .frame(width: 48, height: 48)
                    .background(SimastryColor.gold.opacity(0.10), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(SimastryColor.gold.opacity(0.15), lineWidth: 0.5)
                    )
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    private func communicationFocusCard(companionName: String, companionSign: ZodiacSign) -> some View {
        let guide = CommunicationTemplates.guides[companionSign]
        let tips = guide?.tips ?? []
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let tipIndex = (dayOfYear - 1) % max(tips.count, 1)
        let todayTip = tips.isEmpty ? "Learn their sign to communicate better." : tips[tipIndex]

        return Button {
            HapticManager.buttonPress()
            viewModel.selectedTab = 2
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SimastryColor.celestialBlue)

                    Text("Today with \(companionName)")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Spacer()

                    Text(companionSign.glyph)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(companionSign.color)
                }

                Text(todayTip)
                    .font(SimastryFont.bodyLarge)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                if let approach = guide?.bestApproach {
                    Text(approach)
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text("Open \(companionName) message")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.celestialBlue)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SimastryColor.celestialBlue)
                }
                .padding(.top, 2)
            }
            .padding(20)
            .tintedGlass(SimastryColor.celestialBlue.opacity(0.12), cornerRadius: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(SimastryColor.celestialBlue.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Today with \(companionName). \(todayTip)")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var featureGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            featureGridCard(
                title: "Messages",
                subtitle: "Chat with Nadia",
                systemImage: "message.fill",
                tint: SimastryColor.celestialBlue
            ) {
                viewModel.selectedTab = 2
            }

            featureGridCard(
                title: "Chart",
                subtitle: "Your signals",
                systemImage: "scope",
                tint: SimastryColor.celestialBlue
            ) {
                viewModel.selectedTab = 5
            }

            featureGridCard(
                title: "Soulmate",
                subtitle: "Find your match",
                systemImage: "heart.circle.fill",
                tint: SimastryColor.sunCoral
            ) {
                viewModel.selectedTab = 0
                viewModel.homeSetupPhase = .modeSelection
            }

            featureGridCard(
                title: "Companions",
                subtitle: "Your circle",
                systemImage: "sparkles",
                tint: SimastryColor.gold
            ) {
                viewModel.selectedTab = 1
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private func featureGridCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.10), in: .rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(tint.opacity(0.15), lineWidth: 0.5)
                    )

                Text(title)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(subtitle)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glossyCard(cornerRadius: 18)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(title). \(subtitle)")
    }

    private func signalPill(_ title: String) -> some View {
        Text(title)
            .font(SimastryFont.captionSmall)
            .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.white.opacity(0.055), in: .capsule)
    }

    private var didYouKnowCard: some View {
        let nuggets = AstrologyTemplates.dailyNuggets
        let dayIndex = Calendar.current.component(.day, from: Date()) % nuggets.count
        let nugget = nuggets[dayIndex]

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.amber)

                Text(localization.string("home.didYouKnow"))
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.amber)

                Spacer()
            }

            Text(nugget.title)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)

            Text(nugget.body)
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let feature = nugget.relatedFeature {
                Button {
                    HapticManager.buttonPress()
                    AnalyticsService.shared.track(.didYouKnowTapped)
                    switch feature {
                    case "profile":
                        viewModel.selectedTab = 5
                    case "companions":
                        viewModel.selectedTab = 1
                    case "predict":
                        viewModel.selectedTab = 2
                    case "guides":
                        viewModel.selectedTab = 2
                    default:
                        break
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(localization.string("home.tryIt"))
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.amber)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(SimastryColor.amber)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(20)
        .glossyCard(cornerRadius: 22)
        .accessibilityLabel("Did you know? \(nugget.title). \(nugget.body)")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(reduceMotion ? nil : .spring(SimastrySpring.smooth).delay(0.1), value: appeared)
    }

    private func companionCard(_ companion: CompanionData) -> some View {
        let level = RelationshipLevel.from(messageCount: companion.conversationCount)

        return Button {
            HapticManager.buttonPress()
            viewModel.selectedTab = 1
        } label: {
            HStack(spacing: 14) {
                GlossyOrbView(
                    signColors: [
                        ZodiacSign(rawValue: companion.sunSign)?.color ?? SimastryColor.gold,
                        ZodiacSign(rawValue: companion.moonSign)?.color ?? SimastryColor.celestialBlue
                    ],
                    state: .idle,
                    size: 50
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(companion.name)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    HStack(spacing: 6) {
                        Text(level.name)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.midnight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(SimastryColor.gold, in: .capsule)

                        Text("\(companion.conversationCount) sparks")
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(companion.compatibilityScore)%")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.gold)
                    Text("match")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .padding(18)
            .simastryGlass(cornerRadius: 20)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(companion.name), \(level.name) bond, \(companion.compatibilityScore) percent match")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private func todayEnergyCard(sun: ZodiacSign) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                CelestialRoleIcon(role: .sun, size: 28)
                Text("Your Energy Today")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Spacer()
            }

            Text(AstrologyTemplates.sunSign[sun.rawValue] ?? "")
                .font(SimastryFont.bodyLarge)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                .lineSpacing(3)
        }
        .padding(18)
        .glossyCard(cornerRadius: 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    // MARK: - Streak

    private var streakPill: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("\(streakManager.currentStreak)")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(streakManager.streakEncouragement)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .simastryGlassPill()

            // Milestone toast
            if showStreakMilestone, let message = streakManager.streakMessage {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    Text(message)
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .goldGlassRect(cornerRadius: 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return localization.string("home.goodMorning") }
        if hour < 17 { return localization.string("home.goodAfternoon") }
        return localization.string("home.goodEvening")
    }
}
