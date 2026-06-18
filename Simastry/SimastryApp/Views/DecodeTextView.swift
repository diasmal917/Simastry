import SwiftUI

/// Predict's little sister and the most frequent moment: paste the one
/// message you just received and get the tone, the subtext by their sign —
/// and what NOT to read into it. Fully on-device.
struct DecodeTextView: View {
    @Bindable var viewModel: AppViewModel

    @State private var messageText: String = ""
    @State private var theirSign: ZodiacSign?
    @State private var decoded: Bool = false
    @State private var privacyBlockMessage: String?
    @State private var copiedReplyIndex: Int?

    private let privacyService = ConversationPrivacyService()

    private var canDecode: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && theirSign != nil
    }

    /// Deterministic per (text, day) like the local Predict composer.
    private var seed: Int {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return abs(messageText.count &+ dayOfYear)
    }

    private var tone: SimulationTone? {
        guard let theirSign else { return nil }
        let options: [SimulationTone] = switch theirSign.element {
        case .fire: [.confident, .playful, .flirty]
        case .earth: [.warm, .guarded, .confident]
        case .air: [.playful, .distant, .warm]
        case .water: [.warm, .guarded, .anxious]
        }
        return options[seed % options.count]
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    inputCard
                    signPicker

                    GoldButton("Decode it", isEnabled: canDecode) {
                        decode()
                    }

                    if let privacyBlockMessage {
                        Text(privacyBlockMessage)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if decoded, let theirSign {
                        resultStack(sign: theirSign)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Text("Decoded on this iPhone — the message is never sent or stored.")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, SimastrySpacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Decode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .animation(.spring(SimastrySpring.smooth), value: decoded)
        .onChange(of: messageText) { decoded = false; privacyBlockMessage = nil }
        .onChange(of: theirSign) { decoded = false }
        .onAppear {
            // Person-page handoff: arrive with their sign already selected.
            if let handoffSign = viewModel.decodeDraftSign {
                theirSign = handoffSign
                viewModel.decodeDraftSign = nil
            }
            #if DEBUG
            // Prefill only — the preview taps Decode like a user would,
            // since onChange(of: messageText) clears stale results.
            if viewModel.isDebugPreviewStateActive, messageText.isEmpty {
                messageText = "haha yeah maybe, this week is kind of crazy though"
                theirSign = theirSign ?? .taurus
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("What did they mean?")
                .font(SimastryFont.titleLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Paste the one message you keep rereading.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THEIR MESSAGE")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            TextEditor(text: $messageText)
                .scrollContentBackground(.hidden)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .frame(minHeight: 88)
                .padding(10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if messageText.isEmpty {
                        Text("Paste their message…")
                            .font(SimastryFont.bodyMedium)
                            .foregroundStyle(SimastryColor.textTertiary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    private var signPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THEIR SIGN")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ZodiacSign.allCases) { sign in
                        VStack(spacing: 5) {
                            ZodiacBadgeView(sign: sign, isSelected: theirSign == sign, size: 40) {
                                withAnimation(.spring(SimastrySpring.snappy)) {
                                    theirSign = theirSign == sign ? nil : sign
                                }
                            }
                            .accessibilityLabel("Decode as a \(sign.displayName)")

                            Text(sign.displayName)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(theirSign == sign ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                        }
                        .frame(width: 52)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    private func decode() {
        let prepared = privacyService.prepare(messageText)
        guard prepared.canProceed else {
            privacyBlockMessage = prepared.blockingMessage
                ?? "This message includes content Simastry can't safely read."
            return
        }
        HapticManager.signConfirmed()
        decoded = true
    }

    // MARK: - Results

    private func resultStack(sign: ZodiacSign) -> some View {
        let element = sign.element.rawValue
        let subtextLines = AstrologyTemplates.decodeSubtext[element] ?? []
        let dontLines = AstrologyTemplates.decodeDontReadInto[element] ?? []
        let replies = AstrologyTemplates.suggestedReplies[sign.displayName] ?? []

        return VStack(alignment: .leading, spacing: 14) {
            // Tone
            if let tone {
                HStack(spacing: 8) {
                    Text("READS AS")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.3)

                    Text(tone.rawValue.capitalized)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.midnight)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SimastryGradient.gold, in: Capsule())

                    Spacer()

                    ZodiacIconView(sign: sign, size: 24, showsGlow: false)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .heroGlass(sign.color, cornerRadius: 20)
            }

            // Subtext
            if !subtextLines.isEmpty {
                decodeCard(
                    title: "WHAT IT LIKELY MEANS",
                    icon: "text.magnifyingglass",
                    tint: SimastryColor.celestialBlue,
                    body: subtextLines[seed % subtextLines.count]
                )
            }

            // The anti-spiral line — the signature of this screen.
            if !dontLines.isEmpty {
                decodeCard(
                    title: "WHAT NOT TO READ INTO IT",
                    icon: "heart.slash.circle.fill",
                    tint: SimastryColor.amber,
                    body: dontLines[seed % dontLines.count]
                )
            }

            // Reply directions
            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)

                        Text("WAYS TO REPLY")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.textSecondary)
                            .tracking(1.3)
                    }

                    ForEach(Array(replies.prefix(3).enumerated()), id: \.offset) { index, reply in
                        HStack(alignment: .top, spacing: 8) {
                            Text(reply)
                                .font(.system(.footnote, design: .serif))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 6)

                            Button {
                                HapticManager.buttonPress()
                                UIPasteboard.general.string = reply
                                withAnimation(.spring(SimastrySpring.snappy)) {
                                    copiedReplyIndex = index
                                }
                                Task {
                                    try? await Task.sleep(for: .seconds(1.6))
                                    if copiedReplyIndex == index {
                                        withAnimation(.spring(SimastrySpring.snappy)) {
                                            copiedReplyIndex = nil
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: copiedReplyIndex == index ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(SimastryColor.gold)
                                    .padding(7)
                                    .background(SimastryColor.gold.opacity(0.12), in: Circle())
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(SpringPressStyle())
                            .accessibilityLabel(copiedReplyIndex == index ? "Reply copied" : "Copy this reply")
                        }
                        .padding(10)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
            }
        }
    }

    private func decodeCard(title: String, icon: String, tint: Color, body: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            Text(body)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: tint.opacity(0.6))
    }
}
