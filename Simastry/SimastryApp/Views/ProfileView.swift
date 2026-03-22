import SwiftUI

nonisolated private enum ProfileSheet: Identifiable {
    case companion(CompanionData)
    case share(ShareableCardType)
    case developerMenu
    case about
    case privacy
    case terms

    var id: String {
        switch self {
        case .companion(let companion):
            "companion_\(companion.id.uuidString)"
        case .share(let type):
            "share_\(type.rawValue)"
        case .developerMenu:
            "developerMenu"
        case .about:
            "about"
        case .privacy:
            "privacy"
        case .terms:
            "terms"
        }
    }
}

struct ProfileView: View {
    @Bindable var viewModel: AppViewModel
    @State private var showSignOutConfirmation: Bool = false
    @State private var tapCount: Int = 0
    @State private var expandedRoles: Set<CelestialRole> = []
    @State private var appeared: Bool = false
    @State private var activeSheet: ProfileSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 8)

                        userHeader

                        if viewModel.hasCompletedSigns {
                            if let sun = viewModel.userSunSign,
                               let moon = viewModel.userMoonSign,
                               let rising = viewModel.userRisingSign {
                                aboutYouSection(sun: sun, moon: moon, rising: rising)
                            }
                        } else {
                            placeholderSignCards
                        }

                        if viewModel.hasCompletedSigns {
                            if let companion = viewModel.companions.first {
                                companionSection(companion)
                            }
                        } else {
                            placeholderCompanionSection
                        }

                        subscriptionSection

                        themeToggle

                        footerSection

                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await viewModel.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .companion(let companion):
                    CompanionDetailSheet(companion: companion, viewModel: viewModel)
                case .share(let cardType):
                    ShareableCardView(viewModel: viewModel, cardType: cardType)
                case .developerMenu:
                    devMenuSheet
                case .about:
                    aboutSheet
                case .privacy:
                    legalSheet(title: "Privacy Policy", body: "Simastry collects minimal data to deliver your personalized astrology experience. Your sign placements, companion configurations, and interaction history are stored securely via Supabase and are never shared with third parties.\n\nWe use anonymous analytics to improve app performance. No personal data is sold or used for advertising.\n\nFor the full privacy policy, visit our website.")
                case .terms:
                    legalSheet(title: "Terms of Service", body: "By using Simastry, you agree to use the app for personal entertainment and self-reflection purposes. Astrology readings and predictions are for entertainment only and should not be used as a substitute for professional advice.\n\nSimastry subscriptions are managed through Apple and can be canceled at any time via your Apple ID settings. Refunds are handled by Apple per their refund policy.\n\nFor the full terms of service, visit our website.")
                }
            }
            .onAppear {
                withAnimation(.spring(SimastrySpring.smooth).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }

    private var userHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Simastry")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Text(viewModel.hasCompletedSigns ? "About You" : "Your Stars Await")
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.offWhite)
            }

            Spacer()

            GlossyOrbView(
                signColors: viewModel.hasCompletedSigns
                    ? [
                        viewModel.userSunSign?.color ?? SimastryColor.gold,
                        viewModel.userMoonSign?.color ?? SimastryColor.celestialBlue
                    ]
                    : [
                        Color(red: 197/255, green: 189/255, blue: 179/255),
                        Color(red: 168/255, green: 159/255, blue: 149/255)
                    ],
                state: .idle,
                size: 56
            )
        }
        .padding(20)
        .simastryGlass(cornerRadius: 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    // MARK: - Placeholder Sign Cards

    private var placeholderSignCards: some View {
        VStack(spacing: 16) {
            placeholderSignCard(
                icon: "☉",
                title: "Your Sun Sign",
                subtitle: "Your core identity",
                description: "Discover who you are at your center",
                delay: 0
            )
            placeholderSignCard(
                icon: "☽",
                title: "Your Moon Sign",
                subtitle: "Your emotional world",
                description: "Understand how you feel and process",
                delay: 0.1
            )
            placeholderSignCard(
                icon: "↑★",
                title: "Your Rising Sign",
                subtitle: "Your outer energy",
                description: "See how the world experiences you",
                delay: 0.2
            )

            GoldButton("Discover Your Signs") {
                viewModel.selectedTab = 0
            }
            .padding(.top, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)
        }
    }

    private func placeholderSignCard(icon: String, title: String, subtitle: String, description: String, delay: Double) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(
                        SimastryColor.gold.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                    )
                    .frame(width: 48, height: 48)

                Text(icon)
                    .font(SimastryFont.titleMedium)
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
        .animation(.spring(SimastrySpring.bouncy).delay(delay), value: appeared)
    }

    // MARK: - Placeholder Companion

    private var placeholderCompanionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Companion")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.mutedSilver)

            HStack(spacing: 14) {
                GlossyOrbView(
                    signColors: [
                        Color(red: 197/255, green: 189/255, blue: 179/255),
                        Color(red: 168/255, green: 159/255, blue: 149/255)
                    ],
                    state: .idle,
                    size: 40
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

    // MARK: - About You Section

    private func aboutYouSection(sun: ZodiacSign, moon: ZodiacSign, rising: ZodiacSign) -> some View {
        VStack(spacing: 24) {
            signEntry(role: .sun, sign: sun, delay: 0)
            signEntry(role: .moon, sign: moon, delay: 0.15)
            signEntry(role: .rising, sign: rising, delay: 0.3)

            Button(action: {
                activeSheet = .share(.cosmicDNA)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(SimastryFont.labelSmall)
                    Text("Share Your Cosmic DNA")
                        .font(SimastryFont.labelMedium)
                }
                .foregroundStyle(SimastryColor.gold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share your Cosmic DNA card")

            // Conversation Guide section
            conversationGuideSection(sun: sun)
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
                    activeSheet = .share(.conversationGuide)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.gold)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share your communication guide")
                .accessibilityHint("Creates a share card with your best approach and what to avoid")
            }

            if let guide {
                Text("As a \(sun.displayName), here's what people should know:")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(guide.tips.enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .semibold))
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
                .tintedGlass(SimastryColor.gold.opacity(0.08), cornerRadius: 12)

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
                .tintedGlass(SimastryColor.amber.opacity(0.06), cornerRadius: 12)
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
            withAnimation(.spring(SimastrySpring.snappy)) {
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
                        Text(sign.glyph)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(role.accentColor.opacity(0.7))
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

        return VStack(alignment: .leading, spacing: 12) {
            Text("Your \(companion.mode.replacingOccurrences(of: "_", with: " ").capitalized)")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.mutedSilver)

            Button(action: {
                activeSheet = .companion(companion)
            }) {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        GlossyOrbView(
                            signColors: [
                                ZodiacSign(rawValue: companion.sunSign)?.color ?? SimastryColor.gold,
                                ZodiacSign(rawValue: companion.moonSign)?.color ?? SimastryColor.celestialBlue
                            ],
                            state: .idle,
                            size: 44
                        )

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

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        let tier = viewModel.profile?.tier ?? "free"

        return VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        tierLabel(tier)

                        Button(action: {
                            viewModel.showUpsell = true
                        }) {
                            Text(tier == "free" ? "Upgrade" : "Manage Subscription")
                                .font(SimastryFont.bodySmall)
                                .foregroundStyle(SimastryColor.gold)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }

                if tier == "free" {
                    HStack(spacing: 16) {
                        usagePill(
                            label: "Messages",
                            value: "\(viewModel.remainingDailyMessages)",
                            subtitle: "today",
                            tint: SimastryColor.celestialBlue
                        )
                        usagePill(
                            label: "Predictions",
                            value: "\(viewModel.remainingWeeklyPredictions)",
                            subtitle: "this week",
                            tint: SimastryColor.risingViolet
                        )
                        usagePill(
                            label: "Companions",
                            value: "\(viewModel.companions.count)/\(viewModel.companionLimit)",
                            subtitle: "slots",
                            tint: SimastryColor.gold
                        )
                    }
                } else {
                    HStack(spacing: 10) {
                        unlimitedChip("Unlimited messages")
                        unlimitedChip("Unlimited predictions")
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
                .font(.system(size: 10, weight: .bold))
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
            Text("Appearance")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)

            Button(action: {
                HapticManager.themeToggle()
                withAnimation(.spring(SimastrySpring.snappy)) {
                    viewModel.isDarkMode.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(SimastryColor.gold)
                        .contentTransition(.symbolEffect(.replace))
                    Text(viewModel.isDarkMode ? "Dark" : "Light")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .simastryGlassPill()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                footerLink("About Simastry") { activeSheet = .about }
                footerLink("Privacy Policy") { activeSheet = .privacy }
                footerLink("Terms of Service") { activeSheet = .terms }
            }

            Button(action: { showSignOutConfirmation = true }) {
                Text("Sign Out")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .simastryGlass(cornerRadius: 14)
            }
            .buttonStyle(SpringPressStyle())

            Button {
                tapCount += 1
                if tapCount >= 3 {
                    activeSheet = .developerMenu
                    tapCount = 0
                }
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
        }
        .buttonStyle(.plain)
    }

    private var aboutSheet: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(SimastryFont.displayMedium)
                    .foregroundStyle(SimastryColor.gold)

                Text("Simastry")
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("v1.0.0")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .padding(.top, 28)

            Text("Simastry is your AI-powered astrology companion. Explore zodiac compatibility, simulate conversations through cosmic archetypes, and get practical communication guidance shaped by your signs.")
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
                    viewModel.selectedTab = 0
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
}
