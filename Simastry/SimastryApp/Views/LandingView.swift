import SwiftUI
import CoreMotion

private struct LandingFeature: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let accent: Color
}

private let landingFeatures: [LandingFeature] = [
    LandingFeature(id: 0, icon: SimastryIcon.lens, title: "Decode a message", accent: SimastryColor.celestialBlue),
    LandingFeature(id: 1, icon: SimastryIcon.predict, title: "Ask the future", accent: SimastryColor.risingViolet),
    LandingFeature(id: 2, icon: SimastryIcon.quote, title: "Know what to say", accent: SimastryColor.gold)
]

private enum LandingSlideVisualKind {
    case future
    case daily
    case decode
    case reply
    case panel
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

private let landingSlides: [LandingSlide] = [
    LandingSlide(
        id: 0,
        eyebrow: "ASK THE FUTURE",
        title: "Quick answers when you need a sign.",
        subtitle: "Love, timing, money, career, and replies in one fast read.",
        icon: SimastryIcon.predict,
        accent: SimastryColor.risingViolet,
        visualKind: .future,
        chips: ["Marriage", "Career", "Money", "Replies"]
    ),
    LandingSlide(
        id: 1,
        eyebrow: "DAILY DECIDER",
        title: "Let today pick the small thing.",
        subtitle: "What to wear, eat, text, focus on, or bring into a date.",
        icon: "wand.and.stars",
        accent: SimastryColor.celestialBlue,
        visualKind: .daily,
        chips: ["Wear", "Eat", "Text vibe", "Focus"]
    ),
    LandingSlide(
        id: 2,
        eyebrow: "DECODE",
        title: "Understand the message before you spiral.",
        subtitle: "Paste a text and read the tone, timing, and what they may mean.",
        icon: SimastryIcon.lens,
        accent: SimastryColor.celestialBlue,
        visualKind: .decode,
        chips: ["Tone", "Meaning", "Timing", "Intent"]
    ),
    LandingSlide(
        id: 3,
        eyebrow: "KNOW WHAT TO SAY",
        title: "Get the line that lands like you.",
        subtitle: "Your guides turn the read into wording that feels clear, warm, and usable.",
        icon: SimastryIcon.quote,
        accent: SimastryColor.gold,
        visualKind: .reply,
        chips: ["Warmer", "Direct", "Shorter", "Practical"]
    ),
    LandingSlide(
        id: 4,
        eyebrow: "MEET YOUR PANEL",
        title: "Twenty-four AI astrologers, one private panel.",
        subtitle: "Each guide brings a different lens, voice, and way through the moment.",
        icon: SimastryIcon.astrologers,
        accent: SimastryColor.gold,
        visualKind: .panel,
        chips: ["Private", "Personal", "Daily", "Live"]
    )
]

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
        id: "ada",
        imageName: "Factory_taurus-ada_card",
        name: "Ada",
        role: "Taurus Guide",
        isHero: true,
        widthRatio: 0.44,
        heightRatio: 0.92,
        xRatio: 0.50,
        yRatio: 0.50,
        rotation: 0,
        zIndex: 5
    ),
    LandingCompanionWindow(
        id: "nadia",
        imageName: "Factory_sagittarius-nadia_profile",
        name: "Nadia",
        role: "Sagittarius Guide",
        isHero: false,
        widthRatio: 0.30,
        heightRatio: 0.52,
        xRatio: 0.18,
        yRatio: 0.32,
        rotation: -3.5,
        zIndex: 2
    ),
    LandingCompanionWindow(
        id: "maria",
        imageName: "Factory_gemini-rina_profile",
        name: "Maria",
        role: "Gemini Guide",
        isHero: false,
        widthRatio: 0.29,
        heightRatio: 0.51,
        xRatio: 0.82,
        yRatio: 0.33,
        rotation: 3.5,
        zIndex: 3
    ),
    LandingCompanionWindow(
        id: "leyla",
        imageName: "Factory_virgo-mara_card",
        name: "Leyla",
        role: "Virgo Guide",
        isHero: false,
        widthRatio: 0.29,
        heightRatio: 0.50,
        xRatio: 0.20,
        yRatio: 0.76,
        rotation: 2.5,
        zIndex: 1
    ),
    LandingCompanionWindow(
        id: "elias",
        imageName: "Factory_scorpio-elias_profile",
        name: "Elias",
        role: "Scorpio Guide",
        isHero: false,
        widthRatio: 0.30,
        heightRatio: 0.51,
        xRatio: 0.81,
        yRatio: 0.77,
        rotation: -2.5,
        zIndex: 1
    )
]

