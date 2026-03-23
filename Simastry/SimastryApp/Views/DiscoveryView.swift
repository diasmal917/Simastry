import SwiftUI

// MARK: - Discovery Filter

private enum DiscoveryFilter: String, CaseIterable, Identifiable {
    case compatible = "Compatible"
    case sameSun = "Same Sun"
    case sameMoon = "Same Moon"
    case all = "All"

    var id: String { rawValue }
}

// MARK: - Discovery View

struct DiscoveryView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedFilter: DiscoveryFilter = .compatible
    @State private var selectedProfile: SocialProfile?
    @State private var appeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    if AppConfig.socialDiscoveryEnabled {
                        VStack(spacing: 24) {
                            Spacer().frame(height: 8)

                            visibilityBanner
                            privacyNote

                            if viewModel.isDiscoverable {
                                profileEditingSection
                            }

                            filterTabs
                            profilesList

                            Spacer().frame(height: SimastrySpacing.tabBarClearance)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        comingSoonState
                            .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("Find Others Like You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                    }
                    .accessibilityLabel("Go back")
                }
            }
            .sheet(item: $selectedProfile) { profile in
                ProfileDetailSheet(
                    profile: profile,
                    viewModel: viewModel
                )
            }
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.spring(SimastrySpring.smooth).delay(0.1)) {
                        appeared = true
                    }
                }
                if AppConfig.socialDiscoveryEnabled && viewModel.discoveredProfiles.isEmpty {
                    viewModel.fetchDiscoverableProfiles()
                }
            }
        }
    }

    private var comingSoonState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 32)

            VStack(spacing: 14) {
                Image(systemName: "person.2.slash.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("Discovery is coming soon")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("We're still finishing the secure backend for public profiles and cross-user messaging. You can keep exploring the rest of Simastry while we lock this down.")
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .glossyCard()

            Spacer().frame(height: SimastrySpacing.tabBarClearance)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Visibility Banner

    private var visibilityBanner: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isDiscoverable ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(viewModel.isDiscoverable ? SimastryColor.gold : SimastryColor.mutedSilver)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Want others to find you too?")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("Make your profile visible in discovery")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Spacer()

                Toggle("", isOn: $viewModel.isDiscoverable)
                    .labelsHidden()
                    .tint(SimastryColor.gold)
                    .onChange(of: viewModel.isDiscoverable) {
                        if viewModel.isDiscoverable {
                            viewModel.createSocialProfile()
                        }
                        viewModel.updateSocialProfile()
                    }
                    .accessibilityLabel("Show my profile in discovery. Currently \(viewModel.isDiscoverable ? "on" : "off")")
            }
        }
        .padding(16)
        .glossyCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Profile Editing Section

    private var profileEditingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                Text("Your Discovery Profile")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Display Name")
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(0.5)
                    .textCase(.uppercase)

                TextField("Your first name", text: $viewModel.socialDisplayName)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(12)
                    .simastryGlass(cornerRadius: 12)
                    .onChange(of: viewModel.socialDisplayName) {
                        viewModel.updateSocialProfile()
                    }
                    .accessibilityLabel("Display name for discovery")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Bio")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .tracking(0.5)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(viewModel.socialBio.count)/150")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(
                            viewModel.socialBio.count > 150
                                ? Color.red
                                : SimastryColor.deepMuted
                        )
                }

                TextField("Tell people about you in one sentence", text: $viewModel.socialBio, axis: .vertical)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(2...3)
                    .padding(12)
                    .simastryGlass(cornerRadius: 12)
                    .onChange(of: viewModel.socialBio) {
                        if viewModel.socialBio.count > 150 {
                            viewModel.socialBio = String(viewModel.socialBio.prefix(150))
                        }
                        viewModel.updateSocialProfile()
                    }
                    .accessibilityLabel("Optional bio for discovery profile")
            }

        }
        .padding(18)
        .glossyCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    // MARK: - Privacy Note

    private var privacyNote: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.isDiscoverable ? "eye.fill" : "eye.slash.fill")
                .font(.system(size: 14))
                .foregroundStyle(viewModel.isDiscoverable ? SimastryColor.gold : SimastryColor.celestialBlue)
            Text(viewModel.isDiscoverable
                 ? "Your display name and signs are visible to others."
                 : "You're browsing privately. Others can't see you.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(2)
        }
        .padding(14)
        .simastryGlassLight(cornerRadius: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.isDiscoverable
                            ? "Privacy notice: Your display name and signs are visible to others."
                            : "Privacy notice: You are browsing privately. Others cannot see you.")
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DiscoveryFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(SimastrySpring.snappy)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(
                                selectedFilter == filter
                                    ? SimastryColor.midnight
                                    : SimastryColor.offWhite
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                if selectedFilter == filter {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [SimastryColor.gold, SimastryColor.goldLight],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                } else {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                        )
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter by \(filter.rawValue)")
                    .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Profiles List

    private var profilesList: some View {
        let filtered = filteredProfiles

        return Group {
            if filtered.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, profile in
                        discoveryCard(for: profile, index: index)
                    }
                }
            }
        }
    }

    private var filteredProfiles: [SocialProfile] {
        switch selectedFilter {
        case .compatible:
            return viewModel.discoveredProfiles.filter { viewModel.isElementCompatible($0) }
                .sorted { viewModel.compatibilityWithUser(for: $0) > viewModel.compatibilityWithUser(for: $1) }
        case .sameSun:
            return viewModel.discoveredProfiles.filter {
                $0.sunSign == viewModel.userSunSign?.rawValue
            }
        case .sameMoon:
            return viewModel.discoveredProfiles.filter {
                $0.moonSign == viewModel.userMoonSign?.rawValue
            }
        case .all:
            return viewModel.discoveredProfiles.sorted {
                viewModel.compatibilityWithUser(for: $0) > viewModel.compatibilityWithUser(for: $1)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(SimastryColor.mutedSilver)
            Text("No matches for this filter yet")
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.mutedSilver)
            Text("Try a different filter or check back later")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.deepMuted)
        }
        .padding(.top, 40)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Discovery Card

    private func discoveryCard(for profile: SocialProfile, index: Int) -> some View {
        let compatibility = viewModel.compatibilityWithUser(for: profile)
        let oneLiner = viewModel.elementCompatibilityOneLiner(for: profile)
        let sunSign = ZodiacSign(rawValue: profile.sunSign)
        let moonSign = profile.moonSign.flatMap { ZodiacSign(rawValue: $0) }
        let risingSign = profile.risingSign.flatMap { ZodiacSign(rawValue: $0) }

        return Button {
            selectedProfile = profile
        } label: {
            HStack(spacing: 14) {
                // Zodiac glyph avatar — placeholder for mock/local mode.
                // When Supabase social profiles go live, replace with actual profile photos.
                ZStack {
                    Circle()
                        .fill((sunSign?.color ?? SimastryColor.gold).opacity(0.15))
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    SimastryColor.goldLight,
                                    SimastryColor.gold,
                                    SimastryColor.goldDark
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    Text(sunSign?.glyph ?? "\u{2726}")
                        .font(.system(size: 18))
                        .foregroundStyle(sunSign?.color ?? SimastryColor.gold)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 14) {
                    // Header: name + compatibility
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName)
                                .font(SimastryFont.titleSmall)
                                .foregroundStyle(SimastryColor.offWhite)

                            // Sign glyphs
                            HStack(spacing: 12) {
                                if let sun = sunSign {
                                    signPill(glyph: sun.glyph, label: "Sun", color: SimastryColor.sunCoral)
                                }
                                if let moon = moonSign {
                                    signPill(glyph: moon.glyph, label: "Moon", color: SimastryColor.celestialBlue)
                                }
                                if let rising = risingSign {
                                    signPill(glyph: rising.glyph, label: "Rising", color: SimastryColor.risingViolet)
                                }
                            }
                        }

                        Spacer()

                        // Compatibility score
                        VStack(spacing: 2) {
                            Text("\(compatibility)%")
                                .font(SimastryFont.titleMedium)
                                .foregroundStyle(SimastryColor.gold)
                            Text("Match")
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(SimastryColor.mutedSilver)
                        }
                    }

                    // One-liner
                    Text(oneLiner)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineSpacing(2)
                        .lineLimit(2)
                }
            }
            .padding(18)
            .glossyCard()
        }
        .buttonStyle(SpringPressStyle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(
            reduceMotion ? .none : .spring(SimastrySpring.smooth).delay(Double(index) * 0.05),
            value: appeared
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.displayName), \(compatibility) percent match. \(profile.signSummary)")
        .accessibilityHint("Double tap to view full profile")
    }

    private func signPill(glyph: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(glyph)
                .font(.system(size: 14))
            Text(label)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(color.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) sign: \(glyph)")
    }
}

