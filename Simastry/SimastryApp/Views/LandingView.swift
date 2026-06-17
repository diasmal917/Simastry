import SwiftUI
import CoreMotion

private struct LandingFeature: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let accent: Color
}

private let landingFeatures: [LandingFeature] = [
    LandingFeature(id: 0, icon: SimastryIcon.lens, title: "Decode the message", accent: SimastryColor.celestialBlue),
    LandingFeature(id: 1, icon: SimastryIcon.predict, title: "Predict their reply", accent: SimastryColor.risingViolet),
    LandingFeature(id: 2, icon: SimastryIcon.quote, title: "Know what to say", accent: SimastryColor.gold)
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

struct LandingView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var fallingStars: [FallingStar] = []
    @State private var shimmerStars: [ShimmerStar] = ShimmerStar.generate(count: 25)
    @State private var motionOffset: CGSize = .zero
    @State private var starTimer: Timer?
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
                .ignoresSafeArea()
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

                    foregroundPanel
                }
                .ignoresSafeArea(.container, edges: .bottom)
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
        Text("Simastry")
            .font(SimastryFont.wordmark)
            .italic()
            .foregroundStyle(.white)
            .shadow(color: SimastryColor.gold.opacity(0.35), radius: 18)
            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -16)
            .animation(.spring(SimastrySpring.smooth).delay(0.08), value: appeared)
            .accessibilityAddTraits(.isHeader)
    }

    private var valueStatement: some View {
        VStack(spacing: 6) {
            Text("Your personal panel of AI astrologers")
                .font(SimastryFont.titleMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

            Text("Relationships, timing, and what to say next.")
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
                        .font(.system(size: 8, weight: .bold))
                    Text("SIMASTRY METHOD")
                        .font(.system(size: 8, weight: .bold))
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
            ForEach(landingFeatures) { feature in
                VStack(spacing: 7) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 17, weight: .semibold))
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
                .landingTileSurface(cornerRadius: 16)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Decode the message. Predict their reply. Know what to say.")
    }

    // MARK: - Bottom Panel

    private var foregroundPanel: some View {
        VStack(spacing: 14) {
            methodCredentialLine

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

            HStack(spacing: 4) {
                Image(systemName: SimastryIcon.privacy)
                    .font(.system(size: 9, weight: .medium))
                Text("Private by design")
                    .font(SimastryFont.captionSmall)
            }
            .foregroundStyle(SimastryColor.mutedSilver)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 50)
        .background(
            // The global scrim already grounds this region; this adds a
            // gentle local reinforcement without a visible gradient seam.
            LinearGradient(
                colors: [.clear, .black.opacity(0.35), .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(.container, edges: .bottom)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(.spring(SimastrySpring.bouncy).delay(0.45), value: appeared)
    }

    private var methodCredentialLine: some View {
        HStack(spacing: 6) {
            Image(systemName: SimastryIcon.method)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SimastryColor.goldLight)

            Text("24 guides · 12 zodiac lenses · trained in the Simastry Method")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .landingCredentialSurface()
        .accessibilityLabel("24 guides across 12 zodiac lenses, trained in the Simastry Method")
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


// MARK: - Landing Surfaces

private extension View {
    /// Feature-row tile surface. On iOS 26 it uses real Liquid Glass with a
    /// dark tint so the white labels keep their contrast over the artwork and
    /// the bar stays grounded; on iOS 18 it falls back to the original tinted
    /// scrim with a hairline edge.
    @ViewBuilder
    func landingTileSurface(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular.tint(.black.opacity(0.24)),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self
                .background(.black.opacity(0.30), in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.6)
                }
        }
    }

    /// Method-credential capsule. Liquid Glass on iOS 26 keeps the warm gold
    /// hairline as a brand accent; iOS 18 keeps the original tinted scrim.
    @ViewBuilder
    func landingCredentialSurface() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(.black.opacity(0.18)), in: .capsule)
                .overlay {
                    Capsule()
                        .strokeBorder(SimastryColor.gold.opacity(0.22), lineWidth: 0.6)
                }
        } else {
            self
                .background(.black.opacity(0.25), in: .capsule)
                .overlay {
                    Capsule()
                        .strokeBorder(SimastryColor.gold.opacity(0.22), lineWidth: 0.6)
                }
        }
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
