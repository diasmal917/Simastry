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

/// Pre-auth activation moment: the user gets one practical, on-device read
/// before birth details or account creation.
struct FirstReadView: View {
    @Bindable var viewModel: AppViewModel

    @State private var messageText: String = ""
    @State private var theirSign: ZodiacSign?
    @State private var decoded: Bool = false
    @State private var privacyBlockMessage: String?
    @State private var copiedReplyIndex: Int?
    @State private var tunedReplies: [Int: ReplyTuneAction] = [:]
    @State private var feedbackRating: HelpfulnessRating?
    @State private var feedbackReasons: Set<GuideFeedbackReason> = []

    private let privacyService = ConversationPrivacyService()

    private var canDecode: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && theirSign != nil
    }

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

                    GoldButton("Decode my first read", isEnabled: canDecode) {
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

                        GoldButton("Save this with my chart") {
                            saveFirstReadAndContinue()
                        }
                    }

                    skipButton
                    privacyLine
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)
        }
        .animation(.spring(SimastrySpring.smooth), value: decoded)
        .onChange(of: messageText) {
            resetResultState()
            privacyBlockMessage = nil
        }
        .onChange(of: theirSign) {
            resetResultState()
            if let theirSign {
                viewModel.analytics.track(
                    .firstReadSignSelected,
                    params: ["selectedSign": theirSign.rawValue]
                )
            }
        }
        .onAppear {
            viewModel.analytics.track(.firstReadStarted)
            #if DEBUG
            if viewModel.isDebugPreviewStateActive, messageText.isEmpty {
                messageText = "haha yeah maybe, this week is kind of crazy though"
                theirSign = .taurus
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            SimastryWordmark(font: .system(.title, weight: .bold).italic())

            VStack(spacing: 6) {
                Text("Get your first read")
                    .font(SimastryFont.displayMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .multilineTextAlignment(.center)

                Text("Paste the message you keep rereading. Simastry will decode the tone and show what to say next.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
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
                .frame(minHeight: 92)
                .padding(10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if messageText.isEmpty {
                        Text("Paste their message...")
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

    private var skipButton: some View {
        Button {
            HapticManager.buttonPress()
            continueToBirthDetails()
        } label: {
            Text("Skip for now")
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.mutedSilver)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Continue to birth details without a first read")
    }

    private var privacyLine: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: SimastryIcon.privacy)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SimastryColor.gold.opacity(0.78))

            Text("This first read stays on this iPhone. Next, your chart makes it more personal.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }

    private func decode() {
        let prepared = privacyService.prepare(messageText)
        guard prepared.canProceed else {
            privacyBlockMessage = prepared.blockingMessage
                ?? "This message includes content Simastry can't safely read."
            viewModel.analytics.track(
                .firstReadFailed,
                params: ["reason": "privacy", "messageLengthBucket": messageLengthBucket(prepared.redactedText)]
            )
            return
        }
        HapticManager.signConfirmed()
        viewModel.analytics.track(
            .firstReadMessageEntered,
            params: ["messageLengthBucket": messageLengthBucket(prepared.redactedText)]
        )
        viewModel.analytics.track(
            .firstReadGeneratedTemplate,
            params: [
                "selectedSign": theirSign?.rawValue ?? "unknown",
                "messageLengthBucket": messageLengthBucket(prepared.redactedText),
                "usedFallback": "false"
            ]
        )
        decoded = true
    }

    private func continueToBirthDetails() {
        withAnimation(.spring(SimastrySpring.smooth)) {
            viewModel.currentScreen = .birthDetails
        }
    }

    private func saveFirstReadAndContinue() {
        if decoded, let theirSign, let draft = makeDraft(for: theirSign) {
            viewModel.saveFirstReadDraft(draft)
            viewModel.analytics.track(
                .firstReadSaved,
                params: [
                    "selectedSign": theirSign.rawValue,
                    "messageLengthBucket": messageLengthBucket(draft.messageText),
                    "bestNextMove": draft.bestNextMove?.type.rawValue ?? "none"
                ]
            )
        }
        continueToBirthDetails()
    }

    private func resultStack(sign: ZodiacSign) -> some View {
        let draft = makeDraft(for: sign)

        return VStack(alignment: .leading, spacing: 14) {
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

            if let draft {
                if let bestNextMove = draft.bestNextMove {
                    bestNextMoveCard(bestNextMove, sign: sign)
                }

                firstReadCard(
                    title: "WHAT IT LIKELY MEANS",
                    icon: "text.magnifyingglass",
                    tint: SimastryColor.celestialBlue,
                    body: draft.likelyMeaning
                )

                firstReadCard(
                    title: "WHAT NOT TO ASSUME",
                    icon: "heart.slash.circle.fill",
                    tint: SimastryColor.amber,
                    body: draft.notAssume
                )

                if !draft.suggestedReplies.isEmpty {
                    replyCard(replies: draft.suggestedReplies)
                }

                feedbackCard(for: draft)
            }
        }
    }

    private func makeDraft(for sign: ZodiacSign) -> FirstReadDraft? {
        guard let tone else { return nil }
        let prepared = privacyService.prepare(messageText)
        guard prepared.canProceed else { return nil }

        let element = sign.element.rawValue
        let subtextLines = AstrologyTemplates.decodeSubtext[element] ?? []
        let dontLines = AstrologyTemplates.decodeDontReadInto[element] ?? []
        guard !subtextLines.isEmpty, !dontLines.isEmpty else { return nil }

        let replies = AstrologyTemplates.suggestedReplies[sign.displayName] ?? []
        let bestNextMove = makeBestNextMove(sign: sign, tone: tone)
        let continuationSeed = [
            "Message read as \(tone.displayName) through \(sign.displayName).",
            "Best next move: \(bestNextMove.summary)",
            "Likely meaning: \(subtextLines[seed % subtextLines.count])"
        ].joined(separator: " ")

        return FirstReadDraft(
            messageText: prepared.redactedText.trimmingCharacters(in: .whitespacesAndNewlines),
            sign: sign,
            tone: tone,
            likelyMeaning: subtextLines[seed % subtextLines.count],
            notAssume: dontLines[seed % dontLines.count],
            suggestedReplies: Array(replies.prefix(3)),
            bestNextMove: bestNextMove,
            guideContinuationSeed: continuationSeed,
            safetyLevel: .ok,
            confidence: 72
        )
    }

    private func bestNextMoveCard(_ move: FirstReadBestNextMove, sign: ZodiacSign) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: move.type.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(sign.color)

                Text("BEST NEXT MOVE")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)

                Spacer()

                Text(move.type.title)
                    .font(SimastryFont.captionSmall.weight(.bold))
                    .foregroundStyle(SimastryColor.midnight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(SimastryGradient.gold, in: Capsule())
            }

            Text(move.summary)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let timingNote = move.timingNote {
                Text(timingNote)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: sign.color.opacity(0.7))
    }

    private func firstReadCard(title: String, icon: String, tint: Color, body: String) -> some View {
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

    private func replyCard(replies: [String]) -> some View {
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

            ForEach(Array(replies.enumerated()), id: \.offset) { index, reply in
                let displayedReply = tunedReply(for: reply, action: tunedReplies[index])

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(displayedReply)
                            .font(.system(.footnote, design: .serif))
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 6)

                        Button {
                            HapticManager.buttonPress()
                            UIPasteboard.general.string = displayedReply
                            viewModel.analytics.track(
                                .replyOptionCopied,
                                params: [
                                    "surface": "firstRead",
                                    "replyIndex": "\(index)",
                                    "tuneAction": tunedReplies[index]?.rawValue ?? "none"
                                ]
                            )
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(ReplyTuneAction.allCases) { action in
                                tuneButton(action, isActive: tunedReplies[index] == action) {
                                    if tunedReplies[index] == action {
                                        tunedReplies[index] = nil
                                    } else {
                                        tunedReplies[index] = action
                                        viewModel.analytics.track(
                                            .replyOptionTuned,
                                            params: [
                                                "surface": "firstRead",
                                                "replyIndex": "\(index)",
                                                "tuneAction": action.rawValue
                                            ]
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.6))
    }

    private func tuneButton(_ action: ReplyTuneAction, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.snappy)) {
                onTap()
            }
        } label: {
            Label(action.title, systemImage: action.systemImage)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(isActive ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.84))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    isActive ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.06)),
                    in: Capsule()
                )
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func feedbackCard(for draft: FirstReadDraft) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("TUNE YOUR GUIDES")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            Text("Was this helpful?")
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.offWhite)

            HStack(spacing: 8) {
                ForEach(HelpfulnessRating.allCases) { rating in
                    feedbackRatingButton(rating, draft: draft)
                }
            }

            if let feedbackRating, feedbackRating != .helpful {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(feedbackReasonOptions) { reason in
                            feedbackReasonButton(reason, draft: draft)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if feedbackRating != nil {
                Text("Saved for your guides.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.textTertiary)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.45))
        .animation(.spring(SimastrySpring.smooth), value: feedbackRating)
        .animation(.spring(SimastrySpring.smooth), value: feedbackReasons)
    }

    private var feedbackReasonOptions: [GuideFeedbackReason] {
        [.tooVague, .wrongTone, .notPractical, .tooIntense, .tooMystical, .replyDidntSoundLikeMe]
    }

    private func feedbackRatingButton(_ rating: HelpfulnessRating, draft: FirstReadDraft) -> some View {
        let isActive = feedbackRating == rating
        return Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.snappy)) {
                feedbackRating = rating
                if rating == .helpful {
                    feedbackReasons = []
                }
                submitFeedback(for: draft)
            }
        } label: {
            Text(rating.title)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(isActive ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isActive ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.06)),
                    in: Capsule()
                )
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func feedbackReasonButton(_ reason: GuideFeedbackReason, draft: FirstReadDraft) -> some View {
        let isActive = feedbackReasons.contains(reason)
        return Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.snappy)) {
                if isActive {
                    feedbackReasons.remove(reason)
                } else {
                    feedbackReasons.insert(reason)
                }
                submitFeedback(for: draft)
            }
        } label: {
            Text(reason.title)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(isActive ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.84))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    isActive ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.06)),
                    in: Capsule()
                )
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func submitFeedback(for draft: FirstReadDraft) {
        guard let feedbackRating else { return }
        viewModel.recordGuideFeedback(
            readId: draft.id,
            guideId: nil,
            surface: .firstRead,
            helpfulness: feedbackRating,
            reasons: Array(feedbackReasons).sorted { $0.rawValue < $1.rawValue }
        )
    }

    private func resetResultState() {
        decoded = false
        copiedReplyIndex = nil
        tunedReplies = [:]
        feedbackRating = nil
        feedbackReasons = []
    }

    private func makeBestNextMove(sign: ZodiacSign, tone: SimulationTone) -> FirstReadBestNextMove {
        switch tone {
        case .playful, .flirty:
            return FirstReadBestNextMove(
                type: .replyNow,
                summary: "Match the lightness, but keep one clear thread so the conversation has somewhere to land.",
                timingNote: "Send one warm reply now. Do not stack extra meaning onto a playful message."
            )
        case .warm:
            return FirstReadBestNextMove(
                type: .replyNow,
                summary: "Respond simply and warmly. Let the next message invite more, not prove more.",
                timingNote: "Now is fine if you want the thread to stay open."
            )
        case .confident:
            return FirstReadBestNextMove(
                type: sign.element == .fire ? .replyNow : .clarify,
                summary: "Answer the actual words and keep your self-respect in the center. If it feels unclear, ask one clean question.",
                timingNote: "One direct reply is stronger than several careful hints."
            )
        case .guarded, .distant, .cold:
            return FirstReadBestNextMove(
                type: .replyLater,
                summary: "Give the message a little room, then send one low-pressure check-in only if the connection still feels worth your energy.",
                timingNote: "Wait a few hours, or until tomorrow if you feel activated."
            )
        case .anxious:
            return FirstReadBestNextMove(
                type: .wait,
                summary: "Pause before replying. Regulate first, then choose the simplest message instead of answering the anxiety.",
                timingNote: "Wait at least 20 minutes and reread it once."
            )
        }
    }

    private func tunedReply(for reply: String, action: ReplyTuneAction?) -> String {
        guard let action else { return reply }
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        switch action {
        case .warmer:
            return "\(trimmed) I am glad you told me."
        case .moreDirect:
            return trimmed.hasSuffix("?") ? trimmed : "\(trimmed) What feels realistic for you?"
        case .shorter:
            let sentence = trimmed.split(separator: ".").first.map(String.init) ?? trimmed
            return sentence.count < trimmed.count ? "\(sentence)." : String(trimmed.prefix(96))
        case .lessIntense:
            return trimmed
                .replacingOccurrences(of: "really ", with: "")
                .replacingOccurrences(of: "definitely ", with: "")
                .replacingOccurrences(of: "always ", with: "")
        }
    }

    private func messageLengthBucket(_ text: String) -> String {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).count {
        case 0...40: "short"
        case 41...160: "medium"
        case 161...500: "long"
        default: "very_long"
        }
    }
}
