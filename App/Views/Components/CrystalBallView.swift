import SwiftUI

// MARK: - Palette

/// The crystal-landing mood palette: the reference video's deep emerald ↔
/// violet-wine duotone over near-black, with Simastry's champagne gold kept
/// for accents. Scoped to the crystal landing only.
enum CrystalMood {
    static let nearBlack = Color(red: 0.039, green: 0.039, blue: 0.059)   // #0A0A0F
    static let abyss = Color(red: 0.016, green: 0.02, blue: 0.031)
    static let emerald = Color(red: 0.043, green: 0.18, blue: 0.149)      // deep observatory green
    static let emeraldDeep = Color(red: 0.024, green: 0.102, blue: 0.086)
    static let wine = Color(red: 0.196, green: 0.059, blue: 0.145)        // violet-wine
    static let wineDeep = Color(red: 0.11, green: 0.031, blue: 0.086)
    static let violet = Color(red: 0.22, green: 0.13, blue: 0.32)
    static let goldHint = Color(red: 0.16, green: 0.126, blue: 0.071)
    static let gold = Color(red: 0.85, green: 0.72, blue: 0.45)
}

// MARK: - Background

/// The reference's moody, slowly breathing background: a 3×3 `MeshGradient`
/// whose two interior control points drift on ≥60s sine periods — emerald
/// upper-left, wine right, everything else falling into near-black — with the
/// engraved constellation map barely present for brand continuity.
/// Fully static when Reduce Motion is on.
struct MoodMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                mesh(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                    mesh(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .overlay {
            Image("LandingConstellations")
                .resizable()
                .scaledToFill()
                .opacity(0.05)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private func mesh(at t: TimeInterval) -> some View {
        // Two interior points wander gently; corners stay pinned so the color
        // fields breathe without ever sliding off their reference positions.
        let d1 = Float(sin(t / 31))
        let d2 = Float(cos(t / 43))
        let d3 = Float(sin(t / 53))
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5],
                [0.44 + 0.07 * d1, 0.46 + 0.06 * d2],
                [1, 0.52 + 0.05 * d3],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                CrystalMood.emerald, CrystalMood.nearBlack, CrystalMood.abyss,
                CrystalMood.emeraldDeep, CrystalMood.nearBlack, CrystalMood.wine,
                CrystalMood.abyss, CrystalMood.goldHint, CrystalMood.wineDeep
            ]
        )
        .ignoresSafeArea()
    }
}

// MARK: - Crystal ball

/// The landing hero: a hand-layered glass sphere — nebula smoke, a slowly
/// turning engraved chart wheel, a twinkling micro starfield, thin-film
/// iridescence, speculars and a hairline rim — with the five experts orbiting
/// as small portrait beads that pass behind and in front of the glass.
///
/// Built from pure SwiftUI layers so it runs on the iOS 18 deployment target.
/// // Metal: two shaders would elevate this further —
/// //   1. `.layerEffect(ShaderLibrary.crystalRefraction(.boundingRect, .float(strength)))`
/// //      on the background behind the ball, displacing it radially so the
/// //      mesh gradient visibly bends through the glass;
/// //   2. a caustics pass drawing one moving bright arc inside the lower limb.
/// // Both are drop-in once a .metal file is added to the target; the layered
/// // approximation below is designed so the shaders replace layers 6–7 only.
struct CrystalBallView: View {
    var diameter: CGFloat = 290
    var showsOrbitingExperts: Bool = true
    /// Drag to spin the glass, tap for a light ripple. Off for small
    /// decorative instances.
    var isInteractive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var userSpin: Double = 0
    @State private var lastDragX: CGFloat?
    @State private var rippleStartedAt: TimeInterval?

    private var specialists: [AstrologySpecialist] {
        ExpertAstrologerRegistry.specialists
    }

