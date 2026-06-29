import SwiftUI
import CoreMotion

// MARK: - Slide model

private enum LandingSlideVisualKind {
    case future
    case aura
    case astrologer
    case decode
    case universe
}

private struct LandingSlide: Identifiable {
    let id: Int
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let visualKind: LandingSlideVisualKind
    let chips: [String]
}

private struct LandingReading: Identifiable {
    let id: Int
    let type: String
    let question: String
    let answer: String
    let window: String
}

private struct LandingCompanionWindow: Identifiable {
    let id: String
    let imageName: String
    let name: String
    let role: String
    let isHero: Bool
    let widthRatio: CGFloat
    let heightRatio: CGFloat
    let xRatio: CGFloat
    let yRatio: CGFloat
    let rotation: Double
    let zIndex: Double
}

private let landingCompanionWindows: [LandingCompanionWindow] = [
    LandingCompanionWindow(
        id: "nadia",
        imageName: "Factory_sagittarius-nadia_profile",
        name: "Nadia",
        role: "Evolutionary Astrologer",
        isHero: true,
        widthRatio: 0.49,
        heightRatio: 0.74,
        xRatio: 0.50,
        yRatio: 0.50,
        rotation: 0,
        zIndex: 3
    ),
    LandingCompanionWindow(
        id: "leyla",
        imageName: "Factory_virgo-mara_profile",
        name: "Leyla",
        role: "Western Astrologer",
        isHero: false,
        widthRatio: 0.34,
        heightRatio: 0.47,
        xRatio: 0.18,
        yRatio: 0.75,
        rotation: 1.2,
        zIndex: 4
    ),
    LandingCompanionWindow(
        id: "naomi",
        imageName: "Factory_capricorn-naomi_profile",
        name: "Naomi",
        role: "Chinese Astrologer",
        isHero: false,
        widthRatio: 0.31,
        heightRatio: 0.47,
        xRatio: 0.82,
        yRatio: 0.32,
        rotation: 1.2,
        zIndex: 4
    ),
    LandingCompanionWindow(
        id: "mateo",
        imageName: "Factory_libra-mateo_profile",
        name: "Mateo",
        role: "Vedic Astrologer",
        isHero: false,
        widthRatio: 0.31,
        heightRatio: 0.47,
        xRatio: 0.18,
        yRatio: 0.31,
        rotation: -1.2,
        zIndex: 4
    ),
    LandingCompanionWindow(
        id: "soren",
        imageName: "Factory_aries-cassian_profile",
        name: "Soren",
        role: "Ancient Astrologer",
        isHero: false,
        widthRatio: 0.31,
        heightRatio: 0.47,
        xRatio: 0.82,
        yRatio: 0.76,
        rotation: -1.2,
        zIndex: 4
    )
]

// MARK: - CTA components

