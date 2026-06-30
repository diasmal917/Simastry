import SwiftUI

enum MessageProfileDestination: Identifiable {
    case publicProfile(SocialProfile)
    case guide(FactoryCompanionProfile)

    var id: String {
        switch self {
        case .publicProfile(let profile):
            return "public-\(profile.id.uuidString)"
        case .guide(let profile):
            return "guide-\(profile.id)"
        }
    }
}

private struct MessageGuideSearchEntry: Identifiable {
    let profile: FactoryCompanionProfile
    let haystack: String

    var id: String { profile.id }

    init(profile: FactoryCompanionProfile) {
        let specialist = ExpertAstrologerRegistry.specialist(for: profile)
        self.profile = profile
        haystack = [
            specialist?.characterName,
            specialist?.publicTitle,
            specialist?.tradition,
            specialist?.publicDescription,
            specialist?.focusAreas.joined(separator: " "),
            profile.name,
            profile.handle,
            profile.sign.displayName,
            profile.sign.rawValue,
            profile.headline,
            profile.bio,
            profile.personalityBio,
            profile.tags.joined(separator: " ")
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }

    func matches(_ query: String) -> Bool {
        haystack.contains(query)
    }
}

struct MessageSearchSheet: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool
    @State private var searchText: String = ""
    @Namespace private var searchBarGlass
    @State private var selectedProfileDestination: MessageProfileDestination?

    private static let allGuides = FactoryCompanionCatalog.all
    private static let ardenFirst = allGuides.filter { $0.id == "gemini-arden" }

    private var activeGuideProfiles: [FactoryCompanionProfile] {
        AppConfig.expertAstrologersEnabled
            ? ExpertAstrologerRegistry.archivedProfiles
            : Self.allGuides
    }

    private var guideSearchEntries: [MessageGuideSearchEntry] {
        activeGuideProfiles.map(MessageGuideSearchEntry.init)
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSearching: Bool {
        !query.isEmpty
    }

    private var isLoadingUsers: Bool {
        viewModel.profileDiscoveryStore.searchState == .loading
    }

    private var guideResults: [FactoryCompanionProfile] {
        guard isSearching else {
            return Array(suggestedGuides.prefix(8))
        }
        return Array(guideSearchEntries.filter { $0.matches(query) }.prefix(12).map(\.profile))
    }

    private var userResults: [SocialProfile] {
        guard isSearching else { return [] }
        var seen = Set<UUID>()
        let merged = (viewModel.connectedProfiles + viewModel.discoveredProfiles).filter { profile in
            seen.insert(profile.id).inserted
        }
        return Array(merged.filter(matchesUser).prefix(16))
    }

    private var suggestedGuides: [FactoryCompanionProfile] {
        if AppConfig.expertAstrologersEnabled {
            return ExpertAstrologerRegistry.archivedProfiles
        }

        var seen = Set<String>()
        // Lead the discovery surface with Arden, then the user's panel.
        let ordered = Self.ardenFirst
            + viewModel.panelGuideEntries.map(\.profile)
            + [FactoryCompanionCatalog.featured]
            + Self.allGuides
        return ordered.filter { profile in
            seen.insert(profile.id).inserted
        }
    }

    var body: some View {
        NavigationStack {
            // Content must inset below the nav bar / drag indicator, so the
            // celestial backdrop comes from `.presentationBackground` (below) —
            // NOT a full-bleed `ZStack` layer that would drag the scroll content
            // up under the toolbar and clip the header.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    header
                    guideStrip

                    if isSearching {
                        searchResults
                    } else {
                        guidePreviewFeed
                    }

                    Spacer().frame(height: 104)
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.gold)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomSearchBar
            }
            .task {
                await viewModel.fetchConnectedProfiles()
                await viewModel.searchPublicProfiles(query: query)
            }
            .task(id: query) {
                guard AppConfig.socialDiscoveryEnabled else { return }
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { return }
                await viewModel.searchPublicProfiles(query: query)
            }
            .sheet(item: $selectedProfileDestination) { destination in
                switch destination {
                case .publicProfile(let profile):
                    ProfileDetailSheet(profile: profile, viewModel: viewModel) {
                        dismiss()
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                case .guide(let guide):
                    NavigationStack {
                        if AppConfig.expertAstrologersEnabled {
                            ExpertAstrologersView(viewModel: viewModel)
                        } else {
                            GuideProfileView(viewModel: viewModel, profile: guide)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                selectedProfileDestination = nil
                            }
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.gold)
                        }
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .onChange(of: viewModel.openThreadRequestCompanionId) { _, newValue in
                if newValue != nil {
                    dismiss()
                }
            }
        }
        .presentationBackground {
            CelestialBackground()
        }
        .accessibilityIdentifier("talk.messageSearchSheet")
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            SimastryWordmark()

            Text(AppConfig.expertAstrologersEnabled ? "Expert Astrologers" : "Your Guides")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.deepMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppConfig.expertAstrologersEnabled ? "Simastry, expert astrologers" : "Simastry, your guides")
    }

