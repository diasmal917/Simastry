import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: AppViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var isLoading: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                SimastryShellBackground()

                Group {
                    switch viewModel.homeSetupPhase {
                    case .modeSelection:
                        ModeSelectionView(viewModel: viewModel)
                    case .signSelection:
                        SignSelectionView(viewModel: viewModel)
                    case .companionSetup:
                        CompanionSetupView(viewModel: viewModel)
                    case .soulCreation:
                        SoulCreationView(viewModel: viewModel)
                    case .complete:
                        homeContent
                    }
                }
                .animation(.spring(SimastrySpring.smooth), value: viewModel.homeSetupPhase == .complete)
            }
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 16)

                greetingSection

                if !viewModel.companions.isEmpty {
                    CompanionHeroDeckView(
                        companions: viewModel.companions,
                        onPredict: { companion in
                            viewModel.startPrediction(for: companion)
                        },
                        onOpenCompanions: {
                            viewModel.selectedTab = AppTab.companions.rawValue
                        }
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                }

                predictReplyCard

                if let companion = viewModel.primaryCompanion,
                   let companionSign = ZodiacSign(rawValue: companion.sunSign) {
                    communicationFocusCard(companionName: companion.name, companionSign: companionSign)
                }

                featureGrid

                if let companion = viewModel.primaryCompanion {
                    companionCard(companion)
                }

                if let sun = viewModel.userSunSign {
                    todayEnergyCard(sun: sun)
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, 20)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.spring(SimastrySpring.smooth).delay(0.05)) {
                        appeared = true
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .overlay {
            if isLoading {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 16)

                        // Greeting skeleton
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(SimastryColor.surface)
                                    .frame(width: 100, height: 14)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(SimastryColor.surface)
                                    .frame(width: 180, height: 26)
                            }
                            Spacer()
                            Circle()
                                .fill(SimastryColor.surface)
                                .frame(width: 48, height: 48)
                        }

                        // Predict card skeleton
                        RoundedRectangle(cornerRadius: 22)
                            .fill(SimastryColor.surface)
                            .frame(height: 120)

                        // Communication card skeleton
                        RoundedRectangle(cornerRadius: 22)
                            .fill(SimastryColor.surface)
                            .frame(height: 140)

                        // Grid skeleton
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(SimastryColor.surface)
                                    .frame(height: 110)
                            }
                        }

                        // Companion skeleton
                        RoundedRectangle(cornerRadius: 20)
                            .fill(SimastryColor.surface)
                            .frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                    .skeletonShimmer()
                }
                .scrollIndicators(.hidden)
                .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.3)) {
                isLoading = false
            }
        }
    }

    private var greetingSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingText)
                    .font(.system(size: 14))
                    .foregroundStyle(SimastryColor.mutedSilver)

                if let name = viewModel.profile?.displayName {
                    Text("Hey, \(name)")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)
                } else {
                    Text("Welcome back")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)
                }
            }

            Spacer()

            if let sun = viewModel.userSunSign {
                Text(sun.glyph)
                    .font(.system(size: 28))
                    .foregroundStyle(sun.color)
                    .frame(width: 48, height: 48)
                    .background(sun.color.opacity(0.14), in: Circle())
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    private func communicationFocusCard(companionName: String, companionSign: ZodiacSign) -> some View {
        let guide = CommunicationTemplates.guides[companionSign]
        let tips = guide?.tips ?? []
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let tipIndex = (dayOfYear - 1) % max(tips.count, 1)
        let todayTip = tips.isEmpty ? "Learn their sign to communicate better." : tips[tipIndex]

        return Button {
            HapticManager.buttonPress()
            viewModel.guideFocusSign = companionSign
            viewModel.selectedTab = 3
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SimastryColor.celestialBlue)

                    Text("Today with \(companionName)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)

                    Spacer()

                    Text(companionSign.glyph)
                        .font(.system(size: 18))
                        .foregroundStyle(companionSign.color)
                }

                Text(todayTip)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                if let approach = guide?.bestApproach {
                    Text(approach)
                        .font(.system(size: 13))
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text("Read full guide")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SimastryColor.celestialBlue)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SimastryColor.celestialBlue)
                }
                .padding(.top, 2)
            }
            .padding(20)
            .tintedGlass(SimastryColor.celestialBlue.opacity(0.12), cornerRadius: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(SimastryColor.celestialBlue.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Today with \(companionName). \(todayTip)")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var predictReplyCard: some View {
        Button {
            HapticManager.buttonPress()
            if let companion = viewModel.primaryCompanion {
                viewModel.startPrediction(for: companion)
            } else {
                viewModel.selectedTab = 2
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SimastryColor.risingViolet)

                        Text("PREDICT REPLY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(SimastryColor.risingViolet)
                            .tracking(1.2)
                    }

                    Text(viewModel.primaryCompanion.map { "What will \($0.name) say next?" } ?? "What will they say next?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(viewModel.primaryCompanion == nil ? "Paste a conversation and let the stars predict their next text." : "Paste the thread. Their signs are already loaded.")
                        .font(.system(size: 13))
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(SimastryColor.risingViolet)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(20)
            .tintedGlass(SimastryColor.risingViolet.opacity(0.14), cornerRadius: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(SimastryColor.risingViolet.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Predict their reply. Paste a conversation and let the stars predict their next text.")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var featureGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            featureGridCard(
                title: "Guides",
                subtitle: "What to say",
                systemImage: "bubble.left.and.bubble.right.fill",
                tint: SimastryColor.celestialBlue
            ) {
                viewModel.selectedTab = 3
            }

            featureGridCard(
                title: "Simulate",
                subtitle: "Test a reply",
                systemImage: "wand.and.stars",
                tint: SimastryColor.risingViolet
            ) {
                viewModel.selectedTab = 2
            }

            featureGridCard(
                title: "Soulmate",
                subtitle: "Find your match",
                systemImage: "heart.circle.fill",
                tint: SimastryColor.sunCoral
            ) {
                viewModel.selectedTab = 0
                viewModel.homeSetupPhase = .modeSelection
            }

            featureGridCard(
                title: "Companions",
                subtitle: "Your circle",
                systemImage: "sparkles",
                tint: SimastryColor.gold
            ) {
                viewModel.selectedTab = 1
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private func featureGridCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 12))

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .simastryGlass(cornerRadius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(tint.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(title). \(subtitle)")
    }

    private func companionCard(_ companion: CompanionData) -> some View {
        let level = RelationshipLevel.from(messageCount: companion.conversationCount)

        return Button {
            HapticManager.buttonPress()
            viewModel.selectedTab = 1
        } label: {
            HStack(spacing: 14) {
                GlossyOrbView(
                    signColors: [
                        ZodiacSign(rawValue: companion.sunSign)?.color ?? SimastryColor.gold,
                        ZodiacSign(rawValue: companion.moonSign)?.color ?? SimastryColor.celestialBlue
                    ],
                    state: .idle,
                    size: 50
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(companion.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)

                    HStack(spacing: 6) {
                        Text(level.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SimastryColor.midnight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(SimastryColor.gold, in: .capsule)

                        Text("\(companion.conversationCount) sparks")
                            .font(.system(size: 12))
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(companion.compatibilityScore)%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                    Text("match")
                        .font(.system(size: 10))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .padding(18)
            .simastryGlass(cornerRadius: 20)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(companion.name), \(level.name) bond, \(companion.compatibilityScore) percent match")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private func todayEnergyCard(sun: ZodiacSign) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                CelestialRoleIcon(role: .sun, size: 28)
                Text("Your Energy Today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)
                Spacer()
            }

            Text(AstrologyTemplates.sunSign[sun.rawValue] ?? "")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                .lineSpacing(3)
        }
        .padding(18)
        .simastryGlass(cornerRadius: 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }
}

struct CompanionHeroDeckView: View {
    let companions: [CompanionData]
    let onPredict: (CompanionData) -> Void
    let onOpenCompanions: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeIndex = 0
    @State private var autoRotateTask: Task<Void, Never>?

    private var activeCompanion: CompanionData? {
        guard companions.indices.contains(activeIndex) else { return companions.first }
        return companions[activeIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let activeCompanion {
                heroCopy(for: activeCompanion)
            }

            ZStack {
                ForEach(Array(companions.prefix(6).enumerated()), id: \.element.id) { index, companion in
                    EditorialCompanionCard(
                        companion: companion,
                        isActive: index == activeIndex,
                        rank: rank(for: index)
                    ) {
                        if index == activeIndex {
                            onPredict(companion)
                        } else {
                            setActive(index)
                        }
                    }
                    .zIndex(Double(10 - rank(for: index)))
                    .offset(x: cardOffset(for: index), y: cardLift(for: index))
                    .scaleEffect(cardScale(for: index))
                    .opacity(cardOpacity(for: index))
                }
            }
            .frame(height: 274)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        if value.translation.width < -24 {
                            advance()
                        } else if value.translation.width > 24 {
                            retreat()
                        }
                    }
            )

            HStack(spacing: 10) {
                Button {
                    retreat()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(SpringPressStyle())
                .liquidGlassSurface(cornerRadius: 19, tint: SimastryColor.gold.opacity(0.06), interactive: true)

                Button {
                    advance()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(SpringPressStyle())
                .liquidGlassSurface(cornerRadius: 19, tint: SimastryColor.gold.opacity(0.06), interactive: true)

                Spacer()

                Button {
                    onOpenCompanions()
                } label: {
                    Text("\(min(activeIndex + 1, companions.count)) / \(companions.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SimastryColor.gold)
                        .tracking(1.4)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                }
                .buttonStyle(SpringPressStyle())
                .liquidGlassSurface(cornerRadius: 19, tint: SimastryColor.gold.opacity(0.05), interactive: true)
            }
            .foregroundStyle(SimastryColor.cream)
        }
        .padding(18)
        .background {
            if let activeCompanion,
               let sign = ZodiacSign(rawValue: activeCompanion.sunSign) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                sign.color.opacity(0.32),
                                SimastryColor.plum.opacity(0.16),
                                Color.black.opacity(0.12)
                            ],
                            center: .topTrailing,
                            startRadius: 20,
                            endRadius: 360
                        )
                    )
            }
        }
        .editorialGlassCard(cornerRadius: 30)
        .onAppear {
            startAutoRotate()
        }
        .onDisappear {
            autoRotateTask?.cancel()
        }
        .onChange(of: companions.map(\.id)) { _, _ in
            activeIndex = min(activeIndex, max(companions.count - 1, 0))
            startAutoRotate()
        }
    }

    private func heroCopy(for companion: CompanionData) -> some View {
        let sign = ZodiacSign(rawValue: companion.sunSign)
        let level = RelationshipLevel.from(messageCount: companion.conversationCount)

        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CURRENT COMPANION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(2.2)

                Text(companion.name)
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundStyle(SimastryColor.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("\(sign?.displayName ?? companion.sunSign.capitalized) \(level.name.lowercased()) orbit • \(companion.conversationCount) sparks")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            Spacer()

            Text(sign?.glyph ?? "✦")
                .font(.system(size: 36))
                .foregroundStyle(sign?.color ?? SimastryColor.gold)
                .frame(width: 58, height: 58)
                .background((sign?.color ?? SimastryColor.gold).opacity(0.14), in: Circle())
        }
    }

    private func rank(for index: Int) -> Int {
        guard !companions.isEmpty else { return 0 }
        return (index - activeIndex + companions.count) % companions.count
    }

    private func cardOffset(for index: Int) -> CGFloat {
        switch rank(for: index) {
        case 0: return -52
        case 1: return 44
        case 2: return 126
        case 3: return 198
        default: return 254
        }
    }

    private func cardLift(for index: Int) -> CGFloat {
        rank(for: index) == 0 ? 0 : 12
    }

    private func cardScale(for index: Int) -> CGFloat {
        switch rank(for: index) {
        case 0: return 1
        case 1: return 0.94
        case 2: return 0.88
        default: return 0.82
        }
    }

    private func cardOpacity(for index: Int) -> Double {
        rank(for: index) > 3 ? 0 : 1
    }

    private func setActive(_ index: Int) {
        guard companions.indices.contains(index) else { return }
        withAnimation(.spring(SimastrySpring.smooth)) {
            activeIndex = index
        }
        HapticManager.buttonPress()
    }

    private func advance() {
        guard !companions.isEmpty else { return }
        setActive((activeIndex + 1) % companions.count)
    }

    private func retreat() {
        guard !companions.isEmpty else { return }
        setActive((activeIndex - 1 + companions.count) % companions.count)
    }

    private func startAutoRotate() {
        autoRotateTask?.cancel()
        guard !reduceMotion, companions.count > 1 else { return }

        autoRotateTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.8))
                if Task.isCancelled { return }
                await MainActor.run {
                    withAnimation(.spring(SimastrySpring.drift)) {
                        activeIndex = (activeIndex + 1) % companions.count
                    }
                }
            }
        }
    }
}

struct EditorialCompanionCard: View {
    let companion: CompanionData
    let isActive: Bool
    let rank: Int
    let action: () -> Void

    var body: some View {
        let sign = ZodiacSign(rawValue: companion.sunSign)
        let accent = sign?.color ?? SimastryColor.gold

        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.42),
                                SimastryColor.espresso.opacity(0.94),
                                SimastryColor.ink
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )

                Circle()
                    .fill(accent.opacity(0.26))
                    .blur(radius: 28)
                    .offset(x: 56, y: -76)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(sign?.glyph ?? "✦")
                            .font(.system(size: 27))
                            .foregroundStyle(accent)
                        Spacer()
                    }

                    Spacer()

                    Text(isActive ? "UP NEXT" : companion.mode.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SimastryColor.smoke)
                        .tracking(1.6)

                    Text(companion.name)
                        .font(.system(size: isActive ? 30 : 24, weight: .semibold, design: .serif))
                        .foregroundStyle(SimastryColor.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(sign?.displayName ?? companion.sunSign.capitalized)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SimastryColor.gold)
                        .tracking(1.4)
                }
                .padding(18)
            }
            .frame(width: isActive ? 190 : 166, height: isActive ? 246 : 226)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(isActive ? accent.opacity(0.55) : .white.opacity(0.10), lineWidth: 1)
            }
            .brightness(rank == 0 ? 0 : -0.10 * Double(rank))
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(companion.name), \(sign?.displayName ?? companion.sunSign) companion")
    }
}
