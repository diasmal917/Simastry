import SwiftUI

/// Rehearse the sensitive conversation before having it for real — a chat
/// with a persona simulated from this person's chart and the user's own
/// description. The disclosure banner never leaves the screen.
struct PracticeChatView: View {
    @Bindable var viewModel: AppViewModel
    let person: RelationshipPerson

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [PracticeMessage] = []
    @State private var draft: String = ""
    @State private var isReplying: Bool = false
    @State private var replyTask: Task<Void, Never>?
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                VStack(spacing: 0) {
                    disclosureBanner

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) {
                                if messages.isEmpty {
                                    emptyState
                                }

                                ForEach(messages) { message in
                                    bubble(message)
                                        .id(message.id)
                                }

                                if isReplying {
                                    HStack {
                                        TypingDotsBubble {
                                            personaAvatar(size: 26)
                                        }
                                        Spacer()
                                    }
                                    .id("practice-typing")
                                }

                                Spacer().frame(height: 12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .animation(.spring(SimastrySpring.smooth), value: messages.count)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: messages.count) {
                            if let last = messages.last {
                                withAnimation(.spring(SimastrySpring.smooth)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Practice with \(person.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .tint(SimastryColor.gold)
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            clearRehearsal()
                        } label: {
                            Label("Clear rehearsal", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(SimastryColor.gold)
                    }
                    .accessibilityLabel("Rehearsal options")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
                    .simastryToolbarGlass()
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 0.5)
                    }
            }
            .onAppear {
                messages = viewModel.practiceThread(for: person.id)
            }
            .onDisappear {
                replyTask?.cancel()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func clearRehearsal() {
        replyTask?.cancel()
        replyTask = nil
        isReplying = false
        messages = []
        viewModel.clearPracticeThread(for: person.id)
    }

    /// Pinned and non-dismissable: a rehearsal is never the real person.
    private var disclosureBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "theatermasks.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)

            Text("A rehearsal built from chart patterns — not actually \(person.displayName).")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(SimastryColor.gold.opacity(0.10))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SimastryColor.gold.opacity(0.18))
                .frame(height: 0.5)
        }
        .accessibilityLabel("This is a rehearsal simulation, not the real \(person.displayName)")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            personaAvatar(size: 56)

            Text("Say the thing you've been holding")
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Open exactly how you would in real life. The simulation answers in \(person.displayName)'s plausible register — friction included, because a rehearsal that only flatters is useless.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
        .padding(.top, 36)
    }

    private func personaAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(person.sunSign.color.opacity(0.18))
            Circle()
                .strokeBorder(person.sunSign.color.opacity(0.45), lineWidth: 1)
            ZodiacIconView(sign: person.sunSign, size: size * 0.58, showsGlow: false)
        }
        .frame(width: size, height: size)
    }

    private func bubble(_ message: PracticeMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 54)
            } else {
                personaAvatar(size: 26)
            }

            Text(message.content)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.isUser
                              ? AnyShapeStyle(SimastryColor.gold.opacity(0.22))
                              : AnyShapeStyle(Color.white.opacity(0.07)))
                }
                .frame(maxWidth: 276, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser {
                Spacer(minLength: 54)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("What you'd actually say…", text: $draft, axis: .vertical)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .focused($composerFocused)

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty ? SimastryColor.mutedSilver : SimastryColor.midnight)
                    .frame(width: 36, height: 36)
                    .background(
                        draft.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AnyShapeStyle(Color.white.opacity(0.08))
                            : AnyShapeStyle(SimastryGradient.gold),
                        in: Circle()
                    )
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isReplying)
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isReplying else { return }

        HapticManager.buttonPress()
        draft = ""
        messages.append(PracticeMessage(isUser: true, content: text))
        viewModel.savePracticeThread(messages, for: person.id)

        isReplying = true
        let transcript = messages.suffix(10).map { message in
            GuideReplyService.TranscriptEntry(
                senderName: message.isUser ? "User" : person.displayName,
                content: message.content
            )
        }
        let threadCount = messages.count

        replyTask?.cancel()
        replyTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else {
                    isReplying = false
                    return
                }

                let reply = await viewModel.generatePracticeReply(
                    person: person,
                    transcript: Array(transcript),
                    threadCount: threadCount
                )
                guard !Task.isCancelled else {
                    isReplying = false
                    return
                }

                isReplying = false
                messages.append(PracticeMessage(isUser: false, content: reply))
                viewModel.savePracticeThread(messages, for: person.id)
            } catch is CancellationError {
                isReplying = false
            } catch {
                isReplying = false
            }
        }
    }
}
