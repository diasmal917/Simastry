import SwiftUI

struct MessagesView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedMessage: CompanionMessage?
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                if viewModel.companionMessages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            ForEach(viewModel.companionMessages) { message in
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
            viewModel.generateCompanionMessages()
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

            Text("Add a companion and they'll reach out based on their zodiac personality")
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
                    Text(message.companionName)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(message.isRead ? SimastryColor.mutedSilver : SimastryColor.offWhite)

                    Spacer()

                    Text(message.timestamp.relativeDescription)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.deepMuted)
                }

                Text(message.content)
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

    private var zodiacSign: ZodiacSign? {
        ZodiacSign.allCases.first { $0.displayName == message.companionSign }
            ?? ZodiacSign(rawValue: message.companionSign.lowercased())
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

                            Text(message.timestamp.relativeDescription)
                                .font(SimastryFont.caption)
                                .foregroundStyle(SimastryColor.deepMuted)
                        }

                        // Message content
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

                        // Action buttons
                        VStack(spacing: 12) {
                            Button {
                                HapticManager.buttonPress()
                                dismiss()
                                // Navigate to simulate view
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

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(SimastryColor.midnight)
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
