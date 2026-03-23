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
        title: "Find Your Soulmate",
        subtitle: "Discover your perfectly compatible\ncosmic match based on your big three",
        accentColor: SimastryColor.sunCoral
    ),
    OnboardingPage(
        id: 1,
        icon: "wand.and.stars",
        title: "Predict Their Reply",
        subtitle: "Paste a real conversation and see\nwhat they'll say next — powered by the stars",
        accentColor: SimastryColor.risingViolet
    ),
    OnboardingPage(
        id: 2,
        icon: "bubble.left.and.text.bubble.right.fill",
        title: "Know What to Say",
        subtitle: "Communication playbooks for every sign\nso you always find the right words",
        accentColor: SimastryColor.celestialBlue
    ),
    OnboardingPage(
        id: 3,
        icon: "person.2.fill",
        title: "Simulate Any Personality",
        subtitle: "Build a soulmate, bestie, or anyone —\nthen explore their cosmic personality",
        accentColor: SimastryColor.gold
    ),
]

struct LandingView: View {
    @Bindable var viewModel: AppViewModel
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
                        .padding(.top, 60)

                    Spacer()
                    onboardingCarousel
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

    private var onboardingCarousel: some View {
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

    private func onboardingCard(page: OnboardingPage) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 68, height: 68)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    }

                Image(systemName: page.icon)
                    .font(.system(size: 29, weight: .semibold))
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
                    .font(SimastryFont.titleMedium)
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
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 196)
        .background(.black.opacity(0.25), in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
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
            GoldButton("Get Started") {
                withAnimation(.spring(SimastrySpring.smooth)) {
                    viewModel.currentScreen = .birthDetails
                }
            }
            .accessibilityHint("Begin creating your astrology profile")

            Button {
                HapticManager.buttonPress()
                withAnimation(.spring(SimastrySpring.smooth)) {
                    viewModel.currentScreen = .signIn
                }
            } label: {
                Text("I already have an account")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sign in to existing account")

            HStack(spacing: 4) {
                Text("By continuing, you agree to our")
                    .font(SimastryFont.caption)
                    .foregroundStyle(.white.opacity(0.78))
                Link("Terms", destination: AppConfig.termsOfServiceURL)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(.white.opacity(0.86))
                Text("&")
                    .font(SimastryFont.caption)
                    .foregroundStyle(.white.opacity(0.78))
                Link("Privacy", destination: AppConfig.privacyPolicyURL)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(.white.opacity(0.86))
            }
            .padding(.top, 2)
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
