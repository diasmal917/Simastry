import SwiftUI
import CoreMotion

private struct OnboardingPage: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
}

private let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        id: 0,
        icon: "heart.circle.fill",
        title: "Meet Your Companion",
        subtitle: "Build a fictional astrology guide\naround your Sun, Moon, and Rising",
        accentColor: SimastryColor.sunCoral
    ),
    OnboardingPage(
        id: 1,
        icon: "message.fill",
        title: "Message With Astrology",
        subtitle: "Talk through real relationship moments\nwith chart-grounded companions",
        accentColor: SimastryColor.celestialBlue
    ),
    OnboardingPage(
        id: 2,
        icon: "bubble.left.and.text.bubble.right.fill",
        title: "Know What to Say",
        subtitle: "Communication playbooks for tone,\ntiming, repair, and emotional pattern",
        accentColor: SimastryColor.celestialBlue
    ),
    OnboardingPage(
        id: 3,
        icon: "person.2.fill",
        title: "Practice Any Dynamic",
        subtitle: "Create a companion lens, then rehearse\nthe conversation with placement logic",
        accentColor: SimastryColor.gold
    ),
]

private struct LandingCompanionWindow: Identifiable {
    let id: String
    let imageName: String
    let name: String
    let sign: String
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
        sign: "Taurus",
        widthRatio: 0.45,
        heightRatio: 0.86,
        xRatio: 0.50,
        yRatio: 0.53,
        rotation: -1,
        zIndex: 5
    ),
    LandingCompanionWindow(
        id: "nadia",
        imageName: "Factory_sagittarius-nadia_profile",
        name: "Nadia",
        sign: "Sagittarius",
        widthRatio: 0.31,
        heightRatio: 0.51,
        xRatio: 0.19,
        yRatio: 0.36,
        rotation: -10,
        zIndex: 2
    ),
    LandingCompanionWindow(
        id: "maria",
        imageName: "Factory_gemini-rina_profile",
        name: "Maria",
        sign: "Gemini",
        widthRatio: 0.30,
        heightRatio: 0.50,
        xRatio: 0.82,
        yRatio: 0.37,
        rotation: 9,
        zIndex: 3
    ),
    LandingCompanionWindow(
        id: "leyla",
        imageName: "Factory_virgo-mara_card",
        name: "Leyla",
        sign: "Virgo",
        widthRatio: 0.31,
        heightRatio: 0.52,
        xRatio: 0.25,
        yRatio: 0.72,
        rotation: 7,
        zIndex: 1
    ),
    LandingCompanionWindow(
        id: "elias",
        imageName: "Factory_scorpio-elias_profile",
        name: "Elias",
        sign: "Scorpio",
        widthRatio: 0.32,
        heightRatio: 0.52,
        xRatio: 0.78,
        yRatio: 0.72,
        rotation: -8,
        zIndex: 1
    )
]

