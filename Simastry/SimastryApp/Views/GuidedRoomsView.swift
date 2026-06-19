import SwiftUI

struct GuidedRoomInboxRow: View {
    let room: ChatThreadSummary
    let currentUserId: UUID?
    let action: () -> Void

    private var latestDate: Date {
        room.latestMessage?.createdAt ?? room.thread.updatedAt
    }

    private var isUnread: Bool {
        guard let currentMember = room.humanMembers.first(where: { $0.humanUserId == currentUserId }),
              let latestMessage = room.latestMessage else {
            return false
        }
        if latestMessage.senderUserId == currentUserId { return false }
        guard let lastReadAt = currentMember.lastReadAt else { return true }
        return latestMessage.createdAt > lastReadAt
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                GuidedRoomAvatarStack(members: room.members, currentUserId: currentUserId)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(room.displayTitle(currentUserId: currentUserId))
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(isUnread ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                            .lineLimit(1)

                        if !room.guideMembers.isEmpty {
                            Text("Guided")
                                .font(SimastryFont.captionSmall.weight(.semibold))
                                .foregroundStyle(SimastryColor.goldLight)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(SimastryColor.gold.opacity(0.12), in: Capsule())
                        }

                        Spacer(minLength: 4)

                        Text(latestDate.roomRelativeDescription)
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(isUnread ? SimastryColor.gold : SimastryColor.deepMuted)
                    }

                    HStack(spacing: 5) {
                        if room.latestMessage?.senderKind == .activity {
                            Image(systemName: "rectangle.stack.badge.play.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(SimastryColor.risingViolet)
                        }

                        Text(room.previewText)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(isUnread ? SimastryColor.offWhite.opacity(0.8) : SimastryColor.deepMuted)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                if isUnread {
                    Circle()
                        .fill(SimastryColor.gold)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
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
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(room.displayTitle(currentUserId: currentUserId)). \(room.previewText). \(latestDate.roomRelativeDescription)")
        .accessibilityHint("Double tap to open guided room")
    }
}

struct GuidedRoomCreateView: View {
    @Bindable var viewModel: AppViewModel
    let onCreated: (ChatThreadSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProfileIds: Set<UUID> = []
    @State private var selectedGuideIds: Set<String> = []
    @State private var initializedGuideSelection: Bool = false
    @State private var roomTitle: String = ""
    @State private var isCreating: Bool = false

    private var selectedProfiles: [SocialProfile] {
        viewModel.availableRoomProfiles.filter { selectedProfileIds.contains($0.id) }
    }

    private var canCreate: Bool {
        AppConfig.socialDiscoveryEnabled && !isCreating && (1...4).contains(selectedProfiles.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        introCard

                        if AppConfig.socialDiscoveryEnabled {
                            peopleSection
                            guidesSection
                            titleSection
                            createButton
                        } else {
                            unavailableCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("New Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .task {
                if !initializedGuideSelection {
                    selectedGuideIds = Set(viewModel.panelGuideEntries.map { $0.profile.id })
                    initializedGuideSelection = true
                }
                await viewModel.fetchDiscoverableProfiles()
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.goldLight)

                Text("GUIDED ROOM")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.goldLight)
                    .tracking(1.2)
            }

            Text("Start a private room with opted-in people. Your guides can join as AI participants for reflection, repair, and clarity.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                .lineSpacing(3)

            Text("This is a guided conversation, not therapy.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .padding(14)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.55))
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "People", subtitle: "Pick 1 to 4 opted-in profiles.")

            if viewModel.availableRoomProfiles.isEmpty {
                Text("No opted-in people are available yet.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .surfaceCard(cornerRadius: 16)
            } else {
                VStack(spacing: 9) {
                    ForEach(viewModel.availableRoomProfiles) { profile in
                        GuidedRoomProfilePickRow(
                            profile: profile,
                            isSelected: selectedProfileIds.contains(profile.id)
                        ) {
                            toggleProfile(profile)
                        }
                    }
                }
            }
        }
    }

    private var guidesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Your panel", subtitle: "The guides matched to your chart.")

            VStack(spacing: 9) {
                ForEach(viewModel.panelGuideEntries) { entry in
                    GuidedRoomGuideToggleRow(
                        entry: entry,
                        isSelected: selectedGuideIds.contains(entry.profile.id)
                    ) {
                        if selectedGuideIds.contains(entry.profile.id) {
                            selectedGuideIds.remove(entry.profile.id)
                        } else {
                            selectedGuideIds.insert(entry.profile.id)
                        }
                    }
                }
            }

            Text("Your panel is chosen for you — one guide for each of your Sun, Moon, and Rising signs. Toggle any off for this room.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Room name", subtitle: "Optional. If left blank, it uses member names.")

            TextField("Room name", text: $roomTitle)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(SimastryColor.offWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.09), lineWidth: 0.7)
                }
                .onChange(of: roomTitle) {
                    if roomTitle.count > 64 { roomTitle = String(roomTitle.prefix(64)) }
                }
        }
    }

    private var createButton: some View {
        GoldButton(isCreating ? "Creating..." : "Create Room", isEnabled: canCreate) {
            Task {
                await createRoom()
            }
        }
        .padding(.top, 4)
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Rooms are unavailable")
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)
            Text("Guided Rooms use social discovery and Supabase. Enable the social environment before creating real rooms.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(3)
        }
        .padding(14)
        .surfaceCard(cornerRadius: 18)
    }

