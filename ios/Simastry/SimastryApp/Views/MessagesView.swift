import SwiftUI
import Combine

struct MessagesView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedMessage: CompanionMessage?
    @State private var appeared: Bool = false
    @State private var showPanelChat: Bool = false
    @State private var handledPanelRouteRequest: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                if selectedMessage == nil {
                    if viewModel.inboxMessages.isEmpty {
                        VStack(spacing: 0) {
                            PanelInboxRow(viewModel: viewModel) {
                                openPanelChat()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            Spacer()
                            emptyState
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
            .task {
                await viewModel.refreshInbox(showErrors: false)
            }
            .onAppear {
                presentPanelIfRequested()
            }
            .onChange(of: viewModel.panelChatRouteRequest) {
                presentPanelIfRequested()
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
        }
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

    private var messageList: some View {
        List {
            PanelInboxRow(viewModel: viewModel) {
                openPanelChat()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 10, trailing: 16))

            ForEach(viewModel.inboxMessages) { message in
                MessageRow(message: message)
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
                    Text("Open AI Astrologists")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(SimastryColor.midnight)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .background(SimastryGradient.gold, in: .capsule)
                .shadow(color: SimastryColor.gold.opacity(0.25), radius: 14, y: 6)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityHint("Opens AI Astrologists to choose a message lens")
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

    var body: some View {
        HStack(spacing: 12) {
            MessageAvatarView(message: message, size: 52, showGlow: !message.isRead)

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
        .accessibilityLabel("\(message.companionName). \(previewText). \(message.timestamp.relativeDescription). \(message.isRead ? "Read" : "Unread")")
        .accessibilityHint("Double tap to open conversation")
    }
}

private struct MessageAvatarView: View {
    let message: CompanionMessage
    let size: CGFloat
    var showGlow: Bool = false

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
            if let factoryProfile {
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
    @FocusState private var replyFocused: Bool

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
                        VStack(spacing: 14) {
                            timestampDivider

                            messageMethodLayer

                            ForEach(displayMessages) { threadMessage in
                                DMMessageBubble(
                                    message: threadMessage,
                                    isFromCurrentUser: threadMessage.direction == .outgoing,
                                    companionAvatar: MessageAvatarView(message: message, size: 28, showGlow: false)
                                )
                                .id(threadMessage.id)
                            }

                            if isCompanionTyping {
                                TypingDotsBubble {
                                    MessageAvatarView(message: message, size: 28, showGlow: false)
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
            replyComposer
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

    private var dmHeader: some View {
        HStack(spacing: 12) {
            MessageAvatarView(message: message, size: 44, showGlow: true)

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

            Spacer()

            if message.source == .discovery {
                Button {
                    showSafetyOptions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.84))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel("Conversation safety actions")
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.84))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.07), in: Circle())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Close messages")
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

    private var headerSubtitle: String {
        if message.source == .discovery {
            return "\(message.companionSign) lens • private chat"
        }
        return "\(message.companionSign) Guide • Simastry Method"
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

    private var messageMethodLayer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "scope")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(zodiacSign?.color ?? SimastryColor.gold)

                Text("Why this chat")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.1)
                    .textCase(.uppercase)

                Spacer(minLength: 0)
            }

            Text("Replies use message context, \(message.companionName)'s sign lens, and your communication type. Notification previews stay private.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.76))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(messageMethodSignals.prefix(4))) { signal in
                        MethodSignalChip(signal: signal)
                    }
                }
            }
        }
        .padding(12)
        .surfaceCard(cornerRadius: 18, accent: (zodiacSign?.color ?? SimastryColor.gold).opacity(0.7))
    }

    private var messageMethodSignals: [MethodSignal] {
        var signals: [MethodSignal] = [
            MethodSignal(
                label: "Message context",
                detail: conversationMessages.isEmpty ? "Single message" : "\(conversationMessages.count) messages",
                systemImage: "text.bubble.fill",
                tint: SimastryColor.celestialBlue
            )
        ]

        if let zodiacSign {
            signals.append(
                MethodSignal(
                    label: "Companion lens",
                    detail: zodiacSign.displayName,
                    systemImage: "scope",
                    tint: zodiacSign.color
                )
            )
        }

        if let userSun = viewModel.userSunSign {
            signals.append(
                MethodSignal(
                    label: "Your Sun",
                    detail: userSun.displayName,
                    systemImage: "person.crop.circle.fill",
                    tint: userSun.color
                )
            )
        }

        if let typeSignal = CommunicationTypeProfile.methodSignal(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        ) {
            signals.append(typeSignal)
        }

        signals.append(
            MethodSignal(
                label: "Privacy",
                detail: "Preview safe",
                systemImage: "lock.shield.fill",
                tint: SimastryColor.mutedSilver
            )
        )

        return signals
    }

    private var replyComposer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            Button {
                HapticManager.buttonPress()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.86))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.07), in: Circle())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Add attachment")

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
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.62))
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: 276, alignment: isFromCurrentUser ? .trailing : .leading)
            .background {
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
