import SwiftUI

private enum AIAstrologistSegment: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case signs = "Signs"
    case gram = "Profile"

    var id: String { rawValue }
}

private struct GramPostSelection: Identifiable {
    let profile: FactoryCompanionProfile
    let imageName: String
    let index: Int

    var id: String {
        "\(profile.id)-post-\(index)"
    }
}

struct AIAstrologistsView: View {
    @Bindable var viewModel: AppViewModel
    let initialProfileId: String?
    @State private var currentCastIndex: Int
    @State private var selectedSegment: AIAstrologistSegment = .forYou
    @State private var hasInitializedCastIndex: Bool = false
    @State private var showPredict: Bool = false
    @State private var selectedGramPost: GramPostSelection?
    @State private var gramComments: [String: [String]] = [:]

    init(viewModel: AppViewModel, initialProfileId: String? = nil) {
        self.viewModel = viewModel
        self.initialProfileId = initialProfileId
        _currentCastIndex = State(initialValue: Self.initialCastIndex(initialProfileId: initialProfileId, viewModel: viewModel))
    }

    private var profiles: [FactoryCompanionProfile] {
        FactoryCompanionCatalog.all
    }

    private var profilesBySign: [ZodiacSign: [FactoryCompanionProfile]] {
        Dictionary(grouping: profiles, by: \.sign)
    }

    private var activeProfile: FactoryCompanionProfile {
        profiles[currentCastIndex % profiles.count]
    }

    private var communicationType: CommunicationTypeProfile? {
        CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    private var orderedForYouProfiles: [FactoryCompanionProfile] {
        let preferred = initialProfile ?? FactoryCompanionCatalog.match(for: viewModel.primaryCompanion)
        return [preferred] + profiles.filter { $0.id != preferred.id }
    }

    private var initialProfile: FactoryCompanionProfile? {
        guard let initialProfileId else { return nil }
        return profiles.first { $0.id == initialProfileId }
    }

    private static func initialCastIndex(initialProfileId: String?, viewModel: AppViewModel) -> Int {
        if let initialProfileId,
           let index = FactoryCompanionCatalog.all.firstIndex(where: { $0.id == initialProfileId }) {
            return index
        }
        let fallback = FactoryCompanionCatalog.match(for: viewModel.primaryCompanion)
        return FactoryCompanionCatalog.all.firstIndex(where: { $0.id == fallback.id }) ?? 0
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    segmentControl

                    switch selectedSegment {
                    case .forYou:
                        astrologerDirectory(orderedForYouProfiles)
                    case .signs:
                        signsDirectory
                    case .gram:
                        gramSection(activeProfile)
                    }

                    Spacer().frame(height: SimastrySpacing.tabBarClearance + 20)
                }
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("AI Astrologists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $showPredict) {
            SimulateView(viewModel: viewModel)
        }
        .sheet(item: $selectedGramPost) { post in
            let comments = Binding<[String]>(
                get: { gramComments[post.id] ?? seededComments(for: post.profile, index: post.index) },
                set: {
                    gramComments[post.id] = $0
                    Self.persistGramComments(gramComments)
                }
            )
            GramPostDetailSheet(
                profile: post.profile,
                imageName: post.imageName,
                caption: postCaption(for: post.profile, index: post.index),
                comments: comments,
                onMessage: {
                    viewModel.selectedTab = 2
                    selectedGramPost = nil
                },
                onPredict: {
                    selectedGramPost = nil
                    openPredict(with: post.profile)
                }
            )
        }
        .onAppear {
            if gramComments.isEmpty {
                gramComments = Self.loadGramComments()
            }
            guard !hasInitializedCastIndex else { return }
            selectLaunchProfile()
            hasInitializedCastIndex = true
        }
        .onChange(of: initialProfileId) {
            guard let initialProfile else { return }
            select(initialProfile)
            hasInitializedCastIndex = true
        }
    }

    static let gramCommentsDefaultsKey = "simastry_gram_comments"