    private func toggleProfile(_ profile: SocialProfile) {
        HapticManager.zodiacSelection()
        if selectedProfileIds.contains(profile.id) {
            selectedProfileIds.remove(profile.id)
        } else if selectedProfileIds.count < 4 {
            selectedProfileIds.insert(profile.id)
        } else {
            viewModel.showToast("Room is full", subtitle: "Guided Rooms support up to 5 humans including you.", isError: true)
        }
    }

    private func createRoom() async {
        guard canCreate else { return }
        isCreating = true
        defer { isCreating = false }

        if let room = await viewModel.createGuidedRoom(
            with: selectedProfiles,
            includedGuideProfileIds: selectedGuideIds,
            title: roomTitle
        ) {
            dismiss()
            onCreated(room)
        }
    }
}

struct GuidedRoomChatView: View {
    @Bindable var viewModel: AppViewModel
    let room: ChatThreadSummary

    @Environment(\.dismiss) private var dismiss
    @State private var replyText: String = ""
    @State private var isSendingReply: Bool = false
    @State private var showLeaveConfirmation: Bool = false
    @State private var showReportConfirmation: Bool = false
    @FocusState private var replyFocused: Bool

    private var summary: ChatThreadSummary {
        viewModel.roomSummary(for: room.id) ?? room
    }

    private var messages: [ChatMessage] {
        viewModel.roomMessages(for: room.id)
    }

    private var currentUserId: UUID? {
        viewModel.profile?.id
    }

    private var typingGuides: [ChatThreadMember] {
        summary.guideMembers.filter { member in
            guard let guideProfileId = member.guideProfileId else { return false }
            return viewModel.isGuideTyping(in: summary.id, guideProfileId: guideProfileId)
        }
    }

