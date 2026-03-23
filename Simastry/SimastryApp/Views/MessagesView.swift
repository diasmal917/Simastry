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
            .sheet(item: $selectedMessage) { message in
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
                 : "Add a companion and they'll reach out based on their zodiac personality")
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
        ZodiacSign.allCases.first { $0.displayName == message.companionSign }
            ?? ZodiacSign(rawValue: message.companionSign.lowercased())
    }

    private var previewText: String {
        if message.source == .discovery && message.direction == .outgoing {
            return "You: \(message.content)"
        }
        return message.content
    }

    var body: some View {
        HStack(spacing: 14) {
            // Zodiac glyph circle — serves as avatar in mock/local mode.
            // When Supabase social profiles go live, replace with actual profile photos
            // using ProfileImageView.
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
                        lineWidth: 1.5
                    )
                Text(zodiacSign?.glyph ?? "\u{2726}")
                    .font(.system(size: 18))
                    .foregroundStyle(zodiacSign?.color ?? SimastryColor.gold)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
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
                        .foregroundStyle(SimastryColor.deepMuted)
                }

                Text(previewText)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(message.isRead ? SimastryColor.deepMuted : SimastryColor.offWhite.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if !message.isRead {
                Circle()
                    .fill(SimastryColor.gold)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(14)
        .simastryGlass(cornerRadius: 16)
        .contentShape(.rect)
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
        ZodiacSign.allCases.first { $0.displayName == message.companionSign }
            ?? ZodiacSign(rawValue: message.companionSign.lowercased())
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

                        if message.source == .discovery {
                            discoveryConversationSection
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(message.content)
                                    .font(SimastryFont.bodyLarge)
                                    .foregroundStyle(SimastryColor.offWhite)
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .simastryGlass(cornerRadius: 20)

                            VStack(spacing: 12) {
                                Button {
                                    HapticManager.buttonPress()
                                    dismiss()
                                    viewModel.selectedTab = 3
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Reply with a Prediction")
                                            .font(SimastryFont.labelLarge)
                                    }
                                    .foregroundStyle(SimastryColor.midnight)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(SimastryColor.gold, in: .capsule)
                                }
                                .buttonStyle(SpringPressStyle())

                                if let sign = zodiacSign {
                                    Button {
                                        HapticManager.buttonPress()
                                        dismiss()
                                        viewModel.guideFocusSign = sign
                                        viewModel.selectedTab = 4
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "book.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("View \(sign.displayName) Guide")
                                                .font(SimastryFont.labelLarge)
                                        }
                                        .foregroundStyle(SimastryColor.offWhite)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .simastryGlassPill()
                                    }
                                    .buttonStyle(SpringPressStyle())
                                }
                            }
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
                }
            }
        }
        .task {
            if message.source == .discovery {
                await viewModel.refreshInbox(showErrors: false)
            }
        }
        .confirmationDialog("Discovery Safety", isPresented: $showSafetyOptions, titleVisibility: .visible) {
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
            Text("They won't appear in discovery and this conversation will stop resurfacing.")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
                TextField("Reply with your own message...", text: $replyText, axis: .vertical)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1...4)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(SimastryColor.offWhite.opacity(0.06))
                    )

                HStack(spacing: 12) {
                    if let sign = zodiacSign {
                        Button {
                            HapticManager.buttonPress()
                            dismiss()
                            viewModel.guideFocusSign = sign
                            viewModel.selectedTab = 4
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "book.fill")
                                Text("Guide")
                            }
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .simastryGlassPill()
                        }
                        .buttonStyle(SpringPressStyle())
                    }

                    Button {
                        let outgoingText = replyText
                        isSendingReply = true
                        Task {
                            let sent = await viewModel.sendDiscoveryReply(
                                to: message.companionId,
                                companionName: message.companionName,
                                companionSign: message.companionSign,
                                content: outgoingText
                            )
                            if sent {
                                replyText = ""
                            }
                            isSendingReply = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                            Text(isSendingReply ? "Sending..." : "Send")
                        }
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.midnight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(SimastryColor.gold, in: Capsule())
                    }
                    .buttonStyle(SpringPressStyle())
                    .disabled(isSendingReply || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
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