// Feature rows shown below the first viewport. English copy is hardcoded to
// match the existing landing strings; nothing here is user-generated.
private struct LandingShowcaseItem: Identifiable {
    let id: Int
    let icon: String
    let accent: Color
    let title: String
    let subtitle: String
}

private let landingDailyFeatures: [LandingShowcaseItem] = [
    LandingShowcaseItem(id: 0, icon: SimastryIcon.dailyRead, accent: SimastryColor.sunCoral,
                        title: "Guidance for today",
                        subtitle: "Open to a reading tuned to the day's sky and your chart."),
    LandingShowcaseItem(id: 1, icon: SimastryIcon.lens, accent: SimastryColor.celestialBlue,
                        title: "Decode any message",
                        subtitle: "Paste a text and understand what they really meant."),
    LandingShowcaseItem(id: 2, icon: SimastryIcon.predict, accent: SimastryColor.risingViolet,
                        title: "Ask the future",
                        subtitle: "Love, timing, money, career, and reply questions in one fast read."),
    LandingShowcaseItem(id: 3, icon: SimastryIcon.quote, accent: SimastryColor.gold,
                        title: "Know what to say",
                        subtitle: "Get wording that still sounds like you, only clearer.")
]

private let landingWorldFeatures: [LandingShowcaseItem] = [
    LandingShowcaseItem(id: 0, icon: SimastryIcon.astrologers, accent: SimastryColor.gold,
                        title: "A panel of guides",
                        subtitle: "Twenty-four AI astrologers, each with their own voice."),
    LandingShowcaseItem(id: 1, icon: "person.2.fill", accent: SimastryColor.celestialBlue,
                        title: "Understand your people",
                        subtitle: "Add the people who matter and read every dynamic."),
    LandingShowcaseItem(id: 2, icon: "bookmark.fill", accent: SimastryColor.goldLight,
                        title: "Save what resonates",
                        subtitle: "Keep the prompts and readings you'll want again.")
]