    private var guideStrip: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 9) {
                ForEach(suggestedGuides.prefix(12)) { guide in
                    MessageGuideBubble(profile: guide) {
                        HapticManager.buttonPress()
                        selectedProfileDestination = .guide(guide)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel(AppConfig.expertAstrologersEnabled ? "Expert astrologer shortcuts" : "Guide shortcuts")
    }

    private var guidePreviewFeed: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(guideResults.enumerated()), id: \.element.id) { index, guide in
                MessageGuidePreviewCard(profile: guide) {
                    HapticManager.buttonPress()
                    selectedProfileDestination = .guide(guide)
                }
                .padding(.horizontal, 16)
                .modifier(MessageSearchCardAppear(index: index, reduceMotion: reduceMotion))
            }
        }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !guideResults.isEmpty {
                resultSection(title: AppConfig.expertAstrologersEnabled ? "Expert Astrologers" : "Guides") {
                    ForEach(guideResults) { guide in
                        Button {
                            HapticManager.buttonPress()
                            selectedProfileDestination = .guide(guide)
                        } label: {
                            MessageSearchGuideRow(profile: guide)
                        }
                        .buttonStyle(SpringPressStyle())
                        .accessibilityHint(AppConfig.expertAstrologersEnabled ? "Opens expert astrologers" : "Opens \(guide.name)'s guide profile")
                        .accessibilityIdentifier("talk.messageSearch.guide.\(guide.id)")
                    }
                }
            }

            if !userResults.isEmpty {
                resultSection(title: "Usernames") {
                    ForEach(userResults) { profile in
                        Button {
                            HapticManager.buttonPress()
                            selectedProfileDestination = .publicProfile(profile)
                        } label: {
                            MessageSearchUserRow(profile: profile)
                        }
                        .buttonStyle(SpringPressStyle())
                        .accessibilityHint("Opens \(profile.displayName)'s public profile")
                        .accessibilityIdentifier("talk.messageSearch.user.\(profile.username ?? profile.id.uuidString)")
                    }
                }
            } else if isLoadingUsers {
                MessageSearchStatusCard(
                    systemImage: "person.crop.circle.badge.questionmark",
                    title: "Looking for public users",
                    detail: "Matching public usernames as you type.",
                    showsProgress: true
                )
                .padding(.horizontal, 20)
            } else if case .failed(let message) = viewModel.profileDiscoveryStore.searchState,
                      guideResults.isEmpty {
                MessageSearchStatusCard(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn't load public users",
                    detail: message,
                    showsProgress: false
                )
                .padding(.horizontal, 20)
            } else if guideResults.isEmpty {
                MessageSearchStatusCard(
                    systemImage: "magnifyingglass",
                    title: "No matches yet",
                    detail: AppConfig.expertAstrologersEnabled
                        ? "Try a username, expert name, tradition, or astrology topic."
                        : "Try a username, guide name, zodiac sign, or guide handle.",
                    showsProgress: false
                )
                .padding(.horizontal, 20)
            }
        }
    }

    private func resultSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold)
                .tracking(1.2)
                .textCase(.uppercase)
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                content()
            }
            .padding(.horizontal, 20)
        }
    }

    private var bottomSearchBar: some View {
        searchBarContainer
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background {
                LinearGradient(
                    colors: [
                        SimastryColor.midnight.opacity(0.0),
                        SimastryColor.midnight.opacity(0.72),
                        SimastryColor.midnight.opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .accessibilityElement(children: .contain)
    }

    /// On iOS 26 the bar lives in a glass container so the clear button morphs
    /// out of the bar's glass as you type, then melts back in when cleared.
    @ViewBuilder
    private var searchBarContainer: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                searchBarCapsule
            }
        } else {
            searchBarCapsule
        }
    }

    private var searchBarCapsule: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
                .accessibilityHidden(true)

            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text(AppConfig.expertAstrologersEnabled ? "Search experts or usernames" : "Search guides or usernames")
                        .font(SimastryFont.bodyMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .accessibilityHidden(true)
                }

                TextField("", text: $searchText)
                    .focused($searchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .tint(SimastryColor.gold)
                    .accessibilityLabel(AppConfig.expertAstrologersEnabled ? "Search experts or usernames" : "Search guides or usernames")
                    .accessibilityIdentifier("talk.messageSearch.searchInput")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                searchFocused = true
            }

            if !query.isEmpty {
                Button {
                    HapticManager.buttonPress()
                    searchText = ""
                    searchFocused = true
                } label: {
                    Group {
                        if #available(iOS 26.0, *) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                                .frame(width: 28, height: 28)
                                .glassEffect(.regular.interactive(), in: .circle)
                                .glassEffectID("clear", in: searchBarGlass)
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                                .frame(width: 28, height: 28)
                                .background(SimastryColor.surfaceSunken.opacity(0.55), in: Circle())
                                .overlay {
                                    Circle().stroke(.white.opacity(0.16), lineWidth: 0.8)
                                }
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(SimastrySpring.snappy), value: query.isEmpty)
        .frame(minHeight: 54)
        .padding(.leading, 18)
        .padding(.trailing, query.isEmpty ? 18 : 7)
        .padding(.vertical, 8)
        .messageSearchSearchGlass()
    }

    private func matchesUser(_ profile: SocialProfile) -> Bool {
        guard isSearching else { return false }
        let haystack = [
            profile.username ?? "",
            profile.displayName,
            profile.sunSign,
            profile.moonSign ?? "",
            profile.risingSign ?? "",
            profile.bio ?? "",
            profile.communicationHint ?? ""
        ]
            .joined(separator: " ")
            .lowercased()
        return haystack.contains(query)
    }
}

