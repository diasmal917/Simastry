import SwiftUI

/// The premium "cosmic drift" landing backdrop: the static zodiac wallpaper
/// (`ZodiacWallpaper` asset) treated as a flat, matte celestial field that
/// breathes with a very slow Ken Burns drift. No gloss, glow, or 3D lighting —
/// the image is the art; this view only moves it almost imperceptibly.
///
/// The star-twinkle layer and the gyroscope parallax stay in `LandingView`
/// (which already owns them), so this view is just the image + its drift. The
/// upward cosmic-dust motes live in `CosmicDustLayer` below.
///
/// When `animated` is false (Reduce Motion), the image is held still at a
/// neutral overscan so it still fills the screen edge-to-edge with no motion.
struct CosmicDriftImage: View {
    var animated: Bool
    var imageName: String = "ZodiacWallpaper"

    /// Ken Burns endpoints. The wallpaper's aspect ratio is almost identical to
    /// a modern iPhone, so `scaledToFill` alone leaves almost no overscan — the
    /// scale here doubles as the bleed that keeps the pan (and the clamped tilt
    /// parallax that `LandingView` adds on top) from ever exposing a black edge.
    /// A more noticeable ~6% travel (per request to make the drift a bit obvious);
    /// the 1.08 floor gives ~16px/side bleed that comfortably covers pan+parallax.
    private let restingScale: CGFloat = 1.08
    private let driftedScale: CGFloat = 1.14
    private let panAmount: CGFloat = 7

    @State private var drifted = false

    private var scale: CGFloat {
        guard animated else { return restingScale + (driftedScale - restingScale) / 2 }
        return drifted ? driftedScale : restingScale
    }

    /// A tiny diagonal pan, traversed in lock-step with the zoom.
    private var pan: CGSize {
        guard animated else { return .zero }
        return drifted
            ? CGSize(width: panAmount, height: -panAmount)
            : CGSize(width: -panAmount, height: panAmount)
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .offset(pan)
            .animation(
                animated
                    ? .easeInOut(duration: 18).repeatForever(autoreverses: true)
                    : nil,
                value: drifted
            )
            .onAppear {
                guard animated else { return }
                // Kick the value so the repeating ease-in-out begins its loop.
                drifted = true
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

/// A faint layer of cosmic dust: tiny, very-low-opacity motes drifting slowly
/// upward with a barely-there horizontal sway. Drawn flat in a `Canvas` with
/// normal blending (no additive/glow blend) so it never reads as sparkle or
/// haze-light — just dust catching the faintest light.
///
/// Disabled entirely under Reduce Motion (it is pure motion).
struct CosmicDustLayer: View {
    var animated: Bool
    var moteCount: Int = 26

    @State private var motes: [DustMote] = []

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        Self.draw(motes, at: now, in: size, into: context)
                    }
                }
            } else {
                Color.clear
            }
        }
        .onAppear { if motes.isEmpty { motes = DustMote.generate(count: moteCount) } }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private static func draw(_ motes: [DustMote], at now: TimeInterval, in size: CGSize, into context: GraphicsContext) {
        guard size.width > 0, size.height > 0 else { return }
        let travel = size.height + 80   // off-bottom to off-top, with margin

        for mote in motes {
            // Upward progress 0→1, wrapping. Each mote owns its own slow speed.
            let raw = now * mote.speed + mote.phase
            let progress = raw - floor(raw)

            let y = (size.height + 40) - progress * travel
            let sway = sin(now * mote.swaySpeed + mote.phase * 6.283) * mote.swayAmplitude
            let x = mote.xFraction * size.width + sway

            // Fade in off the bottom and out toward the top so motes never pop.
            let edgeFade = min(progress / 0.14, (1 - progress) / 0.18, 1)
            let opacity = mote.opacity * max(0, edgeFade)
            guard opacity > 0.004 else { continue }

            let rect = CGRect(x: x, y: y, width: mote.size, height: mote.size)
            context.fill(Circle().path(in: rect), with: .color(.white.opacity(opacity)))
        }
    }
}

/// One dust mote. Values are randomized once at generation so the field looks
/// organic rather than gridded; all motion is derived from the timeline clock
/// (no per-frame mutation), keeping the layer cheap.
private struct DustMote {
    let xFraction: CGFloat      // 0...1 horizontal anchor
    let size: CGFloat           // px diameter
    let speed: Double           // loops per second (very slow)
    let phase: Double           // 0...1 start offset within the loop
    let opacity: Double         // peak opacity (very low)
    let swaySpeed: Double
    let swayAmplitude: CGFloat

    static func generate(count: Int) -> [DustMote] {
        var rng = SystemRandomNumberGenerator()
        return (0..<count).map { _ in
            DustMote(
                xFraction: CGFloat.random(in: 0...1, using: &rng),
                size: CGFloat.random(in: 0.8...2.2, using: &rng),
                // ~45–110s to cross the screen — slow, subconscious.
                speed: Double.random(in: 0.009...0.022, using: &rng),
                phase: Double.random(in: 0...1, using: &rng),
                opacity: Double.random(in: 0.05...0.11, using: &rng),
                swaySpeed: Double.random(in: 0.05...0.16, using: &rng),
                swayAmplitude: CGFloat.random(in: 3...9, using: &rng)
            )
        }
    }
}

