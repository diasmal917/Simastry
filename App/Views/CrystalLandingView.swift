import SwiftUI

/// The crystal-ball landing: a short four-page onboarding modeled on the
/// reference video — moody mesh background, a living crystal-ball hero with
/// the five experts orbiting it, live feature previews, glass chips, and a
/// solid-white pill CTA. The cinematic collage landing remains intact behind
/// `AppConfig.landingUsesCrystalOnboarding` (flip to restore).
struct CrystalLandingView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page: Int = CrystalLandingView.initialPage()
    @State private var appeared = false

    // Council page caption cycling (sequential fade — never double-exposed).
    @State private var councilIndex = 0
    @State private var councilOpacity: Double = 1
    @State private var councilTimer: Timer?

    private let pageCount = 4
    private let specialists = ExpertAstrologerRegistry.specialists

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 760

            ZStack {
                MoodMeshBackground()

                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        welcomePage(compact: compact).tag(0)
                        commGuidePage(compact: compact).tag(1)
                        simulateDemoPage(compact: compact).tag(2)
                        councilPage(compact: compact).tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    chrome
                }
            }
        }
        .preferredColorScheme(.dark)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.01 : 0.45)) { appeared = true }
        }
        .onChange(of: page) { _, newPage in
            if newPage == 3 { startCouncilCycle() } else { stopCouncilCycle() }
        }
        .onDisappear { stopCouncilCycle() }
        // No container-level accessibilityIdentifier here: it would propagate
        // onto every child and stomp the cta/back/page identifiers.
    }

    // MARK: - Page 1 · Welcome

    private func welcomePage(compact: Bool) -> some View {
        VStack(spacing: 0) {
            SimastryWordmark(font: .system(size: compact ? 17 : 19, weight: .bold).italic())
                .padding(.top, compact ? 6 : 12)

            Text("Know what to say.\nTo anyone.")
                .font(.system(size: compact ? 29 : 33, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, compact ? 8 : 12)

            Text("Five real astrologers read the people in your life — privately.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            CrystalBallView(diameter: compact ? 196 : 224)
                .padding(.top, compact ? 0 : 4)

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 10) {
                featureChip(icon: "lock.fill", text: "Your chart stays yours")
                featureChip(icon: "sparkles", text: "Five real traditions, kept separate")
                featureChip(icon: "sun.max.fill", text: "One honest note each morning")
            }
            .padding(.top, compact ? 6 : 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("landing.crystal.page.0")
    }

    private func featureChip(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CrystalMood.gold)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .landingGlassCapsule()
    }

    // MARK: - Page 2 · The council

    private func councilPage(compact: Bool) -> some View {
        let selected = specialists[min(councilIndex, specialists.count - 1)]

        return VStack(spacing: 0) {
            pageTitle("Ask once.\nFive traditions answer.", compact: compact)

            Text("Each expert answers only from their own school — never blended.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 8)

            // Shallow arc of the five, the spoken-for expert lifted and lit.
            HStack(alignment: .top, spacing: 13) {
                ForEach(Array(specialists.enumerated()), id: \.element.id) { index, specialist in
                    councilAvatar(specialist, isSelected: index == councilIndex)
                        .offset(y: [16, 5, 0, 5, 16][index])
                        .onTapGesture {
                            HapticManager.buttonPress()
                            swapCouncilSelection(to: index)
                        }
                }
            }
            .padding(.top, compact ? 26 : 44)

            VStack(spacing: 5) {
                Text("\(selected.characterName) · \(selected.publicTitle)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Text(selected.publicDescription)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(councilOpacity)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .landingGlass(cornerRadius: 22)
            .padding(.top, compact ? 22 : 34)

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Private by design — export or delete everything, anytime.")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.55))
            .padding(.top, 14)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("landing.crystal.page.3")
    }

    private func councilAvatar(_ specialist: AstrologySpecialist, isSelected: Bool) -> some View {
        Group {
            if let profile = specialist.archivedProfile {
                Image(profile.profileImageName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(CrystalMood.nearBlack)
                    Image(systemName: specialist.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CrystalMood.gold)
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(
                CrystalMood.gold.opacity(isSelected ? 0.95 : 0.32),
                lineWidth: isSelected ? 1.6 : 0.9
            )
        }
        .scaleEffect(isSelected ? 1.14 : 1)
        .shadow(color: CrystalMood.gold.opacity(isSelected ? 0.35 : 0), radius: 10, y: 4)
        .animation(.spring(SimastrySpring.smooth), value: isSelected)
        .accessibilityLabel("\(specialist.characterName), \(specialist.publicTitle)")
    }

    private func startCouncilCycle() {
        guard !reduceMotion else { return }
        councilTimer?.invalidate()
        councilTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
            Task { @MainActor in
                swapCouncilSelection(to: (councilIndex + 1) % specialists.count)
            }
        }
    }

    private func stopCouncilCycle() {
        councilTimer?.invalidate()
        councilTimer = nil
    }

    /// Fade the caption fully out, swap, fade back in — two experts' text can
    /// never overlap (same pattern as the cinematic hero's caption).
    private func swapCouncilSelection(to index: Int) {
        guard index != councilIndex else { return }
        withAnimation(.easeOut(duration: 0.14)) { councilOpacity = 0 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            councilIndex = index
            withAnimation(.easeIn(duration: 0.2)) { councilOpacity = 1 }
        }
    }

    // MARK: - Page 2 · The communication guide, demoed live

    private struct DemoPersona: Identifiable {
        let id: String
        let label: String
        let icon: String
        let read: String
    }

    private let demoPersonas: [DemoPersona] = [
        DemoPersona(
            id: "mom",
            label: "Mom",
            icon: "heart.fill",
            read: "Leads with worry, hears directness as care.\nOpen with the conclusion, then the reasons.\nDon't make her guess what you're asking for."
        ),
        DemoPersona(
            id: "friend",
            label: "Best friend",
            icon: "person.2.fill",
            read: "Matches your energy — mirrors your tone right back.\nVoice-note honesty lands better than a polished text.\nAsk the real question first, joke second."
        ),
        DemoPersona(
            id: "situationship",
            label: "The situationship",
            icon: "moon.stars.fill",
            read: "Reads pauses louder than words.\nOne clear sentence beats three clever ones.\nName the need — skip the test."
        )
    ]

    @State private var selectedPersonaId: String = "mom"

    private func commGuidePage(compact: Bool) -> some View {
        let persona = demoPersonas.first { $0.id == selectedPersonaId } ?? demoPersonas[0]

        return VStack(spacing: 0) {
            pageTitle("How to talk\nto them.", compact: compact)

            Text("A communication guide for everyone you text.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            HStack(spacing: 8) {
                ForEach(demoPersonas) { candidate in
                    Button {
                        HapticManager.buttonPress()
                        selectedPersonaId = candidate.id
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: candidate.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(candidate.id == selectedPersonaId ? CrystalMood.gold : .white.opacity(0.55))
                            Text(candidate.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(candidate.id == selectedPersonaId ? 0.95 : 0.65))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .landingGlassCapsule(emphasis: candidate.id == selectedPersonaId ? .card : .chip)
                    }
                    .buttonStyle(SpringPressStyle())
                }
            }
            .padding(.top, compact ? 18 : 28)

            VStack(alignment: .leading, spacing: 10) {
                Text("HOW TO TALK TO \(persona.label.uppercased())")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(CrystalMood.gold)

                TypewriterText(text: persona.read)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(6)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .landingGlass(cornerRadius: 24)
            .padding(.top, 16)

            Text("A taste — real guides use their actual chart, privately.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("landing.crystal.page.1")
    }

    // MARK: - Page 3 · Simulate, demoed live

    private func simulateDemoPage(compact: Bool) -> some View {
        VStack(spacing: 0) {
            pageTitle("Practice the\nconversation.", compact: compact)

            Text("Rehearse with a practice partner shaped by their chart — before it counts.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                Text("PRACTICE ANYONE")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(CrystalMood.gold)

                // Their message.
                Text("So are we still on for Friday… or?")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // The rehearsed reply, typing itself.
                VStack(alignment: .trailing, spacing: 4) {
                    TypewriterText(
                        text: "Yes — and I owe you an answer about Saturday too. Give me till tonight?",
                        startDelay: 0.7
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(CrystalMood.gold.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("Drafted with you — you always hit send.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.42))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .landingGlass(cornerRadius: 24)
            .padding(.top, compact ? 18 : 30)

            HStack(spacing: 8) {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CrystalMood.gold)
                Text("A rehearsal, not the real person — they'll still surprise you.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .landingGlassCapsule()
            .padding(.top, 14)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("landing.crystal.page.2")
    }

    private func pageTitle(_ text: String, compact: Bool) -> some View {
        Text(text)
            .font(.system(size: compact ? 28 : 33, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, compact ? 26 : 46)
    }

    // MARK: - Chrome (dots · back · CTA · footer)

    private var isLastPage: Bool { page == pageCount - 1 }

    private var ctaTitle: String {
        switch page {
        case 0: "Get Started"
        case pageCount - 1: "Get your first read"
        default: "Next"
        }
    }

    private var chrome: some View {
        VStack(spacing: 13) {
            dots

            HStack(spacing: 12) {
                if page > 0 {
                    backButton
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }

                CrystalPrimaryButton(title: ctaTitle) { advance() }
                    .accessibilityIdentifier("landing.crystal.cta")
            }
            .animation(.spring(SimastrySpring.smooth), value: page)

            if page == 0 || isLastPage {
                VStack(spacing: 8) {
                    Button {
                        HapticManager.buttonPress()
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            viewModel.currentScreen = .signIn
                        }
                    } label: {
                        Text(localization.string("landing.alreadyHaveAccount"))
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("landing.crystal.signIn")

                    HStack(spacing: 6) {
                        Image(systemName: SimastryIcon.privacy)
                            .font(.system(size: 10, weight: .semibold))
                        Text(localization.string("landing.privateGuides"))
                            .font(.system(size: 11, weight: .semibold))
                        Text("·")
                            .font(.system(size: 11))
                        Link(localization.string("landing.privacy"), destination: AppConfig.privacyPolicyURL)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.55))
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .animation(.spring(SimastrySpring.smooth), value: page == 0 || isLastPage)
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.white : .white.opacity(0.26))
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .animation(.spring(SimastrySpring.snappy), value: page)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(pageCount)")
    }

    private var backButton: some View {
        Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.smooth)) { page = max(0, page - 1) }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .landingGlassCapsule(emphasis: .card)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Back")
        .accessibilityIdentifier("landing.crystal.back")
    }

    private func advance() {
        if isLastPage {
            beginFirstRead()
        } else {
            withAnimation(.spring(SimastrySpring.smooth)) { page += 1 }
        }
    }

    /// Same routing as the cinematic landing's `beginOnboarding()` — straight
    /// to birth details (then the five-expert first read); age gate first when
    /// age isn't verified yet.
    private func beginFirstRead() {
        viewModel.firstReadOnboardingIntent = .astrologer
        withAnimation(.spring(SimastrySpring.smooth)) {
            viewModel.currentScreen = viewModel.isAgeVerified ? .birthDetails : .ageGate
        }
    }

    /// DEBUG-only: lets the screenshot loop open directly onto a page
    /// (`-SimastryPreviewCrystalPage 2`). Returns 0 in release builds.
    private static func initialPage() -> Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-SimastryPreviewCrystalPage"),
           index + 1 < args.count, let value = Int(args[index + 1]) {
            return max(0, min(3, value))
        }
        #endif
        return 0
    }
}

/// Character-by-character reveal for the live demos. Reserves the full text's
/// space up front so nothing reflows while it types; instant under
/// Reduce Motion.
private struct TypewriterText: View {
    let text: String
    var speed: Double = 0.018
    var startDelay: Double = 0.25

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleCount = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text).hidden()
            Text(String(text.prefix(visibleCount)))
        }
        .task(id: text) {
            if reduceMotion {
                visibleCount = text.count
                return
            }
            visibleCount = 0
            try? await Task.sleep(for: .seconds(startDelay))
            if Task.isCancelled { return }
            for index in 1...max(1, text.count) {
                try? await Task.sleep(for: .seconds(speed))
                if Task.isCancelled { return }
                visibleCount = index
            }
        }
    }
}

/// The reference's solid-white pill: black semibold label on white, landing
/// only — every in-app primary action stays champagne gold.
struct CrystalPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(SpringPressStyle())
    }
}

#Preview {
    CrystalLandingView(viewModel: AppViewModel())
}