struct LandingView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var fallingStars: [FallingStar] = []
    @State private var shimmerStars: [ShimmerStar] = ShimmerStar.generate(count: 25)
    @State private var motionOffset: CGSize = .zero
    @State private var starTimer: Timer?
    @State private var currentPage: Int = 0
    @State private var autoAdvanceTimer: Timer?
    @State private var motionManager: CMMotionManager = CMMotionManager()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                Image("LandingImage")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .offset(x: motionOffset.width * 0.6, y: motionOffset.height * 0.6)
                    .clipped()
                    .ignoresSafeArea()

                shimmerLayer(size: geo.size)
                    .offset(x: motionOffset.width * 0.4, y: motionOffset.height * 0.4)

                fallingStarLayer(size: geo.size)
                    .offset(x: motionOffset.width * 1.0, y: motionOffset.height * 1.0)

                VStack(spacing: 0) {
                    Text("Simastry")
                        .font(SimastryFont.displayLarge)
                        .italic()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -20)
                        .animation(.spring(SimastrySpring.smooth).delay(0.1), value: appeared)
                        .padding(.top, landingTopPadding(for: geo.size))

                    companionWindowArrangement(size: geo.size)
                        .frame(height: heroWindowHeight(for: geo.size))
                        .padding(.top, geo.size.height < 720 ? 0 : 6)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 26)
                        .animation(.spring(SimastrySpring.bouncy).delay(0.18), value: appeared)

                    Spacer(minLength: geo.size.height < 720 ? 0 : 6)

                    onboardingCarousel(cardHeight: onboardingCarouselCardHeight(for: geo.size))
                    foregroundPanel
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startFallingStars()
            startMotionUpdates()
            startAutoAdvance()
            withAnimation(.spring(SimastrySpring.smooth).delay(0.3)) {
                appeared = true
            }
        }
        .onDisappear {
            stopMotionUpdates()
            starTimer?.invalidate()
            starTimer = nil
            autoAdvanceTimer?.invalidate()
            autoAdvanceTimer = nil
        }
    }

    private func landingTopPadding(for size: CGSize) -> CGFloat {
        size.height < 720 ? 42 : 58
    }

    private func heroWindowHeight(for size: CGSize) -> CGFloat {
        if size.height < 700 {
            return 176
        }
        return min(max(size.height * 0.30, 220), 280)
    }

    private func onboardingCarouselCardHeight(for size: CGSize) -> CGFloat {
        size.height < 720 ? 138 : 154
    }

    private func onboardingCarousel(cardHeight: CGFloat) -> some View {
        VStack(spacing: 14) {
            TabView(selection: $currentPage) {
                ForEach(onboardingPages) { page in
                    onboardingCard(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 232)
            .onChange(of: currentPage) { _, _ in
                resetAutoAdvance()
            }

            pageIndicator
        }
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(.spring(SimastrySpring.bouncy).delay(0.2), value: appeared)
    }

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
        .accessibilityLabel("Featured Simastry companions including Ada, Nadia, Maria, Leyla, and Elias")
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
        let radius = min(width * 0.14, 22)

        return Image(window.imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height, alignment: .top)
            .clipped()
        .frame(width: width, height: height)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: radius))
        .clipShape(.rect(cornerRadius: radius))
        .overlay {
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(.white.opacity(window.id == "ada" ? 0.34 : 0.18), lineWidth: window.id == "ada" ? 1.2 : 0.8)
        }
        .shadow(color: .black.opacity(0.45), radius: 20, y: 12)
        .shadow(color: SimastryColor.gold.opacity(window.id == "ada" ? 0.22 : 0.08), radius: 18, y: 0)
        .rotationEffect(.degrees(window.rotation))
        .position(
            x: canvasSize.width * window.xRatio,
            y: canvasSize.height * window.yRatio
        )
    }

    private func onboardingCard(page: OnboardingPage) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    }

                Image(systemName: page.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5))
            }
            .background {
                Circle()
                    .fill(page.accentColor.opacity(0.2))
                    .blur(radius: 18)
            }

            VStack(spacing: 10) {
                Text(page.title)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

                Text(page.subtitle)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 136)
        .background(.black.opacity(0.25), in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
        .padding(.horizontal, 4)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(onboardingPages) { page in
                Capsule()
                    .fill(currentPage == page.id ? .white.opacity(0.96) : .white.opacity(0.34))
                    .frame(width: currentPage == page.id ? 28 : 8, height: 8)
                    .animation(.spring(SimastrySpring.snappy), value: currentPage)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.18), in: .capsule)
        .simastryGlassPill()
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func startAutoAdvance() {
        guard !reduceMotion else { return }
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.spring(SimastrySpring.smooth)) {
                    currentPage = (currentPage + 1) % onboardingPages.count
                }
            }
        }
    }

    private func resetAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        startAutoAdvance()
    }

    // MARK: - Bottom Panel

    private var foregroundPanel: some View {
        VStack(spacing: 14) {
            methodStrip

            GoldButton(localization.string("landing.getStarted")) {
                withAnimation(.spring(SimastrySpring.smooth)) {
                    if viewModel.isAgeVerified {
                        viewModel.currentScreen = .birthDetails
                    } else {
                        viewModel.currentScreen = .ageGate
                    }
                }
            }
            .accessibilityHint("Begin creating your astrology profile")

            Button {
                HapticManager.buttonPress()
                withAnimation(.spring(SimastrySpring.smooth)) {
                    viewModel.currentScreen = .signIn
                }
            } label: {
                Text(localization.string("landing.alreadyHaveAccount"))
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sign in to existing account")

            HStack(spacing: 4) {
                Text(localization.string("landing.legalPrefix"))
                    .font(SimastryFont.caption)
                    .foregroundStyle(.white.opacity(0.78))
                Link(localization.string("landing.terms"), destination: AppConfig.termsOfServiceURL)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(.white.opacity(0.86))
                Text("&")
                    .font(SimastryFont.caption)
                    .foregroundStyle(.white.opacity(0.78))
                Link(localization.string("landing.privacy"), destination: AppConfig.privacyPolicyURL)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(.white.opacity(0.86))
            }
            .padding(.top, 2)

            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .medium))
                Text(localization.string("landing.privacyBadge"))
                    .font(SimastryFont.captionSmall)
            }
            .foregroundStyle(SimastryColor.mutedSilver)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 50)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7), .black.opacity(0.92)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(.container, edges: .bottom)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(.spring(SimastrySpring.bouncy).delay(0.5), value: appeared)
    }

    private var methodStrip: some View {
        HStack(spacing: 8) {
            landingMethodChip("Astronomy", icon: "scope")
            landingMethodChip("Astrology", icon: "point.3.connected.trianglepath.dotted")
            landingMethodChip("Guidance", icon: "text.bubble.fill")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.black.opacity(0.20), in: .capsule)
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Method: astronomy, traditional astrology, communication guidance")
    }

    private func landingMethodChip(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(SimastryFont.captionSmall)
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.82))
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