private struct MessageGuideBubble: View {
    let profile: FactoryCompanionProfile
    let action: () -> Void

    private var specialist: AstrologySpecialist? {
        ExpertAstrologerRegistry.specialist(for: profile)
    }

    private var role: String {
        specialist?.publicTitle ?? (AppConfig.expertAstrologersEnabled ? "Expert astrologer" : "\(profile.sign.displayName) guide")
    }

    private var displayName: String {
        specialist?.characterName ?? profile.name
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(profile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 86, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.55),
                                        SimastryWordmark.red.opacity(0.75)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }

                Text(displayName)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(displayName), \(role)")
        .accessibilityHint(AppConfig.expertAstrologersEnabled ? "Opens expert astrologers" : "Opens guide profile")
    }
}

private struct MessageGuidePreviewCard: View {
    let profile: FactoryCompanionProfile
    let action: () -> Void

    private var heroImageName: String {
        AppConfig.expertAstrologersEnabled ? profile.cardImageName : (profile.gridImageNames.first ?? profile.cardImageName)
    }

    private var specialist: AstrologySpecialist? {
        ExpertAstrologerRegistry.specialist(for: profile)
    }

    private var quote: String {
        if let specialist {
            return specialist.longDescription
        }
        let bio = profile.personalityBio.trimmingCharacters(in: .whitespacesAndNewlines)
        return bio.isEmpty ? profile.headline : bio
    }