    private var canSendReply: Bool {
        !isSendingReply && !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 0) {
                roomHeader

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            roomMethodCard

                            ForEach(messages) { message in
                                GuidedRoomMessageBubble(
                                    message: message,
                                    currentUserId: currentUserId
                                )
                                .id(message.id.uuidString)
                            }

                            ForEach(typingGuides) { guide in
                                TypingDotsBubble {
                                    GuidedRoomMemberAvatar(member: guide, size: 28)
                                }
                                .id("typing-\(guide.id.uuidString)")
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            Spacer().frame(height: 16)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .animation(.spring(SimastrySpring.smooth), value: messages.count)
                        .animation(.spring(SimastrySpring.smooth), value: typingGuides.count)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        scrollToLatest(proxy)
                    }
                    .onChange(of: messages.count) {
                        scrollToLatest(proxy)
                    }
                    .onChange(of: typingGuides.count) {
                        scrollToLatest(proxy)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                GuidedRoomActivityTray(summary: summary) { kind in
                    Task {
                        await viewModel.sendRoomActivity(threadId: summary.id, kind: kind)
                    }
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
            await viewModel.loadRoomMessages(threadId: room.id, showErrors: false)
            await viewModel.markGuidedRoomRead(threadId: room.id)
        }
        .confirmationDialog("Room safety", isPresented: $showReportConfirmation, titleVisibility: .visible) {
            Button("Report room", role: .destructive) {
                Task {
                    await viewModel.reportGuidedRoom(threadId: summary.id, details: reportDetails)
                }
            }

            ForEach(blockableMembers) { member in
                Button("Block \(member.displayName)", role: .destructive) {
                    Task {
                        await viewModel.blockRoomMember(member, in: summary.id)
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Use this for safety concerns or to hide rooms with a person.")
        }
        .confirmationDialog("Leave this room?", isPresented: $showLeaveConfirmation, titleVisibility: .visible) {
            Button("Leave room", role: .destructive) {
                Task {
                    await viewModel.leaveGuidedRoom(threadId: summary.id)
                    dismiss()
                }
            }
        } message: {
            Text("The room will be removed from your inbox.")
        }
    }

    private var blockableMembers: [ChatThreadMember] {
        summary.humanMembers.filter { member in
            guard let humanUserId = member.humanUserId else { return false }
            return humanUserId != currentUserId
        }
    }

    private var reportDetails: String? {
        let lines = messages.suffix(8).map { message in
            "\(message.senderDisplayName): \(message.content)"
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private var roomHeader: some View {
        HStack(spacing: 12) {
            GuidedRoomAvatarStack(members: summary.members, currentUserId: currentUserId, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.displayTitle(currentUserId: currentUserId))
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1)

                Text("\(summary.humanMembers.count) humans · \(summary.guideMembers.count) guides · not therapy")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            Menu {
                Button(role: .destructive) {
                    showReportConfirmation = true
                } label: {
                    Label("Safety options", systemImage: "exclamationmark.shield.fill")
                }

                Button(role: .destructive) {
                    showLeaveConfirmation = true
                } label: {
                    Label("Leave room", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.84))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.07), in: Circle())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Room safety menu")

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
            .accessibilityLabel("Close room")
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

    private var roomMethodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SimastryColor.goldLight)

                Text("GUIDED CONVERSATION")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.goldLight)
                    .tracking(1.2)

                Spacer()
            }

            Text("Human messages are shared with room members. Guide replies use public profile signs, recent room messages, and activity cards only.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.76))
                .lineSpacing(2)

            if !summary.guideMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(summary.guideMembers) { member in
                            HStack(spacing: 6) {
                                GuidedRoomMemberAvatar(member: member, size: 20)
                                Text("\(member.displayName) · \(member.roleLabel ?? "Guide")")
                                    .font(SimastryFont.captionSmall.weight(.semibold))
                                    .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(member.roomTint.opacity(0.10), in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(member.roomTint.opacity(0.22), lineWidth: 0.55)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .surfaceCard(cornerRadius: 18, accent: SimastryColor.gold.opacity(0.55))
        .accessibilityElement(children: .combine)
    }

    private var replyComposer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField("Message the room", text: $replyText, axis: .vertical)
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
                    if replyText.count > 800 { replyText = String(replyText.prefix(800)) }
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
            .accessibilityLabel(isSendingReply ? "Sending message" : "Send message")
            .disabled(!canSendReply)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func sendReply() {
        let outgoingText = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoingText.isEmpty else { return }

        isSendingReply = true
        Task {
            let sent = await viewModel.sendRoomMessage(threadId: summary.id, content: outgoingText)
            if sent {
                replyText = ""
            }
            isSendingReply = false
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        let target = typingGuides.first.map { "typing-\($0.id.uuidString)" }
            ?? messages.last?.id.uuidString
        guard let target else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(SimastrySpring.smooth)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        }
    }
}

private struct GuidedRoomActivityTray: View {
    let summary: ChatThreadSummary
    let onSelect: (ChatActivityKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "rectangle.stack.badge.play.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.risingViolet)

                Text("Prompt cards")
                    .font(SimastryFont.captionSmall.weight(.semibold))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.74))

                Spacer()
            }
            .padding(.horizontal, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChatActivityKind.allCases) { kind in
                        Button {
                            HapticManager.zodiacSelection()
                            onSelect(kind)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: kind.systemImage)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(kind.title)
                                    .font(SimastryFont.captionSmall.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(SimastryColor.offWhite)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(SimastryColor.offWhite.opacity(0.08), in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.6)
                            }
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

private struct GuidedRoomMessageBubble: View {
    let message: ChatMessage
    let currentUserId: UUID?

    private var isFromCurrentUser: Bool {
        message.senderKind == .human && message.senderUserId == currentUserId
    }

    var body: some View {
        switch message.senderKind {
        case .system:
            GuidedRoomSystemMessage(message: message)
        case .activity:
            GuidedRoomActivityMessageCard(message: message)
        case .human, .guide:
            HStack(alignment: .bottom, spacing: 8) {
                if isFromCurrentUser {
                    Spacer(minLength: 54)
                } else {
                    GuidedRoomSenderAvatar(message: message, size: 28)
                }

                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 5) {
                    if !isFromCurrentUser {
                        Text(senderLabel)
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(message.senderKind == .guide ? SimastryColor.gold : SimastryColor.mutedSilver)
                            .lineLimit(1)
                    }

                    Text(message.content)
                        .font(SimastryFont.bodyMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 4) {
                        Text(message.createdAt.roomRelativeDescription)
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
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(bubbleFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .stroke(message.senderKind == .guide ? SimastryColor.gold.opacity(0.20) : .white.opacity(0.09), lineWidth: 0.7)
                        }
                }

                if !isFromCurrentUser {
                    Spacer(minLength: 54)
                }
            }
            .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(isFromCurrentUser ? "You" : message.senderDisplayName): \(message.content)")
        }
    }

    private var senderLabel: String {
        if message.senderKind == .guide {
            let sign = message.senderSign.flatMap { ZodiacSign(rawValue: $0.lowercased()) }?.displayName
            return [message.senderDisplayName, sign.map { "\($0) lens" }].compactMap { $0 }.joined(separator: " · ")
        }
        return message.senderDisplayName
    }

    private var bubbleFill: LinearGradient {
        if isFromCurrentUser {
            return LinearGradient(
                colors: [
                    SimastryColor.celestialBlue.opacity(0.96),
                    Color(red: 56/255, green: 110/255, blue: 205/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        if message.senderKind == .guide {
            return LinearGradient(
                colors: [
                    SimastryColor.surfaceElevated,
                    SimastryColor.surface.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [SimastryColor.surfaceElevated, SimastryColor.surface],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct GuidedRoomSystemMessage: View {
    let message: ChatMessage

    var body: some View {
        Text(message.content)
            .font(SimastryFont.caption)
            .foregroundStyle(SimastryColor.mutedSilver)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SimastryColor.offWhite.opacity(0.06), in: Capsule())
            .frame(maxWidth: .infinity)
            .accessibilityLabel(message.content)
    }
}

private struct GuidedRoomActivityMessageCard: View {
    let message: ChatMessage

    private var payload: ChatActivityPayload {
        message.activityPayload ?? ChatActivityPayload(title: message.content, body: "", prompts: [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: message.activityKind?.systemImage ?? "rectangle.stack.badge.play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.risingViolet)

                VStack(alignment: .leading, spacing: 2) {
                    Text(payload.title)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("Optional prompt card")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Spacer()
            }

            if !payload.body.isEmpty {
                Text(payload.body)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                    .lineSpacing(3)
            }

            if !payload.prompts.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(payload.prompts, id: \.self) { prompt in
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(SimastryColor.gold.opacity(0.9))
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(prompt)
                                .font(SimastryFont.caption)
                                .foregroundStyle(SimastryColor.mutedSilver)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 18, accent: SimastryColor.risingViolet.opacity(0.55))
        .accessibilityElement(children: .combine)
    }
}

private struct GuidedRoomAvatarStack: View {
    let members: [ChatThreadMember]
    let currentUserId: UUID?
    var size: CGFloat = 42

    private var visibleMembers: [ChatThreadMember] {
        let humans = members.filter { $0.memberKind == .human && $0.humanUserId != currentUserId }
        let guides = members.filter { $0.memberKind == .guide }
        let currentUser = members.first { $0.memberKind == .human && $0.humanUserId == currentUserId }
        return Array((humans + guides + [currentUser].compactMap { $0 }).prefix(4))
    }

    var body: some View {
        HStack(spacing: -14) {
            ForEach(Array(visibleMembers.enumerated()), id: \.element.id) { index, member in
                GuidedRoomMemberAvatar(member: member, size: size)
                    .background {
                        Circle().fill(SimastryColor.midnight)
                            .frame(width: size + 4, height: size + 4)
                    }
                    .zIndex(Double(visibleMembers.count - index))
            }
        }
        .frame(width: size + CGFloat(max(visibleMembers.count - 1, 0)) * 20, alignment: .leading)
        .accessibilityHidden(true)
    }
}

private struct GuidedRoomSenderAvatar: View {
    let message: ChatMessage
    let size: CGFloat

    var body: some View {
        if message.senderKind == .guide,
           let guideId = message.senderGuideId,
           let profile = FactoryCompanionCatalog.all.first(where: { $0.id == guideId }) {
            Image(profile.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size, alignment: .top)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(profile.sign.color.opacity(0.65), lineWidth: 1.1)
                }
        } else {
            let sign = message.senderSign.flatMap { ZodiacSign(rawValue: $0.lowercased()) }
            ZStack {
                Circle().fill((sign?.color ?? SimastryColor.gold).opacity(0.18))
                if let sign {
                    ZodiacIconView(sign: sign, size: size * 0.72, showsGlow: false)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                }
            }
            .frame(width: size, height: size)
            .overlay {
                Circle().strokeBorder((sign?.color ?? SimastryColor.gold).opacity(0.55), lineWidth: 1.0)
            }
        }
    }
}

private struct GuidedRoomMemberAvatar: View {
    let member: ChatThreadMember
    let size: CGFloat

    var body: some View {
        if member.memberKind == .guide,
           let guideId = member.guideProfileId,
           let profile = FactoryCompanionCatalog.all.first(where: { $0.id == guideId }) {
            Image(profile.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size, alignment: .top)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(profile.sign.color.opacity(0.65), lineWidth: 1.1)
                }
        } else {
            let sign = member.sign.flatMap { ZodiacSign(rawValue: $0.lowercased()) }
            ZStack {
                Circle().fill((sign?.color ?? SimastryColor.gold).opacity(0.18))
                if let sign {
                    ZodiacIconView(sign: sign, size: size * 0.72, showsGlow: false)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                }
            }
            .frame(width: size, height: size)
            .overlay {
                Circle().strokeBorder((sign?.color ?? SimastryColor.gold).opacity(0.55), lineWidth: 1.0)
            }
        }
    }
}

private struct GuidedRoomProfilePickRow: View {
    let profile: SocialProfile
    let isSelected: Bool
    let action: () -> Void

    private var sign: ZodiacSign? {
        ZodiacSign(rawValue: profile.sunSign.lowercased())
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill((sign?.color ?? SimastryColor.gold).opacity(0.18))
                    if let sign {
                        ZodiacIconView(sign: sign, size: 28, showsGlow: false)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)
                    }
                }
                .frame(width: 42, height: 42)
                .overlay {
                    Circle().strokeBorder((sign?.color ?? SimastryColor.gold).opacity(0.52), lineWidth: 1.0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text(profile.signSummary)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? SimastryColor.gold : SimastryColor.deepMuted)
            }
            .padding(12)
            .surfaceCard(cornerRadius: 16, accent: isSelected ? SimastryColor.gold.opacity(0.7) : nil)
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
    }
}

private struct GuidedRoomGuideToggleRow: View {
    let entry: PanelMatcher.Entry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(entry.profile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42, alignment: .top)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(entry.sign.color.opacity(0.62), lineWidth: 1.1)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.profile.name)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("\(entry.role.displayName) · \(entry.sign.displayName) lens")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Spacer()

                Toggle("", isOn: .constant(isSelected))
                    .labelsHidden()
                    .allowsHitTesting(false)
                    .tint(SimastryColor.gold)
            }
            .padding(12)
            .surfaceCard(cornerRadius: 16, accent: isSelected ? entry.sign.color.opacity(0.65) : nil)
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)
            Text(subtitle)
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
    }
}

private extension ChatThreadMember {
    var roomTint: Color {
        guard let raw = sign?.lowercased(), let zodiacSign = ZodiacSign(rawValue: raw) else {
            return SimastryColor.gold
        }
        return zodiacSign.color
    }
}

private extension Date {
    var roomRelativeDescription: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else if interval < 172800 {
            return "Yesterday"
        } else if interval < 604800 {
            return "\(Int(interval / 86400))d ago"
        } else {
            return SimastryDateFormatter.compactDate.string(from: self)
        }
    }
}
