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
    @State private var showDecode: Bool = false
    @State private var handledPanelRouteRequest: Int = 0

    var body: some View {
        NavigationStack {
            Group {
                if !hasInboxContent {
                    VStack(spacing: 0) {
                        talkActions
                            .padding(.bottom, 6)

                        Group {
                            if AppConfig.expertAstrologersEnabled {
                                ExpertAstrologerInboxRow(viewModel: viewModel) {
                                    openExpertAstrologers()
                                }
                            } else {
                                PanelInboxRow(viewModel: viewModel) {
                                    openPanelChat()
                                }
                            }
                        }
                        .padding(.horizontal, 16)

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { CelestialBackground() }
            .accessibilityHidden(isPresentingModal)
            .navigationTitle("Talk")
            .navigationBarTitleDisplayMode(.inline)
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
                    .accessibilityIdentifier("talk.toolbar.newRoomButton")
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.buttonPress()
                        showMessageSearch = true
                    } label: {
                        toolbarActionIcon(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search experts and users")
                    .accessibilityHint(AppConfig.expertAstrologersEnabled ? "Search public users or open expert astrologers" : "Search public users and guides to start a conversation")
                    .accessibilityIdentifier("talk.toolbar.newMessageButton")
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
                ) {
                    selectedMessage = nil
                }
            }
            .fullScreenCover(isPresented: $showPanelChat) {
                PanelChatView(viewModel: viewModel) {
                    showPanelChat = false
                }
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
            .fullScreenCover(isPresented: $showDecode) {
                NavigationStack {
                    DecodeTextView(viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { showDecode = false }
                                    .tint(SimastryColor.gold)
                            }
                        }
                }
            }
            .fullScreenCover(item: $selectedRoom) { room in
                GuidedRoomChatView(viewModel: viewModel, room: room)
            }
        }
    }

    private var hasInboxContent: Bool {
        !viewModel.inboxMessages.isEmpty || !viewModel.chatThreadSummaries.isEmpty || !viewModel.connectedProfiles.isEmpty
    }

    private var isPresentingModal: Bool {
        selectedMessage != nil
            || selectedRoom != nil
            || showPanelChat
            || showCreateRoom
            || showMessageSearch
            || showDecode
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
        guard !AppConfig.expertAstrologersEnabled else {
            openExpertAstrologers()
            return
        }
        HapticManager.buttonPress()
        showPanelChat = true
    }

    private func openExpertAstrologers(question: String? = nil, autoRunEveryone: Bool = false) {
        HapticManager.buttonPress()
        viewModel.openAIAstrologists(question: question, autoRunEveryone: autoRunEveryone)
    }

    /// The Talk command surface — the four communication jobs that sit above the
    /// inbox. Each routes into an existing flow so nothing is duplicated.
    private var talkActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                HapticManager.buttonPress()
                viewModel.openPredict(with: PredictionDraft(category: .messageOutcome, targetSunSign: nil))
            } label: {
                Label("What should I reply back?", systemImage: "text.bubble.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SimastryAccentButtonStyle(accent: SimastryColor.gold))
            .accessibilityHint("Draft a reply and get tone guidance")

            HStack(spacing: 10) {
                talkSecondaryAction(
                    title: "Read a message",
                    systemImage: "doc.text.magnifyingglass",
                    hint: "Decode what a text really means"
                ) {
                    showDecode = true
                }

                if AppConfig.expertAstrologersEnabled {
                    talkSecondaryAction(
                        title: "Ask an expert",
                        systemImage: SimastryIcon.astrologers,
                        hint: "Consult one of the five expert astrologers"
                    ) {
                        openExpertAstrologers()
                    }

                    talkSecondaryAction(
                        title: "Compare all five",
                        systemImage: "square.grid.2x2.fill",
                        hint: "Open the five-tradition comparison flow"
                    ) {
                        openExpertAstrologers(question: "What should I reply back?", autoRunEveryone: false)
                    }
                } else {
                    talkSecondaryAction(
                        title: "Talk to a sign",
                        systemImage: "person.2.fill",
                        hint: "Open your saved people for approach tips"
                    ) {
                        viewModel.selectedTab = .people
                    }

                    talkSecondaryAction(
                        title: "Ask my guides",
                        systemImage: "sparkles",
                        hint: "Open your panel of chart guides"
                    ) {
                        openPanelChat()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func talkSecondaryAction(
        title: String,
        systemImage: String,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                Text(title)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .padding(.horizontal, 6)
            .simastryGlassLight(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
        .accessibilityIdentifier("talk.action.\(title.replacingOccurrences(of: " ", with: ""))")
    }

    private func presentPanelIfRequested() {
        guard !AppConfig.expertAstrologersEnabled else { return }
        guard viewModel.panelChatRouteRequest > handledPanelRouteRequest else { return }
        handledPanelRouteRequest = viewModel.panelChatRouteRequest
        showPanelChat = true
    }

    /// Opens a specific thread on request — the last step of "tap a guide's
    /// Message button anywhere in the app".
    private func presentThreadIfRequested() {
        guard let companionId = viewModel.openThreadRequestCompanionId,
              let message = threadMessage(for: companionId) else {
            return
        }
        viewModel.openThreadRequestCompanionId = nil
        viewModel.markMessageRead(message)
        selectedMessage = message
    }

    private func threadMessage(for companionId: UUID) -> CompanionMessage? {
        if let message = viewModel.inboxMessages.first(where: { $0.companionId == companionId }) {
            return message
        }

        if let message = viewModel.companionMessages
            .filter({ $0.companionId == companionId })
            .max(by: { $0.timestamp < $1.timestamp }) {
            return message
        }

        guard let profile = viewModel.guideProfile(forThreadId: companionId) else { return nil }
        return CompanionMessage(
            companionId: companionId,
            companionName: profile.name,
            companionSign: profile.sign.rawValue,
            content: "Hey — \(profile.name) here, your \(profile.sign.displayName) lens. \(profile.headline) What's the conversation on your mind?",
            isRead: true,
            source: .companion,
            direction: .incoming
        )
    }

    private var messageList: some View {
        List {
            talkActions
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

            Group {
                if AppConfig.expertAstrologersEnabled {
                    ExpertAstrologerInboxRow(viewModel: viewModel) {
                        openExpertAstrologers()
                    }
                } else {
                    PanelInboxRow(viewModel: viewModel) {
                        openPanelChat()
                    }
                }
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

            Spacer().frame(height: SimastrySpacing.tabBarEndClearance)
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
                Text(AppConfig.expertAstrologersEnabled ? "Your expert astrologers are ready" : "Your panel is ready to talk")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(AppConfig.socialDiscoveryEnabled
                     ? "Consult an expert astrologer or send a private intro, and your conversations will gather here."
                     : "Consult an expert astrologer and every reply will stay grounded in their tradition.")
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
                    Text(AppConfig.expertAstrologersEnabled ? "Open Experts" : "Open Guides")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(SimastryColor.offWhite)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .goldGlassPill(interactive: true)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityHint(AppConfig.expertAstrologersEnabled ? "Opens expert astrologers to choose a tradition" : "Opens your guides to choose a message lens")
            .padding(.top, 4)

            InviteFriendsCard(viewModel: viewModel, style: .compact)
                .padding(.horizontal, 32)
                .padding(.top, 4)
        }
        .padding(.bottom, 60)
    }

    /// A fanned row of expert portraits so the empty inbox sells the five
    /// named specialists instead of showing a lone system glyph.
    private var emptyStateCastStrip: some View {
        let profiles = AppConfig.expertAstrologersEnabled
            ? ExpertAstrologerRegistry.archivedProfiles
            : Array(FactoryCompanionCatalog.all.prefix(5))

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

// MARK: - Expert Astrologer Inbox Row

private struct ExpertAstrologerInboxRow: View {
    @Bindable var viewModel: AppViewModel
    let action: () -> Void

    private var latestText: String {
        guard let latest = viewModel.specialistMessages
            .filter({ $0.role == .specialist })
            .max(by: { $0.timestamp < $1.timestamp }) else {
            return "Ask Leyla, Mateo, Naomi, Elias, or Nadia for a tradition-specific read."
        }
        let name = ExpertAstrologerRegistry.specialist(id: latest.specialistId)?.characterName ?? "Expert"
        return "\(name): \(latest.content)"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: -16) {
                    ForEach(Array(ExpertAstrologerRegistry.specialists.enumerated()), id: \.element.id) { index, specialist in
                        expertAvatar(specialist)
                            .zIndex(Double(ExpertAstrologerRegistry.specialists.count - index))
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("Expert Astrologers")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text("5 experts")
                            .font(SimastryFont.captionSmall.weight(.semibold))
                            .foregroundStyle(SimastryColor.goldLight)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(SimastryColor.gold.opacity(0.13), in: Capsule())

                        Spacer()
                    }

                    Text(latestText)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.deepMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // Disclosure chevron marks this as a premium consultation entry
                // point — not an unread DM like the connection rows below it.
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Expert Astrologers. Five specialist AI astrologers. \(latestText)")
    }

    @ViewBuilder
    private func expertAvatar(_ specialist: AstrologySpecialist) -> some View {
        if let profile = specialist.archivedProfile {
            Image(profile.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40, alignment: .top)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(SimastryColor.gold.opacity(0.58), lineWidth: 1.1)
                }
                .background {
                    Circle().fill(SimastryColor.midnight)
                        .frame(width: 44, height: 44)
                }
        } else {
            Text(specialist.placeholderAvatar)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.gold)
                .frame(width: 40, height: 40)
                .background(SimastryColor.gold.opacity(0.12), in: Circle())
                .overlay {
                    Circle().strokeBorder(SimastryColor.gold.opacity(0.58), lineWidth: 1.1)
                }
        }
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

    /// Only real portraits get a framing ring; zodiac-glyph avatars stay borderless.
    private var hasPhoto: Bool {
        if let avatarURL, !avatarURL.isEmpty, URL(string: avatarURL) != nil { return true }
        return factoryProfile != nil
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
        .overlay {
            if hasPhoto {
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
            }
        }
        .shadow(color: showGlow && hasPhoto ? SimastryColor.gold.opacity(0.24) : .clear, radius: 10, y: 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Message Detail Sheet

private struct MessageDetailSheet: View {
    let message: CompanionMessage
    @Bindable var viewModel: AppViewModel
    var onClose: () -> Void = {}
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
                                    viewModel: viewModel,
                                    message: threadMessage,
                                    isFromCurrentUser: threadMessage.direction == .outgoing,
                                    guideId: guideProfile?.id,
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
                    onClose()
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
                    if AppConfig.expertAstrologersEnabled {
                        ExpertAstrologersView(viewModel: viewModel)
                    } else {
                        GuideProfileView(viewModel: viewModel, profile: profile)
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
                closeThread()
            }
        }
    }

    private func closeThread() {
        HapticManager.buttonPress()
        replyFocused = false
        onClose()
        dismiss()
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
            ZStack {
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
            .frame(width: 56, height: 44)
            .contentShape(.rect)
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
        .padding(.leading, 14)
        .padding(.trailing, 64)
        .padding(.top, 95)
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
        return "\(message.companionSign) guide"
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
    @Bindable var viewModel: AppViewModel
    let message: CompanionMessage
    let isFromCurrentUser: Bool
    let guideId: String?
    let companionAvatar: MessageAvatarView
    @State private var submittedFeedbackTitle: String?
    @State private var showTuneOptions: Bool = false

    private var usesCompactWidth: Bool {
        isFromCurrentUser && message.content.count <= 16 && !message.content.contains("\n")
    }

    private var maxBubbleWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return isFromCurrentUser
            ? min(186, screenWidth * 0.54)
            : min(276, screenWidth * 0.74)
    }

    private var shouldShowGuideFeedback: Bool {
        !isFromCurrentUser
            && message.source == .companion
            && guideId != nil
            && !isLowValueGuideReply
    }

    private var isLowValueGuideReply: Bool {
        let normalized = message.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!? "))
        let wordCount = normalized.split(whereSeparator: { $0.isWhitespace }).count
        guard wordCount <= 7 else { return false }
        let suppressed = [
            "hi",
            "hi what's going on",
            "hey",
            "hey i'm here what's up",
            "hey tell me what happened",
            "hey what are we reading",
            "what's going on",
            "tell me what happened"
        ]
        return suppressed.contains(normalized)
    }

    private var savedFeedbackTitle: String? {
        if let submittedFeedbackTitle {
            return submittedFeedbackTitle
        }

        guard let guideId,
              let event = viewModel.guideFeedbackEvents.last(where: {
                  $0.matches(readId: message.id, guideId: guideId, surface: .guideCard)
              }) else {
            return nil
        }

        if event.helpfulness == .helpful {
            return "Helpful"
        }
        if let reason = event.reasons.first,
           let option = GuideFeedbackTuneOption.allCases.first(where: { $0.feedbackReason == reason }) {
            return option.title
        }
        return event.reasons.first?.title ?? event.helpfulness.title
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 54)
            } else {
                companionAvatar
            }

            bubbleContent

            if !isFromCurrentUser {
                Spacer(minLength: 54)
            }
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isFromCurrentUser ? "You" : message.companionName): \(message.content)")
    }

    @ViewBuilder
    private var bubbleContent: some View {
        let content = VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: isFromCurrentUser ? 4 : 5) {
            if !isFromCurrentUser {
                Text(message.companionName)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold)
                    .lineLimit(1)
            }

            Text(message.content)
                .font(isFromCurrentUser ? SimastryFont.bodySmall : SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(isFromCurrentUser ? 2 : 3)
                .multilineTextAlignment(isFromCurrentUser ? .trailing : .leading)
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

        if usesCompactWidth {
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 7) {
                content
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(backgroundShape)

                if shouldShowGuideFeedback {
                    guideFeedbackRow
                }
            }
        } else {
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 7) {
                content
                    .padding(.horizontal, isFromCurrentUser ? 10 : 13)
                    .padding(.vertical, isFromCurrentUser ? 7 : 10)
                    .frame(maxWidth: maxBubbleWidth, alignment: isFromCurrentUser ? .trailing : .leading)
                    .background(backgroundShape)

                if shouldShowGuideFeedback {
                    guideFeedbackRow
                        .frame(maxWidth: maxBubbleWidth, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if isFromCurrentUser {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            SimastryColor.celestialBlue.opacity(0.96),
                            Color(red: 56/255, green: 110/255, blue: 205/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [SimastryColor.surfaceElevated, SimastryColor.surface],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(.white.opacity(0.09), lineWidth: 0.7)
                }
        }
    }

    private var guideFeedbackRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let savedFeedbackTitle {
                Text("\(savedFeedbackTitle) saved")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.48))
                    .accessibilityIdentifier("messages.guideFeedback.saved")
            } else {
                HStack(spacing: 6) {
                    guideFeedbackButton(
                        "Helpful",
                        systemImage: "hand.thumbsup.fill",
                        identifier: "messages.guideFeedback.helpful"
                    ) {
                        submitGuideFeedback(
                            helpfulness: .helpful,
                            reasons: [],
                            savedTitle: "Helpful"
                        )
                    }

                    guideFeedbackButton(
                        "Too vague",
                        systemImage: "questionmark.bubble.fill",
                        identifier: "messages.guideFeedback.tooVague"
                    ) {
                        submitGuideFeedback(
                            helpfulness: .partlyHelpful,
                            reasons: [.tooVague],
                            savedTitle: "Too vague"
                        )
                    }

                    guideFeedbackButton(
                        "Tune",
                        systemImage: "slider.horizontal.3",
                        identifier: "messages.guideFeedback.tune"
                    ) {
                        HapticManager.buttonPress()
                        withAnimation(.spring(SimastrySpring.snappy)) {
                            showTuneOptions.toggle()
                        }
                    }
                }

                if showTuneOptions {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92), spacing: 6)],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(GuideFeedbackTuneOption.allCases) { option in
                            guideFeedbackButton(
                                option.title,
                                systemImage: option.systemImage,
                                identifier: "messages.guideFeedback.\(option.rawValue)"
                            ) {
                                submitGuideFeedback(
                                    helpfulness: .partlyHelpful,
                                    reasons: [option.feedbackReason],
                                    savedTitle: option.title
                                )
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("messages.guideFeedback.row")
    }

    private func guideFeedbackButton(
        _ title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(SimastryColor.offWhite.opacity(0.68))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(SimastryColor.surfaceElevated.opacity(0.96), in: Capsule())
                .overlay {
                    Capsule().stroke(.white.opacity(0.07), lineWidth: 0.7)
                }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityIdentifier(identifier)
    }

    private func submitGuideFeedback(
        helpfulness: HelpfulnessRating,
        reasons: [GuideFeedbackReason],
        savedTitle: String
    ) {
        guard let guideId else { return }
        HapticManager.buttonPress()
        viewModel.recordGuideFeedback(
            readId: message.id,
            guideId: guideId,
            surface: .guideCard,
            helpfulness: helpfulness,
            reasons: reasons
        )
        withAnimation(.spring(SimastrySpring.snappy)) {
            submittedFeedbackTitle = savedTitle
            showTuneOptions = false
        }
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
