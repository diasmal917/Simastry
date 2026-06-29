import SwiftUI

// MARK: - Guide Profile
// The Instagram pattern: tap any guide face anywhere → this profile →
// Message. Promoted from the old directory "gram" segment to THE canonical
// guide destination — portrait, bio, credentials, post grid, one primary
// Message action that opens a real thread.

/// Directory copy keyed by guide id — shared by the profile page and any
/// surface that needs a guide's credentials.
nonisolated enum GuideDirectoryCopy {
    static func qualification(for profile: FactoryCompanionProfile) -> String {
        switch profile.id {
        case "aries-amara":
            "Verified for conflict openings, fast-response timing, and keeping directness attractive instead of reactive."
        case "aries-cassian":
            "Qualified in bold first moves, post-conflict repair, and reading when momentum is courage versus pressure."
        case "taurus-ada":
            "Verified for comfort-based attachment cues, pacing, and messages that make reliability feel desirable."
        case "taurus-theo":
            "Qualified in consistency checks, proof-through-action patterns, and practical wording for slow-building trust."
        case "gemini-rina":
            "Verified for banter analysis, mixed-signal decoding, and finding the one question that reopens a stalled chat."
        case "gemini-arden":
            "Qualified in light-touch repair, playful deflection reads, and keeping curiosity alive without dodging the point."
        case "cancer-mila":
            "Verified for emotional safety patterns, reassurance timing, and separating tenderness from overreaching."
        case "cancer-noel":
            "Qualified in quiet repair, protective silence, and reading what someone is guarding before they explain it."
        case "leo-leona":
            "Verified for confidence coaching, attention dynamics, and helping you answer from dignity rather than performance."
        case "leo-dante":
            "Qualified in warm leadership, expressive timing, and making bold communication land without sounding loud."
        case "virgo-mara":
            "Verified for message editing, precision under stress, and turning emotional clutter into one useful sentence."
        case "virgo-jonah":
            "Qualified in pattern naming, careful accountability, and specifics that prove care without creating a trial."
        case "libra-isolde":
            "Verified for fairness, tone balance, and graceful boundaries that stay charming without becoming vague."
        case "libra-mateo":
            "Qualified in diplomacy, romantic pacing, and phrasing that keeps the conversation open without self-erasure."
        case "scorpio-vera":
            "Verified for intensity control, motive reads, and saying the truth without giving away emotional power."
        case "scorpio-elias":
            "Qualified in hidden-pressure patterns, restraint, and replies that protect your center during charged moments."
        case "sagittarius-nadia":
            "Verified for honesty, space, and timing; especially useful when truth is needed but emotional pressure is rising."
        case "sagittarius-rafi":
            "Qualified in direct truth, distance dynamics, and turning bluntness into clean air instead of a bruise."
        case "capricorn-naomi":
            "Verified for standards, mature restraint, and helping you communicate scarcity without sounding cold."
        case "capricorn-silas":
            "Qualified in long-game strategy, dry timing, and knowing when no reply is the clearest reply."
        case "aquarius-imani":
            "Verified for autonomy, cool-distance reads, and sounding interested without sacrificing independence."
        case "aquarius-yarrow":
            "Qualified in freedom-first connection, unusual warmth, and keeping pressure out of emotionally complex chats."
        case "pisces-liora":
            "Verified for compassion, boundary softness, and reading the feeling underneath the sentence without dissolving."
        case "pisces-zev":
            "Qualified in gentle replies, creative distance, and translating emotion into something another person can hold."
        default:
            "Verified by Simastry's method layer for chart-signals, communication context, and privacy-safe message guidance."
        }
    }

    static func specialty(for profile: FactoryCompanionProfile) -> String {
        switch profile.id {
        case "aries-amara": "Fast replies, clean desire, and when to stop waiting."
        case "aries-cassian": "Bold first moves, conflict resets, and chemistry with momentum."
        case "taurus-ada": "Slow replies, mixed signals, and emotional steadiness."
        case "taurus-theo": "Proof, patience, and wording that makes reliability attractive."
        case "gemini-rina": "Banter, mixed signals, and the question that opens the room."
        case "gemini-arden": "Playful deflection, clever pauses, and keeping heaviness light."
        case "cancer-mila": "Tender subtext, reassurance, and answering without overreaching."
        case "cancer-noel": "Quiet repair, emotional safety, and what silence may protect."
        case "leo-leona": "Dignity, attention, and texting from the part of you that knows its worth."
        case "leo-dante": "Warm confidence, generous timing, and making boldness land softly."
        case "virgo-mara": "Precise edits, useful honesty, and turning mess into one clean sentence."
        case "virgo-jonah": "Pattern naming, careful repair, and specifics that prove care."
        case "libra-isolde": "Tone, fairness, and graceful boundaries that still have a spine."
        case "libra-mateo": "Diplomacy, romantic pacing, and phrasing that keeps the room open."
        case "scorpio-vera": "Emotional power, restraint, and truths that do not leak control."
        case "scorpio-elias": "Charged conversations, uncertainty, and emotional truth."
        case "sagittarius-nadia": "Honesty, space, timing, and desire without emotional claustrophobia."
        case "sagittarius-rafi": "Direct truth, adventure energy, and saying the thing without making it heavy."
        case "capricorn-naomi": "Mature restraint, standards, and messages that do not chase."
        case "capricorn-silas": "Long-game strategy, dry timing, and knowing when silence is the move."
        case "aquarius-imani": "Autonomy, cool distance, and sounding interested without sounding needy."
        case "aquarius-yarrow": "Freedom, odd warmth, and keeping connection alive without pressure."
        case "pisces-liora": "Compassion, boundaries, and the feeling underneath the sentence."
        case "pisces-zev": "Soft replies, artistic distance, and emotions another person can hold."
        default: "\(profile.sign.displayName) communication timing, tone, and relationship context."
        }
    }

    /// One line on why this guide matters for *this* user's chart.
    static func relevance(
        for profile: FactoryCompanionProfile,
        userSun: ZodiacSign?,
        userMoon: ZodiacSign?,
        userRising: ZodiacSign?
    ) -> String? {
        guard let sun = userSun else { return nil }

        if profile.sign == sun {
            return "Shares your \(sun.displayName) Sun — reads your first instinct from the inside."
        }
        if let moon = userMoon, profile.sign == moon {
            return "Matches your \(moon.displayName) Moon — tuned to how you actually feel before you reply."
        }
        if let rising = userRising, profile.sign == rising {
            return "Matches your \(rising.displayName) Rising — fluent in the tone you open with."
        }

        let compatiblePairs: Set<Set<ZodiacElement>> = [[.fire, .air], [.earth, .water]]
        if profile.sign.element == sun.element {
            return "Same \(profile.sign.element.rawValue) element as your Sun — an instinctive common language."
        }
        if compatiblePairs.contains([profile.sign.element, sun.element]) {
            return "\(profile.sign.displayName) complements your \(sun.displayName) Sun — adds what your style reaches for."
        }
        return "A counterpoint to your \(sun.displayName) Sun — strongest when you need a different lens."
    }
}