    var body: some View {
        Group {
            if reduceMotion {
                content(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    content(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(width: diameter * 1.42, height: diameter * 1.18)
        .accessibilityHidden(true)
    }

    private func content(at t: TimeInterval) -> some View {
        ZStack {
            underGlow

            if showsOrbitingExperts {
                beadLayer(at: t, front: false)
            }

            ball(at: t)

            if showsOrbitingExperts {
                beadLayer(at: t, front: true)
            }
        }
    }

    // MARK: Ball

    private func ball(at t: TimeInterval) -> some View {
        ZStack {
            // Everything inside the glass is masked to the sphere…
            ZStack {
                baseSphere
                innerNebula(at: t)
                    .rotationEffect(.radians(userSpin * 0.35))
                engravedWheel(at: t)
                starfield(at: t)
                iridescence(at: t)
                ripple(at: t)
                speculars
            }
            .compositingGroup()
            // The Metal lens: inner layers bulge and bend like real glass.
            .distortionEffect(
                ShaderLibrary.crystalLens(
                    .float2(diameter, diameter),
                    .float(0.22)
                ),
                maxSampleOffset: CGSize(width: diameter * 0.25, height: diameter * 0.25)
            )
            .mask(Circle())

            // …while the rims sit on the boundary itself.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .white.opacity(0.06), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            Circle()
                .stroke(CrystalMood.gold.opacity(0.22), lineWidth: 1.4)
                .blur(radius: 3)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(isInteractive ? spinDrag : nil)
        .onTapGesture {
            guard isInteractive else { return }
            HapticManager.buttonPress()
            rippleStartedAt = Date().timeIntervalSinceReferenceDate
        }
    }

    /// Horizontal drags spin the wheel and swirl the nebula; releasing with
    /// velocity carries a decaying fling.
    private var spinDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let last = lastDragX ?? value.startLocation.x
                userSpin += Double(value.location.x - last) / 90
                lastDragX = value.location.x
            }
            .onEnded { value in
                lastDragX = nil
                let fling = Double(value.predictedEndTranslation.width - value.translation.width) / 240
                withAnimation(.easeOut(duration: 1.4)) {
                    userSpin += min(max(fling, -2.2), 2.2)
                }
            }
    }

    /// A light ring that blooms from a tap and fades — the glass answering.
    @ViewBuilder
    private func ripple(at t: TimeInterval) -> some View {
        if !reduceMotion, let start = rippleStartedAt {
            let progress = (t - start) / 0.65
            if progress > 0, progress < 1 {
                Circle()
                    .strokeBorder(.white.opacity(0.5 * (1 - progress)), lineWidth: 1.6)
                    .frame(
                        width: diameter * (0.25 + 0.75 * progress),
                        height: diameter * (0.25 + 0.75 * progress)
                    )
                    .blur(radius: 1.5)
                    .blendMode(.plusLighter)
            }
        }
    }

    private var baseSphere: some View {
        Circle().fill(
            RadialGradient(
                colors: [
                    Color(red: 0.11, green: 0.10, blue: 0.16),
                    Color(red: 0.055, green: 0.047, blue: 0.098),
                    Color(red: 0.027, green: 0.024, blue: 0.055)
                ],
                center: UnitPoint(x: 0.38, y: 0.32),
                startRadius: diameter * 0.04,
                endRadius: diameter * 0.66
            )
        )
    }

    /// The "smoke" suspended in the glass — a tiny mesh whose interior points
    /// swirl on slow, unequal periods so it never visibly loops.
    private func innerNebula(at t: TimeInterval) -> some View {
        let d1 = Float(sin(t / 17))
        let d2 = Float(cos(t / 23))
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5],
                [0.5 + 0.16 * d1, 0.52 + 0.14 * d2],
                [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                CrystalMood.emeraldDeep, CrystalMood.nearBlack, CrystalMood.violet,
                CrystalMood.wineDeep, CrystalMood.violet, CrystalMood.emerald,
                CrystalMood.nearBlack, CrystalMood.goldHint, CrystalMood.wineDeep
            ]
        )
        .blur(radius: 14)
        .opacity(0.85)
    }

    /// The engraved chart wheel (kit asset, black ground) floats in the sphere;
    /// `.screen` drops its black to transparent so only the gold lines remain.
    private func engravedWheel(at t: TimeInterval) -> some View {
        Image("EmblemWestern")
            .resizable()
            .scaledToFill()
            .frame(width: diameter * 0.94, height: diameter * 0.94)
            .rotationEffect(.radians(t * 2 * .pi / 70 + userSpin))
            .blendMode(.screen)
            .opacity(0.34)
    }

    private func starfield(at t: TimeInterval) -> some View {
        Canvas { context, size in
            var seed: UInt64 = 0x5EED_CAFE
            func random() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 33) / Double(UInt32.max)
            }
            for _ in 0..<40 {
                let x = random() * size.width
                let y = random() * size.height
                let radius = 0.5 + random() * 1.1
                let speed = 0.25 + random() * 0.6
                let phase = random() * .pi * 2
                let twinkle = 0.25 + 0.75 * abs(sin(t * speed + phase))
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.opacity = twinkle * 0.8
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
        .blendMode(.plusLighter)
    }

    /// Thin-film sheen around the limb — a blurred spectral ring turning
    /// against the wheel's direction, additive so it reads as light, not paint.
    private func iridescence(at t: TimeInterval) -> some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        Color(red: 0.15, green: 0.45, blue: 0.42),
                        CrystalMood.violet,
                        Color(red: 0.42, green: 0.16, blue: 0.30),
                        CrystalMood.gold.opacity(0.7),
                        Color(red: 0.15, green: 0.45, blue: 0.42)
                    ],
                    center: .center
                ),
                lineWidth: diameter * 0.11
            )
            .blur(radius: 9)
            .opacity(0.26)
            .rotationEffect(.radians(-t * 2 * .pi / 90))
            .blendMode(.plusLighter)
    }

    private var speculars: some View {
        ZStack {
            // Broad, faint window reflection.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.16), .clear],
                        center: .center,
                        startRadius: 1,
                        endRadius: diameter * 0.24
                    )
                )
                .frame(width: diameter * 0.46, height: diameter * 0.34)
                .rotationEffect(.degrees(-24))
                .offset(x: -diameter * 0.12, y: -diameter * 0.18)

            // Tight key-light catch.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.85), .white.opacity(0.0)],
                        center: .center,
                        startRadius: 0.5,
                        endRadius: diameter * 0.075
                    )
                )
                .frame(width: diameter * 0.15, height: diameter * 0.10)
                .rotationEffect(.degrees(-28))
                .offset(x: -diameter * 0.17, y: -diameter * 0.23)
        }
    }

    private var underGlow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        CrystalMood.gold.opacity(0.26),
                        CrystalMood.violet.opacity(0.18),
                        .clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: diameter * 0.42
                )
            )
            .frame(width: diameter * 0.9, height: diameter * 0.3)
            .offset(y: diameter * 0.52)
            .blur(radius: 18)
    }

    // MARK: Orbiting expert beads

    /// The five experts circle the ball on a flattened ellipse. `sin(phase)`
    /// is the depth: positive is in front of the glass (larger, brighter),
    /// negative passes behind it, so the split front/back layers around the
    /// ball give a real sense of orbit. Static pentagon under Reduce Motion.
    private func beadLayer(at t: TimeInterval, front: Bool) -> some View {
        let orbit = t * 2 * .pi / 48
        return ForEach(Array(specialists.enumerated()), id: \.element.id) { index, specialist in
            let phase = orbit + Double(index) * 2 * .pi / 5
            let depth = sin(phase)
            if (depth >= 0) == front {
                bead(for: specialist, depth: depth)
                    .offset(
                        x: cos(phase) * diameter * 0.62,
                        y: depth * diameter * 0.20
                    )
            }
        }
    }

    private func bead(for specialist: AstrologySpecialist, depth: Double) -> some View {
        let size = 30 + 8 * depth // 22pt at the back, 38pt at the front
        return Group {
            if let profile = specialist.archivedProfile {
                Image(profile.profileImageName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(CrystalMood.nearBlack)
                    Image(systemName: specialist.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CrystalMood.gold)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(CrystalMood.gold.opacity(0.45 + 0.3 * depth), lineWidth: 0.9)
        }
        .opacity(0.55 + 0.45 * max(0, depth) + 0.15 * min(0, depth))
        .shadow(color: .black.opacity(0.4), radius: 5, y: 3)
    }
}

#Preview("Crystal ball on mesh") {
    ZStack {
        MoodMeshBackground()
        CrystalBallView()
    }
}

#Preview("Ball only") {
    ZStack {
        Color.black.ignoresSafeArea()
        CrystalBallView(showsOrbitingExperts: false)
    }
}