    private static func loadGramComments() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: gramCommentsDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func persistGramComments(_ comments: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(comments) else { return }
        UserDefaults.standard.set(data, forKey: gramCommentsDefaultsKey)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Every guide is trained in the Simastry Method and reads through one zodiac lens.")
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            compactSignalStrip(signals: methodSignals(for: activeProfile))
        }
        .padding(.horizontal, 20)
    }

    private func compactSignalStrip(signals: [MethodSignal]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(signals) { signal in
                    compactSignalChip(signal)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }

    private func compactSignalChip(_ signal: MethodSignal) -> some View {
        HStack(spacing: 6) {
            Image(systemName: signal.systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(signal.tint)

            Text(compactSignalLabel(for: signal.label))
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)

            Text(signal.detail)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(SimastryColor.offWhite.opacity(0.92))
                .minimumScaleFactor(0.82)
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(signal.tint.opacity(0.075), in: Capsule())
        .overlay {
            Capsule()
                .stroke(signal.tint.opacity(0.16), lineWidth: 0.55)
        }
        .accessibilityElement(children: .combine)
    }

    private func compactSignalLabel(for label: String) -> String {
        switch label {
        case "Companion lens":
            return "Guide"
        case "Communication type":
            return "Type"
        case "Your Sun":
            return "Sun"
        case "Your Moon":
            return "Moon"
        default:
            return label
        }
    }

    private var segmentControl: some View {
        HStack(spacing: 8) {
            ForEach(AIAstrologistSegment.allCases) { segment in
                Button {
                    HapticManager.buttonPress()
                    withAnimation(.spring(SimastrySpring.smooth)) {
                        selectedSegment = segment
                    }
                } label: {
                    Text(segment.rawValue)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(selectedSegment == segment ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedSegment == segment ? SimastryGradient.gold : LinearGradient(colors: [.white.opacity(0.06), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), in: Capsule())
                }
                .buttonStyle(SpringPressStyle())
            }
        }
        .padding(5)
        .simastryGlassPill()
        .padding(.horizontal, 20)
    }

    private func astrologerDirectory(_ directoryProfiles: [FactoryCompanionProfile]) -> some View {
        LazyVStack(spacing: 14) {
            ForEach(directoryProfiles) { profile in
                astrologerDirectoryCard(profile)
            }
        }
        .padding(.horizontal, 16)
    }

    private func astrologerDirectoryCard(_ profile: FactoryCompanionProfile) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                Image(profile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 124, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [profile.sign.color.opacity(0.50), .white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: profile.sign.color.opacity(0.16), radius: 12, y: 6)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 7) {
                        Text(profile.name)
                            .font(SimastryFont.titleMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                            .lineLimit(1)

                        Text("AI")
                            .font(SimastryFont.captionSmall.weight(.semibold))
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.07), in: Capsule())

                        Spacer(minLength: 0)

                        ZodiacIconView(sign: profile.sign, size: 26, showsGlow: false)
                    }

                    Text("\(profile.sign.displayName) Guide")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(profile.sign.color)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Image(systemName: SimastryIcon.timing)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(SimastryColor.gold)
                        Text("Always available · replies instantly")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .lineLimit(1)

                    Text(profile.headline)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                        .lineSpacing(2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            credentialBlock(profile)

            HStack(spacing: 8) {
                astrologistAction("Message", systemImage: SimastryIcon.message, isPrimary: true) {
                    select(profile)
                    viewModel.selectedTab = 2
                }

                astrologistAction("Profile", systemImage: "person.crop.square", isPrimary: false) {
                    select(profile)
                    selectedSegment = .gram
                }

                astrologistAction("Predict", systemImage: SimastryIcon.predict, isPrimary: false) {
                    openPredict(with: profile)
                }
            }
        }
        .padding(14)
        .surfaceCard(cornerRadius: 24, accent: profile.sign.color.opacity(0.75))
        .onTapGesture {
            select(profile)
        }
    }

    private func credentialBlock(_ profile: FactoryCompanionProfile) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: SimastryIcon.method)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.goldLight)

                Text("SIMASTRY METHOD")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.goldLight)
                    .tracking(1.3)

                Text(methodLine(for: profile.sign))
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            credentialRow(label: "Best for", text: astrologistSpecialty(for: profile), tint: profile.sign.color)

            if let relevance = personalRelevance(for: profile) {
                credentialRow(label: "For you", text: relevance, tint: SimastryColor.gold)
            }

            Text(astrologistQualification(for: profile))
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

    /// Zodiac-lens specialization, in Simastry Method language.
    /// (Shared copy lives on ZodiacSign so the LLM persona prompts match.)
    private func methodLine(for sign: ZodiacSign) -> String {
        sign.methodLine
    }

    /// One line on why this guide matters for *this* user's chart.
    private func personalRelevance(for profile: FactoryCompanionProfile) -> String? {
        guard let sun = viewModel.userSunSign else { return nil }

        if profile.sign == sun {
            return "Shares your \(sun.displayName) Sun — reads your first instinct from the inside."
        }
        if let moon = viewModel.userMoonSign, profile.sign == moon {
            return "Matches your \(moon.displayName) Moon — tuned to how you actually feel before you reply."
        }
        if let rising = viewModel.userRisingSign, profile.sign == rising {
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

    private var signsDirectory: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        let groupedProfiles = profilesBySign

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ZodiacSign.allCases) { sign in
                let signProfiles = groupedProfiles[sign] ?? []
                Button {
                    if let first = signProfiles.first {
                        select(first)
                        selectedSegment = .forYou
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        ZodiacIconView(sign: sign, size: 38, showsGlow: false)

                        Text(sign.displayName)
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text(signProfiles.map(\.name).joined(separator: " + "))
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
                    .padding(14)
                    .surfaceCard(cornerRadius: 18, accent: sign.color.opacity(0.6))
                }
                .buttonStyle(SpringPressStyle())
            }
        }
        .padding(.horizontal, 20)
    }

    private func gramSection(_ profile: FactoryCompanionProfile) -> some View {
        let posts = Array(profile.gridImageNames.prefix(6))

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Image(profile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 82, height: 82, alignment: .top)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(SimastryGradient.gold, lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.name)
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("@\(profile.handle)")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                    Text("\(profile.sign.displayName) Guide · Simastry Method")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.gold)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                gramStat(value: "\(posts.count)", label: "posts")
                gramStat(value: "24", label: "guides")
                gramStat(value: profile.sign.displayName, label: "lens")
            }

            Text(profile.bio)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                astrologistAction("Message", systemImage: SimastryIcon.message, isPrimary: true) {
                    viewModel.selectedTab = 2
                }
                astrologistAction("Predict", systemImage: SimastryIcon.predict, isPrimary: false) {
                    openPredict(with: profile)
                }
            }

            gramGrid(profile, posts)
        }
        .padding(18)
        .surfaceCard(cornerRadius: 24)
        .padding(.horizontal, 20)
    }

    private func astrologistAction(_ label: String, systemImage: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.smooth)) {
                action()
            }
        } label: {
            Label(label, systemImage: systemImage)
                .font(SimastryFont.labelSmall)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(isPrimary ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isPrimary ? SimastryGradient.gold : LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(isPrimary ? .white.opacity(0.18) : .white.opacity(0.10), lineWidth: 0.7)
                }
        }
        .buttonStyle(SpringPressStyle())
    }

    private func gramStat(value: String, label: String) -> some View {
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
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func gramGrid(_ profile: FactoryCompanionProfile, _ imageNames: [String]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(imageNames.enumerated()), id: \.element) { index, imageName in
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
                .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func postCaption(for profile: FactoryCompanionProfile, index: Int) -> String {
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

    private func seededComments(for profile: FactoryCompanionProfile, index: Int) -> [String] {
        [
            "The signal is clear here.",
            "Saving this before I answer my next text."
        ]
    }

    private func methodSignals(for profile: FactoryCompanionProfile) -> [MethodSignal] {
        var signals: [MethodSignal] = [
            MethodSignal(label: "Companion lens", detail: profile.sign.displayName, systemImage: "scope", tint: profile.sign.color)
        ]

        if let typeSignal = CommunicationTypeProfile.methodSignal(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        ) {
            signals.append(typeSignal)
        }

        if let sun = viewModel.userSunSign {
            signals.append(MethodSignal(label: "Your Sun", detail: sun.displayName, systemImage: "sun.max.fill", tint: SimastryColor.sunCoral))
        }
        if let moon = viewModel.userMoonSign {
            signals.append(MethodSignal(label: "Your Moon", detail: moon.displayName, systemImage: "moon.stars.fill", tint: SimastryColor.celestialBlue))
        }

        return signals
    }

    private func astrologistQualification(for profile: FactoryCompanionProfile) -> String {
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

    private func astrologistSpecialty(for profile: FactoryCompanionProfile) -> String {
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

    private func select(_ profile: FactoryCompanionProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            currentCastIndex = index
        }
    }

    private func selectLaunchProfile() {
        select(initialProfile ?? FactoryCompanionCatalog.match(for: viewModel.primaryCompanion))
    }

    private func openPredict(with profile: FactoryCompanionProfile) {
        select(profile)
        viewModel.predictionDraft = PredictionDraft(
            targetName: profile.name,
            targetSunSign: profile.sign,
            question: "What would \(profile.name) notice in this conversation?",
            conversationText: nil
        )
        showPredict = true
    }
}

private struct GramPostDetailSheet: View {
    let profile: FactoryCompanionProfile
    let imageName: String
    let caption: String
    @Binding var comments: [String]
    let onMessage: () -> Void
    let onPredict: () -> Void

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
                                postAction("Predict", systemImage: SimastryIcon.predict, isPrimary: false) {
                                    dismiss()
                                    onPredict()
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
            .navigationTitle("Profile")
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
                                .font(.system(size: 10, weight: .bold))
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
                .background(isPrimary ? SimastryGradient.gold : LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
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