/// Very rare diagonal "falling stars" drifting from the upper-right toward the
/// lower-left. Lives in the background — *behind* the Liquid Glass containers —
/// so the glass softly showcases each streak as it passes underneath, blurred.
///
/// Premium ambient motion, never a meteor shower: roughly one every 6–14s, with
/// quiet gaps, at most 1–2 on screen at once, each tiny and faint with a short
/// delicate trail. Driven by a deterministic schedule (pure function of elapsed
/// time — no per-frame state, no timers) so it stays cheap and never bursts.
/// Disabled under Reduce Motion.
struct FallingStarsLayer: View {
    var animated: Bool

    private static let events = MeteorEvent.schedule(count: 96)
    /// One full loop of the schedule, with a small tail so a star never straddles the wrap.
    private static let period = (events.last?.startTime ?? 600) + 8.0

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        // Drive from absolute time wrapped to the schedule period — robust
                        // to view re-creation (no resettable @State clock), loops naturally.
                        let clock = timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: Self.period)
                        MeteorEvent.draw(Self.events, clock: clock, in: size, into: context)
                    }
                }
                .blur(radius: 1.0)   // soft, premium — within the 0.5–1.5px range
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One scheduled falling star. All fields are derived from a deterministic hash
/// of the index so the schedule is stable across SwiftUI view re-creation (it
/// never jumps), yet looks organic.
private struct MeteorEvent {
    let startTime: Double
    let duration: Double
    let startX: CGFloat        // 0...1 anchor (right side, may begin off-edge)
    let startY: CGFloat        // top band, may begin just above the screen
    let dirX: CGFloat          // unit direction, down-left
    let dirY: CGFloat
    let travelFraction: CGFloat
    let trail: CGFloat         // trail length, px
    let thickness: CGFloat
    let opacity: Double        // 0.12...0.35
    let blue: Double           // 0 = near-white, 1 = faint bluish-white

    /// Deterministic pseudo-random in [0,1) — stable, no RNG state.
    private static func h(_ i: Int, _ p: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(p) * 78.233) * 43758.5453
        return x - floor(x)
    }

    static func schedule(count: Int) -> [MeteorEvent] {
        var events: [MeteorEvent] = []
        var clock = 3.0 + h(0, 9) * 3.0   // first star a few seconds into the loop
        for i in 0..<count {
            clock += 6.0 + h(i, 0) * 8.0   // 6–14s quiet gap between stars
            let dirX = -(0.60 + CGFloat(h(i, 1)) * 0.22)        // left
            let dirY = sqrt(max(0, 1 - dirX * dirX))           // down (unit vector)
            events.append(
                MeteorEvent(
                    startTime: clock,
                    duration: 2.2 + h(i, 2) * 1.6,             // 2.2–3.8s to cross
                    startX: 0.5 + CGFloat(h(i, 3)) * 0.6,      // 0.5–1.1
                    startY: -0.05 + CGFloat(h(i, 4)) * 0.30,   // top band
                    dirX: dirX,
                    dirY: dirY,
                    travelFraction: 0.7 + CGFloat(h(i, 5)) * 0.45,
                    trail: 32 + CGFloat(h(i, 6)) * 40,
                    thickness: 1.4 + CGFloat(h(i, 7)) * 0.8,
                    opacity: 0.14 + h(i, 8) * 0.21,            // 0.14–0.35, faint per spec
                    blue: h(i, 10)
                )
            )
        }
        return events
    }

    static func draw(_ events: [MeteorEvent], clock: TimeInterval, in size: CGSize, into context: GraphicsContext) {
        guard size.width > 0, size.height > 0 else { return }
        let diag = hypot(size.width, size.height)

        for e in events {
            let local = clock - e.startTime
            guard local >= 0, local <= e.duration else { continue }
            let p = local / e.duration

            // Smooth fade in/out so a star never pops or flashes.
            let envelope = min(p / 0.16, (1 - p) / 0.30, 1)
            guard envelope > 0 else { continue }
            let alpha = e.opacity * envelope

            let dist = CGFloat(p) * e.travelFraction * diag
            let headX = e.startX * size.width + e.dirX * dist
            let headY = e.startY * size.height + e.dirY * dist
            let tailX = headX - e.dirX * e.trail
            let tailY = headY - e.dirY * e.trail

            let color = Color(
                red: 0.85 + 0.13 * (1 - e.blue),
                green: 0.90 + 0.07 * (1 - e.blue),
                blue: 1.0
            )

            // Delicate tapered trail: clear tail → faint head.
            var path = Path()
            path.move(to: CGPoint(x: tailX, y: tailY))
            path.addLine(to: CGPoint(x: headX, y: headY))
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0), color.opacity(alpha)]),
                    startPoint: CGPoint(x: tailX, y: tailY),
                    endPoint: CGPoint(x: headX, y: headY)
                ),
                style: StrokeStyle(lineWidth: e.thickness, lineCap: .round)
            )

            // Soft head point — a touch brighter than the trail so the meteor reads.
            let r = e.thickness * 0.9
            let rect = CGRect(x: headX - r, y: headY - r, width: r * 2, height: r * 2)
            context.fill(Circle().path(in: rect), with: .color(color.opacity(min(0.45, alpha * 1.5))))
        }
    }
}
