import SwiftUI

nonisolated private enum ProfileSheet: Identifiable {
    case companion(CompanionData)
    case share(ShareableCardType)
    case about
    case privacy
    case terms

    var id: String {
        switch self {
        case .companion(let companion):
            "companion_\(companion.id.uuidString)"
        case .share(let type):
            "share_\(type.rawValue)"
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
    @State private var expandedRoles: Set<CelestialRole> = []
    @State private var appeared: Bool = false
    @State private var activeSheet: ProfileSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                SimastryShellBackground(accent: SimastryColor.olive)

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

                        conversationAssistToggle

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
                case .about:
                    aboutSheet
                case .privacy:
                    legalSheet(title: "Privacy Policy", body: "Simastry collects minimal data to deliver your personalized astrology experience. Your sign placements, companion configurations, and interaction history are stored securely via Supabase and are never sold.\n\nWe use service providers to operate authentication, database storage, AI guidance, subscriptions, and diagnostics.\n\nFull policy: https://simastry.vercel.app/privacy")
                case .terms:
                    legalSheet(title: "Terms of Service", body: "By using Simastry, you agree to use the app for personal entertainment and self-reflection purposes. Astrology readings and predictions are for entertainment only and should not be used as a substitute for professional advice.\n\nSimastry subscriptions are managed through Apple and can be canceled at any time via your Apple ID settings. Refunds are handled by Apple per their refund policy.\n\nFull terms: https://simastry.vercel.app/terms")
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
                Text("ABOUT ME")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(2.4)

                Text(viewModel.hasCompletedSigns ? "About You" : "Your Stars Await")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(SimastryColor.cream)
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
        .editorialGlassCard(cornerRadius: 24)
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
                    .font(.system(size: 22))
                    .foregroundStyle(SimastryColor.gold.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.6))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(SimastryColor.mutedSilver)

                Rectangle()
                    .fill(SimastryColor.gold.opacity(0.15))
                    .frame(height: 1)
                    .frame(maxWidth: 120)
                    .padding(.vertical, 2)

                Text(description)
                    .font(.system(size: 12, design: .serif))
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
                .font(.system(size: 13, weight: .semibold))
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
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.5))
                    Text("Complete your signs first")
                        .font(.system(size: 13))
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
                        .font(.system(size: 13))
                    Text("Share Your Cosmic DNA")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(SimastryColor.gold)
            }
            .buttonStyle(.plain)

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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)
                Spacer()
                Button {
                    activeSheet = .share(.cosmicDNA)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                        .foregroundStyle(SimastryColor.gold)
                }
                .buttonStyle(.plain)
            }

            if let guide {
                Text("As a \(sun.displayName), here's what people should know:")
                    .font(.system(size: 13))
                    .foregroundStyle(SimastryColor.mutedSilver)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(guide.tips.enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(SimastryColor.gold)
                                .padding(.top, 3)
                            Text(tip)
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                                .lineSpacing(2)
                        }
                    }
                }

                // Best approach
                VStack(alignment: .leading, spacing: 6) {
                    Text("Best Approach")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                        .tracking(1)
                        .textCase(.uppercase)
                    Text(guide.bestApproach)
                        .font(.system(size: 14, design: .serif))
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
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SimastryColor.amber)
                            .tracking(1)
                            .textCase(.uppercase)
                    }
                    Text(guide.avoid)
                        .font(.system(size: 13, design: .serif))
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
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(role.accentColor)
                        Text(sign.glyph)
                            .font(.system(size: 14))
                            .foregroundStyle(role.accentColor.opacity(0.7))
                    }

                    Text(role.subtitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(SimastryColor.offWhite)

                    if isExpanded {
                        Text(templates[sign.rawValue] ?? "")
                            .font(.system(size: 15, design: .serif))
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
                .font(.system(size: 13, weight: .semibold))
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
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(SimastryColor.offWhite)
                            Text(companion.mode.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.system(size: 12))
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

                        if viewModel.isRevenueCatAvailable {
                            Button(action: {
                                viewModel.showUpsell = true
                            }) {
                                Text(tier == "free" ? "Upgrade" : "Manage Subscription")
                                    .font(.system(size: 14))
                                    .foregroundStyle(SimastryColor.gold)
                            }
                            .buttonStyle(.plain)
                        }
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SimastryColor.offWhite)
            Text(subtitle)
                .font(.system(size: 10))
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
                .font(.system(size: 12, weight: .medium))
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
        case "pro":
            Text("Simastry Pro")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
        default:
            Text("Free")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SimastryColor.mutedSilver)
        }
    }

    // MARK: - Theme Toggle

    private var themeToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.system(size: 12))
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
                        .font(.system(size: 14, weight: .medium))
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

    private var conversationAssistToggle: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conversation Assists")
                .font(.system(size: 12))
                .foregroundStyle(SimastryColor.mutedSilver)

            Toggle(isOn: $viewModel.suggestedPromptsEnabled) {
                HStack(spacing: 10) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                        .frame(width: 30, height: 30)
                        .background(SimastryColor.gold.opacity(0.12), in: .rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Prompt bubbles")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(SimastryColor.offWhite)

                        Text("Profile and guide conversation starters")
                            .font(.system(size: 12))
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineLimit(2)
                    }
                }
            }
            .toggleStyle(.switch)
            .tint(SimastryColor.gold)
            .padding(14)
            .simastryGlass(cornerRadius: 16)
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .simastryGlass(cornerRadius: 14)
            }
            .buttonStyle(SpringPressStyle())

            versionLabel
        }
        .opacity(appeared ? 1 : 0)
    }

    private var versionLabel: some View {
        Text("Simastry v1.0.0")
            .font(.system(size: 11))
            .foregroundStyle(SimastryColor.deepMuted)
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .buttonStyle(.plain)
    }

    private var aboutSheet: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("Simastry")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)

                Text("v1.0.0")
                    .font(.system(size: 13))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .padding(.top, 28)

            Text("Simastry is your AI-powered astrology companion. Explore zodiac compatibility, simulate conversations through cosmic archetypes, and get practical communication guidance shaped by your signs.")
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            VStack(spacing: 8) {
                Text("Built with SwiftUI")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SimastryColor.mutedSilver)

                Text("Powered by the stars \u{2728}")
                    .font(.system(size: 13))
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
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(.top, 24)

                Text(body)
                    .font(.body)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)

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
}
