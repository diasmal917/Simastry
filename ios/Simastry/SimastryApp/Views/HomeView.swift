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
    @State private var transitReading: DailyTransitReading?
    @State private var predictionScorecard: PredictionScorecard?
    @State private var handledAstrologistsRouteRequest: Int = 0
    @State private var handledPredictRouteRequest: Int = 0
    @State private var kenBurnsActive: Bool = false
    @Namespace private var panelHeroNamespace

    private var communicationType: CommunicationTypeProfile? {
        CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    private var featuredProfile: FactoryCompanionProfile {
        // Founder pick: Theo leads the Today tab for everyone.
        FactoryCompanionCatalog.all.first { $0.id == "taurus-theo" }
            ?? FactoryCompanionCatalog.match(for: viewModel.primaryCompanion)
    }

    private var castRowProfiles: [FactoryCompanionProfile] {
        let featured = featuredProfile
        return Array(FactoryCompanionCatalog.all.filter { $0.id != featured.id }.prefix(6))
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
                    // Zoom out of the tapped pane/avatar; route requests
                    // without a profile have no on-screen source to zoom from.
                    if let profileId {
                        AIAstrologistsView(viewModel: viewModel, initialProfileId: profileId)
                            .id(profileId)
                            .navigationTransition(.zoom(sourceID: profileId, in: panelHeroNamespace))
                    } else {
                        AIAstrologistsView(viewModel: viewModel, initialProfileId: nil)
                            .id("primary")
                    }
                case .predict:
                    SimulateView(viewModel: viewModel)
                }
            }
            .onAppear {
                // Catch route requests fired before this view mounted
                // (cold-start deep links, preview seeding).
                presentRoutesIfRequested()
            }
            .onChange(of: viewModel.aiAstrologistsRouteRequest) {
                presentRoutesIfRequested()
            }
            .onChange(of: viewModel.predictRouteRequest) {
                presentRoutesIfRequested()
            }
        }
    }

    private func presentRoutesIfRequested() {
        guard viewModel.homeSetupPhase == .complete else { return }
        if viewModel.aiAstrologistsRouteRequest > handledAstrologistsRouteRequest {
            handledAstrologistsRouteRequest = viewModel.aiAstrologistsRouteRequest
            navigationPath.append(HomeRoute.aiAstrologist(profileId: nil))
        }
        if viewModel.predictRouteRequest > handledPredictRouteRequest {
            handledPredictRouteRequest = viewModel.predictRouteRequest
            navigationPath.append(HomeRoute.predict)
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Spacer().frame(height: 6)

                todayHeader

                panelCard

                predictHeroCard

                tipsRow

                dailyReadCard

                methodCourseCard

                todaysSkyCard

                communicationTypeSummaryCard

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
                if !reduceMotion {
                    kenBurnsActive = true
                }
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
                    VStack(spacing: 20) {
                        Spacer().frame(height: 16)

                        // Header skeleton
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(SimastryColor.surface)
                                    .frame(width: 100, height: 14)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(SimastryColor.surface)
                                    .frame(width: 180, height: 30)
                            }
                            Spacer()
                            Circle()
                                .fill(SimastryColor.surface)
                                .frame(width: 48, height: 48)
                        }

                        // Panel skeleton
                        RoundedRectangle(cornerRadius: 24)
                            .fill(SimastryColor.surface)
                            .frame(height: 340)

                        // Predict hero skeleton
                        RoundedRectangle(cornerRadius: 28)
                            .fill(SimastryColor.surface)
                            .frame(height: 200)

                        // Daily read skeleton
                        RoundedRectangle(cornerRadius: 22)
                            .fill(SimastryColor.surface)
                            .frame(height: 150)

                        // Grid skeleton
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(SimastryColor.surface)
                                    .frame(height: 104)
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
            transitReading = TransitEngine.dailyReading(
                sun: viewModel.userSunSign,
                moon: viewModel.userMoonSign,
                rising: viewModel.userRisingSign
            )
            predictionScorecard = PredictionScorecard.from(viewModel.predictionService.loadHistory())
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.3)) {
                isLoading = false
            }
        }
    }

    // MARK: - Header

    private var todayHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedSummaryDate.uppercased())
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textTertiary)
                    .tracking(1.4)

                Text("Today")
                    .font(SimastryFont.displayLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(summaryGreeting)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.gold)
            }

            Spacer()

            if let sun = viewModel.userSunSign {
                ZodiacIconView(sign: sun, size: 42, showsGlow: true)
                    .frame(width: 48, height: 48)
                    .background(SimastryColor.gold.opacity(0.10), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(SimastryColor.gold.opacity(0.18), lineWidth: 0.6)
                    )
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    // MARK: - Predict Hero

    private var predictHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: SimastryIcon.predict)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(SimastryColor.risingViolet)
                    .frame(width: 44, height: 44)
                    .background(SimastryColor.risingViolet.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer()

                Text(remainingPredictionsBadge)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.risingViolet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(SimastryColor.risingViolet.opacity(0.13), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("PREDICT")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.risingViolet)
                    .tracking(1.8)

                Text("What will they say back?")
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("Paste a conversation. Your panel reads the thread and your chart signals, then maps the likely reply, the timing, and your strongest next message.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink(value: HomeRoute.predict) {
                Label("Paste a conversation", systemImage: SimastryIcon.predict)
            }
            .buttonStyle(SimastryAccentButtonStyle(accent: SimastryColor.risingViolet))
            .simultaneousGesture(TapGesture().onEnded {
                HapticManager.buttonPress()
            })
        }
        .padding(18)
        .heroGlass(SimastryColor.risingViolet)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .zIndex(2)
    }

    // MARK: - Daily Read

    /// Which chart signal leads today's read — rotates daily through Sun/Moon/Rising.
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
    private var dailyReadCard: some View {
        if let briefFocusLine {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 8) {
                    Image(systemName: SimastryIcon.dailyRead)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    Text("YOUR DAILY READ")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.5)

                    Spacer()

                    Text("\(briefFocusRole.displayName) focus")
                        .font(SimastryFont.labelSmall)
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
                        Image(systemName: SimastryIcon.quote)
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

                if let dailyReadGuide {
                    Button {
                        HapticManager.buttonPress()
                        viewModel.openPanelChatSeededWithDailyRead(line: briefFocusLine, role: briefFocusRole)
                    } label: {
                        HStack(spacing: 9) {
                            Image(dailyReadGuide.profile.profileImageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28, alignment: .top)
                                .clipShape(Circle())
                                .overlay {
                                    Circle().strokeBorder(dailyReadGuide.sign.color.opacity(0.6), lineWidth: 1)
                                }

                            Text("Talk it through with \(dailyReadGuide.profile.name)")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.goldLight)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(SimastryColor.goldLight.opacity(0.8))
                        }
                        .padding(.top, 4)
                        .contentShape(.rect)
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityLabel("Talk today's read through with \(dailyReadGuide.profile.name) in your panel chat")
                }
            }
            .padding(17)
            .surfaceCard(accent: SimastryColor.gold.opacity(0.8))
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
    }

    /// The guide whose lens matches today's focus rotation.
    private var dailyReadGuide: PanelMatcher.Entry? {
        viewModel.panelGuideEntries.first { $0.role == briefFocusRole }
            ?? viewModel.panelGuideEntries.first
    }

    // MARK: - Tips

    private struct DailyGuideTip: Identifiable {
        let title: String
        let lesson: String
        let opener: String
        let profile: FactoryCompanionProfile
        var id: String { "\(profile.id)-\(title)" }
    }

    /// Two micro-lessons per day, rotating through the template set with
    /// their teaching guides resolved from the catalog.
    private var todaysTips: [DailyGuideTip] {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return AstrologyTemplates.dailyGuideTips(dayOfYear: dayOfYear).compactMap { tip in
            guard let profile = FactoryCompanionCatalog.all.first(where: { $0.id == tip.guideId }) else {
                return nil
            }
            return DailyGuideTip(title: tip.title, lesson: tip.body, opener: tip.opener, profile: profile)
        }
    }

    // MARK: - Simastry Method course

    /// Seven lessons taught in the panel, one a day. The card tracks
    /// progress and flips to a graduate state after lesson seven.
    private var methodCourseCard: some View {
        // Establishes an observation on course progress so the card
        // re-renders after a lesson posts.
        let _ = viewModel.methodCourseVersion
        let state = viewModel.methodCourseState

        return Button {
            HapticManager.buttonPress()
            viewModel.openMethodCourseLesson()
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    Text("THE SIMASTRY METHOD")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.5)

                    Spacer()

                    HStack(spacing: 4) {
                        ForEach(MethodCourseTemplates.lessons) { lesson in
                            Circle()
                                .fill(state.postedLessons.contains(lesson.number)
                                      ? SimastryColor.gold
                                      : SimastryColor.offWhite.opacity(0.14))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .accessibilityLabel("\(state.postedLessons.count) of \(MethodCourseTemplates.lessons.count) lessons complete")
                }

                if state.isComplete {
                    Text("Method Graduate")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text("All seven lessons live in your panel — revisit them any time.")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let lesson = state.currentLesson {
                    Text("Lesson \(lesson.number) of \(MethodCourseTemplates.lessons.count) · \(lesson.title)")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(viewModel.canPostMethodLessonToday
                         ? "A two-minute lesson, taught by your panel. Tap to take it."
                         : "Today's lesson is in your panel — the next one unlocks tomorrow.")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(state.isComplete
            ? "Simastry Method complete. Open your panel."
            : "Simastry Method course. Take the next lesson with your panel.")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    @ViewBuilder
    private var tipsRow: some View {
        if !todaysTips.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.max.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    Text("TIPS")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.5)

                    Spacer()

                    Text("Fresh tomorrow")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.textTertiary)
                }

                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(todaysTips.enumerated()), id: \.element.id) { index, tip in
                        tipCard(tip)
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.96)
                            .animation(
                                reduceMotion ? nil : .spring(SimastrySpring.bouncy).delay(0.12 + Double(index) * 0.08),
                                value: appeared
                            )
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
    }

    private func tipCard(_ tip: DailyGuideTip) -> some View {
        Button {
            HapticManager.buttonPress()
            viewModel.openPanelChatWithTip(lesson: tip.lesson, opener: tip.opener, guideId: tip.profile.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(tip.title)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Image(tip.profile.profileImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28, alignment: .top)
                        .clipShape(Circle())
                        .overlay {
                            Circle().strokeBorder(tip.profile.sign.color.opacity(0.6), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("with \(tip.profile.name)")
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.goldLight)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("\(tip.profile.sign.displayName) Guide")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
            .surfaceCard(cornerRadius: 20, accent: tip.profile.sign.color.opacity(0.7))
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Tip: \(tip.title). Start a conversation with \(tip.profile.name), \(tip.profile.sign.displayName) guide")
    }

    // MARK: - Your Panel

    private var panelCard: some View {
        let profile = featuredProfile

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: SimastryIcon.astrologers)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.goldLight)

                    Text("YOUR PANEL")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.5)
                }

                Spacer()

                NavigationLink(value: HomeRoute.aiAstrologist(profileId: nil)) {
                    HStack(spacing: 3) {
                        Text("All 24 guides")
                            .font(SimastryFont.labelSmall)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(SimastryColor.gold)
                }
                .buttonStyle(.plain)
            }

            featuredGuidePane(profile)

            castRow

            askPanelButton
        }
        .padding(14)
        .surfaceCard(cornerRadius: 24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    /// Opens the group thread with the user's three placement guides.
    private var askPanelButton: some View {
        Button {
            HapticManager.buttonPress()
            viewModel.openPanelChat()
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: -10) {
                    ForEach(Array(viewModel.panelGuideEntries.enumerated()), id: \.element.id) { index, entry in
                        Image(entry.profile.profileImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 26, height: 26, alignment: .top)
                            .clipShape(Circle())
                            .overlay {
                                Circle().strokeBorder(entry.sign.color.opacity(0.6), lineWidth: 1)
                            }
                            .background {
                                Circle().fill(SimastryColor.midnight)
                                    .frame(width: 29, height: 29)
                            }
                            .zIndex(Double(viewModel.panelGuideEntries.count - index))
                    }
                }

                Text("Ask your panel")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.midnight)

                Spacer()

                if viewModel.unreadPanelCount > 0 {
                    Text("\(viewModel.unreadPanelCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SimastryColor.goldLight)
                        .frame(minWidth: 19)
                        .frame(height: 19)
                        .background(SimastryColor.midnight.opacity(0.85), in: Capsule())
                }

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SimastryColor.midnight.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(SimastryGradient.gold, in: Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
            }
            .shadow(color: SimastryColor.gold.opacity(0.22), radius: 12, y: 6)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Ask your panel. Group chat with your three guides.")
    }

    private func featuredGuidePane(_ profile: FactoryCompanionProfile) -> some View {
        NavigationLink(value: HomeRoute.aiAstrologist(profileId: profile.id)) {
            ZStack(alignment: .bottom) {
                // Slow Ken Burns drift keeps the featured portrait alive;
                // the outer clip shape crops the overflow.
                Image(profile.cardImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240, alignment: .top)
                    .clipped()
                    .scaleEffect(kenBurnsActive ? 1.07 : 1.0, anchor: .top)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 14).repeatForever(autoreverses: true),
                        value: kenBurnsActive
                    )

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(color: .black.opacity(0.55), location: 0.72),
                        .init(color: .black.opacity(0.88), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: SimastryIcon.method)
                            .font(.system(size: 9, weight: .bold))
                        Text("SIMASTRY METHOD")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.0)
                    }
                    .foregroundStyle(SimastryColor.goldLight)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(profile.name)
                            .font(SimastryFont.titleLarge)
                            .foregroundStyle(.white)

                        Text("\(profile.sign.displayName) Guide")
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(profile.sign.color)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Text(profile.headline)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [profile.sign.color.opacity(0.40), .white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.9
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .matchedTransitionSource(id: profile.id, in: panelHeroNamespace)
        }
        .buttonStyle(SpringPressStyle())
        .simultaneousGesture(TapGesture().onEnded {
            HapticManager.buttonPress()
        })
        .accessibilityLabel("\(profile.name), \(profile.sign.displayName) Guide. \(profile.headline) Opens guide profile.")
    }

    private var castRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(castRowProfiles) { profile in
                    NavigationLink(value: HomeRoute.aiAstrologist(profileId: profile.id)) {
                        VStack(spacing: 6) {
                            Image(profile.profileImageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56, alignment: .top)
                                .clipShape(Circle())
                                .overlay {
                                    Circle().strokeBorder(profile.sign.color.opacity(0.55), lineWidth: 1.2)
                                }

                            Text(profile.name)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(SimastryColor.mutedSilver)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                        .matchedTransitionSource(id: profile.id, in: panelHeroNamespace)
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityLabel("\(profile.name), \(profile.sign.displayName) Guide")
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Today's Sky

    /// Real transit read: current planetary positions (Swiss Ephemeris)
    /// against the user's natal signs, voiced as message timing.
    @ViewBuilder
    private var todaysSkyCard: some View {
        if let reading = transitReading {
            let (chipLabel, accent): (String, Color) = switch reading.aspect.family {
            case "flow": ("Flow", SimastryColor.gold)
            case "emphasis": ("Emphasis", SimastryColor.celestialBlue)
            default: ("Friction", SimastryColor.sunCoral)
            }

            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Text(reading.body.glyph)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)

                    Text("TODAY'S SKY")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.5)

                    Spacer()

                    Text(chipLabel)
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(accent.opacity(0.12), in: Capsule())
                }

                Text(reading.headline)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(reading.detailLine)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(reading.guidance)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(15)
            .surfaceCard(accent: accent.opacity(0.7))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Today's sky. \(reading.headline). \(reading.guidance)")
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
    }

    // MARK: - Communication Type

    @ViewBuilder
    private var communicationTypeSummaryCard: some View {
        if let communicationType {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(SimastryColor.offWhite.opacity(0.08), lineWidth: 9)
                            .frame(width: 68, height: 68)
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
                                style: StrokeStyle(lineWidth: 9, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-88))
                            .frame(width: 68, height: 68)
                        Image(systemName: SimastryIcon.quote)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(communicationType.accent)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("COMMUNICATION TYPE")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.textTertiary)
                            .tracking(1.3)

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
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.07), in: Capsule())
                                .overlay {
                                    Capsule().strokeBorder(communicationType.accent.opacity(0.28), lineWidth: 0.6)
                                }
                        }
                    }
                }
            }
            .padding(15)
            .surfaceCard()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
    }

    // MARK: - Metrics

    private var summaryMetricGrid: some View {
        let profile = featuredProfile
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return LazyVGrid(columns: columns, spacing: 10) {
            summaryMetricCard(
                title: "Streak",
                value: "\(streakManager.currentStreak)",
                caption: streakManager.currentStreak == 1 ? "day active" : "days active",
                systemImage: SimastryIcon.streak,
                tint: SimastryColor.sunCoral
            )

            summaryMetricCard(
                title: "Predict",
                value: remainingPredictionsDisplay,
                caption: predictionScorecard?.captionLine ?? remainingPredictionsCaption,
                systemImage: SimastryIcon.predict,
                tint: SimastryColor.risingViolet
            )

            summaryMetricCard(
                title: "Chart",
                value: chartSignalCount,
                caption: "signals ready",
                systemImage: SimastryIcon.chart,
                tint: SimastryColor.celestialBlue
            )

            summaryMetricCard(
                title: "Guide",
                value: profile.name,
                caption: "\(profile.sign.displayName) lens",
                systemImage: SimastryIcon.astrologers,
                tint: SimastryColor.gold
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func summaryMetricCard(title: String, value: String, caption: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title.uppercased())
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textTertiary)
                    .tracking(1.1)

                Spacer()
            }

            Spacer(minLength: 0)

            Text(value)
                .font(SimastryFont.metricMedium)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(caption)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(13)
        .surfaceCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(caption)")
    }

    // MARK: - Today With Companion

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
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    Image(systemName: SimastryIcon.message)
                        .font(.system(size: 14, weight: .semibold))
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
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Image(systemName: SimastryIcon.message)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SimastryColor.goldLight)
                    Text("Open \(companionName) message")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.goldLight)
                }
                .padding(.top, 2)
            }
            .padding(18)
            .surfaceCard(accent: SimastryColor.celestialBlue.opacity(0.8))
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Today with \(companionName). \(todayTip)")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    // MARK: - Derived Copy

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

    private var remainingPredictionsBadge: String {
        viewModel.weeklyPredictionLimit == .max ? "Unlimited" : "\(viewModel.remainingWeeklyPredictions) left this week"
    }
}
