import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AppViewModel

    private var selectedTab: Binding<AppTab> {
        Binding(
            get: { AppTab(rawValue: viewModel.selectedTab) ?? .home },
            set: { viewModel.selectedTab = $0.rawValue }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SimastryShellBackground()

            Group {
                switch selectedTab.wrappedValue {
                case .home:
                    HomeView(viewModel: viewModel)
                case .companions:
                    CompanionsView(viewModel: viewModel)
                case .predict:
                    SimulateView(viewModel: viewModel)
                case .guides:
                    GuidesView(viewModel: viewModel)
                case .messages:
                    MessagesView(viewModel: viewModel)
                case .aboutMe:
                    ProfileView(viewModel: viewModel)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.985)))

            LiquidGlassTabBar(selection: selectedTab)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(SimastrySpring.smooth), value: viewModel.selectedTab)
        .onChange(of: viewModel.selectedTab) { _, _ in
            HapticManager.tabChange()
        }
    }
}

struct LiquidGlassTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var glassNamespace

    private let sideTabs: [AppTab] = [.home, .predict, .messages, .aboutMe]

    var body: some View {
        HStack(spacing: 10) {
            tabButton(.home)
            tabButton(.predict)
            companionButton
            tabButton(.messages)
            tabButton(.aboutMe)
        }
        .padding(10)
        .modifier(TabBarGlassSurface(cornerRadius: 34))
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return Button {
            selection = tab
            HapticManager.buttonPress()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(tab == .aboutMe ? "Me" : tab.title)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? SimastryColor.cream : SimastryColor.mutedSilver)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if isSelected {
                    Capsule()
                        .fill(SimastryColor.gold.opacity(0.14))
                        .matchedGeometryEffect(id: "selected-tab", in: glassNamespace)
                }
            }
            .overlay {
                if isSelected {
                    Capsule()
                        .stroke(SimastryColor.gold.opacity(0.22), lineWidth: 1)
                }
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(tab.title)
    }

    private var companionButton: some View {
        let isSelected = selection == .companions

        return Button {
            selection = .companions
            HapticManager.buttonPress()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                SimastryColor.cream.opacity(0.34),
                                SimastryColor.gold.opacity(0.26),
                                SimastryColor.espresso.opacity(0.60)
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 40
                        )
                    )

                Circle()
                    .strokeBorder(SimastryColor.gold.opacity(isSelected ? 0.72 : 0.34), lineWidth: 1.2)

                Circle()
                    .strokeBorder(.white.opacity(0.12), lineWidth: 6)
                    .padding(8)

                Text("✦")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(SimastryColor.cream)
                    .shadow(color: SimastryColor.gold.opacity(0.5), radius: 12)
            }
            .frame(width: 66, height: 66)
            .shadow(color: SimastryColor.gold.opacity(isSelected ? 0.32 : 0.16), radius: isSelected ? 24 : 14)
            .scaleEffect(isSelected ? 1.06 : 1)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Companions")
    }
}

/// Floating tab-bar container surface. On iOS 26 it leans on real Liquid Glass
/// (no opaque fill or manual hairline underneath, which would flatten the glass);
/// on iOS 18 it falls back to the tinted-material treatment.
private struct TabBarGlassSurface: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(SimastryColor.espresso.opacity(0.18)).interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .shadow(color: .black.opacity(0.30), radius: 26, x: 0, y: 16)
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.black.opacity(0.28))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(.white.opacity(0.10), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.36), radius: 28, x: 0, y: 18)
                }
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

