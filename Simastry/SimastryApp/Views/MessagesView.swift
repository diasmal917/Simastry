import SwiftUI
import Combine

struct MessagesView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedMessage: CompanionMessage?
    @State private var selectedRoom: ChatThreadSummary?
    @State private var appeared: Bool = false
    @State private var showPanelChat: Bool = false
    @State private var showCreateRoom: Bool = false
    @State private var showMessageSearch: Bool = false
    @State private var handledPanelRouteRequest: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                if selectedMessage == nil {
                    if !hasInboxContent {
                        VStack(spacing: 0) {
                            PanelInboxRow(viewModel: viewModel) {
                                openPanelChat()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            Spacer()
                            if viewModel.profileDiscoveryStore.connectionState == .loading {
                                connectionLoadingState
                            } else if case .failed(let message) = viewModel.profileDiscoveryStore.connectionState {
                                connectionRetryState(message)
                            } else {
                                emptyState
                            }
                            Spacer()
                        }
                    } else {
                        messageList
                    }
                }
            }
            .accessibilityHidden(selectedMessage != nil)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.buttonPress()
                        showCreateRoom = true
                    } label: {
                        toolbarActionIcon(systemName: "person.3.fill")
                    }
                    .accessibilityLabel("New Room")
                    .accessibilityHint("Create a private guided room with opted-in people")
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.buttonPress()
                        showMessageSearch = true
                    } label: {
                        toolbarActionIcon(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("New Message")
                    .accessibilityHint("Search public users and guides to start a conversation")
                    .buttonStyle(.plain)
                }
            }
            .task {
                await viewModel.refreshInbox(showErrors: false)
                await viewModel.fetchConnectedProfiles()
            }
            .onAppear {
                presentPanelIfRequested()
                presentThreadIfRequested()
            }
            .onChange(of: viewModel.panelChatRouteRequest) {
                presentPanelIfRequested()
            }
            .onChange(of: viewModel.openThreadRequestCompanionId) {
                presentThreadIfRequested()
            }
            .fullScreenCover(item: $selectedMessage) { message in
                MessageDetailSheet(
                    message: message,
                    viewModel: viewModel
                )
            }
            .fullScreenCover(isPresented: $showPanelChat) {
                PanelChatView(viewModel: viewModel)
            }
            .sheet(isPresented: $showCreateRoom) {
                GuidedRoomCreateView(viewModel: viewModel) { room in
                    selectedRoom = room
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showMessageSearch) {
                MessageSearchSheet(viewModel: viewModel)
            }
            .fullScreenCover(item: $selectedRoom) { room in
                GuidedRoomChatView(viewModel: viewModel, room: room)
            }
        }
    }

    private var hasInboxContent: Bool {
        !viewModel.inboxMessages.isEmpty || !viewModel.chatThreadSummaries.isEmpty || !viewModel.connectedProfiles.isEmpty
    }

    private func toolbarActionIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(SimastryColor.gold)
    }

    private var connectionLoadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(SimastryColor.gold)
            Text("Loading connections")
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading connected people")
    }

    private func connectionRetryState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(SimastryColor.sunCoral)
            Text("Couldn't load connections")
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
            Text(message)
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.deepMuted)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    await viewModel.fetchConnectedProfiles()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SimastryAccentButtonStyle(accent: SimastryColor.gold))
        }
        .padding(16)
    }

    private func openPanelChat() {
        HapticManager.buttonPress()
        showPanelChat = true
    }

    private func presentPanelIfRequested() {
        guard viewModel.panelChatRouteRequest > handledPanelRouteRequest else { return }
        handledPanelRouteRequest = viewModel.panelChatRouteRequest
        showPanelChat = true
    }

    /// Opens a specific thread on request — the last step of "tap a guide's
    /// Message button anywhere in the app".
    private func presentThreadIfRequested() {
        guard let companionId = viewModel.openThreadRequestCompanionId,
              let message = viewModel.inboxMessages.first(where: { $0.companionId == companionId }) else {
            return
        }
        viewModel.openThreadRequestCompanionId = nil
        viewModel.markMessageRead(message)
        selectedMessage = message
    }

    private var messageList: some View {
        List {
            PanelInboxRow(viewModel: viewModel) {
                openPanelChat()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 10, trailing: 16))

            ForEach(viewModel.inboxMessages) { message in
                MessageRow(message: message, publicProfile: viewModel.publicProfile(for: message.companionId))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .contentShape(.rect)
                    .onTapGesture {
                        HapticManager.buttonPress()
                        viewModel.markMessageRead(message)
                        selectedMessage = message
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation(.spring(SimastrySpring.snappy)) {
                                viewModel.deleteMessage(message)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityLabel("Delete message")
                    }
            }

            ForEach(connectedProfilesWithoutThreads) { profile in
                MessageRow(message: placeholderMessage(for: profile), publicProfile: profile)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .contentShape(.rect)
                    .onTapGesture {
                        HapticManager.buttonPress()
                        selectedMessage = placeholderMessage(for: profile)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.removeUserConnection(profile: profile)
                            }
                        } label: {
                            Label("Remove", systemImage: "person.crop.circle.badge.minus")
                        }
                        .accessibilityLabel("Remove \(profile.displayName) from connections")
                    }
            }

            ForEach(viewModel.chatThreadSummaries) { room in
                GuidedRoomInboxRow(
                    room: room,
                    currentUserId: viewModel.profile?.id
                ) {
                    HapticManager.buttonPress()
                    selectedRoom = room
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            }

            Spacer().frame(height: SimastrySpacing.tabBarClearance)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .refreshable {
            await viewModel.refreshInbox(showErrors: true)
        }
    }

    private var connectedProfilesWithoutThreads: [SocialProfile] {
        let threadIds = Set(viewModel.inboxMessages.filter { $0.source == .discovery }.map(\.companionId))
        return viewModel.connectedProfiles.filter { !threadIds.contains($0.id) }
    }

    private func placeholderMessage(for profile: SocialProfile) -> CompanionMessage {
        CompanionMessage(
            companionId: profile.id,
            companionName: profile.displayName,
            companionSign: ZodiacSign(rawValue: profile.sunSign)?.displayName ?? profile.sunSign.capitalized,
            content: profile.communicationHint ?? "Start with one honest question.",
            isRead: true,
            source: .discovery,
            direction: .incoming
        )
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            emptyStateCastStrip

            VStack(spacing: 8) {
                Text("Your panel is ready to talk")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(AppConfig.socialDiscoveryEnabled
                     ? "Open a guide or send a private intro, and your conversations will gather here."
                     : "Open a guide and every reply will read through their sign lens and your chart.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
            }

            Button {
                HapticManager.buttonPress()
                viewModel.openAIAstrologists()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: SimastryIcon.astrologers)
                        .font(.system(size: 15, weight: .semibold))
                    Text("Open Guides")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(SimastryColor.offWhite)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .goldGlassPill(interactive: true)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityHint("Opens your guides to choose a message lens")
            .padding(.top, 4)

            InviteFriendsCard(viewModel: viewModel, style: .compact)
                .padding(.horizontal, 32)
                .padding(.top, 4)
        }
        .padding(.bottom, 60)
    }

    /// A fanned row of guide portraits so the empty inbox sells the cast
    /// instead of showing a lone system glyph.
    private var emptyStateCastStrip: some View {
        let profiles = Array(FactoryCompanionCatalog.all.prefix(5))

        return HStack(spacing: -14) {
            ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                Image(profile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58, alignment: .top)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(profile.sign.color.opacity(0.6), lineWidth: 1.3)
                    }
                    .background {
                        Circle().fill(SimastryColor.midnight)
                            .frame(width: 62, height: 62)
                    }
                    .zIndex(Double(profiles.count - index))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Panel Inbox Row

/// Pinned group-thread entry at the top of the inbox — the user's three
/// placement guides in one conversation.
private struct PanelInboxRow: View {
    @Bindable var viewModel: AppViewModel
    let action: () -> Void

    private var previewText: String {
        guard let latest = viewModel.latestPanelMessage else {
            return "Meet your three guides — one thread, three lenses."
        }
        if latest.senderId == PanelParticipant.localUserId {
            return "You: \(latest.content)"
        }
        let name = viewModel.panelGuideEntry(forParticipantId: latest.senderId)?.profile.name ?? "Guide"
        return "\(name): \(latest.content)"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: -16) {
                    ForEach(Array(viewModel.panelGuideEntries.enumerated()), id: \.element.id) { index, entry in
                        Image(entry.profile.profileImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40, alignment: .top)
                            .clipShape(Circle())
                            .overlay {
                                Circle().strokeBorder(entry.sign.color.opacity(0.6), lineWidth: 1.1)
                            }
                            .background {
                                Circle().fill(SimastryColor.midnight)
                                    .frame(width: 44, height: 44)
                            }
                            .zIndex(Double(viewModel.panelGuideEntries.count - index))
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("Your Panel")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text("Pinned")
                            .font(SimastryFont.captionSmall.weight(.semibold))
                            .foregroundStyle(SimastryColor.goldLight)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(SimastryColor.gold.opacity(0.13), in: Capsule())

                        Spacer()

                        if viewModel.unreadPanelCount > 0 {
                            Text("\(viewModel.unreadPanelCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(SimastryColor.midnight)
                                .frame(minWidth: 20)
                                .frame(height: 20)
                                .background(SimastryColor.gold, in: Capsule())
                        }
                    }

                    Text(previewText)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(viewModel.unreadPanelCount > 0 ? SimastryColor.offWhite.opacity(0.8) : SimastryColor.deepMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Your Panel, pinned group chat with your three guides. \(previewText)")
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: CompanionMessage
    var publicProfile: SocialProfile?

    private var zodiacSign: ZodiacSign? {
        ZodiacSign(rawValue: message.companionSign.lowercased())
            ?? ZodiacSign.allCases.first { $0.displayName.lowercased() == message.companionSign.lowercased() }
    }

    private var previewText: String {
        if message.direction == .outgoing {
            return "You: \(message.content)"
        }
        return message.content
    }

    private var accessibilityPreviewSentence: String {
        let trimmed = previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.unicodeScalars.last else { return "" }
        return CharacterSet(charactersIn: ".!?").contains(last) ? trimmed : "\(trimmed)."
    }

    var body: some View {
        HStack(spacing: 12) {
            MessageAvatarView(
                message: message,
                size: 52,
                showGlow: !message.isRead,
                avatarURL: publicProfile?.avatarURL
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 6) {
                        Text(message.companionName)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(message.isRead ? SimastryColor.mutedSilver : SimastryColor.offWhite)

                        if message.source == .discovery {
                            Text("Discovery")
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(SimastryColor.gold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SimastryColor.gold.opacity(0.12), in: Capsule())
                        }
                    }

                    Spacer()

                    Text(message.timestamp.relativeDescription)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(message.isRead ? SimastryColor.deepMuted : SimastryColor.gold)
                }

                Text(previewText)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(message.isRead ? SimastryColor.deepMuted : SimastryColor.offWhite.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if !message.isRead {
                Text("1")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(width: 20, height: 20)
                    .background(SimastryColor.gold, in: Circle())
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SimastryColor.offWhite.opacity(0.07))
                .frame(height: 0.5)
                .padding(.leading, 64)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.companionName). \(accessibilityPreviewSentence) \(message.timestamp.relativeDescription). \(message.isRead ? "Read" : "Unread")")
        .accessibilityHint("Double tap to open conversation")
    }
}

private struct MessageAvatarView: View {
    let message: CompanionMessage
    let size: CGFloat
    var showGlow: Bool = false
    var avatarURL: String?

    private var zodiacSign: ZodiacSign? {
        ZodiacSign(rawValue: message.companionSign.lowercased())
            ?? ZodiacSign.allCases.first { $0.displayName.lowercased() == message.companionSign.lowercased() }
    }

    private var factoryProfile: FactoryCompanionProfile? {
        let normalizedName = message.companionName.lowercased()
        if let exact = FactoryCompanionCatalog.all.first(where: { $0.name.lowercased() == normalizedName }) {
            return exact
        }
        guard message.source == .companion, let zodiacSign else { return nil }
        return FactoryCompanionCatalog.all.first { $0.sign == zodiacSign }
    }

    var body: some View {
        ZStack {
            if let avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Circle()
                            .fill((zodiacSign?.color ?? SimastryColor.gold).opacity(0.18))
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else if let factoryProfile {
                Image(factoryProfile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size, alignment: .top)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill((zodiacSign?.color ?? SimastryColor.gold).opacity(0.18))

                if let zodiacSign {
                    ZodiacIconView(sign: zodiacSign, size: size * 0.62, showsGlow: false)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                }
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            SimastryColor.goldLight,
                            SimastryColor.gold.opacity(showGlow ? 0.95 : 0.55),
                            SimastryColor.goldDark.opacity(showGlow ? 0.9 : 0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: showGlow ? 1.8 : 0.8
                )
        )
        .shadow(color: showGlow ? SimastryColor.gold.opacity(0.24) : .clear, radius: 10, y: 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Message Detail Sheet

private struct MessageDetailSheet: View {
    let message: CompanionMessage
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var replyText: String = ""
    @State private var isSendingReply: Bool = false
    @State private var showSafetyOptions: Bool = false
    @State private var showBlockConfirmation: Bool = false
    @State private var selectedProfileDestination: MessageProfileDestination?
    @State private var calibratingProfile: FactoryCompanionProfile?
    @Namespace private var headerGlass
    @State private var promptRotationOffset: Int = 0
    @FocusState private var replyFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isCompanionTyping: Bool {
        message.source == .companion && viewModel.typingCompanionIds.contains(message.companionId)
    }

    private var zodiacSign: ZodiacSign? {
        ZodiacSign(rawValue: message.companionSign.lowercased())
            ?? ZodiacSign.allCases.first { $0.displayName.lowercased() == message.companionSign.lowercased() }
    }

    private var conversationMessages: [CompanionMessage] {
        viewModel.discoveryConversation(with: message.companionId)
    }

    private var publicProfile: SocialProfile? {
        viewModel.publicProfile(for: message.companionId)
    }

    private var guideProfile: FactoryCompanionProfile? {
        guard message.source == .companion else { return nil }
        return viewModel.guideProfile(
            forThreadId: message.companionId,
            companionName: message.companionName,
            companionSign: message.companionSign
        )
    }

    private var discoverySafetyProfile: SocialProfile {
        SocialProfile(
            id: message.companionId,
            displayName: message.companionName,
            sunSign: zodiacSign?.rawValue ?? message.companionSign.lowercased(),
            moonSign: nil,
            risingSign: nil,
            bio: nil,
            isVisible: true
        )
    }

    private var reportDetails: String? {
        let summary = conversationMessages.suffix(4).map { threadMessage in
            let author = threadMessage.direction == .outgoing ? "Reporter" : threadMessage.companionName
            return "\(author): \(threadMessage.content)"
        }
        guard !summary.isEmpty else { return nil }
        return summary.joined(separator: "\n")
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 0) {
                dmHeader

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            timestampDivider

                            ForEach(displayMessages) { threadMessage in
                                DMMessageBubble(
                                    message: threadMessage,
                                    isFromCurrentUser: threadMessage.direction == .outgoing,
                                    companionAvatar: MessageAvatarView(
                                        message: message,
                                        size: 28,
                                        showGlow: false,
                                        avatarURL: publicProfile?.avatarURL
                                    )
                                )
                                .id(threadMessage.id)
                            }

                            if isCompanionTyping {
                                TypingDotsBubble {
                                    MessageAvatarView(message: message, size: 28, showGlow: false, avatarURL: publicProfile?.avatarURL)
                                }
                                .id("typing-indicator")
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            Spacer().frame(height: 16)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .animation(.spring(SimastrySpring.smooth), value: isCompanionTyping)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        scrollToLatest(proxy)
                    }
                    .onChange(of: displayMessages.count) {
                        scrollToLatest(proxy)
                    }
                    .onChange(of: isCompanionTyping) {
                        if isCompanionTyping {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                withAnimation(.spring(SimastrySpring.smooth)) {
                                    proxy.scrollTo("typing-indicator", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if viewModel.conversationSuggestionsEnabled {
                    bottomSuggestionBubbles
                }

                replyComposer
            }
                .simastryToolbarGlass()
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(height: 0.5)
                }
        }
        .task {
            if message.source == .discovery {
                await viewModel.refreshInbox(showErrors: false)
            } else {
                viewModel.openCompanionThreadId = message.companionId
                viewModel.markCompanionThreadRead(message.companionId)
            }
        }
        .onDisappear {
            if viewModel.openCompanionThreadId == message.companionId {
                viewModel.openCompanionThreadId = nil
            }
        }
        .confirmationDialog("Report or Block", isPresented: $showSafetyOptions, titleVisibility: .visible) {
            ForEach(DiscoveryReportReason.allCases) { reason in
                Button("Report \(reason.displayName)") {
                    Task {
                        await viewModel.reportDiscoveryProfile(
                            discoverySafetyProfile,
                            reason: reason,
                            details: reportDetails
                        )
                    }
                }
            }

            Button("Block \(message.companionName)", role: .destructive) {
                showBlockConfirmation = true
            }

            Button("Cancel", role: .cancel) {}
        }
        .alert("Block \(message.companionName)?", isPresented: $showBlockConfirmation) {
            Button("Block Profile", role: .destructive) {
                Task {
                    await viewModel.blockDiscoveryProfile(discoverySafetyProfile)
                    viewModel.deleteMessage(message)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see each other in Simastry anymore. This can't be undone.")
        }
        .sheet(item: $selectedProfileDestination) { destination in
            switch destination {
            case .publicProfile(let profile):
                ProfileDetailSheet(profile: profile, viewModel: viewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .guide(let profile):
                NavigationStack {
                    GuideProfileView(viewModel: viewModel, profile: profile)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    selectedProfileDestination = nil
                                }
                                .font(SimastryFont.labelMedium)
                                .foregroundStyle(SimastryColor.gold)
                            }
                        }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $calibratingProfile) { profile in
            GuideCalibrationSheet(viewModel: viewModel, profile: profile) {}
        }
        .onReceive(Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()) { _ in
            guard viewModel.conversationSuggestionsEnabled, !reduceMotion else { return }
            let prompts = viewModel.iceBreakers(for: message)
            guard prompts.count > 1 else { return }
            withAnimation(.spring(SimastrySpring.smooth)) {
                promptRotationOffset = (promptRotationOffset + 1) % prompts.count
            }
        }
        .presentationBackground(SimastryColor.midnight)
    }

    private var displayMessages: [CompanionMessage] {
        if message.source == .discovery {
            let thread = conversationMessages
            return thread.isEmpty ? [message] : thread
        }
        let thread = viewModel.companionConversation(with: message.companionId)
        return thread.isEmpty ? [message] : thread
    }

    /// Trailing header controls as a Liquid Glass cluster — on iOS 26 the
    /// buttons share a `GlassEffectContainer` so their glass blends and morphs;
    /// older OSes fall back to the flat translucent circles.
    @ViewBuilder
    private var headerActions: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                headerActionStack
            }
        } else {
            headerActionStack
        }
    }

    private var headerActionStack: some View {
        HStack(spacing: 8) {
            if message.source == .discovery {
                headerIconButton("ellipsis", label: "Conversation safety actions") {
                    showSafetyOptions = true
                }
            }

            if let guide = guideProfile {
                headerIconButton(
                    "slider.horizontal.3",
                    tint: SimastryColor.gold,
                    label: "Calibrate \(message.companionName)",
                    hint: "Choose this guide's register, personality lens, and topics"
                ) {
                    HapticManager.buttonPress()
                    calibratingProfile = guide
                }
            }

            headerIconButton("xmark", label: "Close messages") {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func headerIconButton(
        _ systemName: String,
        tint: Color = SimastryColor.offWhite.opacity(0.84),
        label: String,
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if #available(iOS 26.0, *) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID(systemName, in: headerGlass)
            } else {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.07), in: Circle())
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }

    private var dmHeader: some View {
        HStack(spacing: 12) {
            dmIdentity

            Spacer()

            headerActions
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .simastryToolbarGlass()
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var dmIdentity: some View {
        if canOpenHeaderProfile {
            Button {
                HapticManager.buttonPress()
                openHeaderProfile()
            } label: {
                dmIdentityContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(message.companionName)'s profile")
            .accessibilityHint("Shows profile details before continuing the conversation")
        } else {
            dmIdentityContent
        }
    }

    private var dmIdentityContent: some View {
        HStack(spacing: 12) {
            MessageAvatarView(message: message, size: 44, showGlow: true, avatarURL: publicProfile?.avatarURL)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(message.companionName)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(1)

                    if message.source == .companion {
                        Text("AI")
                            .font(SimastryFont.microBold)
                            .foregroundStyle(SimastryColor.midnight)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(SimastryColor.gold.opacity(0.92), in: Capsule())
                            .accessibilityLabel("AI guide")
                    }

                    if let zodiacSign {
                        ZodiacIconView(sign: zodiacSign, size: 18, showsGlow: false)
                    }

                    if let bondLevel {
                        RelationshipLevelChip(level: bondLevel)
                    }
                }

                Text(headerSubtitle)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(1)
            }
        }
    }

    private var canOpenHeaderProfile: Bool {
        switch message.source {
        case .discovery:
            return publicProfile != nil
        case .companion:
            return guideProfile != nil
        }
    }

    private func openHeaderProfile() {
        switch message.source {
        case .discovery:
            if let publicProfile {
                selectedProfileDestination = .publicProfile(publicProfile)
            }
        case .companion:
            if let guideProfile {
                selectedProfileDestination = .guide(guideProfile)
            }
        }
    }

    private var headerSubtitle: String {
        if message.source == .discovery {
            return "\(message.companionSign) lens • private chat"
        }
        return "\(message.companionSign) AI Guide • Simastry Method"
    }

    /// Bond level with this guide — companion threads only.
    private var bondLevel: RelationshipLevel? {
        guard message.source == .companion,
              let companion = viewModel.companions.first(where: { $0.id == message.companionId }) else {
            return nil
        }
        return RelationshipLevel(rawValue: companion.relationshipLevel)
            ?? RelationshipLevel.from(messageCount: companion.conversationCount)
    }

    private var timestampDivider: some View {
        Text(message.timestamp.chatDayDescription)
            .font(SimastryFont.captionSmall)
            .foregroundStyle(SimastryColor.deepMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.05), in: Capsule())
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let last = displayMessages.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(SimastrySpring.smooth)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var bottomSuggestionBubbles: some View {
        MessageSuggestionStrip(prompts: visibleSuggestionPrompts) { prompt in
            HapticManager.buttonPress()
            replyText = prompt
            replyFocused = true
        }
    }

    private var visibleSuggestionPrompts: [String] {
        let prompts = viewModel.iceBreakers(for: message).filter { !$0.isEmpty }
        guard !prompts.isEmpty else { return [] }
        let offset = promptRotationOffset % prompts.count
        let rotated = Array(prompts[offset...]) + Array(prompts[..<offset])
        return Array(rotated.prefix(5))
    }

    private var replyComposer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField("Message", text: $replyText, axis: .vertical)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1...4)
                .focused($replyFocused)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(SimastryColor.offWhite.opacity(0.08))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(replyFocused ? 0.18 : 0.08), lineWidth: 0.7)
                }
                .onChange(of: replyText) {
                    if replyText.count > 500 { replyText = String(replyText.prefix(500)) }
                }

            Button {
                sendReply()
            } label: {
                Image(systemName: isSendingReply ? "ellipsis" : "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canSendReply ? SimastryColor.midnight : SimastryColor.mutedSilver)
                    .frame(width: 38, height: 38)
                    .background(canSendReply ? SimastryGradient.gold : LinearGradient(colors: [.white.opacity(0.08), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel(isSendingReply ? "Sending reply" : "Send reply")
            .disabled(!canSendReply)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    private var canSendReply: Bool {
        !isSendingReply && !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendReply() {
        let outgoingText = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoingText.isEmpty else { return }

        isSendingReply = true
        Task {
            let sent: Bool
            if message.source == .discovery {
                sent = await viewModel.sendDiscoveryReply(
                    to: message.companionId,
                    companionName: message.companionName,
                    companionSign: message.companionSign,
                    content: outgoingText
                )
            } else {
                sent = await viewModel.sendCompanionThreadMessage(
                    companionId: message.companionId,
                    companionName: message.companionName,
                    companionSign: message.companionSign,
                    content: outgoingText
                )
            }

            if sent {
                replyText = ""
            }
            isSendingReply = false
        }
    }
}

private struct MessageSuggestionStrip: View {
    let prompts: [String]
    let onSelect: (String) -> Void

    var body: some View {
        if !prompts.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button {
                            onSelect(prompt)
                        } label: {
                            Text(prompt)
                                .font(SimastryFont.caption)
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .simastryGlassPill(interactive: true)
                        }
                        .buttonStyle(SpringPressStyle())
                        .accessibilityLabel("Use suggested reply: \(prompt)")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 2)
            }
            .accessibilityLabel("Suggested questions and replies")
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

private struct DMMessageBubble: View {
    let message: CompanionMessage
    let isFromCurrentUser: Bool
    let companionAvatar: MessageAvatarView

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 54)
            } else {
                companionAvatar
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 5) {
                if !isFromCurrentUser {
                    Text(message.companionName)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.gold)
                        .lineLimit(1)
                }

                Text(message.content)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text(message.timestamp.relativeDescription)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(isFromCurrentUser ? 0.70 : 0.46))

                    if isFromCurrentUser {
                        Image(systemName: "checkmark")
                            .font(SimastryFont.microBold)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.62))
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: 276, alignment: isFromCurrentUser ? .trailing : .leading)
            .background {
                if isFromCurrentUser {
                    RoundedRectangle(cornerRadius: SimastryRadius.large, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    SimastryColor.celestialBlue.opacity(0.96),
                                    SimastryColor.linkBlue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: SimastryRadius.large, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [SimastryColor.surfaceElevated, SimastryColor.surface],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: SimastryRadius.large, style: .continuous)
                                .stroke(.white.opacity(0.09), lineWidth: 0.7)
                        }
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 54)
            }
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isFromCurrentUser ? "You" : message.companionName): \(message.content)")
    }
}

// MARK: - Date Extension for Relative Time

private extension Date {
    var chatDayDescription: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        }
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        return SimastryDateFormatter.chatDay.string(from: self)
    }

    var relativeDescription: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 172800 {
            return "Yesterday"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            return SimastryDateFormatter.compactDate.string(from: self)
        }
    }
}
