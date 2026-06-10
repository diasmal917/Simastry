import SwiftUI

private enum HomeRoute: Hashable {
    case aiAstrologist(profileId: String?)
    case predict
}

struct HomeView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @StateObject private var streakManager = StreakManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var navigationPath = NavigationPath()
    @State private var appeared: Bool = false
    @State private var isLoading: Bool = true
    @State private var showStreakMilestone: Bool = false

    private var communicationType: CommunicationTypeProfile? {
        CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    private var adaProfile: FactoryCompanionProfile {
        FactoryCompanionCatalog.all.first { $0.id == "taurus-ada" } ?? FactoryCompanionCatalog.featured
    }

    private var eliasProfile: FactoryCompanionProfile {
        FactoryCompanionCatalog.all.first { $0.id == "scorpio-elias" } ?? FactoryCompanionCatalog.featured
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .aiAstrologist(let profileId):
                    AIAstrologistsView(viewModel: viewModel, initialProfileId: profileId)
                        .id(profileId ?? "primary")
                case .predict:
                    SimulateView(viewModel: viewModel)
                }
            }
            .onChange(of: viewModel.aiAstrologistsRouteRequest) {
                guard viewModel.homeSetupPhase == .complete else { return }
                navigationPath.append(HomeRoute.aiAstrologist(profileId: nil))
            }
            .onChange(of: viewModel.predictRouteRequest) {
                guard viewModel.homeSetupPhase == .complete else { return }
                navigationPath.append(HomeRoute.predict)
            }
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Spacer().frame(height: 6)

                summaryHeader

                predictCard

                topAstrologistButton

                aiAstrologistsHeroCard

                communicationTypeSummaryCard

                dailyBriefCard

                summaryMetricGrid

                if let companion = viewModel.primaryCompanion,
                   let companionSign = ZodiacSign(rawValue: companion.sunSign) {
                    communicationFocusCard(companionName: companion.name, companionSign: companionSign)
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

                        // Daily brief skeleton
                        RoundedRectangle(cornerRadius: 22)
                            .fill(SimastryColor.surface)
                            .frame(height: 170)

                        // AI Astrologists skeleton
                        RoundedRectangle(cornerRadius: 20)
                            .fill(SimastryColor.surface)
                            .frame(height: 210)

                        // Grid skeleton
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(SimastryColor.surface)
                                    .frame(height: 110)
                            }
                        }
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
                title: "Guide",
                value: profile.sign.displayName,
                caption: "active astrologist",
                systemImage: "sparkles",
                tint: profile.sign.color
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var topAstrologistButton: some View {
        let profile = eliasProfile

        return Button {
            HapticManager.buttonPress()
            navigationPath.append(HomeRoute.aiAstrologist(profileId: profile.id))
        } label: {
            HStack(spacing: 12) {
                Image(profile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 74, height: 74, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 21, style: .continuous)
                            .stroke(SimastryColor.gold.opacity(0.34), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(profile.name)
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text(profile.sign.displayName)
                            .font(SimastryFont.captionSmall.weight(.semibold))
                            .foregroundStyle(profile.sign.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(profile.sign.color.opacity(0.14), in: Capsule())
                    }

                    Text("Ask Elias for a deeper read before you reply.")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(width: 34, height: 34)
                    .background(SimastryGradient.gold, in: Circle())
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [SimastryColor.surface.opacity(0.96), SimastryColor.surface.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [profile.sign.color.opacity(0.30), .white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Open Elias, Scorpio AI Astrologist")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .zIndex(2)
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
                    Image(systemName: "message.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SimastryColor.goldLight)
                    Text("Open \(companionName) message")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.goldLight)
                }
                .padding(.top, 2)
            }
            .padding(20)
            .background(SimastryColor.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [SimastryColor.celestialBlue.opacity(0.24), .white.opacity(0.055)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Today with \(companionName). \(todayTip)")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var aiAstrologistsHeroCard: some View {
        let profile = adaProfile

        return NavigationLink(value: HomeRoute.aiAstrologist(profileId: profile.id)) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    homeAdaCollage(profile: profile)
                        .frame(maxWidth: .infinity)
                        .frame(height: 238)
                        .clipped()
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("\(profile.sign.displayName) guide • AI Astrologist")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.goldLight)
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.75), radius: 4, y: 1)

                    HStack(alignment: .center, spacing: 10) {
                        Text(profile.name)
                            .font(SimastryFont.titleLarge)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 5, y: 2)

                        Spacer()

                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(SimastryColor.midnight)
                            .frame(width: 36, height: 36)
                            .background(SimastryGradient.gold, in: Circle())
                    }

                    Text("Reads your \(communicationType?.title ?? "communication type") with \(profile.sign.displayName) timing.")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineSpacing(3)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.75), radius: 4, y: 1)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.78))
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 0.8)
            )
        }
        .buttonStyle(SpringPressStyle())
        .simultaneousGesture(TapGesture().onEnded {
            HapticManager.buttonPress()
        })
        .accessibilityLabel("AI Astrologists. \(profile.name), \(profile.sign.displayName) guide. Opens the astrologist directory.")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .zIndex(1)
    }

    private func homeAdaCollage(profile: FactoryCompanionProfile) -> some View {
        GeometryReader { proxy in
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 14) {
                    homeAdaCollageBody(profile: profile, size: proxy.size)
                }
            } else {
                homeAdaCollageBody(profile: profile, size: proxy.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func homeAdaCollageBody(profile: FactoryCompanionProfile, size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    SimastryColor.midnight,
                    SimastryColor.surface.opacity(0.96),
                    profile.sign.color.opacity(0.28),
                    SimastryColor.midnight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "sparkles")
                .font(.system(size: 92, weight: .light))
                .foregroundStyle(SimastryColor.gold.opacity(0.08))
                .rotationEffect(.degrees(-10))
                .position(x: size.width * 0.88, y: size.height * 0.23)

            homeCollageWindow(
                imageName: "Factory_scorpio-elias_profile",
                accent: SimastryColor.goldLight,
                width: size.width * 0.38,
                height: 126,
                x: size.width * 0.23,
                y: size.height * 0.72,
                rotation: -7,
                zIndex: 4,
                imageAlignment: .top,
                imageOffsetY: -4
            )

            homeCollageWindow(
                imageName: "Factory_virgo-mara_card",
                accent: profile.sign.color,
                width: size.width * 0.44,
                height: 168,
                x: size.width * 0.78,
                y: size.height * 0.43,
                rotation: 6,
                zIndex: 2,
                imageAlignment: .top,
                imageOffsetY: -7
            )

            homeCollageWindow(
                imageName: profile.profileImageName,
                accent: SimastryColor.gold,
                width: size.width * 0.58,
                height: 206,
                x: size.width * 0.47,
                y: size.height * 0.53,
                rotation: -2,
                zIndex: 3,
                imageAlignment: .top,
                imageOffsetY: -12
            )
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.10), location: 0),
                    .init(color: .clear, location: 0.44),
                    .init(color: .black.opacity(0.48), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func homeCollageWindow(
        imageName: String,
        accent: Color,
        width: CGFloat,
        height: CGFloat,
        x: CGFloat,
        y: CGFloat,
        rotation: Double,
        zIndex: Double,
        imageAlignment: Alignment,
        imageOffsetY: CGFloat
    ) -> some View {
        let radius = min(width * 0.16, 22)

        return Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height + abs(imageOffsetY) * 2, alignment: imageAlignment)
            .offset(y: imageOffsetY)
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [accent.opacity(0.42), .white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            }
            .shadow(color: .black.opacity(0.42), radius: 18, y: 12)
            .shadow(color: accent.opacity(0.14), radius: 14, y: 0)
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
            .zIndex(zIndex)
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
                    Text("Predict their reply")
                        .font(SimastryFont.titleMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("Paste a text thread. Simastry reads the conversation and chart signals to estimate how they may respond, then helps you choose your next message.")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            NavigationLink(value: HomeRoute.predict) {
                Label("Paste conversation", systemImage: "wand.and.stars")
            }
            .buttonStyle(.simastryPrimary)
            .simultaneousGesture(TapGesture().onEnded {
                HapticManager.buttonPress()
            })
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

    // MARK: - Daily Communication Brief

    /// Which chart signal leads today's brief — rotates daily through Sun/Moon/Rising.
    private var briefFocusRole: CelestialRole {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return [CelestialRole.sun, .moon, .rising][dayOfYear % 3]
    }

    private var briefFocusLine: String? {
        guard let communicationType else { return nil }
        switch briefFocusRole {
        case .sun: return communicationType.sunSignal
        case .moon: return communicationType.moonSignal
        case .rising: return communicationType.risingSignal
        }
    }

    private var briefMoveLine: String? {
        guard let sun = viewModel.userSunSign else { return nil }
        let moves = AstrologyTemplates.companionReplyGuidance[sun.element.rawValue] ?? []
        guard !moves.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return moves[dayOfYear % moves.count]
    }

    @ViewBuilder
    private var dailyBriefCard: some View {
        if let briefFocusLine {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "sun.haze.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    Text("Daily brief")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .tracking(1.3)
                        .textCase(.uppercase)

                    Spacer()

                    Text("\(briefFocusRole.displayName) focus")
                        .font(SimastryFont.captionSmall.weight(.semibold))
                        .foregroundStyle(SimastryColor.gold)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(SimastryColor.gold.opacity(0.12), in: Capsule())
                }

                Text(briefFocusLine)
                    .font(SimastryFont.bodyLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                if let briefMoveLine {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(SimastryColor.gold)
                            .padding(.top, 3)

                        Text(briefMoveLine)
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    briefAction("Predict a reply", systemImage: "wand.and.stars", isPrimary: true) {
                        navigationPath.append(HomeRoute.predict)
                    }
                    briefAction("Messages", systemImage: "message.fill", isPrimary: false) {
                        viewModel.selectedTab = 2
                    }
                }
                .padding(.top, 2)
            }
            .padding(18)
            .background(SimastryColor.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [SimastryColor.gold.opacity(0.26), .white.opacity(0.055)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Daily brief, \(briefFocusRole.displayName) focus. \(briefFocusLine)")
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
    }

    private func briefAction(_ label: String, systemImage: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            Label(label, systemImage: systemImage)
                .font(SimastryFont.labelMedium)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(isPrimary ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    isPrimary
                        ? SimastryGradient.gold
                        : LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule()
                )
        }
        .buttonStyle(SpringPressStyle())
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
