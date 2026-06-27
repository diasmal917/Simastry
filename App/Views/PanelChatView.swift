import SwiftUI

/// Group thread between the user and their three placement guides.
struct PanelChatView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var replyText: String = ""
    @State private var isSendingReply: Bool = false
    @FocusState private var replyFocused: Bool

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 0) {
                panelHeader

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            methodCard

                            ForEach(viewModel.sortedPanelMessages) { message in
                                PanelMessageBubble(viewModel: viewModel, message: message)
                                    .id(message.id)
                            }

                            ForEach(typingEntries) { entry in
                                TypingDotsBubble {
                                    guideAvatar(entry.profile, size: 28)
                                }
                                .id("typing-\(entry.profile.id)")
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            Spacer().frame(height: 16)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .animation(.spring(SimastrySpring.smooth), value: viewModel.panelTypingParticipantIds)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        scrollToLatest(proxy)
                    }
                    .onChange(of: viewModel.panelMessages.count) {
                        scrollToLatest(proxy)
                    }
                    .onChange(of: viewModel.panelTypingParticipantIds) {
                        if let first = typingEntries.first {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                withAnimation(.spring(SimastrySpring.smooth)) {
                                    proxy.scrollTo("typing-\(first.profile.id)", anchor: .bottom)
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
            viewModel.isPanelThreadOpen = true
            viewModel.postPanelWelcomeBackIfNeeded()
            viewModel.markPanelThreadRead()
            viewModel.seedPanelWelcomeIfNeeded()
        }
        .onDisappear {
            viewModel.isPanelThreadOpen = false
        }
    }

    private var typingEntries: [PanelMatcher.Entry] {
        viewModel.panelGuideEntries.filter {
            viewModel.panelTypingParticipantIds.contains($0.profile.id)
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: -12) {
                ForEach(Array(viewModel.panelGuideEntries.enumerated()), id: \.element.id) { index, entry in
                    guideAvatar(entry.profile, size: 38)
                        .background {
                            Circle().fill(SimastryColor.midnight)
                                .frame(width: 42, height: 42)
                        }
                        .zIndex(Double(viewModel.panelGuideEntries.count - index))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Your Panel")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1)

                Text("\(viewModel.panelGuideEntries.count) AI guides · Sun, Moon and Rising lenses")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

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
            .accessibilityLabel("Close panel chat")
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

    private func guideAvatar(_ profile: FactoryCompanionProfile, size: CGFloat) -> some View {
        Image(profile.profileImageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size, alignment: .top)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(profile.sign.color.opacity(0.6), lineWidth: 1.1)
            }
            .accessibilityHidden(true)
    }

    // MARK: - Method Card

    private var methodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: SimastryIcon.method)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.goldLight)

                Text("YOUR ADVISORY PANEL")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.goldLight)
                    .tracking(1.2)

                Spacer(minLength: 0)
            }

            Text("AI guides read this through your Sun, Moon, and Rising lenses. Private by default.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.76))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if let firstReadContext {
                firstReadContextPill(firstReadContext)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.panelGuideEntries) { entry in
                        HStack(spacing: 6) {
                            guideAvatar(entry.profile, size: 20)
                            Text("\(entry.profile.name) · \(entry.role.displayName)")
                                .font(SimastryFont.captionSmall.weight(.semibold))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(entry.sign.color.opacity(0.10), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(entry.sign.color.opacity(0.22), lineWidth: 0.55)
                        }
                    }
                }
            }
        }
        .padding(12)
        .surfaceCard(cornerRadius: 18, accent: SimastryColor.gold.opacity(0.7))
        .accessibilityElement(children: .combine)
    }

    private var firstReadContext: FirstReadDraft? {
        guard let draft = viewModel.firstReadDraft, !draft.isDismissed else { return nil }
        return draft
    }

    private func firstReadContextPill(_ draft: FirstReadDraft) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("Continuing your first read")
                    .font(SimastryFont.captionSmall.weight(.bold))
                    .foregroundStyle(SimastryColor.gold)

                Text("\"\(panelSnippet(draft.messageText))\"")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.76))
                    .lineLimit(2)

                if let move = draft.bestNextMove {
                    Text("Next move: \(move.type.title)")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(SimastryColor.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(SimastryColor.gold.opacity(0.15), lineWidth: 0.6)
        }
    }

    private func panelSnippet(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 72 else { return trimmed }
        return "\(trimmed.prefix(72))..."
    }

    // MARK: - Composer

    private var replyComposer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField("Ask your panel", text: $replyText, axis: .vertical)
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
            .accessibilityLabel(isSendingReply ? "Sending message" : "Send message")
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
            let sent = await viewModel.sendPanelMessage(outgoingText)
            if sent {
                replyText = ""
            }
            isSendingReply = false
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let last = viewModel.sortedPanelMessages.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(SimastrySpring.smooth)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Bubble

