import SwiftUI

private enum HomeRoute: Hashable {
    case aiAstrologist(profileId: String?)
    case guideProfile(profileId: String)
    case predict
    case decode
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
    @State private var handledAstrologistsRouteRequest: Int = 0
    @State private var handledPredictRouteRequest: Int = 0
    @State private var handledDecodeRouteRequest: Int = 0
    @State private var kenBurnsActive: Bool = false
    @State private var sealedDrafts: [SealedDraft] = []
    @State private var showSealedDraftCompose: Bool = false
    @State private var rereadDraft: SealedDraft?
    @State private var generatingDailyDecisionCategory: DailyDecisionCategory?
    @State private var showAuraSnapshotSheet: Bool = false
    @Namespace private var panelHeroNamespace

    private var communicationType: CommunicationTypeProfile? {
        CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    private var featuredProfile: FactoryCompanionProfile {
        FactoryCompanionCatalog.featured
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
            .overlay(alignment: .top) {
                streakMilestoneToast
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
                case .guideProfile(let profileId):
                    // The Instagram pattern: any guide face lands here.
                    if let profile = FactoryCompanionCatalog.all.first(where: { $0.id == profileId }) {
                        GuideProfileView(viewModel: viewModel, profile: profile)
                            .navigationTransition(.zoom(sourceID: profileId, in: panelHeroNamespace))
                    }
                case .predict:
                    SimulateView(viewModel: viewModel)
                case .decode:
                    DecodeTextView(viewModel: viewModel)
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
            .onChange(of: viewModel.decodeRouteRequest) {
                presentRoutesIfRequested()
            }
            .sheet(isPresented: $showAuraSnapshotSheet) {
                AuraSnapshotSheet(viewModel: viewModel)
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
        if viewModel.decodeRouteRequest > handledDecodeRouteRequest {
            handledDecodeRouteRequest = viewModel.decodeRouteRequest
            navigationPath.append(HomeRoute.decode)
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Spacer().frame(height: 6)

                // Today feed ordering: lead with the header, then the primary
                // Ask the Future / Decode CTA and Daily Decider, then Aura, then
                // the guide panel, then people/social, then learn/extra content.
                todayHeader

                predictHeroCard

                dailyDeciderCard

                AuraSnapshotCard(
                    snapshot: viewModel.auraSnapshot,
                    onOpen: { showAuraSnapshotSheet = true },
                    onClear: { viewModel.clearAuraSnapshot() }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                panelCard

                todayWithGuideCard

                firstReadMemoryCard

                situationCard

                continueStrip

                todaysReadCard

                learnCard

                sealedDraftsRow

                Spacer().frame(height: SimastrySpacing.tabBarClearance)
            }
            .padding(.horizontal, 16)
            .onAppear {
                streakManager.recordCheckIn()
                AnalyticsService.shared.track(.appOpened, key: "streak", value: "\(streakManager.currentStreak)")
                sealedDrafts = SealedDraftStore().load()
                viewModel.todayStore.reloadSavedPrompts()
                viewModel.todayStore.reloadDailyDecisions()
                viewModel.reloadAuraSnapshot()
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
            // Today's reading is computed synchronously above, so reveal content
            // as soon as it's ready — no artificial delay just to show shimmer.
            withAnimation(.easeOut(duration: 0.3)) {
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private var streakMilestoneToast: some View {
        if showStreakMilestone, let message = streakManager.streakMessage {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SimastryColor.gold)

                Text(message)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(SimastryColor.gold.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: SimastryColor.gold.opacity(0.25), radius: 18, y: 8)
            .padding(.top, 12)
            .padding(.horizontal, 20)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(50)
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
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    private var todayCardGuide: FactoryCompanionProfile {
        FactoryCompanionCatalog.all.first { $0.id == "taurus-theo" } ?? featuredProfile
    }

    private var todayWithGuideCard: some View {
        let prompt = dailyNadiaPrompt
        let guide = todayCardGuide

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(guide.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48, alignment: .top)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(SimastryColor.gold.opacity(0.7), lineWidth: 1.2)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY WITH \(guide.name.uppercased())")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.gold)
                        .tracking(1.4)

                    Text(prompt)
                        .font(SimastryFont.bodyLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 8) {
                Button {
                    HapticManager.buttonPress()
                    viewModel.openPrivatePredictionFromToday()
                } label: {
                    PredictionOrbLabel(title: "Ask something private", iconSize: 22)
                }
                .buttonStyle(SimastryAccentButtonStyle(accent: SimastryColor.risingViolet))
                .accessibilityHint("Opens Ask the Future for a private question")
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.gold.opacity(0.7))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var dailyDeciderCard: some View {
        let latest = viewModel.todayStore.latestDailyDecision

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.celestialBlue)
                    .frame(width: 32, height: 32)
                    .background(SimastryColor.celestialBlue.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY DECIDER")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.celestialBlue)
                        .tracking(1.4)

                    if latest == nil {
                        Text("Can't decide? Tap one below.")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }

            if let latest {
                dailyDecisionResult(latest)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(DailyDecisionCategory.allCases) { category in
                        dailyDecisionChip(category)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.celestialBlue.opacity(0.7))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private func dailyDecisionResult(_ decision: DailyDecision) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: decision.category.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.celestialBlue)

                Text(decision.category.title.uppercased())
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.2)
            }

            Text(decision.pick)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(decision.whyToday)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .padding(.top, 2)

                Text(decision.tinyNextMove)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.goldLight)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let safetyNote = decision.safetyNote {
                Text(safetyNote)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.deepMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(SimastryColor.offWhite.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(decision.category.title) pick. \(decision.pick). \(decision.whyToday). \(decision.tinyNextMove)")
    }

    private func dailyDecisionChip(_ category: DailyDecisionCategory) -> some View {
        let isLoading = generatingDailyDecisionCategory == category

        return Button {
            chooseDailyDecision(category)
        } label: {
            HStack(spacing: 7) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(SimastryColor.celestialBlue)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: category.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 14, height: 14)
                }

                Text(category.title)
                    .font(SimastryFont.labelMedium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(SimastryColor.offWhite)
            .frame(minWidth: 86, minHeight: 38)
            .padding(.horizontal, 10)
            .background(SimastryColor.offWhite.opacity(0.08), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(SimastryColor.celestialBlue.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
        .disabled(generatingDailyDecisionCategory != nil)
        .accessibilityLabel("Choose \(category.title)")
    }

    private func chooseDailyDecision(_ category: DailyDecisionCategory) {
        guard generatingDailyDecisionCategory == nil else { return }
        HapticManager.buttonPress()
        generatingDailyDecisionCategory = category

        Task {
            let decision = await viewModel.generateDailyDecision(
                category: category,
                transitReading: transitReading
            )
            generatingDailyDecisionCategory = nil
            viewModel.showToast(
                "Daily pick ready",
                subtitle: decision.category.title,
                isError: false
            )
        }
    }

    @ViewBuilder
    private var firstReadMemoryCard: some View {
        if let draft = viewModel.firstReadDraft, !draft.isDismissed, let sign = draft.sign {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(sign.color)
                        .frame(width: 28, height: 28)
                        .background(sign.color.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR FIRST READ")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.textSecondary)
                            .tracking(1.4)

                        Text("\(sign.displayName) message · \(draft.tone?.displayName ?? "Read")")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.gold)
                    }

                    Spacer()

                    Button {
                        HapticManager.buttonPress()
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            viewModel.dismissFirstReadDraft()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(SimastryFont.microBold)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityLabel("Dismiss your first read")
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let move = draft.bestNextMove {
                        HStack(spacing: 7) {
                            Image(systemName: move.type.systemImage)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(sign.color)

                            Text("Best next move")
                                .font(SimastryFont.captionSmall.weight(.bold))
                                .foregroundStyle(SimastryColor.gold)

                            Text(move.type.title)
                                .font(SimastryFont.captionSmall.weight(.semibold))
                                .foregroundStyle(SimastryColor.midnight)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(SimastryGradient.gold, in: Capsule())
                        }

                        Text(move.summary)
                            .font(SimastryFont.bodyMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(draft.likelyMeaning)
                            .font(SimastryFont.bodyMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if draft.bestNextMove != nil {
                        Text(draft.likelyMeaning)
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    HapticManager.buttonPress()
                    viewModel.analytics.track(
                        .firstReadContinueGuidesTapped,
                        params: [
                            "selectedSign": sign.rawValue,
                            "bestNextMove": draft.bestNextMove?.type.rawValue ?? "none"
                        ]
                    )
                    viewModel.openPanelChatWithFirstRead(draft)
                } label: {
                    Label("Continue this with your guides", systemImage: "message.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(SimastryAccentButtonStyle(accent: sign.color))

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: SimastryIcon.privacy)
                        .font(SimastryFont.microSemibold)
                        .foregroundStyle(SimastryColor.gold.opacity(0.72))

                    Text("Shared with your panel only when you open it.")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .surfaceCard(cornerRadius: 22, accent: sign.color.opacity(0.7))
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .accessibilityIdentifier("firstReadMemoryCard")
        }
    }

    private var continueStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 10) {
                    continuePills
                }
            } else {
                continuePills
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    private var continuePills: some View {
        HStack(spacing: 10) {
            Button {
                HapticManager.buttonPress()
                viewModel.startGuideChat(featuredProfile)
            } label: {
                continuePill(title: "Open guide chat", icon: "person.wave.2.fill")
            }
            .buttonStyle(SpringPressStyle())

            if let person = viewModel.relationshipPeople.first {
                Button {
                    HapticManager.buttonPress()
                    viewModel.peopleDetailRequestPersonId = person.id
                    viewModel.selectedTab = .people
                } label: {
                    continuePill(title: "Review \(person.displayName)", icon: "person.text.rectangle.fill")
                }
                .buttonStyle(SpringPressStyle())
            }

            if let savedPrompt = viewModel.todayStore.savedDailyPrompts.first {
                Button {
                    HapticManager.buttonPress()
                    viewModel.openPanelChatWithTip(
                        lesson: savedPrompt.text,
                        opener: "This is the one you saved. Want to work it through?",
                        guideId: savedPrompt.guideId
                    )
                } label: {
                    continuePill(title: "Open saved note", icon: "bookmark.fill")
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityHint("Opens the saved Today prompt with its guide")
            }
        }
    }

    private var dailyNadiaPrompt: String {
        let prompts = [
            "Say the true thing with enough room for the other person to stay open.",
            "Before you reply, separate honesty from urgency.",
            "A clean question will work better today than a perfect paragraph.",
            "If the conversation feels tight, lead with space before explanation."
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return prompts[day % prompts.count]
    }

    private func continuePill(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(SimastryFont.labelMedium)
            .foregroundStyle(SimastryColor.offWhite)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .simastryGlassPill()
    }

    // MARK: - Simulate Hero

    private var predictHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                PredictionOrbIcon(size: 42, animated: appeared)
                    .frame(width: 44, height: 44)
                    .background(SimastryColor.risingViolet.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer()

                Text(remainingPredictionsBadge)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.risingViolet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(SimastryColor.risingViolet.opacity(0.13), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("ASK THE FUTURE")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.risingViolet)
                    .tracking(1.8)

                Text("Love, timing, money, career, replies")
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("Ask one question — get a short answer, a likely window, and one move.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            simulateSourceHint

            NavigationLink(value: HomeRoute.predict) {
                PredictionOrbLabel(title: "Ask a question", iconSize: 21)
            }
            .buttonStyle(SimastryAccentButtonStyle(accent: SimastryColor.risingViolet))
            .simultaneousGesture(TapGesture().onEnded {
                HapticManager.buttonPress()
            })
            .accessibilityHint("Opens Ask the Future")

            NavigationLink(value: HomeRoute.decode) {
                Text("Decode one text instead \u{2192}")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.risingViolet)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                HapticManager.buttonPress()
            })
            .accessibilityLabel("Decode one received text")
        }
        .padding(18)
        .heroGlass(SimastryColor.risingViolet)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .zIndex(2)
    }

    private var simulateSourceHint: some View {
        HStack(spacing: 7) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SimastryColor.risingViolet.opacity(0.9))

            Text("Reads your chart and the details you add.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .help("Sources: your saved chart placements, optional relationship signs, and pasted conversation text for reply predictions.")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Future answer sources: your chart, optional relationship signs, and conversation text for replies")
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

    /// The one daily-reading card: focus line, the move, today's sky, and
    /// the talk-it-through row — four former cards merged so Today scans
    /// in one pass.
    @ViewBuilder
    private var todaysReadCard: some View {
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

                if let typeTitle = communicationType?.title {
                    Text(typeTitle)
                        .font(SimastryFont.captionSmall.weight(.semibold))
                        .foregroundStyle(SimastryColor.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
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

                if let reading = transitReading {
                    let accent: Color = switch reading.aspect.family {
                    case "flow": SimastryColor.gold
                    case "emphasis": SimastryColor.celestialBlue
                    default: SimastryColor.sunCoral
                    }

                    Divider().overlay(SimastryColor.offWhite.opacity(0.08))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Image(systemName: reading.body.systemImageName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(accent)

                            Text(reading.headline)
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        Text(reading.guidance)
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Today's sky: \(reading.headline). \(reading.guidance)")
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

    // MARK: - The Situation

    /// The most recently updated active saga — the card the user actually
    /// opens the app to check.
    private var activeSituationPerson: RelationshipPerson? {
        viewModel.relationshipPeople
            .filter { $0.situationStatus != nil }
            .max { ($0.situationUpdatedAt ?? .distantPast) < ($1.situationUpdatedAt ?? .distantPast) }
    }

    @ViewBuilder
    private var situationCard: some View {
        if let person = activeSituationPerson, let status = person.situationStatus {
            let day = person.situationDay()
            let line = AstrologyTemplates.situationLines[status.rawValue]?[person.sunSign.element.rawValue]?
                .replacingOccurrences(of: "{n}", with: "\(day)")

            Button {
                HapticManager.buttonPress()
                viewModel.selectedTab = .people
                viewModel.peopleDetailRequestPersonId = person.id
            } label: {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 8) {
                        Image(systemName: status.systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)

                        Text("THE SITUATION")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.textSecondary)
                            .tracking(1.5)

                        Spacer()

                        Text(status.title)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.gold)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(SimastryColor.gold.opacity(0.12), in: Capsule())
                    }

                    HStack(spacing: 8) {
                        ZodiacIconView(sign: person.sunSign, size: 22, showsGlow: false)

                        Text("\(person.displayName) · Day \(day)")
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.offWhite)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    if let line {
                        Text(line)
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }

                    if status == .newSpark,
                       let opener = AstrologyTemplates.newSparkOpeners[person.sunSign] {
                        HStack(alignment: .top, spacing: 8) {
                            Text("\u{201C}\(opener)\u{201D}")
                                .font(.system(.footnote, design: .serif))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 6)

                            Button {
                                HapticManager.buttonPress()
                                UIPasteboard.general.string = opener
                                viewModel.showToast("Opener copied", subtitle: "First move, ready to send", isError: false)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(SimastryColor.gold)
                                    .padding(8)
                                    .background(SimastryColor.gold.opacity(0.12), in: Circle())
                            }
                            .buttonStyle(SpringPressStyle())
                            .accessibilityLabel("Copy the first-text opener")
                        }
                        .padding(10)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard(cornerRadius: 20, accent: person.sunSign.color.opacity(0.7))
                .contentShape(.rect)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("The situation with \(person.displayName): \(status.title), day \(day). Opens their page.")
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
    }

    // MARK: - Sealed Drafts

    /// The 1am protocol's home on Today: open drafts when they exist, and a
    /// standing invitation during late-night hours when they don't.
    @ViewBuilder
    private var sealedDraftsRow: some View {
        let store = SealedDraftStore()

        if !sealedDrafts.isEmpty || SealedDraftStore.isLateNight() {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.badge.clock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.celestialBlue)

                    Text("SEALED DRAFTS")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.5)

                    Spacer()

                    Button {
                        HapticManager.buttonPress()
                        showSealedDraftCompose = true
                    } label: {
                        Label("Seal one", systemImage: "plus")
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.celestialBlue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Seal a new draft for morning")
                }

                if sealedDrafts.isEmpty {
                    Text("About to send something at this hour? Seal it for morning eyes instead.")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(sealedDrafts) { draft in
                        Button {
                            HapticManager.buttonPress()
                            rereadDraft = draft
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: draft.isReleased() ? "envelope.open.fill" : "envelope.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(draft.isReleased() ? SimastryColor.gold : SimastryColor.mutedSilver)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(draft.text)
                                        .font(SimastryFont.labelMedium)
                                        .foregroundStyle(SimastryColor.offWhite.opacity(draft.isReleased() ? 0.92 : 0.55))
                                        .lineLimit(1)

                                    Text(draft.isReleased() ? "Unsealed — still true in daylight?" : "Unseals at 8:30")
                                        .font(SimastryFont.captionSmall)
                                        .foregroundStyle(draft.isReleased() ? SimastryColor.gold : SimastryColor.textTertiary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(SimastryFont.microSemibold)
                                    .foregroundStyle(SimastryColor.mutedSilver)
                            }
                            .padding(10)
                            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(.rect)
                        }
                        .buttonStyle(SpringPressStyle())
                        .accessibilityLabel(draft.isReleased() ? "Unsealed draft, ready to reread" : "Sealed draft, unseals at 8:30")
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(cornerRadius: 20, accent: SimastryColor.celestialBlue.opacity(0.6))
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .sheet(isPresented: $showSealedDraftCompose) {
                SealedDraftView(viewModel: viewModel) {
                    sealedDrafts = store.load()
                }
            }
            .sheet(item: $rereadDraft) { draft in
                SealedDraftView(viewModel: viewModel, existingDraft: draft) {
                    sealedDrafts = store.load()
                }
            }
        }
    }

    // MARK: - Learn (Method course + daily tips, one card)

    /// One learning slot: the Method course leads while it's running, the
    /// two daily guide tips ride below as compact chips. After graduation
    /// the tips carry the card alone.
    private var learnCard: some View {
        // Establishes an observation on course progress so the card
        // re-renders after a lesson posts.
        let _ = viewModel.methodCourseVersion
        let state = viewModel.methodCourseState

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("LEARN")
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

            if !state.isComplete, let lesson = state.currentLesson {
                Button {
                    HapticManager.buttonPress()
                    viewModel.openMethodCourseLesson()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel("Simastry Method course. Take the next lesson with your panel.")

                Divider().overlay(SimastryColor.offWhite.opacity(0.08))
            }

            if !todaysTips.isEmpty {
                HStack(spacing: 10) {
                    ForEach(todaysTips) { tip in
                        compactTipChip(tip)
                    }
                }

                Text(state.isComplete ? "Method Graduate · fresh tips daily" : "Fresh tips tomorrow")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.textTertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private func compactTipChip(_ tip: DailyGuideTip) -> some View {
        Button {
            HapticManager.buttonPress()
            viewModel.openPanelChatWithTip(lesson: tip.lesson, opener: tip.opener, guideId: tip.profile.id)
        } label: {
            HStack(spacing: 8) {
                Image(tip.profile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26, alignment: .top)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(tip.profile.sign.color.opacity(0.6), lineWidth: 1)
                    }

                Text(tip.title)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Tip: \(tip.title). Start a conversation with \(tip.profile.name)")
    }


    // MARK: - Your Guides

    private var panelCard: some View {
        let profile = featuredProfile

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: SimastryIcon.astrologers)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.goldLight)

                    Text("YOUR GUIDES")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.5)
                }

                Spacer()
            }

            featuredGuidePane(profile)

            castRow

            allAstrologersButton

            talkToPanelButton
        }
        .padding(14)
        .surfaceCard(cornerRadius: 24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var allAstrologersButton: some View {
        Button {
            HapticManager.buttonPress()
            navigationPath.append(HomeRoute.aiAstrologist(profileId: nil))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: SimastryIcon.astrologers)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SimastryColor.midnight.opacity(0.82))

                Text("View Astrologers")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.midnight)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SimastryColor.midnight.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(SimastryGradient.gold, in: Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
            }
            .shadow(color: SimastryColor.gold.opacity(0.20), radius: 12, y: 6)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("View Astrologers. Opens the complete guides directory.")
    }

    /// Opens the group thread with the user's three placement guides.
    private var talkToPanelButton: some View {
        Button {
            HapticManager.buttonPress()
            viewModel.openPanelChat()
        } label: {
            HStack(spacing: 10) {
                panelFaceStack(size: 26)

                Text("Talk to your panel")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Spacer()

                if viewModel.unreadPanelCount > 0 {
                    Text("\(viewModel.unreadPanelCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SimastryColor.midnight)
                        .frame(minWidth: 19)
                        .frame(height: 19)
                        .background(SimastryColor.gold, in: Capsule())
                }

                Image(systemName: SimastryIcon.message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SimastryColor.goldLight.opacity(0.92))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(SimastryColor.surfaceSunken.opacity(0.88), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.16), SimastryColor.gold.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Talk to your panel. Group chat with your three guides.")
    }

    private func panelFaceStack(size: CGFloat) -> some View {
        HStack(spacing: -10) {
            ForEach(Array(viewModel.panelGuideEntries.enumerated()), id: \.element.id) { index, entry in
                Image(entry.profile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size, alignment: .top)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(entry.sign.color.opacity(0.65), lineWidth: 1)
                    }
                    .background {
                        Circle().fill(SimastryColor.midnight)
                            .frame(width: size + 3, height: size + 3)
                    }
                    .zIndex(Double(viewModel.panelGuideEntries.count - index))
            }
        }
    }

    private func featuredGuidePane(_ profile: FactoryCompanionProfile) -> some View {
        NavigationLink(value: HomeRoute.guideProfile(profileId: profile.id)) {
            ZStack(alignment: .bottom) {
                featuredGuideMedia(profile)

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
                            .font(SimastryFont.microBold)
                        Text("SIMASTRY METHOD")
                            .font(SimastryFont.microBold)
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

    @ViewBuilder
    private func featuredGuideMedia(_ profile: FactoryCompanionProfile) -> some View {
        ZStack(alignment: .topLeading) {
            featuredGuideImage(profile)

            if profile.id == "sagittarius-nadia", !reduceMotion {
                GeometryReader { proxy in
                    let sourceAspect: CGFloat = 16.0 / 9.0
                    let videoWidth = max(proxy.size.width, proxy.size.height * sourceAspect)
                    let rightSideFocusOffset = max(0, videoWidth - proxy.size.width) * 0.66

                    MutedLoopingVideoView(resourceName: "NadiaFeaturedGuide", resourceExtension: "mp4")
                        .frame(width: videoWidth, height: proxy.size.height)
                        .offset(x: -rightSideFocusOffset)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240, alignment: .top)
        .clipped()
    }

    private func featuredGuideImage(_ profile: FactoryCompanionProfile) -> some View {
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
    }

    private var castRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(castRowProfiles) { profile in
                    NavigationLink(value: HomeRoute.guideProfile(profileId: profile.id)) {
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

    private var remainingPredictionsBadge: String {
        viewModel.weeklyPredictionLimit == .max ? "Unlimited" : "\(viewModel.remainingWeeklyPredictions) left this week"
    }
}
