import SwiftUI
import PhotosUI

nonisolated private enum ProfileSheet: Identifiable {
    case companion(CompanionData)
    case share(ShareableCardType)
    #if DEBUG
    case developerMenu
    #endif
    case about
    case privacy
    case terms
    case methodology
    case astrologerPartner
    case profileDetails
    case aura
    case careerRead
    case settings
    case journal
    case expertKnowledge

    var id: String {
        switch self {
        case .companion(let companion):
            "companion_\(companion.id.uuidString)"
        case .share(let type):
            "share_\(type.rawValue)"
        #if DEBUG
        case .developerMenu:
            "developerMenu"
        #endif
        case .about:
            "about"
        case .privacy:
            "privacy"
        case .terms:
            "terms"
        case .methodology:
            "methodology"
        case .astrologerPartner:
            "astrologerPartner"
        case .profileDetails:
            "profileDetails"
        case .aura:
            "aura"
        case .careerRead:
            "careerRead"
        case .settings:
            "settings"
        case .journal:
            "journal"
        case .expertKnowledge:
            "expertKnowledge"
        }
    }
}

struct ProfileView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @StateObject private var streakManager = StreakManager.shared
    @State private var showSignOutConfirmation: Bool = false
    @State private var showLanguagePicker: Bool = false
    @State private var tapCount: Int = 0
    @State private var expandedRoles: Set<CelestialRole> = []
    @State private var appeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var activeSheet: ProfileSheet?
    @State private var referralCodeInput: String = ""
    @State private var showReferralConfirmation: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showDeletePhotoConfirmation: Bool = false
    @State private var showDeleteAccountConfirmation: Bool = false
    @State private var exportFileURL: URL?
    @State private var showExportShare: Bool = false
    @State private var showDiscoveryView: Bool = false
    @State private var handledAuraRouteRequest: Int = 0
    @State private var handledShareCardRouteRequest: Int = 0
    @State private var handledCareerReadRouteRequest: Int = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 8)

                        profileRenderSection("about-you") {
                            if viewModel.hasCompletedSigns {
                                if let sun = viewModel.userSunSign,
                                   let moon = viewModel.userMoonSign,
                                   let rising = viewModel.userRisingSign {
                                    aboutYouSection(sun: sun, moon: moon, rising: rising)
                                } else {
                                    placeholderSignCards
                                    auraButtonSection
                                }
                            } else {
                                placeholderSignCards
                                auraButtonSection
                            }
                        }

                        profileRenderSection("companion") {
                            if AppConfig.expertAstrologersEnabled {
                                expertAstrologersProfileSection
                            } else {
                                if viewModel.hasCompletedSigns {
                                    if let companion = viewModel.companions.first {
                                        companionSafeSection(companion)
                                    }
                                } else {
                                    placeholderCompanionSection
                                }
                            }
                        }

                        profileRenderSection("tools") {
                            profileHubSection
                        }

                        profileRenderSection("language") {
                            languageSelector
                        }

                        profileRenderSection("footer") {
                            footerSection

                            deleteAccountSection
                        }

                        Spacer().frame(height: SimastrySpacing.tabBarEndClearance)
                    }
                    .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .background { CelestialBackground() }
            .accessibilityHidden(activeSheet != nil)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(SimastryColor.gold)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.buttonPress()
                        activeSheet = .settings
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .tint(SimastryColor.gold)
                    .accessibilityLabel("Open settings")
                    .accessibilityIdentifier("profile.settingsButton")
                }
            }
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await viewModel.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Clear Local Data", isPresented: $showDeleteAccountConfirmation) {
                Button("Clear Local Data", role: .destructive) {
                    viewModel.clearLocalDeviceData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes saved notes, local people, wallet address, and device-only Simastry data from this iPhone. Your account is not deleted.")
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .companion(let companion):
                    CompanionDetailSheet(companion: companion, viewModel: viewModel)
                case .share(let cardType):
                    ShareableCardView(viewModel: viewModel, cardType: cardType)
                #if DEBUG
                case .developerMenu:
                    devMenuSheet
                #endif
                case .about:
                    aboutSheet
                case .privacy:
                    legalSheet(title: "Privacy Policy", body: "Simastry collects the data needed to deliver your personalized astrology experience: profile details you enter, sign placements, expert AI consultation history, People records, Aura settings, and optional read-only wallet context such as a public address and per-sign Zodiac counts.\n\nExpert AI requests are processed through Simastry's backend and may be sent to an AI provider to generate a response. Wallet checks use only public addresses and are routed through Simastry's backend before supported chain data is queried. Simastry cannot sign, approve, or move funds.\n\nWe use privacy-conscious analytics and crash logs to improve performance. No personal data is sold or used for advertising.\n\nFor the full privacy policy, visit our website.")
                case .terms:
                    legalSheet(title: "Terms of Service", body: "By using Simastry, you agree to use the app for personal entertainment and self-reflection purposes. Astrology readings and predictions are for entertainment only and should not be used as a substitute for professional advice.\n\nSimastry subscriptions are managed through Apple and can be canceled at any time via your Apple ID settings. Refunds are handled by Apple per their refund policy.\n\nFor the full terms of service, visit our website.")
                case .methodology:
                    methodologySheet
                case .astrologerPartner:
                    astrologerPartnerSheet
                case .profileDetails:
                    profileDetailsSheet
                case .aura:
                    AuraView(viewModel: viewModel)
                case .careerRead:
                    CareerReadView(viewModel: viewModel)
                case .settings:
                    SimastrySettingsView(viewModel: viewModel)
                case .journal:
                    SavedInsightsView(viewModel: viewModel)
                case .expertKnowledge:
                    ExpertKnowledgeView(viewModel: viewModel)
                }
            }
            .onAppear {
                CrashReporter.log("ProfileView appeared")
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.spring(SimastrySpring.smooth).delay(0.1)) {
                        appeared = true
                    }
                }
                presentProfileRoutesIfRequested()
            }
            .onChange(of: viewModel.auraRouteRequest) {
                presentProfileRoutesIfRequested()
            }
            .onChange(of: viewModel.shareCardRouteRequest) {
                presentProfileRoutesIfRequested()
            }
            .onChange(of: viewModel.careerReadRouteRequest) {
                presentProfileRoutesIfRequested()
            }
        }
    }

    private func profileRenderSection<Content: View>(
        _ name: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .onAppear {
                CrashReporter.log("ProfileView section appeared: \(name)")
            }
    }

    /// Catch sheet requests fired before this view mounted (deep links,
    /// preview seeding) — same handled-counter pattern as the Home routes.
    private func presentProfileRoutesIfRequested() {
        if viewModel.auraRouteRequest > handledAuraRouteRequest {
            handledAuraRouteRequest = viewModel.auraRouteRequest
            activeSheet = .aura
        }
        if viewModel.shareCardRouteRequest > handledShareCardRouteRequest {
            handledShareCardRouteRequest = viewModel.shareCardRouteRequest
            activeSheet = .share(.cosmicDNA)
        }
        if viewModel.careerReadRouteRequest > handledCareerReadRouteRequest {
            handledCareerReadRouteRequest = viewModel.careerReadRouteRequest
            activeSheet = .careerRead
        }
    }

    private var communicationType: CommunicationTypeProfile? {
        CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    private var astrologerContactURL: URL {
        URL(string: "mailto:\(AppConfig.astrologerContactEmail)") ?? AppConfig.websiteURL
    }

    // MARK: - Placeholder Sign Cards

    private var placeholderSignCards: some View {
        VStack(spacing: 16) {
            placeholderSignCard(
                systemImage: CelestialRole.sun.iconName,
                title: "Your Sun Sign",
                subtitle: "Your core identity",
                description: "Discover who you are at your center",
                delay: 0
            )
            placeholderSignCard(
                systemImage: CelestialRole.moon.iconName,
                title: "Your Moon Sign",
                subtitle: "Your emotional world",
                description: "Understand how you feel and process",
                delay: 0.1
            )
            placeholderSignCard(
                systemImage: CelestialRole.rising.iconName,
                title: "Your Rising Sign",
                subtitle: "Your outer energy",
                description: "See how the world experiences you",
                delay: 0.2
            )

            GoldButton("Discover Your Signs") {
                viewModel.selectedTab = .today
            }
            .padding(.top, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)
        }
    }

    private func placeholderSignCard(systemImage: String, title: String, subtitle: String, description: String, delay: Double) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(
                        SimastryColor.gold.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.6))
                Text(subtitle)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Rectangle()
                    .fill(SimastryColor.gold.opacity(0.15))
                    .frame(height: 1)
                    .frame(maxWidth: 120)
                    .padding(.vertical, 2)

                Text(description)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver.opacity(0.7))
            }

            Spacer()
        }
        .padding(16)
        .simastryGlass(cornerRadius: 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(reduceMotion ? .default : .spring(SimastrySpring.bouncy).delay(delay), value: appeared)
    }

    // MARK: - Placeholder Companion

    private var placeholderCompanionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Companion")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.mutedSilver)

            HStack(spacing: 14) {
                profileSymbolTile(
                    systemName: "person.fill.questionmark",
                    accent: SimastryColor.mutedSilver,
                    size: 42
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Not yet created")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.5))
                    Text("Complete your signs first")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Spacer()
            }
            .padding(16)
            .simastryGlass(cornerRadius: 16)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var expertAstrologersProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expert Astrologers")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.mutedSilver)

            Button {
                HapticManager.buttonPress()
                viewModel.openAIAstrologists()
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: -8) {
                        ForEach(Array(ExpertAstrologerRegistry.specialists.enumerated()), id: \.element.id) { index, specialist in
                            expertAstrologerAvatar(specialist, size: 40)
                                .zIndex(Double(ExpertAstrologerRegistry.specialists.count - index))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Leyla, Mateo, Naomi, Soren, and Nadia")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                            .lineLimit(2)
                        Text("Five AI astrology specialists, each grounded in a distinct tradition.")
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(15)
                .glossyCard(cornerRadius: 18)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Open Expert Astrologers")
            .accessibilityHint("Consult Leyla, Mateo, Naomi, Soren, and Nadia")
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func expertAstrologerAvatar(_ specialist: AstrologySpecialist, size: CGFloat) -> some View {
        ZStack {
            if let profile = specialist.archivedProfile {
                Image(profile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size, alignment: .top)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(SimastryColor.gold.opacity(0.18))
                    .overlay {
                        Text(specialist.placeholderAvatar)
                            .font(.system(size: size * 0.45))
                    }
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Circle().strokeBorder(SimastryColor.gold.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 8, y: 5)
        .accessibilityHidden(true)
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .scaleEffect(streakManager.isMilestone && !reduceMotion ? 1.1 : 1.0)
                    .animation(
                        streakManager.isMilestone && !reduceMotion
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: streakManager.isMilestone
                    )

                Text("Your Streak")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)

                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(streakManager.currentStreak)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(SimastryColor.gold)

                    Text("current")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                VStack(spacing: 4) {
                    Text("\(streakManager.longestStreak)")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimastryColor.goldDark)

                    Text("longest")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Spacer()
            }

            StreakCalendarView(
                currentStreak: streakManager.currentStreak,
                lastCheckIn: streakManager.lastCheckIn
            )

            methodCourseLine
        }
        .padding(20)
        .glossyCard(cornerRadius: 22)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var methodCourseLine: some View {
        let _ = viewModel.methodCourseVersion
        let state = viewModel.methodCourseState

        return HStack(spacing: 7) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)

            Text(state.isComplete
                 ? "Simastry Method Graduate"
                 : "Simastry Method · \(state.postedLessons.count) of \(MethodCourseTemplates.lessons.count) lessons")
                .font(SimastryFont.labelSmall)
                .foregroundStyle(state.isComplete ? SimastryColor.gold : SimastryColor.mutedSilver)

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - About You Section

    private func aboutYouSection(sun: ZodiacSign, moon: ZodiacSign, rising: ZodiacSign) -> some View {
        VStack(spacing: 24) {
            profileImageSection
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            signEntry(role: .sun, sign: sun, delay: 0)
            signEntry(role: .moon, sign: moon, delay: 0.15)
            signEntry(role: .rising, sign: rising, delay: 0.3)

            // Communication signals section
            conversationGuideSection(sun: sun)

            // Aura sits below the chart and communication guide now, not at the top.
            auraButtonSection

            careerReadButtonSection

            Button(action: {
                activeSheet = .share(.cosmicDNA)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(SimastryFont.labelSmall)
                    Text("Share Your Card")
                        .font(SimastryFont.labelMedium)
                }
                .foregroundStyle(SimastryColor.gold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share your Simastry card")

            if AppConfig.socialDiscoveryEnabled {
                // MARK: Public Identity
                socialAccountsSection
            }

            if AppConfig.socialDiscoveryEnabled {
                // MARK: Find Others Like You
                discoverySection
            }
        }
    }

    private var auraButtonSection: some View {
        Button {
            HapticManager.buttonPress()
            activeSheet = .aura
        } label: {
            HStack(spacing: 14) {
                profileSymbolTile(
                    systemName: "sparkles",
                    accent: viewModel.userSunSign?.color ?? SimastryColor.gold,
                    size: 54
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Aura")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(auraButtonSubtitle)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .padding(16)
            .simastryGlass(cornerRadius: 20)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Open your Aura page")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private var careerReadButtonSection: some View {
        Button {
            HapticManager.buttonPress()
            activeSheet = .careerRead
        } label: {
            HStack(spacing: 14) {
                profileSymbolTile(
                    systemName: "briefcase.fill",
                    accent: SimastryColor.celestialBlue,
                    size: 54
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Career Read")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text("How you work, lead, and read to colleagues — plus how to decode your boss.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .padding(16)
            .simastryGlass(cornerRadius: 20)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Open your Career Read")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private func profileSymbolTile(systemName: String, accent: Color, size: CGFloat) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [accent.opacity(0.22), .white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
    }

    private var auraButtonSubtitle: String {
        if let profile = CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        ) {
            return "\(profile.title) · chart-signal energy"
        }
        return "Visualize your Sun, Moon, and Rising once your signs are set."
    }

    private func aboutYouSafeSection(sun: ZodiacSign, moon: ZodiacSign, rising: ZodiacSign) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("About You")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                    if let communicationType {
                        Text(communicationType.title)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(communicationType.accent)
                    }
                }

                Spacer()

                Button {
                    HapticManager.buttonPress()
                    activeSheet = .profileDetails
                } label: {
                    Text("Details")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.gold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(SimastryColor.gold.opacity(0.11), in: Capsule())
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel("Open profile details")
            }

            HStack(spacing: 10) {
                compactSignTile(role: .sun, sign: sun)
                compactSignTile(role: .moon, sign: moon)
                compactSignTile(role: .rising, sign: rising)
            }

            HStack(spacing: 10) {
                safeProfileAction(
                    title: "Aura",
                    subtitle: "Your chart energy",
                    systemImage: "sparkles",
                    accent: sun.color
                ) {
                    activeSheet = .aura
                }

                safeProfileAction(
                    title: "Share",
                    subtitle: "Your card",
                    systemImage: "square.and.arrow.up",
                    accent: SimastryColor.gold
                ) {
                    activeSheet = .share(.cosmicDNA)
                }
            }
        }
        .padding(18)
        .glossyCard(cornerRadius: 22)
        .accessibilityIdentifier("profile.aboutYouCompact")
    }

    private func companionSafeSection(_ companion: CompanionData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Guide")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)

            Button {
                HapticManager.buttonPress()
                activeSheet = .companion(companion)
            } label: {
                HStack(spacing: 13) {
                    profileSymbolTile(
                        systemName: "sparkle.magnifyingglass",
                        accent: ZodiacSign(rawValue: companion.sunSign.lowercased())?.color ?? SimastryColor.gold,
                        size: 44
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(companion.name.isEmpty ? "Guide" : companion.name)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                            .lineLimit(1)
                        Text("\(companion.sunSign.capitalized) guide")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .padding(15)
                .glossyCard(cornerRadius: 18)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Open your guide")
        }
    }

    private func safeProfileAction(
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text(subtitle)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(title == "Share" ? "Share your Simastry card" : (title == "Aura" ? "Open your Aura page" : title))
    }

    private func aboutYouCompactSection(sun: ZodiacSign, moon: ZodiacSign, rising: ZodiacSign) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("About You")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Spacer()
                Button {
                    HapticManager.buttonPress()
                    activeSheet = .profileDetails
                } label: {
                    Text("Details")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.gold)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                compactSignTile(role: .sun, sign: sun)
                compactSignTile(role: .moon, sign: moon)
                compactSignTile(role: .rising, sign: rising)
            }

            if let communicationType {
                Text(communicationType.title)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.86))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(communicationType.accent.opacity(0.14), in: Capsule())
            }
        }
        .padding(18)
        .glossyCard(cornerRadius: 22)
        .accessibilityIdentifier("profile.aboutYouCompact")
    }

    private func compactSignTile(role: CelestialRole, sign: ZodiacSign) -> some View {
        VStack(spacing: 7) {
            ZodiacIconView(sign: sign, size: 30, showsGlow: false)
            Text(role.displayName)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
            Text(sign.displayName)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(sign.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var profileHubSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile tools")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)

            profileHubButton(
                title: "Profile details",
                subtitle: "Moments, invites, public identity, and data.",
                systemImage: "person.text.rectangle.fill"
            ) {
                activeSheet = .profileDetails
            }

            profileHubButton(
                title: "Settings",
                subtitle: "Account, privacy, and local app controls.",
                systemImage: "gearshape.fill"
            ) {
                activeSheet = .settings
            }

            profileHubButton(
                title: "Private journal",
                subtitle: "Lines you saved from notes and readings. This device only.",
                systemImage: "bookmark.fill"
            ) {
                activeSheet = .journal
            }

            profileHubButton(
                title: "What the experts know",
                subtitle: "Per-expert data on file, gaps, and where to edit it.",
                systemImage: "lock.shield.fill"
            ) {
                activeSheet = .expertKnowledge
            }

            profileHubButton(
                title: "How Simastry works",
                subtitle: "Methodology, AI disclosure, and privacy.",
                systemImage: "books.vertical.fill"
            ) {
                activeSheet = .methodology
            }

            profileHubButton(
                title: "Work with an astrologer",
                subtitle: "Find a human reader for deeper chart work.",
                systemImage: "person.crop.circle.badge.checkmark"
            ) {
                openURL(AppConfig.astrologerDirectoryURL)
            }
        }
    }

    private func profileHubButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .frame(width: 38, height: 38)
                    .background(SimastryColor.gold.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text(subtitle)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .padding(15)
            .simastryGlass(cornerRadius: 18)
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
    }

    private var profileDetailsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    MomentsSection(viewModel: viewModel)
                    subscriptionSection
                    aboutOurApproachSection
                    astrologerSection
                    InviteFriendsCard(viewModel: viewModel)
                    referralCodeSection
                    forAstrologersSection
                    dataExportSection

                    if viewModel.hasCompletedSigns {
                        streakSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            // `.background` (not a full-bleed ZStack layer) keeps the scroll
            // content inset below the nav bar so the first card isn't clipped.
            .background { CelestialBackground() }
            .navigationTitle("Profile details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        activeSheet = nil
                    }
                    .tint(SimastryColor.gold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Discovery Section

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if AppConfig.socialDiscoveryEnabled {
                Button {
                    showDiscoveryView = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.2.wave.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [SimastryColor.gold, SimastryColor.goldLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Find Others Like You")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .padding(16)
                    .glossyCard()
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel("Find other Simastry users with compatible signs")
                .accessibilityHint("Opens discovery to find people with similar or compatible signs")
                .accessibilityIdentifier("profile.discoveryButton")
                .fullScreenCover(isPresented: $showDiscoveryView) {
                    DiscoveryView(viewModel: viewModel)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Visible in Discovery")
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                        Text("Make your profile visible to others. You can always browse without being visible.")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { viewModel.isDiscoverable },
                        set: { newValue in
                            if newValue != viewModel.isDiscoverable {
                                viewModel.toggleDiscoverability()
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(SimastryColor.gold)
                }
                .padding(.horizontal, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Visible in discovery toggle. Make your profile visible to others. You can always browse without being visible. Currently \(viewModel.isDiscoverable ? "on" : "off")")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.2.wave.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)
                        Text("Discovery Unavailable")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                    }

                    Text("Discovery profiles are temporarily unavailable in this build. You can still manage your profile and messages.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .glossyCard()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Discovery unavailable. Discovery profiles are temporarily unavailable in this build.")
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    // MARK: - Public Identity Section

    private var socialAccountsSection: some View {
        let normalized = PublicProfile.normalizedUsername(viewModel.publicUsername)
        let hasUsername = !normalized.isEmpty
        let usernameIsValid = PublicProfile.isValidUsername(normalized)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "at.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                Text("Public Identity")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
            }

            Text("One Simastry username powers discovery, messages, and share cards.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("SIMASTRY USERNAME")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.deepMuted)
                    .tracking(0.8)

                HStack(spacing: 10) {
                    Text("@")
                        .font(SimastryFont.bodyMedium)
                        .foregroundStyle(SimastryColor.gold)

                    TextField("maya.sag", text: $viewModel.publicUsername)
                        .font(SimastryFont.bodyMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: viewModel.publicUsername) {
                            viewModel.publicUsername = PublicProfile.normalizedUsername(viewModel.publicUsername)
                            viewModel.updateSocialProfile()
                        }
                        .accessibilityLabel("Simastry username")
                        .accessibilityHint("This is the only public username Simastry uses.")
                }
                .padding(12)
                .simastryGlass(cornerRadius: 12)
                .help("Source: your public profile username. This is the single handle shown in Discovery, Messages, and share cards.")

                Text(hasUsername && !usernameIsValid
                     ? "Use 3-24 lowercase letters, numbers, periods, or underscores."
                     : "This is the only public handle Simastry shows.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(hasUsername && !usernameIsValid ? SimastryColor.sunCoral : SimastryColor.deepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 7) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("Outside social handles stay off your core Simastry identity.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.deepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .help("Simastry no longer publishes Instagram, TikTok, or X handles from this profile surface.")
        }
        .padding(18)
        .glossyCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    // MARK: - Profile Image Picker

    private var profileImageSection: some View {
        let profileImage = viewModel.profileImage
        let sunSign = viewModel.userSunSign

        return VStack(spacing: 10) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ProfileImageView(
                    image: profileImage,
                    size: 100,
                    showEditBadge: profileImage != nil,
                    sunSign: sunSign
                )
            }
            .buttonStyle(.plain)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await processSelectedPhoto(newItem)
                }
            }
            .contextMenu {
                if viewModel.profileImage != nil {
                    Button(role: .destructive) {
                        showDeletePhotoConfirmation = true
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog(
                "Remove Profile Photo",
                isPresented: $showDeletePhotoConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    viewModel.deleteProfileImage()
                }
                Button("Cancel", role: .cancel) {}
            }

            if viewModel.profileImage == nil {
                Text("Tap to add a photo")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func processSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let originalImage = UIImage(data: data) else { return }

        let resized = resizeImage(originalImage, maxDimension: 400)
        viewModel.saveProfileImage(resized)
        selectedPhotoItem = nil
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func conversationGuideSection(sun: ZodiacSign) -> some View {
        let guide = CommunicationTemplates.guides[sun]

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.celestialBlue)
                Text("How to Talk to You")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Spacer()
                Button {
                    activeSheet = .share(.cosmicDNA)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.gold)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share your Simastry card")
                .accessibilityHint("Creates a share card with your signs and how to talk to you")
            }

            if let guide {
                Text("As a \(sun.displayName), here's what people should know:")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(guide.tips.enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkle")
                                .font(SimastryFont.microSemibold)
                                .foregroundStyle(SimastryColor.gold)
                                .padding(.top, 3)
                            Text(tip)
                                .font(SimastryFont.bodyLarge)
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                                .lineSpacing(2)
                        }
                    }
                }

                // Best approach
                VStack(alignment: .leading, spacing: 6) {
                    Text("Best Approach")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.gold)
                        .tracking(1)
                        .textCase(.uppercase)
                    Text(guide.bestApproach)
                        .font(SimastryFont.bodyLarge)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                        .lineSpacing(2)
                }
                .padding(12)
                .surfaceCard(cornerRadius: 12, accent: SimastryColor.gold.opacity(0.6))

                // What to avoid
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(SimastryColor.amber)
                        Text("What to Avoid")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.amber)
                            .tracking(1)
                            .textCase(.uppercase)
                    }
                    Text(guide.avoid)
                        .font(SimastryFont.bodyLarge)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.7))
                        .lineSpacing(2)
                }
                .padding(12)
                .surfaceCard(cornerRadius: 12, accent: SimastryColor.amber.opacity(0.6))
            }
        }
        .padding(18)
        .simastryGlass(cornerRadius: 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    private func signEntry(role: CelestialRole, sign: ZodiacSign, delay: Double) -> some View {
        let isExpanded = expandedRoles.contains(role)
        let templates: [String: String] = {
            switch role {
            case .sun: return AstrologyTemplates.sunSign
            case .moon: return AstrologyTemplates.moonSign
            case .rising: return AstrologyTemplates.risingSign
            }
        }()

        return Button(action: {
            withAnimation(reduceMotion ? .default : .spring(SimastrySpring.snappy)) {
                if expandedRoles.contains(role) {
                    expandedRoles.remove(role)
                } else {
                    expandedRoles.insert(role)
                }
            }
        }) {
            HStack(spacing: 14) {
                CelestialRoleIcon(role: role, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(role.displayName) in \(sign.displayName)")
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(role.accentColor)
                        ZodiacIconView(sign: sign, size: 16, showsGlow: false)
                    }

                    Text(role.subtitle)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    if isExpanded {
                        Text(templates[sign.rawValue] ?? "")
                            .font(SimastryFont.bodyLarge)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.7))
                            .lineSpacing(3)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(role.displayName) in \(sign.displayName). \(role.subtitle)")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    // MARK: - Companion Section

    private func companionSection(_ companion: CompanionData) -> some View {
        let level = RelationshipLevel.from(messageCount: companion.conversationCount)
        let matchedProfile = FactoryCompanionCatalog.match(for: companion)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Your \(companion.mode.replacingOccurrences(of: "_", with: " ").capitalized)")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.mutedSilver)

            Button(action: {
                activeSheet = .companion(companion)
            }) {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        companionPortraitTile(matchedProfile, size: 48)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(companion.name)
                                .font(SimastryFont.titleSmall)
                                .foregroundStyle(SimastryColor.offWhite)
                            Text(companion.mode.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(SimastryFont.caption)
                                .foregroundStyle(SimastryColor.mutedSilver)
                        }

                        Spacer()

                        CompatibilityRingView(score: companion.compatibilityScore, size: 48)
                    }

                    HStack(spacing: 8) {
                        if let sun = ZodiacSign(rawValue: companion.sunSign) {
                            ZodiacBadgeView(sign: sun, isSelected: false, size: 24)
                        }
                        if let moon = ZodiacSign(rawValue: companion.moonSign) {
                            ZodiacBadgeView(sign: moon, isSelected: false, size: 24)
                        }
                        if let rising = ZodiacSign(rawValue: companion.risingSign) {
                            ZodiacBadgeView(sign: rising, isSelected: false, size: 24)
                        }
                        Spacer()
                        RelationshipBadgeView(
                            level: level,
                            messageCount: companion.conversationCount,
                            size: 32
                        )
                    }
                }
                .padding(18)
                .simastryGlass(cornerRadius: 18)
            }
            .buttonStyle(SpringPressStyle())
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func companionPortraitTile(_ profile: FactoryCompanionProfile, size: CGFloat) -> some View {
        Image(profile.profileImageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size, alignment: .top)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(profile.sign.color.opacity(0.72), lineWidth: 1.2)
            }
            .shadow(color: profile.sign.color.opacity(0.22), radius: 10, y: 4)
            .help("Source: the companion portrait matched from this companion's name and Sun sign.")
            .accessibilityLabel("\(profile.name) portrait")
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        let tier = viewModel.profile?.tier ?? "free"
        let isBetaAccess = !viewModel.isRevenueCatAvailable

        return VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        tierLabel(isBetaAccess ? "beta" : tier)

                        if isBetaAccess {
                            Text("Internal beta access is unlocked while purchases are unavailable.")
                                .font(SimastryFont.bodySmall)
                                .foregroundStyle(SimastryColor.mutedSilver)
                        } else {
                            Button(action: {
                                if tier == "free" {
                                    viewModel.showUpsell = true
                                } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                    openURL(url)
                                }
                            }) {
                                Text(tier == "free" ? "Upgrade" : "Manage Subscription")
                                    .font(SimastryFont.bodySmall)
                                    .foregroundStyle(SimastryColor.gold)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()
                }

                if isBetaAccess {
                    HStack(spacing: 10) {
                        unlimitedChip("Beta messages")
                        unlimitedChip(AppConfig.expertAstrologersEnabled ? "Expert access" : "Guide access")
                    }
                } else if tier == "free" {
                    HStack(spacing: 16) {
                        usagePill(
                            label: "Messages",
                            value: "\(viewModel.remainingDailyMessages)",
                            subtitle: "today",
                            tint: SimastryColor.celestialBlue
                        )
                        usagePill(
                            label: AppConfig.expertAstrologersEnabled ? "Experts" : "Companions",
                            value: AppConfig.expertAstrologersEnabled ? "\(ExpertAstrologerRegistry.specialists.count)" : "\(viewModel.companions.count)/\(viewModel.companionLimit)",
                            subtitle: AppConfig.expertAstrologersEnabled ? "available" : "slots",
                            tint: SimastryColor.gold
                        )
                    }

                } else {
                    HStack(spacing: 10) {
                        unlimitedChip("Unlimited messages")
                        unlimitedChip(AppConfig.expertAstrologersEnabled ? "All five experts" : "More companions")
                    }
                }
            }
            .padding(20)
            .simastryGlass(cornerRadius: 18)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 25)
    }

    private func usagePill(label: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(tint)
            Text(label)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.offWhite)
            Text(subtitle)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    private func unlimitedChip(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "infinity")
                .font(SimastryFont.microBold)
            Text(text)
                .font(SimastryFont.labelSmall)
        }
        .foregroundStyle(SimastryColor.gold)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SimastryColor.gold.opacity(0.1), in: .capsule)
    }

    @ViewBuilder
    private func tierLabel(_ tier: String) -> some View {
        switch tier {
        case "beta":
            Text("Beta Access")
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.gold)
        case "plus":
            Text("Simastry+")
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.gold)
        case "pro":
            Text("Simastry Pro")
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.gold)
        default:
            Text("Free")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
    }

    // MARK: - Theme Toggle

    private var themeToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.string("profile.appearance"))
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)

            Button(action: {
                HapticManager.themeToggle()
                withAnimation(reduceMotion ? .default : .spring(SimastrySpring.snappy)) {
                    viewModel.isDarkMode.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(SimastryColor.gold)
                        .contentTransition(.symbolEffect(.replace))
                    Text(viewModel.isDarkMode ? localization.string("profile.dark") : localization.string("profile.light"))
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .simastryGlassPill(interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localization.string("profile.darkMode"))
            .accessibilityValue(viewModel.isDarkMode ? localization.string("profile.dark") : localization.string("profile.light"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Language Selector

    private var languageSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.string("profile.language"))
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)

            Button(action: {
                HapticManager.buttonPress()
                showLanguagePicker = true
            }) {
                HStack(spacing: 10) {
                    Text(localization.currentLanguage.shortCode)
                        .font(SimastryFont.captionSmall.weight(.bold))
                        .foregroundStyle(SimastryColor.gold)
                        .frame(width: 34, height: 24)
                        .background(SimastryColor.gold.opacity(0.12), in: Capsule())
                    Text(localization.currentLanguage.displayName)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .simastryGlassPill(interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localization.string("profile.language"))
            .accessibilityValue(localization.currentLanguage.displayName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
        }
    }

    private var languagePickerSheet: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(LocalizationManager.Language.allCases) { language in
                            Button(action: {
                                HapticManager.buttonPress()
                                withAnimation(.spring(SimastrySpring.snappy)) {
                                    localization.currentLanguage = language
                                }
                                showLanguagePicker = false
                            }) {
                                HStack(spacing: 14) {
                                    Text(language.shortCode)
                                        .font(SimastryFont.captionSmall.weight(.bold))
                                        .foregroundStyle(SimastryColor.gold)
                                        .frame(width: 42, height: 28)
                                        .background(SimastryColor.gold.opacity(0.12), in: Capsule())

                                    Text(language.displayName)
                                        .font(SimastryFont.titleSmall)
                                        .foregroundStyle(SimastryColor.offWhite)

                                    Spacer()

                                    if localization.currentLanguage == language {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(SimastryColor.gold)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .simastryGlass(cornerRadius: 16)
                            }
                            .buttonStyle(SpringPressStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(localization.string("profile.selectLanguage"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localization.string("common.cancel")) {
                        showLanguagePicker = false
                    }
                    .foregroundStyle(SimastryColor.gold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - About Our Approach

    private var aboutOurApproachSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.string("profile.aboutApproach"))
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)

            Button(action: {
                activeSheet = .methodology
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.string("profile.methodology"))
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                        Text("Methodology, AI disclosure & privacy")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .padding(16)
                .simastryGlass(cornerRadius: 16)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("How Simastry Works. Learn about our methodology, AI disclosure, and privacy commitment.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
    }

    private var methodologySheet: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    Text("How Simastry Works")
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(AppConfig.astrologyTradition)
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .padding(.top, 24)

                ForEach(Array(AstrologyTemplates.methodology.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: section.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(SimastryColor.gold)

                            Text(section.title)
                                .font(SimastryFont.titleSmall)
                                .foregroundStyle(SimastryColor.offWhite)
                        }

                        Text(section.body)
                            .font(SimastryFont.bodyLarge)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.82))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .simastryGlass(cornerRadius: 16)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    // MARK: - Work with an Astrologer

    private var astrologerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Work with an Astrologer")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.mutedSilver)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                        .frame(width: 44, height: 44)
                        .background(SimastryColor.gold.opacity(0.10), in: .rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(SimastryColor.gold.opacity(0.15), lineWidth: 0.5)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recommended by Astrologers")
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text("Simastry helps you use astrological insights daily. For deeper chart readings, consult a professional astrologer.")
                            .font(SimastryFont.bodyLarge)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Link(destination: AppConfig.astrologerDirectoryURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Find an Astrologer")
                            .font(SimastryFont.labelLarge)
                    }
                    .foregroundStyle(SimastryColor.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SimastryColor.gold.opacity(0.12), in: .capsule)
                    .overlay(
                        Capsule()
                            .stroke(SimastryColor.gold.opacity(0.25), lineWidth: 0.5)
                    )
                }
            }
            .padding(18)
            .simastryGlass(cornerRadius: 20)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Referral Code

    private var referralCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Referral Code")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.mutedSilver)

            if let info = viewModel.referralInfo, let code = info.referralCode, !code.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Referral applied \u{2713}")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.gold)
                        Text(code)
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }

                    Spacer()
                }
                .padding(16)
                .simastryGlass(cornerRadius: 16)
            } else {
                HStack(spacing: 12) {
                    TextField("Enter code", text: $referralCodeInput)
                        .font(SimastryFont.bodyMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)

                    Button(action: {
                        let trimmed = referralCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        // Invite-shaped codes grant the welcome predictions;
                        // anything else falls back to the legacy referral path.
                        if InviteCode.isValid(trimmed) {
                            viewModel.applyInviteCode(trimmed)
                        } else {
                            viewModel.applyReferralCode(trimmed)
                            showReferralConfirmation = true
                        }
                        referralCodeInput = ""
                    }) {
                        Text("Apply")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.midnight)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(SimastryColor.gold, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .simastryGlass(cornerRadius: 16)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - For Astrologers

    private var forAstrologersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                activeSheet = .astrologerPartner
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Are you an astrologer?")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                        Text("Learn about our partner program")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .padding(16)
                .simastryGlass(cornerRadius: 16)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Are you an astrologer? Learn about our partner program.")
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var astrologerPartnerSheet: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)

                    Text("For Astrologers")
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                }
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Are you an astrologer?")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.gold)

                    Text("Simastry is the daily practice tool your clients use between sessions. We help them apply the insights from your readings to everyday communication.")
                        .font(SimastryFont.bodyLarge)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        partnerBenefitRow(icon: "person.2.fill", text: "Your clients stay engaged with astrology daily")
                        partnerBenefitRow(icon: "link", text: "Your referral code tracks installs you drive")
                        partnerBenefitRow(icon: "chart.bar.fill", text: "Build your practice as a distribution partner")
                    }
                    .padding(.vertical, 4)

                    Text("Want to partner with us?")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Link(destination: astrologerContactURL) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(AppConfig.astrologerContactEmail)
                                .font(SimastryFont.labelLarge)
                        }
                        .foregroundStyle(SimastryColor.gold)
                    }
                }
                .padding(20)
                .goldGlassRect(cornerRadius: 20)

                Link(destination: AppConfig.astrologerPartnerURL) {
                    HStack(spacing: 8) {
                        Text("Learn More")
                            .font(SimastryFont.labelLarge)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(SimastryColor.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SimastryColor.gold.opacity(0.12), in: .capsule)
                    .overlay(
                        Capsule()
                            .stroke(SimastryColor.gold.opacity(0.25), lineWidth: 0.5)
                    )
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private func partnerBenefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
                .frame(width: 20)
                .padding(.top, 2)

            Text(text)
                .font(SimastryFont.bodyLarge)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                .lineSpacing(2)
        }
    }

    // MARK: - Data Export

    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                if let url = viewModel.exportUserData() {
                    exportFileURL = url
                    showExportShare = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SimastryColor.celestialBlue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export My Data")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                        Text("Download all your data as JSON")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .padding(16)
                .simastryGlass(cornerRadius: 16)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Export My Data. Download all your data as JSON.")
            .sheet(isPresented: $showExportShare) {
                if let url = exportFileURL {
                    ActivityViewRepresentable(activityItems: [url])
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }


    // MARK: - Footer

    // MARK: - Delete Account

    private var deleteAccountSection: some View {
        VStack(spacing: 0) {
            Button(action: { showDeleteAccountConfirmation = true }) {
                Text("Clear Local Data")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear local Simastry data from this device")
        }
        .padding(.top, 16)
        .opacity(appeared ? 1 : 0)
    }

    private var footerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                footerLink("About Simastry") { activeSheet = .about }
                footerLink("Privacy Policy") { activeSheet = .privacy }
                footerLink("Terms of Service") { activeSheet = .terms }
            }

            Button(action: { showSignOutConfirmation = true }) {
                Text(localization.string("profile.signOut"))
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .simastryGlass(cornerRadius: 14)
            }
            .buttonStyle(SpringPressStyle())

            Button {
                // The tier-override developer menu must never ship reachable
                // in release builds — it bypasses RevenueCat entitlements.
                #if DEBUG
                tapCount += 1
                if tapCount >= 3 {
                    activeSheet = .developerMenu
                    tapCount = 0
                }
                #endif
            } label: {
                Text("Simastry v1.0.0")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.deepMuted)
            }
            .buttonStyle(.plain)
        }
        .opacity(appeared ? 1 : 0)
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.mutedSilver)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var aboutSheet: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(SimastryFont.displayMedium)
                    .foregroundStyle(SimastryColor.gold)

                SimastryWordmark(font: .system(.title2, weight: .bold).italic())

                Text("v1.0.0")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .padding(.top, 28)

            Text("Simastry is your AI-powered astrology consultation app. Ask five expert AI astrologers grounded in Western, Vedic, Chinese, Ancient, and Evolutionary traditions, then compare the perspectives that help you move with more clarity.")
                .font(SimastryFont.bodyLarge)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            VStack(spacing: 8) {
                Text("Built with SwiftUI")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Text("Powered by the stars \u{2728}")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.gold.opacity(0.7))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func legalSheet(title: String, body: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(.top, 24)

                Text(body)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)

                Link("Read full policy online", destination: title.contains("Privacy") ? AppConfig.privacyPolicyURL : AppConfig.termsOfServiceURL)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.gold)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    // MARK: - Dev Menu

    #if DEBUG
    private var devMenuSheet: some View {
        VStack(spacing: 20) {
            Text("Developer Menu")
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)
                .padding(.top, 20)

            VStack(spacing: 12) {
                Text("Tier Override")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)

                HStack(spacing: 12) {
                    devTierButton("Free", tier: "free")
                    devTierButton("Plus", tier: "plus")
                    devTierButton("Pro", tier: "pro")
                }
            }

            Button("Reset Onboarding") {
                Task {
                    viewModel.profile = nil
                    viewModel.companions = []
                    viewModel.userSunSign = nil
                    viewModel.userMoonSign = nil
                    viewModel.userRisingSign = nil
                    viewModel.homeSetupPhase = .modeSelection
                    viewModel.selectedTab = .today
                    activeSheet = nil
                }
            }
            .font(SimastryFont.labelLarge)
            .foregroundStyle(SimastryColor.amber)

            Button("Clear Companion") {
                Task {
                    if let companion = viewModel.companions.first {
                        await viewModel.deleteCompanion(companion)
                    }
                    activeSheet = nil
                }
            }
            .font(SimastryFont.labelLarge)
            .foregroundStyle(.red.opacity(0.8))

            Spacer()
        }
        .padding(.horizontal, 20)
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    #endif

    #if DEBUG
    private func devTierButton(_ label: String, tier: String) -> some View {
        let isActive = viewModel.profile?.tier == tier
        return Button(action: {
            Task {
                await viewModel.applyTierOverride(tier)
            }
        }) {
            Text(label)
                .font(SimastryFont.labelMedium)
                .foregroundStyle(isActive ? SimastryColor.midnight : SimastryColor.offWhite)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isActive ? SimastryColor.gold : .clear, in: .capsule)
                .simastryGlassPill()
        }
        .buttonStyle(.plain)
    }
    #endif
}

// MARK: - UIActivityViewController Wrapper

private struct ActivityViewRepresentable: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