struct GuideProfileView: View {
    @Bindable var viewModel: AppViewModel
    let profile: FactoryCompanionProfile

    @State private var selectedGramPost: GramPostSelection?
    @State private var calibratingProfile: FactoryCompanionProfile?
    @State private var calibrationRefreshID = UUID()
    @State private var gramComments: [String: [String]] = [:]

    private var posts: [String] {
        profile.gridImageNames
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    profileHeader
                    statsRow
                    bioBlock
                    actionRow
                    credentialBlock
                    postGrid
                    Spacer().frame(height: SimastrySpacing.tabBarEndClearance)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("@\(profile.handle)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $selectedGramPost) { post in
            let comments = Binding<[String]>(
                get: { gramComments[post.id] ?? GuideGramStore.seededComments },
                set: {
                    gramComments[post.id] = $0
                    GuideGramStore.persist(gramComments)
                }
            )
            GramPostDetailSheet(
                profile: post.profile,
                imageName: post.imageName,
                caption: GuideGramStore.caption(for: post.profile, index: post.index),
                comments: comments,
                onMessage: {
                    selectedGramPost = nil
                    viewModel.startGuideChat(post.profile)
                },
                onCalibrate: {
                    selectedGramPost = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        calibratingProfile = post.profile
                    }
                }
            )
        }
        .sheet(item: $calibratingProfile) { profile in
            GuideCalibrationSheet(viewModel: viewModel, profile: profile) {
                calibrationRefreshID = UUID()
            }
        }
        .onAppear {
            if gramComments.isEmpty {
                gramComments = GuideGramStore.load()
            }
        }
    }

    private var profileHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(profile.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 86, height: 86, alignment: .top)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(SimastryGradient.gold, lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(profile.name)
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("AI")
                        .font(SimastryFont.captionSmall.weight(.semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.07), in: Capsule())
                }

                Text("\(profile.sign.displayName) Guide · Simastry Method")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.gold)

                Text(profile.metadataLine)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)

                HStack(spacing: 5) {
                    Image(systemName: SimastryIcon.timing)
                        .font(SimastryFont.microSemibold)
                        .foregroundStyle(SimastryColor.gold)
                    Text("Always available · replies instantly")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }

            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat(value: "\(posts.count)", label: "posts")
            stat(value: profile.sign.displayName, label: "lens")
            stat(value: profile.sign.element.rawValue.capitalized, label: "element")
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(SimastryFont.metricSmall)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var bioBlock: some View {
        let calibration = GuideCalibrationStore.shared.calibration(for: profile.id)

        return VStack(alignment: .leading, spacing: 6) {
            Text(profile.headline)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)

            Text(profile.personalityBio)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if !calibration.isDefault {
                calibratedBadge(summary: calibration.displaySummary)
                    .padding(.top, 4)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            profileAction("Message", systemImage: SimastryIcon.message, isPrimary: true) {
                viewModel.startGuideChat(profile)
            }

            profileAction("Calibrate", systemImage: "slider.horizontal.3", isPrimary: false) {
                calibratingProfile = profile
            }
        }
    }

    private func profileAction(_ label: String, systemImage: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            Label(label, systemImage: systemImage)
                .font(SimastryFont.labelLarge)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(isPrimary ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isPrimary ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.06)), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(isPrimary ? .white.opacity(0.18) : .white.opacity(0.10), lineWidth: 0.7)
                }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(isPrimary ? "Message \(profile.name)" : "\(label) with \(profile.name)")
    }

    private var credentialBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: SimastryIcon.method)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.goldLight)

                Text("SIMASTRY METHOD")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.goldLight)
                    .tracking(1.3)

                Text(profile.sign.methodLine)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            credentialRow(label: "Best for", text: GuideDirectoryCopy.specialty(for: profile), tint: profile.sign.color)

            if let relevance = GuideDirectoryCopy.relevance(
                for: profile,
                userSun: viewModel.userSunSign,
                userMoon: viewModel.userMoonSign,
                userRising: viewModel.userRisingSign
            ) {
                credentialRow(label: "For you", text: relevance, tint: SimastryColor.gold)
            }

            Text(GuideDirectoryCopy.qualification(for: profile))
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SimastryColor.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(SimastryColor.gold.opacity(0.14), lineWidth: 0.6)
        }
    }

    private func credentialRow(label: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text(label)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(tint)
                .frame(width: 52, alignment: .leading)
                .padding(.top, 0.5)

            Text(text)
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var postGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(posts.enumerated()), id: \.element) { index, imageName in
                Button {
                    HapticManager.buttonPress()
                    selectedGramPost = GramPostSelection(profile: profile, imageName: imageName, index: index)
                } label: {
                    Rectangle()
                        .fill(Color.clear)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Post \(index + 1) by \(profile.name)")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func calibratedBadge(summary: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
                .font(SimastryFont.microSemibold)
            Text("Calibrated")
                .font(SimastryFont.labelSmall)
            Text(summary)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineLimit(1)
        }
        .foregroundStyle(SimastryColor.gold)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SimastryColor.gold.opacity(0.10), in: Capsule())
        .overlay {
            Capsule().strokeBorder(SimastryColor.gold.opacity(0.18), lineWidth: 0.7)
        }
    }
}

