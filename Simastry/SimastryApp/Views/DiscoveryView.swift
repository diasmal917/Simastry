import SwiftUI
import PhotosUI
import UIKit

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
    @State private var searchText: String = ""
    @State private var selectedFilter: DiscoveryFilter = .compatible
    @State private var selectedProfile: SocialProfile?
    @State private var selectedAvatarItem: PhotosPickerItem?
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
                        .refreshable {
                            await viewModel.searchPublicProfiles(query: searchText)
                        }
                    } else {
                        comingSoonState
                            .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("Find Others Like You")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search usernames")
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
                if AppConfig.socialDiscoveryEnabled {
                    Task {
                        await viewModel.loadSocialProfile()
                        await viewModel.searchPublicProfiles(query: searchText)
                    }
                }
            }
            .task(id: searchText) {
                guard AppConfig.socialDiscoveryEnabled else { return }
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await viewModel.searchPublicProfiles(query: searchText)
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

            discoveryAvatarPicker

            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(0.5)
                    .textCase(.uppercase)

                TextField("maya.sag", text: $viewModel.publicUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(12)
                    .simastryGlass(cornerRadius: 12)
                    .onChange(of: viewModel.publicUsername) {
                        viewModel.publicUsername = PublicProfile.normalizedUsername(viewModel.publicUsername)
                        viewModel.updateSocialProfile()
                    }
                    .accessibilityLabel("Public username")

                Text("3-24 characters: lowercase letters, numbers, periods, or underscores.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(PublicProfile.isValidUsername(viewModel.publicUsername) ? SimastryColor.deepMuted : SimastryColor.sunCoral)
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

            VStack(alignment: .leading, spacing: 6) {
                Text("Communication Hint")
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(0.5)
                    .textCase(.uppercase)

                TextField("How people should start with you", text: $viewModel.communicationHint, axis: .vertical)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1...2)
                    .padding(12)
                    .simastryGlass(cornerRadius: 12)
                    .onChange(of: viewModel.communicationHint) {
                        if viewModel.communicationHint.count > 96 {
                            viewModel.communicationHint = String(viewModel.communicationHint.prefix(96))
                        }
                        viewModel.updateSocialProfile()
                    }
                    .accessibilityLabel("Communication hint")
            }

        }
        .padding(18)
        .glossyCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private var discoveryAvatarPicker: some View {
        let profileImage = viewModel.profileImage
        let sunSign = viewModel.userSunSign
        let isUploadingAvatar = viewModel.profileDiscoveryStore.isUploadingAvatar

        return HStack(spacing: 14) {
            PhotosPicker(selection: $selectedAvatarItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    ProfileImageView(
                        image: profileImage,
                        size: 70,
                        showEditBadge: false,
                        sunSign: sunSign
                    )

                    Image(systemName: isUploadingAvatar ? "arrow.triangle.2.circlepath" : "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.midnight)
                        .frame(width: 24, height: 24)
                        .background(SimastryColor.gold, in: Circle())
                }
            }
            .buttonStyle(.plain)
            .disabled(isUploadingAvatar)
            .accessibilityLabel(profileImage == nil ? "Add discovery profile photo" : "Change discovery profile photo")
            .accessibilityHint("Uploads a public avatar for people who can discover your profile.")
            .onChange(of: selectedAvatarItem) { _, newItem in
                Task {
                    await uploadSelectedAvatar(newItem)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(isUploadingAvatar ? "Uploading photo" : "Profile photo")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                Text("Visible only when your discovery profile is on.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .simastryGlassLight(cornerRadius: 14)
    }

    private func uploadSelectedAvatar(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            selectedAvatarItem = nil
            viewModel.showToast("Couldn't use photo", subtitle: "Try another image.", isError: true)
            return
        }

        await viewModel.uploadPublicProfileAvatar(resizeImage(image, maxDimension: 512))
        selectedAvatarItem = nil
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

    // MARK: - Privacy Note

    private var privacyNote: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.isDiscoverable ? "lock.shield.fill" : "lock.open.fill")
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
                    .buttonStyle(SpringPressStyle())
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
            if viewModel.profileDiscoveryStore.searchState == .loading &&
                filtered.isEmpty &&
                viewModel.connectedProfiles.isEmpty {
                loadingState
            } else if case .failed(let message) = viewModel.profileDiscoveryStore.searchState,
                      filtered.isEmpty,
                      viewModel.connectedProfiles.isEmpty {
                retryState(message: message)
            } else if filtered.isEmpty && viewModel.connectedProfiles.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !viewModel.connectedProfiles.isEmpty {
                        connectedProfilesSection
                    }

                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, profile in
                        discoveryCard(for: profile, index: index)
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(SimastryColor.gold)
            Text("Looking for public profiles")
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading public profiles")
    }

    private func retryState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(SimastryColor.sunCoral)
            Text("Couldn't load profiles")
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
            Text(message)
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.deepMuted)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    await viewModel.searchPublicProfiles(query: searchText)
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SimastryAccentButtonStyle(accent: SimastryColor.gold))
            .accessibilityLabel("Try loading public profiles again")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var connectedProfilesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connected")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold)
                .tracking(1.4)

            ForEach(viewModel.connectedProfiles) { profile in
                discoveryCard(for: profile, index: 0)
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
                PublicProfileAvatar(profile: profile, size: 44)

                VStack(alignment: .leading, spacing: 14) {
                    // Header: name + compatibility
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName)
                                .font(SimastryFont.titleSmall)
                                .foregroundStyle(SimastryColor.offWhite)

                            if let username = profile.username {
                                Text("@\(username)")
                                    .font(SimastryFont.captionSmall)
                                    .foregroundStyle(SimastryColor.deepMuted)
                            }

                            // Sign badges
                            HStack(spacing: 12) {
                                if let sun = sunSign {
                                    signPill(sign: sun, label: "Sun", color: SimastryColor.sunCoral)
                                }
                                if let moon = moonSign {
                                    signPill(sign: moon, label: "Moon", color: SimastryColor.celestialBlue)
                                }
                                if let rising = risingSign {
                                    signPill(sign: rising, label: "Rising", color: SimastryColor.risingViolet)
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

                    if let hint = profile.communicationHint, !hint.isEmpty {
                        Text(hint)
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.gold.opacity(0.9))
                            .lineLimit(2)
                    }
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

    private func signPill(sign: ZodiacSign, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            ZodiacIconView(sign: sign, size: 14, showsGlow: false)
            Text(label)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(color.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) sign: \(sign.displayName)")
    }
}

struct PublicProfileAvatar: View {
    let profile: SocialProfile
    let size: CGFloat

    private var sunSign: ZodiacSign? {
        ZodiacSign(rawValue: profile.sunSign)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill((sunSign?.color ?? SimastryColor.gold).opacity(0.15))

            if let avatarURL = profile.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        discoveryAvatarFallback(size: size, sunSign: sunSign)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                discoveryAvatarFallback(size: size, sunSign: sunSign)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .stroke(SimastryGradient.gold, lineWidth: 1.4)
        }
        .accessibilityLabel("\(profile.displayName) profile picture")
    }

    @ViewBuilder
    private func discoveryAvatarFallback(size: CGFloat, sunSign: ZodiacSign?) -> some View {
        if let sunSign {
            ZodiacIconView(sign: sunSign, size: size * 0.58, showsGlow: false)
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
        }
    }
}

// MARK: - Profile Detail Sheet

struct ProfileDetailSheet: View {
    let profile: SocialProfile
    @Bindable var viewModel: AppViewModel
    let onOpenMessages: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showAddConfirmation = false
    @State private var hasSentHi = false
    @State private var showSafetyOptions = false
    @State private var showBlockConfirmation = false

    init(
        profile: SocialProfile,
        viewModel: AppViewModel,
        onOpenMessages: (() -> Void)? = nil
    ) {
        self.profile = profile
        self.viewModel = viewModel
        self.onOpenMessages = onOpenMessages
    }

    private var compatibility: Int {
        viewModel.compatibilityWithUser(for: profile)
    }

    private var isConnected: Bool {
        viewModel.connectedProfiles.contains { $0.id == profile.id }
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
                        if let hint = profile.communicationHint, !hint.isEmpty {
                            communicationHintSection(hint)
                        }
                        if !profile.iceBreakers.isEmpty {
                            iceBreakerSection
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
            .task {
                hasSentHi = !viewModel.discoveryConversation(with: profile.id).isEmpty
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSafetyOptions = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .accessibilityLabel("Profile safety actions")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.gold)
                }
            }
            .confirmationDialog("Report or Block", isPresented: $showSafetyOptions, titleVisibility: .visible) {
                ForEach(DiscoveryReportReason.allCases) { reason in
                    Button("Report \(reason.displayName)") {
                        Task {
                            await viewModel.reportDiscoveryProfile(profile, reason: reason)
                        }
                    }
                }

                Button("Block \(profile.displayName)", role: .destructive) {
                    showBlockConfirmation = true
                }

                Button("Cancel", role: .cancel) {}
            }
            .alert("Block \(profile.displayName)?", isPresented: $showBlockConfirmation) {
                Button("Block Profile", role: .destructive) {
                    Task {
                        await viewModel.blockDiscoveryProfile(profile)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You won't see each other in Simastry anymore. This can't be undone.")
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
            PublicProfileAvatar(profile: profile, size: 86)

            Text(profile.displayName)
                .font(SimastryFont.titleLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text(profile.signSummary)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)

            if let username = profile.username {
                Text("@\(username)")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.deepMuted)
            }

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
                ZodiacIconView(sign: sign, size: 22, showsGlow: false)
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
                    .surfaceCard(cornerRadius: 12, accent: SimastryColor.gold.opacity(0.6))
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

    private func communicationHintSection(_ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to Start")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold)
                .tracking(1)
                .textCase(.uppercase)

            Text(hint)
                .font(SimastryFont.bodyLarge)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                .lineSpacing(3)
        }
        .padding(18)
        .glossyCard()
    }

    private var iceBreakerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ice Breakers")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold)
                .tracking(1)
                .textCase(.uppercase)

            ForEach(profile.iceBreakers.prefix(4), id: \.self) { prompt in
                Text(prompt)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.86))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .simastryGlassPill()
                    .accessibilityLabel("Suggested question: \(prompt)")
            }
        }
        .padding(18)
        .glossyCard()
    }

    // MARK: - Action Buttons

    private var addCompanionButton: some View {
        VStack(spacing: 12) {
            Button {
                if hasSentHi {
                    openMessagesAndDismiss()
                } else {
                    Task {
                        let didSend = await viewModel.sendDiscoveryMessage(from: profile)
                        hasSentHi = didSend
                        if didSend, onOpenMessages != nil {
                            openMessagesAndDismiss()
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: hasSentHi ? "bubble.left.and.bubble.right.fill" : "hand.wave.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(hasSentHi ? "Open Messages" : "Start Chat")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(hasSentHi ? SimastryColor.mutedSilver : SimastryColor.offWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .simastryGlassPill()
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel(hasSentHi ? "Open your conversation with \(profile.displayName)" : "Start a chat with \(profile.displayName)")
            .accessibilityHint(hasSentHi ? "Opens your Messages inbox" : "Sends an intro to start a discovery conversation")

            Button {
                Task {
                    if isConnected {
                        await viewModel.removeUserConnection(profile: profile)
                    } else {
                        await viewModel.addUserConnection(profile: profile)
                        hasSentHi = true
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isConnected ? "person.crop.circle.badge.minus" : "person.crop.circle.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(isConnected ? "Remove Connection" : "Add Connection")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(isConnected ? SimastryColor.mutedSilver : SimastryColor.midnight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: isConnected
                            ? [SimastryColor.surface.opacity(0.75), SimastryColor.surface.opacity(0.55)]
                            : [SimastryColor.gold, SimastryColor.goldLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel(isConnected ? "Remove \(profile.displayName) from connections" : "Add \(profile.displayName) as a connection")
            .accessibilityHint(isConnected ? "Removes this public profile from your connected people" : "Saves this public profile to your connected people")

            Button {
                showAddConfirmation = true
            } label: {
                Text("Create practice companion")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.gold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create a practice companion from \(profile.displayName)")
        }
    }

    private func openMessagesAndDismiss() {
        dismiss()
        viewModel.selectedTab = .messages
        onOpenMessages?()
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