    private var role: String {
        specialist?.publicTitle ?? (AppConfig.expertAstrologersEnabled ? "Expert astrologer" : "\(profile.sign.displayName) guide")
    }

    private var displayName: String {
        specialist?.characterName ?? profile.name
    }

    private var tags: [String] {
        specialist?.focusAreas.prefix(3).map(\.self) ?? profile.tags.prefix(3).map(\.self)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                hero
                caption
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .messageSearchCardGlass(cornerRadius: 30, interactive: true)
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayName), \(role). \(specialist?.publicDescription ?? profile.headline)")
        .accessibilityHint(AppConfig.expertAstrologersEnabled ? "Opens expert astrologers" : "Opens guide profile")
    }

    private var hero: some View {
        Image(heroImageName)
            .resizable()
            .scaledToFill()
            .frame(height: 280, alignment: .top)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [
                        .black.opacity(0.50),
                        .black.opacity(0.04),
                        .black.opacity(0.12),
                        .black.opacity(0.46)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay { glassSheen }
            .overlay(alignment: .topLeading) {
                nameOverlay.padding(14)
            }
            .overlay(alignment: .topTrailing) {
                zodiacBadge.padding(14)
            }
            .accessibilityHidden(true)
    }

    /// Specular sheen so the photo reads as if it sits under a glass surface.
    private var glassSheen: some View {
        LinearGradient(
            colors: [
                .white.opacity(0.20),
                .white.opacity(0.02),
                .clear,
                .white.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }

    private var nameOverlay: some View {
        HStack(spacing: 9) {
            Image(profile.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36, alignment: .top)
                .clipShape(Circle())
                .overlay { Circle().stroke(.white.opacity(0.85), lineWidth: 1.5) }
                .shadow(color: .black.opacity(0.40), radius: 5, y: 2)

            Text(displayName)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
        }
    }

    private var zodiacBadge: some View {
        Group {
            if let specialist {
                Image(systemName: specialist.symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.24), in: Circle())
            } else {
                ZodiacIconView(sign: profile.sign, size: 30, showsGlow: true)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
        .accessibilityHidden(true)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(quote)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.95))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !tags.isEmpty {
                HStack(spacing: 7) {
                    ForEach(tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.gold.opacity(0.92))
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .messageSearchSmallGlass()
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 8) {
                Text(specialist?.publicTitle ?? "@\(profile.handle)")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Chat")
                        .font(SimastryFont.labelMedium)
                }
                .foregroundStyle(SimastryColor.gold)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .goldGlassPill()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MessageSearchGuideRow: View {
    let profile: FactoryCompanionProfile

    private var specialist: AstrologySpecialist? {
        ExpertAstrologerRegistry.specialist(for: profile)
    }

    private var role: String {
        specialist?.publicTitle ?? (AppConfig.expertAstrologersEnabled ? "Expert Astrologer" : "\(profile.sign.displayName) Guide")
    }

    private var description: String {
        specialist?.publicDescription ?? (AppConfig.expertAstrologersEnabled ? "One of the five Simastry astrology specialists." : GuideDirectoryCopy.specialty(for: profile))
    }

    private var displayName: String {
        specialist?.characterName ?? profile.name
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(profile.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52, alignment: .top)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(profile.sign.color.opacity(0.75), lineWidth: 1.2)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(1)

                    if let specialist {
                        Image(systemName: specialist.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)
                    } else {
                        ZodiacIconView(sign: profile.sign, size: 17, showsGlow: false)
                    }
                }

                Text(role)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold.opacity(0.9))
                    .lineLimit(1)

                Text(description)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SimastryColor.deepMuted)
        }
        .padding(14)
        .simastryGlass(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName), \(role). \(description)")
    }
}

