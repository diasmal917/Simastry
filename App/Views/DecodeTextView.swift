import SwiftUI

/// Decode uses owner-scoped People context for semantic analysis when the
/// secure service is available. Its deterministic sign templates remain as a
/// clearly labeled on-device fallback.
struct DecodeTextView: View {
    @Bindable var viewModel: AppViewModel

    @State private var messageText: String = ""
    @State private var theirSign: ZodiacSign?
    @State private var selectedPersonId: UUID?
    @State private var decoded: Bool = false
    @State private var semanticResult: CompanionDecodeResult?
    @State private var isDecoding = false
    @State private var usedOfflineFallback = false
    @State private var privacyBlockMessage: String?
    @State private var copiedReplyIndex: Int?

    private let privacyService = ConversationPrivacyService()

    private var canDecode: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && theirSign != nil
    }

    /// Deterministic per (text, day) like the local Compass fallback.
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                inputCard
                personPicker
                signPicker

                GoldButton(isDecoding ? "Decoding…" : "Decode it", isEnabled: canDecode && !isDecoding) {
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

                Text(privacyFooter)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, SimastrySpacing.tabBarEndClearance)
        }
        .scrollIndicators(.hidden)
        // `.background` keeps "What did they mean?" below the nav bar (no ghost).
        .background { CelestialBackground() }
        .navigationTitle("Decode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .accessibilityIdentifier("decode.screen")
        .animation(.spring(SimastrySpring.smooth), value: decoded)
        .onChange(of: messageText) { resetResult() }
        .onChange(of: theirSign) { resetResult() }
        .onChange(of: selectedPersonId) {
            resetResult()
            if let selectedPersonId,
               let person = viewModel.relationshipPeople.first(where: { $0.id == selectedPersonId }) {
                theirSign = person.sunSign
            }
        }
        .onAppear {
            // Person-page handoff: arrive with their sign already selected.
            if let personId = viewModel.decodeDraftPersonId,
               let person = viewModel.relationshipPeople.first(where: { $0.id == personId }) {
                selectedPersonId = personId
                theirSign = person.sunSign
                viewModel.decodeDraftPersonId = nil
            }
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

    private var privacyFooter: String {
        if semanticResult != nil {
            return "Redacted before secure analysis. The message was not persisted."
        }
        if usedOfflineFallback {
            return "Offline fallback — decoded on this iPhone and never sent or stored."
        }
        return "Choose a saved person for secure semantic analysis. Without one, Decode uses the labeled on-device fallback."
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

    private var personPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERSON · PRIVATE")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            Picker("Person", selection: $selectedPersonId) {
                Text("No saved person — offline fallback").tag(UUID?.none)
                ForEach(viewModel.relationshipPeople) { person in
                    Text(person.displayName).tag(Optional(person.id))
                }
            }
            .pickerStyle(.menu)
            .tint(SimastryColor.gold)

            Text("The server authorizes this People ID for your account; a name or zodiac sign alone is never used as identity.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
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
                            .accessibilityLabel("Decode as \(sign.displayName)")

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
        privacyBlockMessage = nil
        semanticResult = nil
        usedOfflineFallback = false

        guard let selectedPersonId,
              viewModel.primaryCompanionPersona != nil else {
            usedOfflineFallback = true
            decoded = true
            viewModel.analytics.track(.companionDecodeOfflineFallback, params: ["reason": "no_saved_person"])
            return
        }

        isDecoding = true
        Task {
            defer { isDecoding = false }
            do {
                let result = try await viewModel.semanticDecode(
                    message: prepared.redactedText,
                    personId: selectedPersonId
                )
                guard result.messagePersisted == false else {
                    throw SupabaseServiceError.invalidFunctionResponse
                }
                semanticResult = result
                decoded = true
            } catch {
                usedOfflineFallback = true
                decoded = true
                viewModel.analytics.track(.companionDecodeOfflineFallback, params: ["reason": "live_unavailable"])
                privacyBlockMessage = "Live semantic analysis was unavailable. Showing the labeled on-device sign template instead."
            }
        }
    }

    private func resetResult() {
        decoded = false
        semanticResult = nil
        usedOfflineFallback = false
        privacyBlockMessage = nil
    }

    // MARK: - Results

    @ViewBuilder
    private func resultStack(sign: ZodiacSign) -> some View {
        if let semanticResult {
            semanticResultStack(semanticResult, sign: sign)
        } else {
            offlineResultStack(sign: sign)
        }
    }

    private func offlineResultStack(sign: ZodiacSign) -> some View {
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

    private func semanticResultStack(_ result: CompanionDecodeResult, sign: ZodiacSign) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("SEMANTIC TONE")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
                Text(result.tone)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.midnight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(SimastryGradient.gold, in: Capsule())
                Spacer()
                ZodiacIconView(sign: sign, size: 24, showsGlow: false)
            }
            .padding(16)
            .heroGlass(sign.color, cornerRadius: 20)

            decodeCard(
                title: "ONE LIKELY READING",
                icon: "text.magnifyingglass",
                tint: SimastryColor.celestialBlue,
                body: result.likelyMeaning
            )
            decodeCard(
                title: "A PLAUSIBLE ALTERNATIVE",
                icon: "arrow.triangle.branch",
                tint: SimastryColor.risingViolet,
                body: result.plausibleAlternative
            )
            decodeCard(
                title: "WHAT NOT TO ASSUME",
                icon: "heart.slash.circle.fill",
                tint: SimastryColor.amber,
                body: result.whatNotToAssume
            )

            if !result.replyDrafts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("REPLY DRAFTS")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .tracking(1.3)
                    ForEach(Array(result.replyDrafts.prefix(3).enumerated()), id: \.offset) { index, reply in
                        HStack(alignment: .top, spacing: 8) {
                            Text(reply)
                                .font(.system(.footnote, design: .serif))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            Button {
                                UIPasteboard.general.string = reply
                                copiedReplyIndex = index
                            } label: {
                                Image(systemName: copiedReplyIndex == index ? "checkmark" : "doc.on.doc")
                                    .foregroundStyle(SimastryColor.gold)
                                    .padding(7)
                                    .background(SimastryColor.gold.opacity(0.12), in: Circle())
                            }
                            .accessibilityLabel(copiedReplyIndex == index ? "Reply copied" : "Copy this reply")
                        }
                        .padding(10)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(16)
                .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
            }

            Text("AI analysis · persona v\(result.personaVersion) · \(result.modelVersion)")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
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
