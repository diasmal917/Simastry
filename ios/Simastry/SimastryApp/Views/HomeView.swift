import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @StateObject private var streakManager = StreakManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var isLoading: Bool = true
    @State private var showStreakMilestone: Bool = false
    @State private var showAIAstrologists: Bool = false
    @State private var showPredict: Bool = false

    private var communicationType: CommunicationTypeProfile? {
        CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

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
            .navigationDestination(isPresented: $showAIAstrologists) {
                AIAstrologistsView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showPredict) {
                SimulateView(viewModel: viewModel)
            }
            .onChange(of: viewModel.aiAstrologistsRouteRequest) {
                guard viewModel.homeSetupPhase == .complete else { return }
                showAIAstrologists = true
            }
            .onChange(of: viewModel.predictRouteRequest) {
                guard viewModel.homeSetupPhase == .complete else { return }
                showPredict = true
            }
        }
    }

    private var gramContent: some View {
        let profile = FactoryCompanionCatalog.match(for: viewModel.primaryCompanion)
        let posts = Array(profile.gridImageNames.prefix(6))

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                gramHeader(profile)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 18) {
                        Image(profile.profileImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 92, height: 92)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [SimastryColor.goldLight, SimastryColor.gold, SimastryColor.goldDark],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )

                        HStack(spacing: 18) {
                            gramStat(value: "\(posts.count)", label: "posts")
                            gramStat(value: "24", label: "astrologists")
                            VStack(spacing: 3) {
                                ZodiacIconView(sign: profile.sign, size: 34, showsGlow: false)
                                Text(profile.sign.displayName)
                                    .font(SimastryFont.captionSmall)
                                    .foregroundStyle(SimastryColor.mutedSilver)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name)
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text(profile.metadataLine)
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.mutedSilver)

                        Text(profile.bio)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        ForEach(profile.tags, id: \.self) { tag in
                            Text(tag)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.82))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.07), in: Capsule())
                        }
                    }

                    gramMethodChips(profile)
                }
                .padding(.horizontal, 20)

                Divider()
                    .overlay(SimastryColor.offWhite.opacity(0.12))
                    .padding(.horizontal, 20)

                gramGrid(posts)

                Spacer().frame(height: SimastrySpacing.tabBarClearance)
            }
            .padding(.top, 14)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private func gramHeader(_ profile: FactoryCompanionProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gram")
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("@\(profile.handle)")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            Spacer()

            Button {
                HapticManager.buttonPress()
                viewModel.selectedTab = 2
            } label: {
                Image(systemName: "message.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(width: 42, height: 42)
                    .background(SimastryColor.gold, in: Circle())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Message \(profile.name)")
        }
        .padding(.horizontal, 20)
    }

    private func gramStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1)

            Text(label)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }

    private func gramMethodChips(_ profile: FactoryCompanionProfile) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                gramMethodChip(systemImage: "scope", text: "\(profile.sign.displayName) lens", tint: profile.sign.color)
                gramMethodChip(systemImage: "checkmark.seal.fill", text: "Factory photos", tint: SimastryColor.gold)
                gramMethodChip(systemImage: "lock.fill", text: "Fictional", tint: SimastryColor.celestialBlue)
            }
            .padding(.vertical, 1)
        }
    }

    private func gramMethodChip(systemImage: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)

            Text(text)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.055), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 0.5))
    }

    private func gramGrid(_ imageNames: [String]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(imageNames, id: \.self) { imageName in
                GeometryReader { proxy in
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.width)
                        .clipped()
                }
                .aspectRatio(1, contentMode: .fit)
                .accessibilityHidden(true)
            }
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Spacer().frame(height: 6)

                summaryHeader

                communicationTypeSummaryCard

                summaryMetricGrid

                aiAstrologistsHeroCard

                predictCard

                if let companion = viewModel.primaryCompanion,
                   let companionSign = ZodiacSign(rawValue: companion.sunSign) {
                    communicationFocusCard(companionName: companion.name, companionSign: companionSign)
                }

                if let sun = viewModel.userSunSign {
                    todayEnergyCard(sun: sun)
                }

                Spacer().frame(height: SimastrySpacing.tabBarClearance)
            }
            .padding(.horizontal, 16)
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
                    .padding(.horizontal, 16)
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

    private var summaryHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(formattedSummaryDate)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Text("Summary")
                    .font(SimastryFont.displayMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(summaryGreeting)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.gold)
            }

            Spacer()

            if let sun = viewModel.userSunSign {
                ZodiacIconView(sign: sun, size: 42, showsGlow: true)
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

    @ViewBuilder
    private var communicationTypeSummaryCard: some View {
        if let communicationType {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(SimastryColor.offWhite.opacity(0.08), lineWidth: 10)
                            .frame(width: 74, height: 74)
                        Circle()
                            .trim(from: 0.05, to: 0.82)
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        communicationType.accent,
                                        SimastryColor.gold,
                                        SimastryColor.celestialBlue,
                                        communicationType.accent
                                    ],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-88))
                            .frame(width: 74, height: 74)
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(communicationType.accent)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Communication type")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .tracking(1.2)
                            .textCase(.uppercase)

                        Text(communicationType.title)
                            .font(SimastryFont.titleMedium)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text(communicationType.summary)
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineSpacing(3)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !communicationType.keywords.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(communicationType.keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(SimastryFont.labelSmall)
                                .foregroundStyle(SimastryColor.midnight)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(SimastryColor.gold.opacity(0.92), in: Capsule())
                        }
                    }
                }
            }
            .padding(14)
            .background(SimastryColor.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 0.8)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
    }

    private var summaryMetricGrid: some View {
        let profile = FactoryCompanionCatalog.match(for: viewModel.primaryCompanion)
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return LazyVGrid(columns: columns, spacing: 10) {
            summaryMetricCard(
                title: "Streak",
                value: "\(streakManager.currentStreak)",
                caption: "days active",
                systemImage: "flame.fill",
                tint: SimastryColor.gold
            )

            summaryMetricCard(
                title: "Predict",
                value: remainingPredictionsDisplay,
                caption: remainingPredictionsCaption,
                systemImage: "wand.and.stars",
                tint: SimastryColor.risingViolet
            )

            summaryMetricCard(
                title: "Chart",
                value: chartSignalCount,
                caption: "signals ready",
                systemImage: "scope",
                tint: SimastryColor.celestialBlue
            )

            summaryMetricCard(
                title: "Lens",
                value: profile.sign.displayName,
                caption: "active astrologist",
                systemImage: "sparkles",
                tint: profile.sign.color
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func summaryMetricCard(title: String, value: String, caption: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
            }

            Text(title)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)

            Text(value)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(caption)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(12)
        .background(SimastryColor.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.7)
        }
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

                    ZodiacIconView(sign: companionSign, size: 28, showsGlow: false)
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
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.74))
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text("Open \(companionName) message")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.goldLight)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SimastryColor.goldLight)
                }
                .padding(.top, 2)
            }
            .padding(20)
            .tintedGlass(SimastryColor.celestialBlue, cornerRadius: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(SimastryColor.celestialBlue.opacity(0.22), lineWidth: 1)
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
                title: "Predict",
                subtitle: "Model a reply",
                systemImage: "wand.and.stars",
                tint: SimastryColor.risingViolet
            ) {
                showPredict = true
            }

            featureGridCard(
                title: "AI Astrologists",
                subtitle: "Portraits and Gram",
                systemImage: "sparkles",
                tint: SimastryColor.gold
            ) {
                viewModel.openAIAstrologists()
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private var aiAstrologistsHeroCard: some View {
        let profile = FactoryCompanionCatalog.match(for: viewModel.primaryCompanion)

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Image(profile.cardImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipped()

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("FOR YOU")
                        .font(SimastryFont.overline)
                        .tracking(1.1)
                }
                .foregroundStyle(SimastryColor.gold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.42), in: Capsule())
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Text("AI Astrologists")
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Spacer()

                    Button {
                        HapticManager.buttonPress()
                        showAIAstrologists = true
                    } label: {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(SimastryColor.midnight)
                            .frame(width: 36, height: 36)
                            .background(SimastryGradient.gold, in: Circle())
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityLabel("Open AI Astrologists")
                }

                Text("\(profile.sign.displayName) lens • Factory portraits")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .lineLimit(1)

                Text("\(profile.name) reads your \(communicationType?.title ?? "communication type") through a \(profile.sign.displayName) lens.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

            }
            .padding(16)
        }
        .background(SimastryColor.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 0.8)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var predictCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SimastryColor.risingViolet)
                    .frame(width: 42, height: 42)
                    .background(SimastryColor.risingViolet.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Predict")
                        .font(SimastryFont.titleMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("Paste a real conversation and model the likely reply through chart signals.")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                HapticManager.buttonPress()
                showPredict = true
            } label: {
                Label("Predict their response", systemImage: "wand.and.stars")
            }
            .buttonStyle(.simastryPrimary)
        }
        .padding(16)
        .background(SimastryColor.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 0.8)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
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
                        viewModel.openAIAstrologists()
                    case "predict":
                        showPredict = true
                    case "guides":
                        viewModel.selectedTab = 1
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
            viewModel.openAIAstrologists()
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
                    Text("fit")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .padding(18)
            .simastryGlass(cornerRadius: 20)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(companion.name), \(level.name) bond, \(companion.compatibilityScore) percent fit")
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

    private var summaryGreeting: String {
        if let name = viewModel.profile?.displayName {
            return "\(greetingText), \(name)"
        }
        return greetingText
    }

    private var formattedSummaryDate: String {
        SimastryDateFormatter.summaryDate.string(from: Date())
    }

    private var chartSignalCount: String {
        let count = [viewModel.userSunSign, viewModel.userMoonSign, viewModel.userRisingSign]
            .compactMap { $0 }
            .count
        return "\(count)/3"
    }

    private var remainingPredictionsDisplay: String {
        viewModel.weeklyPredictionLimit == .max ? "∞" : "\(viewModel.remainingWeeklyPredictions)"
    }

    private var remainingPredictionsCaption: String {
        viewModel.weeklyPredictionLimit == .max ? "unlimited" : "weekly left"
    }
}