private struct LandingPrimaryButton: View {
    let title: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            HStack(spacing: 9) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .goldGlassPill(interactive: true)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(.spring(SimastrySpring.snappy), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - Landing

struct LandingView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var shimmerStars: [ShimmerStar] = ShimmerStar.generate(count: 34)
    @State private var motionOffset: CGSize = .zero
    @State private var readingIndex: Int = 0
    @State private var readingTimer: Timer?
    @State private var motionManager: CMMotionManager = CMMotionManager()
    @State private var selectedSlideID: Int = LandingView.initialSlideID()

    private var localizedLandingSlides: [LandingSlide] {
        [
            LandingSlide(
                id: 0,
                eyebrow: localization.string("landing.slide.panel.eyebrow"),
                title: localization.string("landing.slide.panel.title"),
                subtitle: localization.string("landing.slide.panel.subtitle"),
                icon: SimastryIcon.astrologers,
                accent: SimastryColor.gold,
                visualKind: .universe,
                chips: localization.list("landing.slide.panel.chips")
            ),
            LandingSlide(
                id: 1,
                eyebrow: localization.string("landing.slide.future.eyebrow"),
                title: localization.string("landing.slide.future.title"),
                subtitle: localization.string("landing.slide.future.subtitle"),
                icon: "sparkles",
                accent: SimastryColor.risingViolet,
                visualKind: .future,
                chips: localization.list("landing.slide.future.chips")
            ),
            LandingSlide(
                id: 2,
                eyebrow: localization.string("landing.slide.aura.eyebrow"),
                title: localization.string("landing.slide.aura.title"),
                subtitle: localization.string("landing.slide.aura.subtitle"),
                icon: "camera.filters",
                accent: SimastryColor.celestialBlue,
                visualKind: .aura,
                chips: localization.list("landing.slide.aura.chips")
            ),
            LandingSlide(
                id: 3,
                eyebrow: localization.string("landing.slide.astrologer.eyebrow"),
                title: localization.string("landing.slide.astrologer.title"),
                subtitle: localization.string("landing.slide.astrologer.subtitle"),
                icon: "bubble.left.and.bubble.right.fill",
                accent: SimastryColor.gold,
                visualKind: .astrologer,
                chips: localization.list("landing.slide.astrologer.chips")
            ),
            LandingSlide(
                id: 4,
                eyebrow: localization.string("landing.slide.decode.eyebrow"),
                title: localization.string("landing.slide.decode.title"),
                subtitle: localization.string("landing.slide.decode.subtitle"),
                icon: SimastryIcon.lens,
                accent: SimastryColor.celestialBlue,
                visualKind: .decode,
                chips: localization.list("landing.slide.decode.chips")
            )
        ]
    }

    /// Rotating teaser readings shown on the flagship slide. Starts broad
    /// (timing / love / money) so marriage is one of several, not the face of
    /// the app. The fourth reuses the existing, fully-localized commitment strings.
    private var landingReadings: [LandingReading] {
        [
            LandingReading(id: 0,
                           type: localization.string("landing.reading.change.type"),
                           question: localization.string("landing.reading.change.question"),
                           answer: localization.string("landing.reading.change.answer"),
                           window: localization.string("landing.reading.change.window")),
            LandingReading(id: 1,
                           type: localization.string("landing.reading.love.type"),
                           question: localization.string("landing.reading.love.question"),
                           answer: localization.string("landing.reading.love.answer"),
                           window: localization.string("landing.reading.love.window")),
            LandingReading(id: 2,
                           type: localization.string("landing.reading.money.type"),
                           question: localization.string("landing.reading.money.question"),
                           answer: localization.string("landing.reading.money.answer"),
                           window: localization.string("landing.reading.money.window")),
            LandingReading(id: 3,
                           type: localization.string("landing.visual.future.type"),
                           question: localization.string("landing.visual.future.question"),
                           answer: localization.string("landing.visual.future.answer"),
                           window: localization.string("landing.visual.future.window"))
        ]
    }

    private func startReadingCycle() {
        guard !reduceMotion else { return }
        readingTimer?.invalidate()
        readingTimer = Timer.scheduledTimer(withTimeInterval: 3.6, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.6)) {
                    readingIndex += 1
                }
            }
        }
    }

    /// DEBUG-only: lets the screenshot-verification workflow launch directly
    /// onto a given carousel slide (e.g. `-SimastryPreviewLandingSlide 2`).
    /// Returns 0 in release so production onboarding is unchanged.
    static func initialSlideID() -> Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-SimastryPreviewLandingSlide"),
           i + 1 < args.count, let n = Int(args[i + 1]) {
            return max(0, min(4, n))
        }
        #endif
        return 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                landingBackground(size: geo.size)

                TabView(selection: $selectedSlideID) {
                    ForEach(localizedLandingSlides) { slide in
                        landingSlide(slide, size: geo.size, topInset: geo.safeAreaInsets.top)
                            .tag(slide.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(SimastrySpring.smooth), value: selectedSlideID)

                // Fixed wordmark — pinned above the carousel so it stays put while
                // the slides page beneath it (each slide reserves this same band).
                VStack(spacing: 0) {
                    wordmark
                        .padding(.top, landingTopPadding(for: geo.size, topInset: geo.safeAreaInsets.top))
                    Spacer(minLength: 0)
                }

                VStack {
                    Spacer()
                    landingActionBar(bottomInset: geo.safeAreaInsets.bottom)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 12))
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startMotionUpdates()
            startReadingCycle()
            withAnimation(.spring(SimastrySpring.smooth).delay(0.3)) {
                appeared = true
            }
        }
        .onDisappear {
            stopMotionUpdates()
            readingTimer?.invalidate()
            readingTimer = nil
        }
    }

    // MARK: - Background

    private func landingBackground(size: CGSize) -> some View {
        ZStack {
            Color.black

            // The pastel zodiac wallpaper, with a very slow Ken Burns drift.
            // No clip: the view's built-in overscan absorbs both the drift pan
            // and the parallax offset below, so no black edge is ever exposed.
            CosmicDriftImage(animated: !reduceMotion)
                .frame(width: size.width, height: size.height)
                .offset(x: motionOffset.width * 0.40, y: motionOffset.height * 0.40)

            // Faint cosmic dust drifting upward, sitting just above the wallpaper.
            CosmicDustLayer(animated: !reduceMotion)
                .frame(width: size.width, height: size.height)
                .offset(x: motionOffset.width * 0.22, y: motionOffset.height * 0.22)

            // Legibility veil — lighter up top so the field breathes around the
            // wordmark, then progressively darker through the headline
            // band and the bottom CTA so white text always keeps its ground.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.34), location: 0),
                    .init(color: .black.opacity(0.14), location: 0.16),
                    .init(color: .black.opacity(0.42), location: 0.50),
                    .init(color: .black.opacity(0.68), location: 0.74),
                    .init(color: .black.opacity(0.94), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Rare diagonal falling stars — above the veil so the glass cards
            // (which sit in front of this whole background) softly showcase each
            // streak as it drifts behind them.
            FallingStarsLayer(animated: !reduceMotion)
                .frame(width: size.width, height: size.height)
                .offset(x: motionOffset.width * 0.28, y: motionOffset.height * 0.28)

            shimmerLayer(size: size)
                .offset(x: motionOffset.width * 0.3, y: motionOffset.height * 0.3)
        }
    }

    // MARK: - Slide composition

    private func landingSlide(_ slide: LandingSlide, size: CGSize, topInset: CGFloat) -> some View {
        let compact = size.height < 760
        let bottomClearance = compact ? CGFloat(176) : CGFloat(198)

        return VStack(spacing: compact ? 10 : 16) {
            // Invisible placeholder reserving the band for the pinned wordmark
            // (drawn in `body`), so slide content keeps its exact position.
            wordmark
                .padding(.top, landingTopPadding(for: size, topInset: topInset))
                .hidden()

            slideContent(slide, size: size, compact: compact)

            Spacer(minLength: bottomClearance)
        }
        .frame(width: size.width, height: size.height)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .animation(.spring(SimastrySpring.smooth).delay(0.12), value: appeared)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(slide.eyebrow). \(slide.title). \(slide.subtitle)")
    }

    @ViewBuilder
    private func slideContent(_ slide: LandingSlide, size: CGSize, compact: Bool) -> some View {
        // Every slide is a fixed-height visual band, then the copy block — so the
        // eyebrow / title / chips stay anchored at the same Y while you swipe.
        switch slide.visualKind {
        case .future:
            // The reading card is shorter than the band; center it so the copy lines up.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                futureVisual(accent: slide.accent, size: size)
                Spacer(minLength: 0)
            }
            .frame(height: nonFutureVisualHeight(size: size, compact: compact))
            .padding(.horizontal, 24)
            .padding(.top, compact ? 0 : 4)

        case .universe:
            companionWindowArrangement(size: size)
                .frame(height: nonFutureVisualHeight(size: size, compact: compact))
                .padding(.horizontal, 6)
                .padding(.top, compact ? 0 : 4)

        default:
            slideVisual(slide, compact: compact)
                .frame(height: nonFutureVisualHeight(size: size, compact: compact))
                .padding(.horizontal, 24)
                .padding(.top, compact ? 0 : 6)
        }

        slideCopy(slide, compact: compact, tiny: size.height < 700)
    }

    private func nonFutureVisualHeight(size: CGSize, compact: Bool) -> CGFloat {
        if size.height < 700 { return 196 }
        if compact { return 208 }
        return min(max(size.height * 0.30, 250), 296)
    }

    private func slideCopy(_ slide: LandingSlide, compact: Bool, tiny: Bool) -> some View {
        VStack(spacing: compact ? 8 : 11) {
            HStack(spacing: 7) {
                Image(systemName: slide.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(slide.eyebrow)
                    .font(SimastryFont.overline)
                    .tracking(1.6)
            }
            .foregroundStyle(slide.accent)
            .padding(.horizontal, 13)
            .padding(.vertical, compact ? 6 : 7)
            .landingGlassCapsule()

            Text(slide.title)
                .font(.system(size: compact ? 24 : 31, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.74)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.62), radius: 8, y: 4)

            Text(slide.subtitle)
                .font(compact ? SimastryFont.bodySmall : SimastryFont.bodyLarge)
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .lineSpacing(compact ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.55), radius: 5, y: 2)

            if !tiny {
                chipRow(slide.chips, accent: slide.accent)
            }
        }
        .padding(.horizontal, 26)
    }

    @ViewBuilder
    private func slideVisual(_ slide: LandingSlide, compact: Bool) -> some View {
        switch slide.visualKind {
        case .future, .universe:
            EmptyView()
        case .aura:
            auraVisual(accent: slide.accent, compact: compact)
        case .astrologer:
            astrologerVisual(accent: slide.accent)
        case .decode:
            decodeVisual(accent: slide.accent)
        }
    }

    // MARK: - Slide 1 · Ask the Future

    private func futureVisual(accent: Color, size: CGSize) -> some View {
        let compact = size.height < 760
        // Orb removed — the reading card now leads the Ask-the-Future slide.
        return predictionReadingCard(accent: accent, compact: compact)
    }

    private func predictionReadingCard(accent: Color, compact: Bool) -> some View {
        let reading = landingReadings[readingIndex % landingReadings.count]
        return VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            // The reading crossfades through love / money / timing / commitment
            // so the first thing you see feels alive and broad — not fixed on one question.
            Group {
                HStack(spacing: 10) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: compact ? 13 : 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: compact ? 31 : 36, height: compact ? 31 : 36)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(reading.question)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .contentTransition(.opacity)
                        Text(reading.type)
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(.white.opacity(0.58))
                            .contentTransition(.opacity)
                    }

                    Spacer(minLength: 0)
                }

                landingAnswerRow(
                    title: localization.string("landing.visual.future.shortAnswer"),
                    body: reading.answer
                )

                HStack(spacing: 10) {
                    Image(systemName: SimastryIcon.timing)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SimastryColor.goldLight)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(localization.string("landing.visual.future.windowTitle").uppercased())
                            .font(SimastryFont.overline)
                            .tracking(1.0)
                            .foregroundStyle(SimastryColor.goldLight.opacity(0.9))
                        Text(reading.window)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(.white)
                            .contentTransition(.opacity)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, compact ? 11 : 13)
                .padding(.vertical, compact ? 9 : 11)
                .landingGlass(cornerRadius: 16)
            }
        }
        .frame(minHeight: compact ? 150 : 168, alignment: .top)
        .padding(compact ? 14 : 18)
        .landingGlass(cornerRadius: compact ? 22 : 26)
    }

    // MARK: - Slide 2 · Aura Snapshot

    private func auraVisual(accent: Color, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 13) {
            HStack(spacing: 10) {
                Image(systemName: "camera.filters")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.string("landing.visual.aura.vibeTitle"))
                        .font(SimastryFont.overline)
                        .tracking(1.2)
                        .foregroundStyle(accent)
                    Text(localization.string("landing.visual.aura.vibe"))
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Image(systemName: SimastryIcon.privacy)
                        .font(.system(size: 9, weight: .semibold))
                    Text(localization.string("landing.visual.aura.local"))
                        .font(SimastryFont.microSemibold)
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .landingGlassCapsule()
            }

            auraPaletteBar(compact: compact)

            HStack(spacing: 9) {
                auraRitualCell(localization.string("landing.visual.daily.wear"),
                               localization.string("landing.visual.daily.wearBody"), "tshirt.fill", SimastryColor.celestialBlue, compact: compact)
                auraRitualCell(localization.string("landing.visual.daily.eat"),
                               localization.string("landing.visual.daily.eatBody"), "fork.knife", SimastryColor.sunCoral, compact: compact)
                auraRitualCell(localization.string("landing.visual.daily.focus"),
                               localization.string("landing.visual.daily.focusBody"), "scope", SimastryColor.gold, compact: compact)
            }
        }
        .padding(compact ? 14 : 18)
        .landingGlass(cornerRadius: compact ? 22 : 26)
    }

    private func auraPaletteBar(compact: Bool) -> some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        SimastryColor.sunCoral,
                        SimastryColor.gold,
                        SimastryColor.risingViolet,
                        SimastryColor.celestialBlue
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: compact ? 26 : 30)
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.7)
            }
            .overlay(alignment: .leading) {
                Text(localization.string("landing.visual.aura.palette"))
                    .font(SimastryFont.microSemibold)
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .padding(.leading, 11)
            }
    }

    private func auraRitualCell(_ title: String, _ body: String, _ icon: String, _ accent: Color, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
            Text(title)
                .font(SimastryFont.microSemibold)
                .foregroundStyle(.white.opacity(0.68))
            Text(body)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 64 : 78, alignment: .topLeading)
        .padding(compact ? 9 : 11)
        .landingGlass(cornerRadius: 15)
    }

    // MARK: - Slide 3 · Speak with an AI Astrologer

    private func astrologerVisual(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image("Factory_sagittarius-nadia_profile")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(accent.opacity(0.4), lineWidth: 0.8)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nadia")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(.white)
                    Text(localization.string("landing.visual.astrologer.role"))
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Image(systemName: SimastryIcon.privacy)
                        .font(.system(size: 9, weight: .semibold))
                    Text(localization.string("landing.visual.astrologer.badge"))
                        .font(SimastryFont.microSemibold)
                }
                .foregroundStyle(SimastryColor.goldLight)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .landingGlassCapsule()
            }

            Text(localization.string("landing.visual.future.answer"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .landingGlass(cornerRadius: 18)

            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                Text(localization.string("landing.visual.astrologer.typing"))
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(.white.opacity(0.66))
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .landingGlass(cornerRadius: 26)
    }

    // MARK: - Slide 4 · Decode a Message

    private func decodeVisual(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            landingBubble(localization.string("landing.visual.decode.bubble1"), alignment: .leading, accent: SimastryColor.offWhite.opacity(0.18))
            landingBubble(localization.string("landing.visual.decode.bubble2"), alignment: .trailing, accent: .white.opacity(0.12))

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(accent)
                Text(localization.string("landing.visual.decode.tone"))
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .landingGlass(cornerRadius: 16)
        }
        .padding(18)
        .landingGlass(cornerRadius: 26)
    }

    // MARK: - Shared visual pieces

    private func landingAnswerRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(SimastryFont.overline)
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.52))
            Text(body)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
    }

    private func landingBubble(_ text: String, alignment: HorizontalAlignment, accent: Color) -> some View {
        HStack {
            if alignment == .trailing { Spacer(minLength: 36) }
            Text(text)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(.white)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(13)
                .background(accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.7)
                }
            if alignment == .leading { Spacer(minLength: 36) }
        }
    }

    private func chipRow(_ chips: [String], accent: Color) -> some View {
        HStack(spacing: 7) {
            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(SimastryFont.captionSmall.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .landingGlassCapsule()
            }
        }
    }

    // MARK: - Action bar

    private func landingActionBar(bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            slideDots

            LandingPrimaryButton(title: localization.string("landing.getStarted")) {
                beginOnboarding()
            }
            .accessibilityHint(localization.string("landing.accessibilityHint"))

            alreadyHaveAccountButton

            HStack(spacing: 6) {
                Image(systemName: SimastryIcon.privacy)
                    .font(SimastryFont.microSemibold)
                Text(localization.string("landing.privateGuides"))
                    .font(SimastryFont.captionSmall.weight(.semibold))
                Text("·")
                    .font(SimastryFont.captionSmall)
                Link(localization.string("landing.privacy"), destination: AppConfig.privacyPolicyURL)
                    .font(SimastryFont.captionSmall.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.64))
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, bottomInset > 0 ? 10 : 14)
        .landingGlass(cornerRadius: 30)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .animation(.spring(SimastrySpring.bouncy).delay(0.32), value: appeared)
    }

    private var slideDots: some View {
        HStack(spacing: 7) {
            ForEach(localizedLandingSlides) { slide in
                Capsule()
                    .fill(slide.id == selectedSlideID ? slide.accent : .white.opacity(0.24))
                    .frame(width: slide.id == selectedSlideID ? 24 : 7, height: 7)
                    .animation(.spring(SimastrySpring.snappy), value: selectedSlideID)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            localization.string(
                "landing.slideCount",
                replacements: [
                    "current": "\(selectedSlideID + 1)",
                    "total": "\(localizedLandingSlides.count)"
                ]
            )
        )
    }

    private var alreadyHaveAccountButton: some View {
        Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.smooth)) {
                viewModel.currentScreen = .signIn
            }
        } label: {
            Text(localization.string("landing.alreadyHaveAccount"))
                .font(SimastryFont.bodySmall)
                .foregroundStyle(.white.opacity(0.78))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localization.string("landing.signIn"))
    }

    private func beginOnboarding() {
        withAnimation(.spring(SimastrySpring.smooth)) {
            if viewModel.isAgeVerified {
                viewModel.currentScreen = .firstReadChoice
            } else {
                viewModel.currentScreen = .ageGate
            }
        }
    }

    private func landingTopPadding(for size: CGSize, topInset: CGFloat) -> CGFloat {
        // The carousel ignores the safe area for its full-bleed background, so
        // honor the real top inset here to keep the wordmark/orb clear of the
        // status bar and Dynamic Island, with a fixed minimum for older devices.
        max(topInset + 12, size.height < 720 ? 40 : 60)
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        SimastryWordmark(font: .system(.largeTitle, weight: .bold).italic())
            // Gold outer glow removed — keep only a soft black shadow for legibility.
            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -16)
            .animation(.spring(SimastrySpring.smooth).delay(0.08), value: appeared)
    }

    // MARK: - Companion collage (Slide 5 · feature universe)

    private func companionWindowArrangement(size: CGSize) -> some View {
        GeometryReader { proxy in
            let canvas = proxy.size

            ZStack {
                constellationBackdrop(size: canvas)
                    .allowsHitTesting(false)

                ForEach(landingCompanionWindows) { window in
                    companionWindow(window, canvasSize: canvas)
                        .zIndex(window.zIndex)
                }
            }
            .frame(width: canvas.width, height: canvas.height)
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Featured Simastry expert astrologers: Leyla, Mateo, Naomi, Soren, and Nadia")
    }

    private func constellationBackdrop(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let points = [
                CGPoint(x: canvasSize.width * 0.18, y: canvasSize.height * 0.24),
                CGPoint(x: canvasSize.width * 0.40, y: canvasSize.height * 0.17),
                CGPoint(x: canvasSize.width * 0.62, y: canvasSize.height * 0.29),
                CGPoint(x: canvasSize.width * 0.82, y: canvasSize.height * 0.22),
                CGPoint(x: canvasSize.width * 0.72, y: canvasSize.height * 0.74),
                CGPoint(x: canvasSize.width * 0.48, y: canvasSize.height * 0.83),
                CGPoint(x: canvasSize.width * 0.25, y: canvasSize.height * 0.70)
            ]

            var path = Path()
            for (index, point) in points.enumerated() {
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            context.stroke(path, with: .color(SimastryColor.gold.opacity(0.25)), lineWidth: 0.7)

            for point in points {
                let rect = CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)
                context.fill(Circle().path(in: rect), with: .color(.white.opacity(0.6)))
            }
        }
    }

    private func companionWindow(_ window: LandingCompanionWindow, canvasSize: CGSize) -> some View {
        let width = canvasSize.width * window.widthRatio
        let height = canvasSize.height * window.heightRatio
        let radius: CGFloat = window.isHero ? 26 : 20

        return Image(window.imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height, alignment: .top)
            .clipped()
            .frame(width: width, height: height)
            .overlay(alignment: .bottom) {
                paneScrim(window, radius: radius)
            }
            .clipShape(.rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(window.isHero ? 0.30 : 0.16),
                                .white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: window.isHero ? 1.0 : 0.7
                    )
            }
            .shadow(color: .black.opacity(0.5), radius: 22, y: 14)
            .shadow(color: SimastryColor.gold.opacity(window.isHero ? 0.20 : 0.06), radius: 18, y: 0)
            .rotationEffect(.degrees(window.rotation))
            .position(
                x: canvasSize.width * window.xRatio,
                y: canvasSize.height * window.yRatio
            )
    }

    @ViewBuilder
    private func paneScrim(_ window: LandingCompanionWindow, radius: CGFloat) -> some View {
        let labelsTrailing = !window.isHero && window.xRatio > 0.5
        let alignment: HorizontalAlignment = labelsTrailing ? .trailing : .leading

        VStack(alignment: alignment, spacing: window.isHero ? 3 : 1) {
            if window.isHero {
                HStack(spacing: 4) {
                    Image(systemName: SimastryIcon.method)
                        .font(SimastryFont.microBold)
                    Text("SIMASTRY METHOD")
                        .font(SimastryFont.microBold)
                        .tracking(0.8)
                }
                .foregroundStyle(SimastryColor.goldLight)
            }

            Text(window.name)
                .font(window.isHero ? SimastryFont.titleSmall : SimastryFont.labelSmall)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(window.role)
                .font(window.isHero ? SimastryFont.labelSmall : SimastryFont.captionSmall)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: labelsTrailing ? .trailing : .leading)
        .padding(.horizontal, window.isHero ? 14 : 10)
        .padding(.top, 26)
        .padding(.bottom, window.isHero ? 12 : 8)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.55), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Shimmer Stars

    private func shimmerLayer(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            for star in shimmerStars {
                let point = CGPoint(
                    x: star.x * canvasSize.width,
                    y: star.y * canvasSize.height
                )
                let r = star.currentSize / 2
                let rect = CGRect(x: point.x - r, y: point.y - r, width: star.currentSize, height: star.currentSize)
                context.opacity = star.currentOpacity
                context.fill(
                    Path { p in
                        p.addEllipse(in: rect)
                    },
                    with: .color(star.isWarm ? SimastryColor.gold : Color(red: 0.72, green: 0.77, blue: 0.85))
                )
            }
        }
        .allowsHitTesting(false)
        .task {
            await animateShimmerStars()
        }
    }

    private func animateShimmerStars() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(80))
            for i in shimmerStars.indices {
                guard shimmerStars[i].doesShimmer else { continue }
                let elapsed = Date().timeIntervalSince(shimmerStars[i].lastToggle)
                if elapsed >= shimmerStars[i].cycleSpeed {
                    shimmerStars[i].isBright.toggle()
                    shimmerStars[i].lastToggle = Date()
                    // Opacity-only twinkle — no scale pulse, so stars never flash as sparkles.
                    shimmerStars[i].currentOpacity = shimmerStars[i].isBright
                        ? Double.random(in: 0.55...0.85)
                        : Double.random(in: 0.08...0.25)
                }
            }
        }
    }

    // MARK: - Motion

    private func startMotionUpdates() {
        guard !reduceMotion, motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 20.0
        motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let pitch = motion.attitude.pitch
            let roll = motion.attitude.roll
            // Clamp the tilt offset so the parallax stays premium and never
            // swings far enough to feel distracting (or expose a wallpaper edge).
            let limit: CGFloat = 16
            let targetX = min(max(CGFloat(roll) * 16, -limit), limit)
            let targetY = min(max(CGFloat(pitch) * 16, -limit), limit)
            guard abs(motionOffset.width - targetX) > 1 || abs(motionOffset.height - targetY) > 1 else {
                return
            }
            withAnimation(.easeOut(duration: 0.18)) {
                motionOffset = CGSize(width: targetX, height: targetY)
            }
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

// MARK: - Models

private struct ShimmerStar {
    let x: Double
    let y: Double
    let baseSize: Double
    let isWarm: Bool
    let doesShimmer: Bool
    let doesPulse: Bool
    let cycleSpeed: Double
    var isBright: Bool = false
    var lastToggle: Date = Date(timeIntervalSinceReferenceDate: Double.random(in: -5...0))
    var currentOpacity: Double
    var currentSize: Double

    static func generate(count: Int) -> [ShimmerStar] {
        (0..<count).map { i in
            let doesShimmer = i < 16
            let doesPulse = doesShimmer && i < 6
            let baseSize = Double.random(in: 1.0...3.0)
            let staticOpacity = doesShimmer ? Double.random(in: 0.1...0.3) : Double.random(in: 0.15...0.4)
            return ShimmerStar(
                x: Double.random(in: 0.02...0.98),
                y: Double.random(in: 0.02...0.96),
                baseSize: baseSize,
                isWarm: Double.random(in: 0...1) > 0.3,
                doesShimmer: doesShimmer,
                doesPulse: doesPulse,
                cycleSpeed: doesShimmer ? Double.random(in: 2.5...5.5) : 100,
                currentOpacity: staticOpacity,
                currentSize: baseSize
            )
        }
    }
}