struct MessagesView: View {
    @Bindable var viewModel: AppViewModel
    @State private var latestMessages: [UUID: MessageData] = [:]
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var searchText: String = ""
    @State private var searchResults: [SearchableUserProfile] = []
    @State private var isSearchingUsers = false
    @State private var searchError: String?
    @State private var selectedProfile: SearchableUserProfile?

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var connectedSearchMatch: SearchableUserProfile? {
        guard !trimmedSearchText.isEmpty else { return nil }
        return viewModel.connectedUsers.first {
            $0.searchableText.localizedStandardContains(trimmedSearchText.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SimastryShellBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        CinematicSectionHeader(
                            eyebrow: "MESSAGES",
                            title: "Your conversation orbit.",
                            subtitle: "Add people by username, open their profile, and keep their signs close when you message."
                        )
                        .padding(.top, 18)

                        userSearchSection

                        if !viewModel.connectedUsers.isEmpty {
                            connectedPeopleSection
                        }

                        if viewModel.companions.isEmpty && viewModel.connectedUsers.isEmpty {
                            emptyState
                        }

                        if !viewModel.companions.isEmpty {
                            companionInboxSection
                        }

                        if let loadError {
                            Text(loadError)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SimastryColor.rose)
                                .padding(.top, 4)
                        }

                        Spacer().frame(height: 118)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedProfile) { profile in
                UserProfileSheet(profile: profile, viewModel: viewModel)
            }
            .task {
                await loadMessagesTabData()
            }
            .task(id: viewModel.companions.map(\.id)) {
                await loadLatestMessages()
            }
            .task(id: trimmedSearchText) {
                await searchProfiles()
            }
            .refreshable {
                await loadMessagesTabData()
            }
        }
    }

    private var userSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                TextField("Search usernames", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(SimastryColor.offWhite)
                    .font(.system(size: 15, weight: .medium))

                if !trimmedSearchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .tintedGlass(SimastryColor.gold.opacity(0.08), cornerRadius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(SimastryColor.gold.opacity(0.12), lineWidth: 1)
            }

            if !trimmedSearchText.isEmpty {
                if isSearchingUsers {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(SimastryColor.gold)
                        Text("Searching usernames...")
                            .font(.system(size: 13))
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .padding(.horizontal, 4)
                } else if let searchError {
                    Text(searchError)
                        .font(.system(size: 13))
                        .foregroundStyle(SimastryColor.rose)
                        .padding(.horizontal, 4)
                } else if searchResults.isEmpty {
                    if let connectedSearchMatch {
                        Text("@\(connectedSearchMatch.username) is already in Messages.")
                            .font(.system(size: 13))
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .padding(.horizontal, 4)
                    } else {
                        Text("No usernames matched \(trimmedSearchText).")
                            .font(.system(size: 13))
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .padding(.horizontal, 4)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(searchResults) { profile in
                            searchResultRow(profile)
                        }
                    }
                }
            }
        }
    }

    private var connectedPeopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("People")

            VStack(spacing: 12) {
                ForEach(viewModel.connectedUsers) { profile in
                    connectedProfileRow(profile)
                }
            }
        }
    }

    private var companionInboxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Guides and companions")

            companionInboxList
        }
    }

    private var companionInboxList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.companions) { companion in
                Button {
                    HapticManager.buttonPress()
                    viewModel.startPrediction(for: companion)
                } label: {
                    messageRow(for: companion)
                }
                .buttonStyle(SpringPressStyle())
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .tint(SimastryColor.gold)
                    .padding(18)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            GlossyOrbView(
                signColors: [SimastryColor.gold.opacity(0.9), SimastryColor.plum.opacity(0.8)],
                state: .idle,
                size: 86
            )

            Text("No one in your orbit yet")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(SimastryColor.cream)

            Text("Search a username above or create a companion to begin collecting conversation context.")
                .font(.system(size: 14))
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)

            GoldButton("Create companion") {
                viewModel.selectedTab = AppTab.home.rawValue
                viewModel.homeSetupPhase = .modeSelection
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(26)
        .editorialGlassCard(cornerRadius: 28)
    }

    private func searchResultRow(_ profile: SearchableUserProfile) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedProfile = profile
            } label: {
                HStack(spacing: 12) {
                    UserAvatarView(
                        urlString: profile.avatarURL,
                        initials: profile.initials,
                        accent: profile.accentSign.color,
                        size: 48
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SimastryColor.offWhite)
                            .lineLimit(1)

                        Text("@\(profile.username)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SimastryColor.gold.opacity(0.84))
                            .lineLimit(1)

                        Text(profile.placementLine)
                            .font(.system(size: 11))
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button {
                Task {
                    await viewModel.addUserConnection(profile)
                    searchText = ""
                    searchResults = []
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(width: 34, height: 34)
                    .background(SimastryColor.gold, in: Circle())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Add \(profile.displayName)")
        }
        .padding(14)
        .simastryGlass(cornerRadius: 20)
    }

    private func connectedProfileRow(_ profile: SearchableUserProfile) -> some View {
        HStack(alignment: .center, spacing: 13) {
            Button {
                selectedProfile = profile
            } label: {
                HStack(alignment: .center, spacing: 13) {
                    UserAvatarView(
                        urlString: profile.avatarURL,
                        initials: profile.initials,
                        accent: profile.accentSign.color,
                        size: 58
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 7) {
                            Text(profile.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(SimastryColor.offWhite)
                                .lineLimit(1)

                            if let sunSign = profile.sunSign {
                                Text(sunSign.glyph)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(sunSign.color)
                            }
                        }

                        Text("@\(profile.username) • \(profile.lastActiveLine)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SimastryColor.gold.opacity(0.78))
                            .lineLimit(1)

                        Text(profile.communicationHint)
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineLimit(2)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button {
                viewModel.startPrediction(for: profile)
            } label: {
                Image(systemName: "message.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(width: 38, height: 38)
                    .background(SimastryColor.gold, in: Circle())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Message \(profile.displayName)")
        }
        .padding(16)
        .editorialGlassCard(cornerRadius: 22)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(SimastryColor.mutedSilver)
            .tracking(2)
            .textCase(.uppercase)
    }

    private func messageRow(for companion: CompanionData) -> some View {
        let sun = ZodiacSign(rawValue: companion.sunSign)
        let latest = latestMessages[companion.id]

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((sun?.color ?? SimastryColor.gold).opacity(0.16))
                Text(sun?.glyph ?? "✦")
                    .font(.system(size: 24))
                    .foregroundStyle(sun?.color ?? SimastryColor.gold)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(companion.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SimastryColor.cream)
                        .lineLimit(1)

                    Text(companion.mode.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SimastryColor.gold)
                        .tracking(0.8)
                        .lineLimit(1)
                }

                Text(latest?.content ?? "No saved message yet. Start a prediction with \(companion.name).")
                    .font(.system(size: 13))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(2)

                Text("\(companion.conversationCount) sparks • \(sun?.displayName ?? companion.sunSign.capitalized)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SimastryColor.smoke)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(SimastryColor.gold.opacity(0.72))
        }
        .padding(16)
        .editorialGlassCard(cornerRadius: 22)
        .accessibilityLabel("\(companion.name), \(latest?.content ?? "no recent message")")
    }

    private func loadLatestMessages() async {
        guard !viewModel.companions.isEmpty else {
            latestMessages = [:]
            isLoading = false
            return
        }
        isLoading = true
        loadError = nil

        var nextMessages: [UUID: MessageData] = [:]

        for companion in viewModel.companions {
            do {
                let messages = try await viewModel.supabase.fetchMessages(companionId: companion.id)
                if let latest = messages.sorted(by: {
                    ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                }).first {
                    nextMessages[companion.id] = latest
                }
            } catch {
                loadError = "Some messages could not be loaded."
            }
        }

        latestMessages = nextMessages
        isLoading = false
    }

    private func loadMessagesTabData() async {
        await viewModel.loadConnectedUsers()
        await loadLatestMessages()
    }

    private func searchProfiles() async {
        let query = trimmedSearchText
        searchError = nil
        guard !query.isEmpty else {
            searchResults = []
            isSearchingUsers = false
            return
        }

        isSearchingUsers = true
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        do {
            searchResults = try await viewModel.searchUserProfiles(matching: query)
        } catch {
            searchResults = []
            searchError = "Search is unavailable right now."
        }

        isSearchingUsers = false
    }
}

private struct UserProfileSheet: View {
    let profile: SearchableUserProfile
    @Bindable var viewModel: AppViewModel

    @Environment(\.dismiss) private var dismiss

    private var firstName: String {
        profile.displayName.split(separator: " ").first.map(String.init) ?? profile.displayName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    UserAvatarView(
                        urlString: profile.avatarURL,
                        initials: profile.initials,
                        accent: profile.accentSign.color,
                        size: 118
                    )

                    VStack(spacing: 4) {
                        Text(profile.displayName)
                            .font(.system(size: 27, weight: .semibold, design: .serif))
                            .foregroundStyle(SimastryColor.cream)

                        Text("@\(profile.username)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(SimastryColor.gold)
                    }

                    Text(profile.communicationHint)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(SimastryColor.gold.opacity(0.84))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 14) {
                    Text(profile.bio)
                        .font(.system(size: 15))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)

                    if profile.sunSign != nil || profile.moonSign != nil || profile.risingSign != nil {
                        HStack(spacing: 8) {
                            if let sunSign = profile.sunSign {
                                signPill("Sun", sign: sunSign)
                            }
                            if let moonSign = profile.moonSign {
                                signPill("Moon", sign: moonSign)
                            }
                            if let risingSign = profile.risingSign {
                                signPill("Rising", sign: risingSign)
                            }
                        }
                    } else {
                        Text("Signs pending")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                }
                .padding(18)
                .simastryGlass(cornerRadius: 22)

                PromptBubbleCarousel(
                    prompts: profile.suggestedIceBreakers,
                    isEnabled: viewModel.suggestedPromptsEnabled
                ) { prompt in
                    viewModel.startPrediction(for: profile, question: prompt)
                    dismiss()
                }

                VStack(spacing: 12) {
                    GoldButton("Message \(firstName)") {
                        viewModel.startPrediction(for: profile)
                        dismiss()
                    }

                    Button {
                        Task {
                            if viewModel.isUserConnected(profile) {
                                await viewModel.removeUserConnection(profile)
                            } else {
                                await viewModel.addUserConnection(profile)
                            }
                            dismiss()
                        }
                    } label: {
                        Text(viewModel.isUserConnected(profile) ? "Remove from Messages" : "Add to Messages")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(viewModel.isUserConnected(profile) ? SimastryColor.rose : SimastryColor.gold)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 22)
        }
        .scrollIndicators(.hidden)
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private func signPill(_ label: String, sign: ZodiacSign) -> some View {
        VStack(spacing: 5) {
            Text(sign.glyph)
                .font(.system(size: 19, weight: .semibold, design: .serif))
                .foregroundStyle(sign.color)

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(0.8)

            Text(sign.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(sign.color.opacity(0.12), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(sign.color.opacity(0.18), lineWidth: 1)
        }
    }
}