// MARK: - Profile Detail Sheet

private struct ProfileDetailSheet: View {
    let profile: SocialProfile
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddConfirmation = false
    @State private var hasSentHi = false

    private var compatibility: Int {
        viewModel.compatibilityWithUser(for: profile)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 8)

                        profileHeader
                        signBreakdown
                        compatibilitySection
                        if let bio = profile.bio, !bio.isEmpty {
                            bioSection(bio)
                        }
                        addCompanionButton
                        privacyReminder

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle(profile.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.gold)
                }
            }
            .alert("Add as Companion?", isPresented: $showAddConfirmation) {
                Button("Add Companion") {
                    Task {
                        await viewModel.addCompanionFromDiscovery(profile)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will create a companion with \(profile.displayName)'s signs so you can explore your compatibility.")
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            // Avatar placeholder — shows zodiac glyph in mock/local mode.
            // When Supabase social profiles go live, replace with actual profile photos.
            let signColor = ZodiacSign(rawValue: profile.sunSign)?.color ?? SimastryColor.gold

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [signColor.opacity(0.6), signColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        SimastryColor.goldLight,
                                        SimastryColor.gold,
                                        SimastryColor.goldDark
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                    )

                Text(ZodiacSign(rawValue: profile.sunSign)?.glyph ?? "")
                    .font(.system(size: 36))
            }
            .accessibilityHidden(true)

            Text(profile.displayName)
                .font(SimastryFont.titleLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text(profile.signSummary)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)

            // Compatibility badge
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                Text("\(compatibility)% Compatible")
                    .font(SimastryFont.labelMedium)
            }
            .foregroundStyle(SimastryColor.gold)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .goldGlassPill()
            .accessibilityLabel("\(compatibility) percent compatible with you")
        }
    }

    // MARK: - Sign Breakdown

    private var signBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign Placements")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold)
                .tracking(1)
                .textCase(.uppercase)

            if let sunSign = ZodiacSign(rawValue: profile.sunSign) {
                signRow(
                    role: .sun,
                    sign: sunSign,
                    description: AstrologyTemplates.sunSign[profile.sunSign] ?? ""
                )
            }

            if let moonRaw = profile.moonSign, let moonSign = ZodiacSign(rawValue: moonRaw) {
                signRow(
                    role: .moon,
                    sign: moonSign,
                    description: AstrologyTemplates.moonSign[moonRaw] ?? ""
                )
            }

            if let risingRaw = profile.risingSign, let risingSign = ZodiacSign(rawValue: risingRaw) {
                signRow(
                    role: .rising,
                    sign: risingSign,
                    description: AstrologyTemplates.risingSign[risingRaw] ?? ""
                )
            }
        }
        .padding(18)
        .glossyCard()
    }

    private func signRow(role: CelestialRole, sign: ZodiacSign, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 2) {
                Image(systemName: role.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(role.accentColor)
                Text(sign.glyph)
                    .font(.system(size: 20))
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(role.displayName)
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(sign.displayName)
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                }
                Text(description)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver.opacity(0.8))
                    .lineSpacing(2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(role.displayName) in \(sign.displayName). \(description)")
    }

    // MARK: - Compatibility Section

    private var compatibilitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Why You Might Click")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold)
                .tracking(1)
                .textCase(.uppercase)

            let oneLiner = viewModel.elementCompatibilityOneLiner(for: profile)

            Text(oneLiner)
                .font(SimastryFont.bodyLarge)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                .lineSpacing(3)

            // Element insight
            if let userSun = viewModel.userSunSign,
               let companionSun = ZodiacSign(rawValue: profile.sunSign) {
                let insight = AstrologyTemplates.elementPairingInsightText(
                    element1: userSun.element.rawValue,
                    element2: companionSun.element.rawValue
                )
                if let insight {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)
                            .padding(.top, 3)
                        Text(insight)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .tintedGlass(SimastryColor.gold.opacity(0.06), cornerRadius: 12)
                }
            }
        }
        .padding(18)
        .glossyCard()
    }

    // MARK: - Bio

    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold)
                .tracking(1)
                .textCase(.uppercase)

            Text(bio)
                .font(SimastryFont.bodyLarge)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                .lineSpacing(3)
        }
        .padding(18)
        .glossyCard()
    }

    // MARK: - Action Buttons

    private var addCompanionButton: some View {
        VStack(spacing: 12) {
            // Say Hi button
            Button {
                viewModel.sendDiscoveryMessage(from: profile)
                hasSentHi = true
            } label: {
                HStack(spacing: 10) {
                    Text("\u{1F44B}")
                        .font(.system(size: 16))
                    Text(hasSentHi ? "Message Sent!" : "Say Hi \u{1F44B}")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(hasSentHi ? SimastryColor.mutedSilver : SimastryColor.offWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .simastryGlassPill()
            }
            .buttonStyle(SpringPressStyle())
            .disabled(hasSentHi)
            .accessibilityLabel(hasSentHi ? "Message already sent to \(profile.displayName)" : "Say hi to \(profile.displayName)")
            .accessibilityHint("Sends an intro message to your Messages inbox")

            // Add as Companion button
            Button {
                showAddConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add as Companion")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(SimastryColor.midnight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [SimastryColor.gold, SimastryColor.goldLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Add \(profile.displayName) as a companion")
            .accessibilityHint("Creates a companion with their signs to explore compatibility")
        }
    }

    // MARK: - Privacy Reminder

    private var privacyReminder: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 12))
                .foregroundStyle(SimastryColor.celestialBlue)
            Text("Only display name and signs are shared. No email, birth details, or location.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)
                .lineSpacing(2)
        }
        .padding(12)
        .simastryGlassLight(cornerRadius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Privacy: Only display name and signs are shared.")
    }
}