struct GuideCalibrationSheet: View {
    let viewModel: AppViewModel
    let profile: FactoryCompanionProfile
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var role: GuideCalibrationRole
    @State private var personalityType: MBTIPersonalityType?
    @State private var styleBalance: GuideCalibrationStyleBalance
    @State private var directness: GuideCalibrationDirectness
    @State private var detailLevel: GuideCalibrationDetailLevel
    @State private var selectedTopics: Set<String>
    @State private var customTopic: String = ""
    @State private var errorMessage: String?

    private var customTopics: [String] {
        let builtIns = Set(GuideCalibration.availableTopics.map { $0.lowercased() })
        return selectedTopics
            .filter { !builtIns.contains($0.lowercased()) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var displayedTopics: [String] {
        GuideCalibration.availableTopics + customTopics
    }

    init(viewModel: AppViewModel, profile: FactoryCompanionProfile, onSave: @escaping () -> Void) {
        self.viewModel = viewModel
        self.profile = profile
        self.onSave = onSave

        let saved = GuideCalibrationStore.shared.calibration(for: profile.id)
        _role = State(initialValue: saved.role)
        _personalityType = State(initialValue: saved.personalityType)
        _styleBalance = State(initialValue: saved.styleBalance ?? .balanced)
        _directness = State(initialValue: saved.directness ?? .balanced)
        _detailLevel = State(initialValue: saved.detailLevel ?? .balanced)
        _selectedTopics = State(initialValue: Set(saved.topics))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        lensSection
                        relationshipSection
                        styleSection
                        personalitySection
                        topicsSection
                    }
                    .padding(20)
                    .padding(.bottom, 22)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Calibrate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(SimastryColor.gold)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .tint(SimastryColor.gold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: role)
    }

    private var header: some View {
        HStack(spacing: 13) {
            Image(profile.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54, alignment: .top)
                .clipShape(Circle())
                .overlay(Circle().stroke(SimastryColor.gold.opacity(0.30), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("\(profile.sign.displayName) guide · tone and topics only")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            Spacer()
        }
        .padding(16)
        .glossyCard(cornerRadius: 20)
    }

    /// The transparency card formerly shown in the chat as "Why this chat" —
    /// now part of calibration, explaining the lens this guide reads you through.
    private var lensSection: some View {
        calibrationSection(title: "Why this guide", systemImage: "scope") {
            VStack(alignment: .leading, spacing: 10) {
                Text(GuideDirectoryCopy.specialty(for: profile))
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(lensSignals) { signal in
                            MethodSignalChip(signal: signal)
                        }
                    }
                }
            }
        }
    }

    private var lensSignals: [MethodSignal] {
        var signals: [MethodSignal] = [
            MethodSignal(
                label: "Companion lens",
                detail: "\(profile.sign.displayName) guide",
                systemImage: "scope",
                tint: profile.sign.color
            )
        ]
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
                detail: "Tone & topics only",
                systemImage: "lock.shield.fill",
                tint: SimastryColor.mutedSilver
            )
        )
        return signals
    }

    private var relationshipSection: some View {
        calibrationSection(title: "Relationship", systemImage: "person.2.fill") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(GuideCalibrationRole.allCases) { option in
                    calibrationChip(option.title, isActive: role == option) {
                        role = option
                    }
                }
            }
        }
    }

    private var personalitySection: some View {
        calibrationSection(title: "Personality type", systemImage: "brain.head.profile") {
            Picker("Personality type", selection: $personalityType) {
                Text("None").tag(MBTIPersonalityType?.none)
                ForEach(MBTIPersonalityType.allCases) { type in
                    Text(type.rawValue).tag(Optional(type))
                }
            }
            .pickerStyle(.menu)
            .tint(SimastryColor.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            Text("Optional. This shapes the guide's language without changing their zodiac lens.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
        }
    }

    private var styleSection: some View {
        calibrationSection(title: "Guide style", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Practical / mystical")
                        .font(SimastryFont.captionSmall.weight(.semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                        ForEach(GuideCalibrationStyleBalance.allCases) { option in
                            calibrationChip(option.title, isActive: styleBalance == option) {
                                styleBalance = option
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Gentle / direct")
                        .font(SimastryFont.captionSmall.weight(.semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                        ForEach(GuideCalibrationDirectness.allCases) { option in
                            calibrationChip(option.title, isActive: directness == option) {
                                directness = option
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Short / detailed")
                        .font(SimastryFont.captionSmall.weight(.semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                        ForEach(GuideCalibrationDetailLevel.allCases) { option in
                            calibrationChip(option.title, isActive: detailLevel == option) {
                                detailLevel = option
                            }
                        }
                    }
                }
            }
        }
    }

    private var topicsSection: some View {
        calibrationSection(title: "Topics", systemImage: "bubble.left.and.text.bubble.right.fill") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], spacing: 8) {
                ForEach(displayedTopics, id: \.self) { topic in
                    calibrationChip(topic, isActive: selectedTopics.contains(topic)) {
                        toggleTopic(topic)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Add your own topic", text: $customTopic)
                        .font(SimastryFont.bodyMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.055), in: Capsule())
                        .onChange(of: customTopic) {
                            if customTopic.count > 40 {
                                customTopic = String(customTopic.prefix(40))
                            }
                        }

                    Button {
                        addCustomTopic()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(SimastryColor.midnight)
                            .frame(width: 34, height: 34)
                            .background(SimastryColor.gold, in: Circle())
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityLabel("Add custom topic")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.sunCoral)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Custom topics stay on this device and must pass safety checks.")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.textTertiary)
                }
            }
        }
    }

    private func calibrationSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text(title.uppercased())
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    private func calibrationChip(_ title: String, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            HapticManager.buttonPress()
            onTap()
        } label: {
            Text(title)
                .font(SimastryFont.labelSmall)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isActive ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    isActive ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.06)),
                    in: Capsule()
                )
                .overlay {
                    Capsule().strokeBorder(
                        isActive ? .white.opacity(0.24) : .white.opacity(0.08),
                        lineWidth: 0.6
                    )
                }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func toggleTopic(_ topic: String) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
        } else {
            selectedTopics.insert(topic)
        }
        errorMessage = nil
    }

    private func addCustomTopic() {
        let trimmed = customTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = ContentModerationService.moderateCalibrationTopic(trimmed)
        guard result.isAllowed else {
            errorMessage = result.reason
            return
        }

        if selectedTopics.contains(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            customTopic = ""
            errorMessage = nil
            return
        }

        selectedTopics.insert(trimmed)
        customTopic = ""
        errorMessage = nil
        HapticManager.buttonPress()
    }

    private func save() {
        let builtIn = GuideCalibration.availableTopics.filter { selectedTopics.contains($0) }
        let custom = customTopics.filter { selectedTopics.contains($0) }
        let calibration = GuideCalibration(
            role: role,
            personalityType: personalityType,
            topics: builtIn + custom,
            updatedAt: Date(),
            styleBalance: styleBalance,
            directness: directness,
            detailLevel: detailLevel
        )

        GuideCalibrationStore.shared.save(calibration, for: profile.id)
        onSave()
        dismiss()
    }
}

// MARK: - Gram plumbing (shared with the post detail sheet)

struct GramPostSelection: Identifiable {
    let profile: FactoryCompanionProfile
    let imageName: String
    let index: Int

    var id: String {
        "\(profile.id)-post-\(index)"
    }
}

/// Captions, seeded comments, and the local persistence for guide posts.
nonisolated enum GuideGramStore {
    static let defaultsKey = "simastry_gram_comments"

    static func caption(for profile: FactoryCompanionProfile, index: Int) -> String {
        let captions = [
            "Reading tone through \(profile.sign.displayName) today: less performance, more signal.",
            "\(profile.sign.displayName) timing check: say it clearly, then let the reply breathe.",
            "Your message has a weather pattern. I am looking for the pressure point before the words.",
            "Chart logic first, charm second. Both matter.",
            "A small wording shift can change the whole room.",
            "The best reply is usually the one that keeps your dignity intact."
        ]
        return captions[index % captions.count]
    }

    static var seededComments: [String] {
        [
            "The signal is clear here.",
            "Saving this before I answer my next text."
        ]
    }

    static func load() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func persist(_ comments: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(comments) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

struct GramPostDetailSheet: View {
    let profile: FactoryCompanionProfile
    let imageName: String
    let caption: String
    @Binding var comments: [String]
    let onMessage: () -> Void
    let onCalibrate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var commentDraft: String = ""

    private var trimmedComment: String {
        commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 430)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(alignment: .topLeading) {
                                HStack(spacing: 8) {
                                    Image(profile.profileImageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 34, height: 34, alignment: .top)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(profile.name)
                                            .font(SimastryFont.labelLarge)
                                            .foregroundStyle(SimastryColor.offWhite)
                                        Text("@\(profile.handle)")
                                            .font(SimastryFont.captionSmall)
                                            .foregroundStyle(SimastryColor.mutedSilver)
                                    }
                                }
                                .padding(10)
                                .background(.black.opacity(0.42), in: Capsule())
                                .padding(12)
                            }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                ZodiacIconView(sign: profile.sign, size: 24, showsGlow: false)
                                Text("\(profile.sign.displayName) lens")
                                    .font(SimastryFont.overline)
                                    .foregroundStyle(SimastryColor.gold)
                                    .tracking(1.0)
                                    .textCase(.uppercase)
                            }

                            Text(caption)
                                .font(SimastryFont.bodyMedium)
                                .foregroundStyle(SimastryColor.offWhite)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 8) {
                                postAction("Message", systemImage: SimastryIcon.message, isPrimary: true) {
                                    dismiss()
                                    onMessage()
                                }
                                postAction("Calibrate", systemImage: "slider.horizontal.3", isPrimary: false) {
                                    dismiss()
                                    onCalibrate()
                                }
                            }
                            .padding(.top, 2)
                        }
                        .padding(16)
                        .glossyCard(cornerRadius: 20)

                        commentsSection
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.2)
                .textCase(.uppercase)

            ForEach(Array(comments.enumerated()), id: \.offset) { _, comment in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(SimastryColor.gold.opacity(0.20))
                        .frame(width: 26, height: 26)
                        .overlay {
                            Image(systemName: "sparkles")
                                .font(SimastryFont.microBold)
                                .foregroundStyle(SimastryColor.gold)
                        }

                    Text(comment)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 8) {
                TextField("Add a comment", text: $commentDraft)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.06), in: Capsule())
                    .onChange(of: commentDraft) {
                        if commentDraft.count > 180 {
                            commentDraft = String(commentDraft.prefix(180))
                        }
                    }

                Button {
                    addComment()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(trimmedComment.isEmpty ? SimastryColor.mutedSilver : SimastryColor.midnight)
                        .frame(width: 34, height: 34)
                        .background(trimmedComment.isEmpty ? Color.white.opacity(0.08) : SimastryColor.gold, in: Circle())
                }
                .disabled(trimmedComment.isEmpty)
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel("Add comment")
            }
        }
        .padding(16)
        .glossyCard(cornerRadius: 20)
    }

    private func postAction(_ label: String, systemImage: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            Label(label, systemImage: systemImage)
                .font(SimastryFont.labelMedium)
                .foregroundStyle(isPrimary ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(isPrimary ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.06)), in: Capsule())
        }
        .buttonStyle(SpringPressStyle())
    }

    private func addComment() {
        guard !trimmedComment.isEmpty else { return }
        comments.append(trimmedComment)
        commentDraft = ""
        HapticManager.buttonPress()
    }
}
