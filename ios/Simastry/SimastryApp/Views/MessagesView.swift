import SwiftUI

struct MessagesView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedMessage: CompanionMessage?
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                if viewModel.inboxMessages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.refreshInbox(showErrors: false)
            }
            .fullScreenCover(item: $selectedMessage) { message in
                MessageDetailSheet(
                    message: message,
                    viewModel: viewModel
                )
            }
        }
    }

    private var messageList: some View {
        List {
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
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(SimastryColor.mutedSilver.opacity(0.5))

            Text("No messages yet")
                .font(SimastryFont.titleMedium)
                .foregroundStyle(SimastryColor.offWhite)

            Text(AppConfig.socialDiscoveryEnabled
                 ? "Add a companion or send a discovery intro, and your messages will gather here."
                 : "Add a companion and messages will reflect their sign lens and your chart context.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if viewModel.companions.isEmpty {
                Button {
                    HapticManager.buttonPress()
                    viewModel.selectedTab = 0
                    viewModel.homeSetupPhase = .modeSelection
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add Companion")
                            .font(SimastryFont.labelLarge)
                    }
                    .foregroundStyle(SimastryColor.midnight)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(SimastryColor.gold, in: .capsule)
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityHint("Opens companion setup to add your first companion")
                .padding(.top, 8)
            }
        }
        .padding(.bottom, 60)
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
        if message.source == .discovery && message.direction == .outgoing {
            return "You: \(message.content)"
        }
        return message.content
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((zodiacSign?.color ?? SimastryColor.gold).opacity(0.18))
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
                        lineWidth: message.isRead ? 0.8 : 1.6
                    )
                Text(zodiacSign?.glyph ?? "\u{2726}")
                    .font(.system(size: 20))
                    .foregroundStyle(zodiacSign?.color ?? SimastryColor.gold)
            }
            .frame(width: 52, height: 52)

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

// MARK: - Message Detail Sheet

private struct MessageDetailSheet: View {
    let message: CompanionMessage
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var replyText: String = ""
    @State private var isSendingReply: Bool = false
    @State private var showSafetyOptions: Bool = false
    @State private var showBlockConfirmation: Bool = false

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
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 16)

                        // Companion header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill((zodiacSign?.color ?? SimastryColor.gold).opacity(0.15))
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
                                        lineWidth: 2
                                    )
                                Text(zodiacSign?.glyph ?? "\u{2726}")
                                    .font(.system(size: 28))
                                    .foregroundStyle(zodiacSign?.color ?? SimastryColor.gold)
                            }
                            .frame(width: 64, height: 64)

                            Text(message.companionName)
                                .font(SimastryFont.titleMedium)
                                .foregroundStyle(SimastryColor.offWhite)

                            Text("\(message.companionSign) Sun")
                                .font(SimastryFont.labelMedium)
                                .foregroundStyle(zodiacSign?.color ?? SimastryColor.mutedSilver)

                            if message.source == .discovery {
                                Text("Discovery Chat")
                                    .font(SimastryFont.captionSmall)
                                    .foregroundStyle(SimastryColor.gold)
                            }

                            Text(message.timestamp.relativeDescription)
                                .font(SimastryFont.caption)
                                .foregroundStyle(SimastryColor.deepMuted)
                        }

                        messageMethodLayer

                        if message.source == .discovery {
                            discoveryConversationSection
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(message.content)
                                            .font(SimastryFont.bodyLarge)
                                            .foregroundStyle(SimastryColor.offWhite)
                                            .lineSpacing(5)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Text(message.timestamp.relativeDescription)
                                            .font(SimastryFont.captionSmall)
                                            .foregroundStyle(SimastryColor.deepMuted)
                                    }
                                    .padding(14)
                                    .background(SimastryColor.offWhite.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                                    Spacer(minLength: 44)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            replyComposer
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if message.source == .discovery {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showSafetyOptions = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(SimastryColor.mutedSilver)
                        }
                        .accessibilityLabel("Discovery safety actions")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .accessibilityLabel("Close message detail")
                }
            }
        }
        .task {
            if message.source == .discovery {
                await viewModel.refreshInbox(showErrors: false)
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

    private var discoveryConversationSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Conversation")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(1)
                    .textCase(.uppercase)

                if conversationMessages.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: 14))
                            .foregroundStyle(SimastryColor.mutedSilver)
                        Text("Start the conversation — say something!")
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }

                ForEach(conversationMessages) { threadMessage in
                    HStack {
                        if threadMessage.direction == .outgoing {
                            Spacer(minLength: 44)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(threadMessage.direction == .outgoing ? "You" : threadMessage.companionName)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(threadMessage.direction == .outgoing ? SimastryColor.midnight.opacity(0.72) : SimastryColor.gold)

                            Text(threadMessage.content)
                                .font(SimastryFont.bodyMedium)
                                .foregroundStyle(threadMessage.direction == .outgoing ? SimastryColor.midnight : SimastryColor.offWhite)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(threadMessage.timestamp.relativeDescription)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(threadMessage.direction == .outgoing ? SimastryColor.midnight.opacity(0.62) : SimastryColor.deepMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            threadMessage.direction == .outgoing ? SimastryColor.gold : SimastryColor.offWhite.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )

                        if threadMessage.direction == .incoming {
                            Spacer(minLength: 44)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .simastryGlass(cornerRadius: 20)

            VStack(spacing: 12) {
                replyComposer

                if replyText.count > 0 {
                    Text("\(replyText.count)/500")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.deepMuted)
                }
            }
        }
    }

    private var messageMethodLayer: some View {
        MethodLayerPanel(
            title: "Conversation lens",
            summary: "This thread stays anchored to message context and the companion's sign lens, so replies feel personal without exposing private content.",
            signals: messageMethodSignals,
            footer: "Private messages are not exposed in notification previews.",
            accent: zodiacSign?.color ?? SimastryColor.gold
        )
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
        HStack(spacing: 10) {
            TextField("Message", text: $replyText, axis: .vertical)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    Capsule(style: .continuous)
                        .fill(SimastryColor.offWhite.opacity(0.07))
                )
                .onChange(of: replyText) {
                    if replyText.count > 500 { replyText = String(replyText.prefix(500)) }
                }

            Button {
                sendReply()
            } label: {
                Image(systemName: isSendingReply ? "ellipsis" : "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(width: 42, height: 42)
                    .background(SimastryColor.gold, in: Circle())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel(isSendingReply ? "Sending reply" : "Send reply")
            .disabled(isSendingReply || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.top, 4)
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
            } else if let companion = viewModel.companions.first(where: { $0.id == message.companionId }) {
                sent = await viewModel.recordCompanionInteraction(
                    with: companion,
                    title: "Message sent",
                    subtitle: outgoingText
                )
            } else {
                viewModel.showToast("Message saved", subtitle: "Your reply is ready for this thread.", isError: false)
                sent = true
            }

            if sent {
                replyText = ""
            }
            isSendingReply = false
        }
    }
}

// MARK: - Date Extension for Relative Time

private extension Date {
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
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }
}