private extension View {
    @ViewBuilder
    func messageSearchSearchGlass() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surfaceSunken.opacity(0.60), in: Capsule())
                .background(SimastryColor.offWhite.opacity(0.055), in: Capsule())
                .background(SimastryColor.gold.opacity(0.022), in: Capsule())
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.19)).interactive(true), in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.42),
                                    .white.opacity(0.15),
                                    SimastryColor.gold.opacity(0.20),
                                    .white.opacity(0.07)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(.white.opacity(0.22))
                        .frame(height: 1)
                        .padding(.horizontal, 26)
                        .padding(.top, 1.5)
                        .blur(radius: 0.5)
                }
                .shadow(color: .black.opacity(0.40), radius: 26, y: 14)
                .shadow(color: SimastryColor.gold.opacity(0.10), radius: 26, y: 10)
        } else {
            self
                .background(SimastryColor.surface.opacity(0.86), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.30), .white.opacity(0.10), SimastryColor.gold.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.85
                        )
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .frame(height: 1)
                        .padding(.horizontal, 26)
                        .padding(.top, 1.5)
                }
                .shadow(color: .black.opacity(0.34), radius: 20, y: 11)
        }
    }

    @ViewBuilder
    func messageSearchSmallGlass(interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surfaceSunken.opacity(0.42), in: Capsule())
                .background(SimastryColor.offWhite.opacity(0.045), in: Capsule())
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.12)).interactive(interactive), in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.26), SimastryColor.gold.opacity(0.18), .white.opacity(0.055)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.65
                        )
                }
        } else {
            self
                .background(SimastryColor.surface.opacity(0.70), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.14), lineWidth: 0.55)
                }
        }
    }

    @ViewBuilder
    func messageSearchCardGlass(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surfaceSunken.opacity(0.28), in: .rect(cornerRadius: cornerRadius))
                .background(SimastryColor.offWhite.opacity(0.055), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.16)).interactive(interactive), in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.40),
                                    .white.opacity(0.11),
                                    SimastryColor.gold.opacity(0.14),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.95
                        )
                }
                .shadow(color: .black.opacity(0.30), radius: 24, y: 14)
                .shadow(color: SimastryColor.gold.opacity(0.08), radius: 26, y: 12)
        } else {
            self
                .background(SimastryColor.surface.opacity(0.66), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.26), .white.opacity(0.08), SimastryColor.gold.opacity(0.11)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
                .shadow(color: .black.opacity(0.26), radius: 20, y: 11)
        }
    }
}

private struct MessageSearchUserRow: View {
    let profile: SocialProfile

    var body: some View {
        HStack(spacing: 13) {
            PublicProfileAvatar(profile: profile, size: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.displayName)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1)

                if let username = profile.username {
                    Text("@\(username)")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.gold.opacity(0.9))
                        .lineLimit(1)
                }

                Text(profile.communicationHint ?? profile.signSummary)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SimastryColor.deepMuted)
        }
        .padding(14)
        .simastryGlass(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.displayName), \(profile.signSummary)")
    }
}

private struct MessageSearchStatusCard: View {
    let systemImage: String
    let title: String
    let detail: String
    let showsProgress: Bool

    var body: some View {
        VStack(spacing: 12) {
            if showsProgress {
                ProgressView()
                    .tint(SimastryColor.gold)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
            }

            Text(title)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text(detail)
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .simastryGlass(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

private struct MessageSearchCardAppear: ViewModifier {
    let index: Int
    let reduceMotion: Bool
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.spring(SimastrySpring.smooth).delay(Double(min(index, 4)) * 0.05)) {
                        appeared = true
                    }
                }
            }
    }
}