/// Translucent glass CTA for the landing — replaces the heavy gold fill with a
/// material that reads as Liquid Glass on iOS 26 and a tinted ultra-thin
/// material on iOS 18. White text keeps contrast high over both treatments.
private struct LandingGlassCTA: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(SimastryColor.surface.opacity(0.16), in: .capsule)
                .glassEffect(.regular.tint(SimastryColor.gold.opacity(0.13)).interactive(), in: .capsule)
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.42), SimastryColor.gold.opacity(0.22)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.9
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        } else {
            content
                .background(SimastryColor.gold.opacity(0.10), in: .capsule)
                .background(.ultraThinMaterial, in: .capsule)
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.40), SimastryColor.gold.opacity(0.20)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        }
    }
}

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
                    .font(SimastryFont.titleSmall)
                Image(systemName: "arrow.right")
                    .font(.system(size: SimastryIconSize.md, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .modifier(LandingGlassCTA())
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

struct LandingView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var fallingStars: [FallingStar] = []
    @State private var shimmerStars: [ShimmerStar] = ShimmerStar.generate(count: 25)
    @State private var motionOffset: CGSize = .zero
    @State private var starTimer: Timer?
    @State private var motionManager: CMMotionManager = CMMotionManager()
    @State private var selectedSlideID: Int = 0

    private var localizedLandingFeatures: [LandingFeature] {
        [
            LandingFeature(id: 0, icon: SimastryIcon.lens, title: localization.string("landing.feature.decode"), accent: SimastryColor.celestialBlue),
            LandingFeature(id: 1, icon: SimastryIcon.predict, title: localization.string("landing.feature.future"), accent: SimastryColor.risingViolet),
            LandingFeature(id: 2, icon: SimastryIcon.quote, title: localization.string("landing.feature.say"), accent: SimastryColor.gold)
        ]
    }

    private var localizedLandingSlides: [LandingSlide] {
        [
            LandingSlide(
                id: 0,
                eyebrow: localization.string("landing.slide.future.eyebrow"),
                title: localization.string("landing.slide.future.title"),
                subtitle: localization.string("landing.slide.future.subtitle"),
                icon: SimastryIcon.predict,
                accent: SimastryColor.risingViolet,
                visualKind: .future,
                chips: localization.list("landing.slide.future.chips")
            ),
            LandingSlide(
                id: 1,
                eyebrow: localization.string("landing.slide.daily.eyebrow"),
                title: localization.string("landing.slide.daily.title"),
                subtitle: localization.string("landing.slide.daily.subtitle"),
                icon: "wand.and.stars",
                accent: SimastryColor.celestialBlue,
                visualKind: .daily,
                chips: localization.list("landing.slide.daily.chips")
            ),
            LandingSlide(
                id: 2,
                eyebrow: localization.string("landing.slide.decode.eyebrow"),
                title: localization.string("landing.slide.decode.title"),
                subtitle: localization.string("landing.slide.decode.subtitle"),
                icon: SimastryIcon.lens,
                accent: SimastryColor.celestialBlue,
                visualKind: .decode,
                chips: localization.list("landing.slide.decode.chips")
            ),
            LandingSlide(
                id: 3,
                eyebrow: localization.string("landing.slide.reply.eyebrow"),
                title: localization.string("landing.slide.reply.title"),
                subtitle: localization.string("landing.slide.reply.subtitle"),
                icon: SimastryIcon.quote,
                accent: SimastryColor.gold,
                visualKind: .reply,
                chips: localization.list("landing.slide.reply.chips")
            ),
            LandingSlide(
                id: 4,
                eyebrow: localization.string("landing.slide.panel.eyebrow"),
                title: localization.string("landing.slide.panel.title"),
                subtitle: localization.string("landing.slide.panel.subtitle"),
                icon: SimastryIcon.astrologers,
                accent: SimastryColor.gold,
                visualKind: .panel,
                chips: localization.list("landing.slide.panel.chips")
            )
        ]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                landingBackground(size: geo.size)

                TabView(selection: $selectedSlideID) {
                    ForEach(localizedLandingSlides) { slide in
                        landingSlide(slide, size: geo.size)
                            .tag(slide.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(SimastrySpring.smooth), value: selectedSlideID)

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
            startFallingStars()
            startMotionUpdates()
            withAnimation(.spring(SimastrySpring.smooth).delay(0.3)) {
                appeared = true
            }
        }
        .onDisappear {
            stopMotionUpdates()
            starTimer?.invalidate()
            starTimer = nil
        }
    }

    // MARK: - Slide Deck

    private func landingBackground(size: CGSize) -> some View {
        ZStack {
            Color.black

            Image("LandingImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .offset(x: motionOffset.width * 0.55, y: motionOffset.height * 0.55)
                .clipped()
                .saturation(0.92)
                .brightness(-0.04)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.40), location: 0),
                    .init(color: .black.opacity(0.16), location: 0.20),
                    .init(color: .black.opacity(0.26), location: 0.52),
                    .init(color: .black.opacity(0.82), location: 0.86),
                    .init(color: .black.opacity(0.96), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            shimmerLayer(size: size)
                .offset(x: motionOffset.width * 0.35, y: motionOffset.height * 0.35)

            fallingStarLayer(size: size)
                .offset(x: motionOffset.width * 0.9, y: motionOffset.height * 0.9)
        }
    }

    private func landingSlide(_ slide: LandingSlide, size: CGSize) -> some View {
        let compact = size.height < 760
        let bottomClearance = compact ? CGFloat(184) : CGFloat(204)

        return VStack(spacing: compact ? 14 : 18) {
            wordmark
                .padding(.top, landingTopPadding(for: size))

            if slide.visualKind == .panel {
                slideCopy(slide, compact: compact)
                    .padding(.top, compact ? 0 : 6)

                companionWindowArrangement(size: size)
                    .frame(height: compact ? 286 : min(max(size.height * 0.38, 320), 390))
                    .padding(.horizontal, 6)
                    .padding(.top, compact ? 2 : 8)
            } else {
                slideVisual(slide, size: size, compact: compact)
                    .frame(height: compact ? 222 : min(max(size.height * 0.31, 260), 306))
                    .padding(.horizontal, 24)
                    .padding(.top, compact ? 0 : 8)

                slideCopy(slide, compact: compact)
            }

            Spacer(minLength: bottomClearance)
        }
        .frame(width: size.width, height: size.height)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .animation(.spring(SimastrySpring.smooth).delay(0.12), value: appeared)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(slide.eyebrow). \(slide.title). \(slide.subtitle)")
    }

    private func slideCopy(_ slide: LandingSlide, compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 12) {
            HStack(spacing: 7) {
                Image(systemName: slide.icon)
                    .font(.system(size: SimastryIconSize.sm, weight: .bold))
                Text(slide.eyebrow)
                    .font(SimastryFont.overline)
                    .tracking(1.6)
            }
            .foregroundStyle(slide.accent)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .simastryGlassPill()

            Text(slide.title)
                .font(.system(size: compact ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.62), radius: 8, y: 4)

            Text(slide.subtitle)
                .font(SimastryFont.bodyLarge)
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.55), radius: 5, y: 2)

            chipRow(slide.chips, accent: slide.accent)
        }
        .padding(.horizontal, 26)
    }

    @ViewBuilder
    private func slideVisual(_ slide: LandingSlide, size: CGSize, compact: Bool) -> some View {
        switch slide.visualKind {
        case .future:
            futureAnswerVisual(accent: slide.accent)
        case .daily:
            dailyDeciderVisual(accent: slide.accent)
        case .decode:
            decodeVisual(accent: slide.accent)
        case .reply:
            replyVisual(accent: slide.accent)
        case .panel:
            companionWindowArrangement(size: size)
        }
    }

    private func futureAnswerVisual(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: SimastryIcon.predict)
                    .font(.system(size: SimastryIconSize.md, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(accent.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.string("landing.visual.future.question"))
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(.white)
                    Text(localization.string("landing.visual.future.type"))
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer()
            }

            landingAnswerRow(title: localization.string("landing.visual.future.shortAnswer"), body: localization.string("landing.visual.future.answer"))
            landingAnswerRow(title: localization.string("landing.visual.future.windowTitle"), body: localization.string("landing.visual.future.window"))
            landingAnswerRow(title: localization.string("landing.visual.future.nextMoveTitle"), body: localization.string("landing.visual.future.nextMove"))
        }
        .padding(18)
        .heroGlass(accent, cornerRadius: 26)
    }

    private func dailyDeciderVisual(accent: Color) -> some View {
        let decisions = [
            (localization.string("landing.visual.daily.wear"), localization.string("landing.visual.daily.wearBody"), "tshirt.fill"),
            (localization.string("landing.visual.daily.eat"), localization.string("landing.visual.daily.eatBody"), "fork.knife"),
            (localization.string("landing.visual.daily.text"), localization.string("landing.visual.daily.textBody"), "bubble.left.and.bubble.right.fill"),
            (localization.string("landing.visual.daily.focus"), localization.string("landing.visual.daily.focusBody"), "scope")
        ]

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localization.string("landing.visual.daily.title"))
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(accent)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(decisions.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: item.2)
                            .font(.system(size: SimastryIconSize.md, weight: .semibold))
                            .foregroundStyle(accent)
                        Text(item.0)
                            .font(SimastryFont.captionSmall.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.70))
                        Text(item.1)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .padding(12)
                    .tintedGlass(accent, cornerRadius: SimastryRadius.large)
                }
            }
        }
        .padding(18)
        .heroGlass(accent, cornerRadius: 26)
    }

    private func decodeVisual(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            landingBubble(localization.string("landing.visual.decode.bubble1"), alignment: .leading, accent: SimastryColor.offWhite.opacity(0.18))
            landingBubble(localization.string("landing.visual.decode.bubble2"), alignment: .trailing, accent: accent.opacity(0.22))

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(accent)
                Text(localization.string("landing.visual.decode.tone"))
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .simastryGlass(cornerRadius: 16)
        }
        .padding(18)
        .heroGlass(accent, cornerRadius: 26)
    }

    private func replyVisual(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: SimastryIcon.quote)
                    .font(.system(size: SimastryIconSize.md, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(accent.opacity(0.16), in: Circle())
                Text(localization.string("landing.visual.reply.title"))
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(.white)
                Spacer()
            }

            Text(localization.string("landing.visual.reply.line"))
                .font(SimastryFont.titleMedium)
                .foregroundStyle(.white)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(localization.list("landing.visual.reply.chips"), id: \.self) { item in
                    Text(item)
                        .font(SimastryFont.captionSmall.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .simastryGlassPill()
                }
            }
        }
        .padding(18)
        .heroGlass(accent, cornerRadius: 26)
    }

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
                .background(accent, in: RoundedRectangle(cornerRadius: SimastryRadius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SimastryRadius.large, style: .continuous)
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
                    .background(accent.opacity(0.12), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(accent.opacity(0.26), lineWidth: 0.65)
                    }
            }
        }
    }

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
        .simastryGlass(cornerRadius: 30)
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

    // MARK: - Hero (first viewport)

    private func heroSection(geo: GeometryProxy) -> some View {
        ZStack {
            Color.black

            Image("LandingImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .offset(x: motionOffset.width * 0.6, y: motionOffset.height * 0.6)
                .clipped()

            // Calms the busy artwork where text must read: a light veil
            // behind the wordmark, untouched art behind the collage, and
            // progressively solid ground under the feature row and CTA.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.30), location: 0),
                    .init(color: .black.opacity(0.05), location: 0.18),
                    .init(color: .clear, location: 0.34),
                    .init(color: .black.opacity(0.30), location: 0.62),
                    .init(color: .black.opacity(0.66), location: 0.78),
                    .init(color: .black.opacity(0.94), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            shimmerLayer(size: geo.size)
                .offset(x: motionOffset.width * 0.4, y: motionOffset.height * 0.4)

            fallingStarLayer(size: geo.size)
                .offset(x: motionOffset.width * 1.0, y: motionOffset.height * 1.0)

            VStack(spacing: 0) {
                wordmark
                    .padding(.top, landingTopPadding(for: geo.size))

                valueStatement
                    .padding(.top, 10)
                    .padding(.horizontal, 32)

                companionWindowArrangement(size: geo.size)
                    .frame(height: heroWindowHeight(for: geo.size))
                    .padding(.top, geo.size.height < 720 ? 8 : 16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 26)
                    .animation(.spring(SimastrySpring.bouncy).delay(0.22), value: appeared)

                Spacer(minLength: 8)

                featureRow
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(.spring(SimastrySpring.smooth).delay(0.34), value: appeared)

                heroCTA
            }
        }
        .clipped()
    }

    private func landingTopPadding(for size: CGSize) -> CGFloat {
        size.height < 720 ? 40 : 60
    }

    private func heroWindowHeight(for size: CGSize) -> CGFloat {
        if size.height < 700 {
            return 220
        }
        return min(max(size.height * 0.36, 270), 330)
    }

    // MARK: - Wordmark & Value

    private var wordmark: some View {
        SimastryWordmark(font: .system(.largeTitle, weight: .bold).italic())
            .shadow(color: SimastryColor.gold.opacity(0.30), radius: 18)
            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -16)
            .animation(.spring(SimastrySpring.smooth).delay(0.08), value: appeared)
    }

    private var valueStatement: some View {
        VStack(spacing: 6) {
            Text(localization.string("landing.value.title"))
                .font(SimastryFont.titleMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

            Text(localization.string("landing.value.subtitle"))
                .font(SimastryFont.bodySmall)
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
        .animation(.spring(SimastrySpring.smooth).delay(0.15), value: appeared)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Companion Collage

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
        .accessibilityLabel("Featured Simastry guides: Ada the Taurus Guide, Nadia the Sagittarius Guide, Maria the Gemini Guide, Leyla the Virgo Guide, and Elias the Scorpio Guide")
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
                paneScrim(window, width: width, radius: radius)
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
    private func paneScrim(_ window: LandingCompanionWindow, width: CGFloat, radius: CGFloat) -> some View {
        // Right-side panes sit partly behind the hero pane, so their labels
        // hug the visible (outer) edge instead of the occluded one.
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

            Text(window.isHero ? window.role : window.role.replacingOccurrences(of: " Guide", with: ""))
                .font(window.isHero ? SimastryFont.labelSmall : SimastryFont.captionSmall)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
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

    // MARK: - Feature Row

    private var featureRow: some View {
        HStack(spacing: 10) {
            ForEach(localizedLandingFeatures) { feature in
                VStack(spacing: 7) {
                    Image(systemName: feature.icon)
                        .font(.system(size: SimastryIconSize.md, weight: .semibold))
                        .foregroundStyle(feature.accent)
                        .frame(height: 20)

                    Text(feature.title)
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
                .background(.black.opacity(0.30), in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.6)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localization.string("landing.feature.accessibility"))
    }

    // MARK: - Hero CTA

    private var heroCTA: some View {
        VStack(spacing: 13) {
            methodCredentialLine

            LandingPrimaryButton(title: localization.string("landing.getStarted")) {
                beginOnboarding()
            }
            .accessibilityHint(localization.string("landing.accessibilityHint"))

            alreadyHaveAccountButton

            scrollHint
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 46)
        .background(
            // The global scrim already grounds this region; this adds a
            // gentle local reinforcement without a visible gradient seam.
            LinearGradient(
                colors: [.clear, .black.opacity(0.35), .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(.spring(SimastrySpring.bouncy).delay(0.45), value: appeared)
    }

    private var scrollHint: some View {
        VStack(spacing: 2) {
            Text(localization.string("landing.seeInside"))
                .font(SimastryFont.captionSmall)
                .foregroundStyle(.white.opacity(0.62))
            Image(systemName: "chevron.compact.down")
                .font(.system(size: SimastryIconSize.md, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .accessibilityHidden(true)
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

    // MARK: - Feature Showcase (below the fold)

    private var featureShowcase: some View {
        VStack(spacing: 26) {
            showcaseGroup(title: localization.string("landing.showcase.daily"), items: landingDailyFeatures)
            showcaseGroup(title: localization.string("landing.showcase.world"), items: landingWorldFeatures)
        }
        .padding(.horizontal, 20)
    }

    private func showcaseGroup(title: String, items: [LandingShowcaseItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(SimastryFont.overline)
                .tracking(1.2)
                .foregroundStyle(SimastryColor.gold.opacity(0.85))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    showcaseRow(item)
                    if index < items.count - 1 {
                        Divider()
                            .overlay(Color.white.opacity(0.07))
                            .padding(.leading, 70)
                    }
                }
            }
            .surfaceCard()
        }
    }

    private func showcaseRow(_ item: LandingShowcaseItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.icon)
                .font(.system(size: SimastryIconSize.md, weight: .semibold))
                .foregroundStyle(item.accent)
                .frame(width: 40, height: 40)
                .background(item.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(item.accent.opacity(0.28), lineWidth: 0.6)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title). \(item.subtitle)")
    }

    // MARK: - Trust Band

    private var trustBand: some View {
        VStack(spacing: 10) {
            Image(systemName: SimastryIcon.privacy)
                .font(.system(size: SimastryIconSize.lg, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
                .frame(width: 48, height: 48)
                .background(SimastryColor.gold.opacity(0.10), in: Circle())
                .overlay(Circle().strokeBorder(SimastryColor.gold.opacity(0.25), lineWidth: 0.7))

            Text(localization.string("landing.trust.title"))
                .font(SimastryFont.titleMedium)
                .foregroundStyle(.white)

            Text(localization.string("landing.trust.subtitle"))
                .font(SimastryFont.bodySmall)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(localization.string("landing.bottom.title"))
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(localization.string("landing.bottom.subtitle"))
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(.white.opacity(0.62))
            }

            LandingPrimaryButton(title: localization.string("landing.getStarted")) {
                beginOnboarding()
            }
            .accessibilityHint(localization.string("landing.accessibilityHint"))

            alreadyHaveAccountButton

            legalFooter
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 54)
    }

    private var legalFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(localization.string("landing.legalPrefix"))
                    .font(SimastryFont.caption)
                    .foregroundStyle(.white.opacity(0.66))
                Link(localization.string("landing.terms"), destination: AppConfig.termsOfServiceURL)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(.white.opacity(0.82))
                Text(localization.string("landing.and"))
                    .font(SimastryFont.caption)
                    .foregroundStyle(.white.opacity(0.66))
                Link(localization.string("landing.privacy"), destination: AppConfig.privacyPolicyURL)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(.white.opacity(0.82))
            }

            HStack(spacing: 4) {
                Image(systemName: SimastryIcon.privacy)
                    .font(SimastryFont.microMedium)
                Text(localization.string("landing.privacyBadge"))
                    .font(SimastryFont.captionSmall)
            }
            .foregroundStyle(SimastryColor.mutedSilver)
        }
    }

    private var methodCredentialLine: some View {
        HStack(spacing: 6) {
            Image(systemName: SimastryIcon.method)
                .font(SimastryFont.microSemibold)
                .foregroundStyle(SimastryColor.goldLight)

            Text(localization.string("landing.methodCredential"))
                .font(SimastryFont.captionSmall)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.25), in: .capsule)
        .overlay {
            Capsule()
                .strokeBorder(SimastryColor.gold.opacity(0.22), lineWidth: 0.6)
        }
        .accessibilityLabel(localization.string("landing.methodCredential"))
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
                    let targetOpacity = shimmerStars[i].isBright
                        ? Double.random(in: 0.6...0.95)
                        : Double.random(in: 0.08...0.25)
                    let targetScale = shimmerStars[i].isBright && shimmerStars[i].doesPulse ? 1.3 : 1.0
                    shimmerStars[i].currentOpacity = targetOpacity
                    shimmerStars[i].currentSize = shimmerStars[i].baseSize * targetScale
                }
            }
        }
    }

    // MARK: - Falling Stars

    private func fallingStarLayer(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            Canvas { context, canvasSize in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for star in fallingStars {
                    let elapsed = now - star.startTime
                    let progress = elapsed / star.duration
                    guard progress >= 0, progress <= 1 else { continue }

                    let x = star.startX * canvasSize.width + (star.driftX * canvasSize.width * progress)
                    let y = -10 + (canvasSize.height + 20) * progress

                    let fadeIn = min(progress / 0.1, 1.0)
                    let fadeOut = min((1.0 - progress) / 0.15, 1.0)
                    let opacity = star.opacity * fadeIn * fadeOut

                    let rect = CGRect(x: x - star.size / 2, y: y - star.size / 2, width: star.size, height: star.size)
                    context.opacity = opacity

                    if star.size > 3.5 {
                        let glowRect = rect.insetBy(dx: -2, dy: -2)
                        context.opacity = opacity * 0.3
                        context.fill(Circle().path(in: glowRect), with: .color(SimastryColor.gold))
                        context.opacity = opacity
                    }

                    context.fill(
                        RoundedRectangle(cornerRadius: star.size / 3).path(in: rect),
                        with: .color(SimastryColor.gold)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func startFallingStars() {
        guard !reduceMotion else { return }
        spawnStar()
        starTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            Task { @MainActor in
                spawnStar()
                fallingStars.removeAll { Date().timeIntervalSinceReferenceDate - $0.startTime > $0.duration + 0.5 }
            }
        }
    }

    private func spawnStar() {
        let star = FallingStar(
            startX: Double.random(in: 0.3...1.1),
            driftX: Double.random(in: -0.35 ... -0.15),
            size: Double.random(in: 2...5.5),
            opacity: Double.random(in: 0.4...1.0),
            duration: Double.random(in: 3.5...6.5),
            startTime: Date().timeIntervalSinceReferenceDate
        )
        fallingStars.append(star)
    }

    // MARK: - Motion

    private func startMotionUpdates() {
        guard !reduceMotion, motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let pitch = motion.attitude.pitch
            let roll = motion.attitude.roll
            let targetX = CGFloat(roll) * 25
            let targetY = CGFloat(pitch) * 25
            withAnimation(.spring(Spring(response: 0.8, dampingRatio: 0.85))) {
                motionOffset = CGSize(width: targetX, height: targetY)
            }
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}


// MARK: - Models

private struct FallingStar {
    let startX: Double
    let driftX: Double
    let size: Double
    let opacity: Double
    let duration: Double
    let startTime: Double
}

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
            let doesShimmer = i < 10
            let doesPulse = doesShimmer && i < 4
            let baseSize = Double.random(in: 1.0...3.5)
            let staticOpacity = doesShimmer ? Double.random(in: 0.1...0.3) : Double.random(in: 0.15...0.4)
            return ShimmerStar(
                x: Double.random(in: 0.02...0.98),
                y: Double.random(in: 0.02...0.55),
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
