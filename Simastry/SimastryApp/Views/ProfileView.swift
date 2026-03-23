import SwiftUI
import PhotosUI

nonisolated private enum ProfileSheet: Identifiable {
    case companion(CompanionData)
    case share(ShareableCardType)
    case developerMenu
    case about
    case privacy
    case terms
    case methodology
    case astrologerPartner

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
        case .methodology:
            "methodology"
        case .astrologerPartner:
            "astrologerPartner"
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
    @State private var activeSheet: ProfileSheet?
    @State private var referralCodeInput: String = ""
    @State private var showReferralConfirmation: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showDeletePhotoConfirmation: Bool = false
    @State private var showDeleteAccountConfirmation: Bool = false
    @State private var exportFileURL: URL?
    @State private var showExportShare: Bool = false
    @State private var showDiscoveryView: Bool = false

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

                        languageSelector

                        aboutOurApproachSection

                        astrologerSection

                        referralCodeSection

                        forAstrologersSection

                        dataExportSection

                        footerSection

                        deleteAccountSection

                        Spacer().frame(height: SimastrySpacing.tabBarClearance)
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
            .alert("Clear My Data", isPresented: $showDeleteAccountConfirmation) {
                Button("Clear My Data", role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears your Simastry data from this device and attempts to remove your server data too. The app will tell you if any server cleanup still needs support follow-up.")
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
                case .methodology:
                    methodologySheet
                case .astrologerPartner:
                    astrologerPartnerSheet
                }
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
                        SimastryColor.placeholderLight,
                        SimastryColor.placeholderDark
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
        .animation(reduceMotion ? .default : .spring(SimastrySpring.bouncy).delay(delay), value: appeared)
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
                        SimastryColor.placeholderLight,
                        SimastryColor.placeholderDark
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
        }
        .padding(20)
        .glossyCard(cornerRadius: 22)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    // MARK: - About You Section

    private func aboutYouSection(sun: ZodiacSign, moon: ZodiacSign, rising: ZodiacSign) -> some View {
        VStack(spacing: 24) {
            profileImageSection
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            streakSection

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

            if AppConfig.socialDiscoveryEnabled {
                // MARK: Social Accounts
                socialAccountsSection
            }

            // MARK: Find Others Like You
            discoverySection

            // Conversation Guide section
            conversationGuideSection(sun: sun)
        }
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
                        Text("Discovery Coming Soon")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                    }

                    Text("We're still finishing the secure backend for discovery profiles and cross-user messaging.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .glossyCard()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Discovery coming soon. Secure profile discovery and cross-user messaging are still in development.")
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    // MARK: - Social Accounts Section

    private var socialAccountsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                Text("Social Accounts")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
            }

            Text("Add your socials so others can find you outside Simastry")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)

            socialLinkField(
                icon: "camera.fill",
                platform: "Instagram",
                value: Binding(
                    get: { viewModel.socialLinks.instagram ?? "" },
                    set: { newValue in
                        var links = viewModel.socialLinks
                        links.instagram = newValue.isEmpty ? nil : newValue
                        viewModel.updateSocialLinks(links)
                    }
                )
            )

            socialLinkField(
                icon: "play.rectangle.fill",
                platform: "TikTok",
                value: Binding(
                    get: { viewModel.socialLinks.tiktok ?? "" },
                    set: { newValue in
                        var links = viewModel.socialLinks
                        links.tiktok = newValue.isEmpty ? nil : newValue
                        viewModel.updateSocialLinks(links)
                    }
                )
            )

            socialLinkField(
                icon: "at",
                platform: "Twitter/X",
                value: Binding(
                    get: { viewModel.socialLinks.twitter ?? "" },
                    set: { newValue in
                        var links = viewModel.socialLinks
                        links.twitter = newValue.isEmpty ? nil : newValue
                        viewModel.updateSocialLinks(links)
                    }
                )
            )
        }
        .padding(18)
        .glossyCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private func socialLinkField(icon: String, platform: String, value: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SimastryColor.gold)
                .frame(width: 24)

            TextField("@username", text: value)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(12)
        .simastryGlass(cornerRadius: 12)
        .accessibilityLabel("\(platform) username")
    }

    // MARK: - Profile Image Picker

    private var profileImageSection: some View {
        VStack(spacing: 10) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ProfileImageView(
                    image: viewModel.profileImage,
                    size: 100,
                    showEditBadge: viewModel.profileImage != nil,
                    sunSignGlyph: viewModel.userSunSign?.glyph
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
                .simastryGlassPill()
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
                    Text(localization.currentLanguage.flag)
                        .font(.system(size: 16))
                    Text(localization.currentLanguage.displayName)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .simastryGlassPill()
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
                                    Text(language.flag)
                                        .font(.system(size: 24))

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
                        guard !referralCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        viewModel.applyReferralCode(referralCodeInput)
                        showReferralConfirmation = true
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

                    Link(destination: URL(string: "mailto:\(AppConfig.astrologerContactEmail)")!) {
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
                Text("Clear My Data")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear your Simastry data from this device")
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

// MARK: - UIActivityViewController Wrapper

private struct ActivityViewRepresentable: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