private struct PanelMessageBubble: View {
    @Bindable var viewModel: AppViewModel
    let message: PanelMessage
    @State private var showGuideProfile: Bool = false
    @State private var submittedFeedbackTitle: String?
    @State private var showTuneOptions: Bool = false

    private var isFromCurrentUser: Bool {
        message.senderId == PanelParticipant.localUserId
    }

    private var guideEntry: PanelMatcher.Entry? {
        isFromCurrentUser ? nil : viewModel.panelGuideEntry(forParticipantId: message.senderId)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 54)
            } else if let guideEntry {
                // Instagram pattern: tapping a face opens the profile.
                Button {
                    HapticManager.buttonPress()
                    showGuideProfile = true
                } label: {
                    Image(guideEntry.profile.profileImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28, alignment: .top)
                        .clipShape(Circle())
                        .overlay {
                            Circle().strokeBorder(guideEntry.sign.color.opacity(0.55), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(guideEntry.profile.name)'s profile")
                .sheet(isPresented: $showGuideProfile) {
                    NavigationStack {
                        GuideProfileView(viewModel: viewModel, profile: guideEntry.profile)
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 5) {
                if let guideEntry {
                    HStack(spacing: 5) {
                        Text(guideEntry.profile.name)
                            .font(SimastryFont.captionSmall.weight(.semibold))
                            .foregroundStyle(guideEntry.sign.color)
                            .lineLimit(1)

                        Text("\(guideEntry.role.displayName) lens")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.deepMuted)
                            .lineLimit(1)
                    }
                }

                Text(message.content)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message.timestamp.panelRelativeDescription)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(isFromCurrentUser ? 0.70 : 0.46))

                if let guideEntry {
                    guideFeedbackRow(for: guideEntry)
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
                                .stroke((guideEntry?.sign.color ?? .white).opacity(0.14), lineWidth: 0.7)
                        }
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 54)
            }
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isFromCurrentUser ? "You" : (guideEntry?.profile.name ?? "Guide")): \(message.content)")
    }

    private func guideFeedbackRow(for guideEntry: PanelMatcher.Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let submittedFeedbackTitle {
                Text("\(submittedFeedbackTitle) saved")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.48))
            } else {
                HStack(spacing: 6) {
                    guideFeedbackButton("Helpful", systemImage: "hand.thumbsup.fill") {
                        submitGuideFeedback(
                            guideEntry: guideEntry,
                            helpfulness: .helpful,
                            reasons: [],
                            savedTitle: "Helpful"
                        )
                    }

                    guideFeedbackButton("Too vague", systemImage: "questionmark.bubble.fill") {
                        submitGuideFeedback(
                            guideEntry: guideEntry,
                            helpfulness: .partlyHelpful,
                            reasons: [.tooVague],
                            savedTitle: "Too vague"
                        )
                    }

                    guideFeedbackButton("Tune", systemImage: "slider.horizontal.3") {
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
                            guideFeedbackButton(option.title, systemImage: option.systemImage) {
                                submitGuideFeedback(
                                    guideEntry: guideEntry,
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
    }

    private func guideFeedbackButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(SimastryColor.offWhite.opacity(0.68))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(.white.opacity(0.055), in: Capsule())
        }
        .buttonStyle(SpringPressStyle())
    }

    private func submitGuideFeedback(
        guideEntry: PanelMatcher.Entry,
        helpfulness: HelpfulnessRating,
        reasons: [GuideFeedbackReason],
        savedTitle: String
    ) {
        HapticManager.buttonPress()
        viewModel.recordGuideFeedback(
            readId: message.id,
            aiUsageEventId: message.aiUsageEventId,
            guideId: guideEntry.profile.id,
            surface: .panelChat,
            helpfulness: helpfulness,
            reasons: reasons
        )
        withAnimation(.spring(SimastrySpring.snappy)) {
            submittedFeedbackTitle = savedTitle
        }
    }
}

private extension Date {
    var panelRelativeDescription: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 172800 { return "Yesterday" }
        return SimastryDateFormatter.compactDate.string(from: self)
    }
}
