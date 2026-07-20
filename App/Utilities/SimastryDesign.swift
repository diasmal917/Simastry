import SwiftUI

struct SimastrySpacing {
    /// 4pt base grid. Prefer these tokens over ad-hoc literals so vertical
    /// rhythm and horizontal gutters stay consistent across screens.
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    /// Extra breathing room above the floating Liquid Glass tab bar. Measured on
    /// iPhone 17 Pro (iOS 26.2): the system does NOT inset plain `ScrollView`
    /// content for the floating bar, so screens must add their own clearance.
    /// This token is the small in-flow cushion used between stacked tab content.
    static let tabBarClearance: CGFloat = 12

    /// End-of-scroll room so the final card/text clears the floating Liquid Glass
    /// tab bar. The bar's glass capsule top sits ~89pt above the screen bottom on
    /// iPhone 17 Pro; 108pt leaves a comfortable ~20pt gap above it. Use this for
    /// the trailing spacer / bottom padding on any scroll content that sits behind
    /// the tab bar (tab roots and views pushed within a tab's NavigationStack).
    static let tabBarEndClearance: CGFloat = 108
}

struct SimastrySpring {
    static let snappy = Spring(response: 0.35, dampingRatio: 0.82)
    static let smooth = Spring(response: 0.55, dampingRatio: 0.86)
    static let bouncy = Spring(response: 0.70, dampingRatio: 0.65)
    static let grounded = Spring(response: 0.45, dampingRatio: 0.90)
    static let drift = Spring(response: 1.20, dampingRatio: 0.95)
    /// Critically damped: settles with no overshoot. The onboarding default —
    /// bounce is reserved for user-driven drag releases.
    static let settle = Spring(response: 0.35, dampingRatio: 1.0)
}

/// Motion tokens for frequent interface feedback. State changes are short and
/// intentionally non-bouncy; native sheets retain the system's own motion.
enum SimastryMotion {
    static let press = Animation.easeOut(duration: 0.14)
    static let stateChange = Animation.easeInOut(duration: 0.20)
    static let reveal = Animation.easeOut(duration: 0.20)

    // Compass live instrument (Stage 4). Entrances ease out (arrive slow),
    // exits ease in (leave fast) — the same in/out asymmetry the rest of the
    // app's motion follows, just named for this screen's own choreography.
    static let instrumentEnter = Animation.easeOut(duration: 0.32)
    static let instrumentExit = Animation.easeIn(duration: 0.18)
    static let segmentSelect = Animation.spring(SimastrySpring.snappy)
    /// The Now dial's day-progress arc draws itself in once, the first time
    /// it renders with real data. Never reused for a repeating/looping
    /// effect — call sites must gate this behind a one-shot flag.
    static let dialSweep = Animation.easeOut(duration: 0.6)
}

struct SimastryColor {
    // Base
    static let midnight = Color(red: 5/255, green: 5/255, blue: 10/255)
    static let pureBlack = Color.black

    // Surface tiers — sunken < surface < elevated. Use elevated for cards that
    // must read as objects, not washes.
    static let surfaceSunken = Color(red: 8/255, green: 9/255, blue: 15/255)
    static let surface = Color(red: 12/255, green: 14/255, blue: 22/255)
    static let surfaceElevated = Color(red: 21/255, green: 24/255, blue: 38/255)

    // Brand gold — luminous champagne, not antique brass.
    static let gold = Color(red: 224/255, green: 186/255, blue: 98/255)
    static let goldLight = Color(red: 245/255, green: 214/255, blue: 140/255)
    static let goldDark = Color(red: 168/255, green: 134/255, blue: 62/255)

    // Accent set — one job each: violet = Predict, coral = Sun/energy,
    // blue = Moon/messages, gold = brand/primary.
    static let celestialBlue = Color(red: 96/255, green: 156/255, blue: 245/255)
    static let sunCoral = Color(red: 255/255, green: 138/255, blue: 101/255)
    static let risingViolet = Color(red: 178/255, green: 140/255, blue: 255/255)
    static let orchidPink = Color(red: 214/255, green: 130/255, blue: 172/255)
    static let sageGreen = Color(red: 126/255, green: 168/255, blue: 120/255)

    // Text hierarchy
    static let offWhite = Color(red: 242/255, green: 244/255, blue: 248/255)
    static let mutedSilver = Color(red: 156/255, green: 170/255, blue: 192/255)
    static let deepMuted = Color(red: 122/255, green: 132/255, blue: 152/255)

    static let amber = Color(red: 222/255, green: 152/255, blue: 62/255)
    static let placeholderLight = Color(red: 197/255, green: 189/255, blue: 179/255)
    static let placeholderDark = Color(red: 168/255, green: 159/255, blue: 149/255)

    // Semantic aliases
    static let textPrimary = offWhite
    static let textSecondary = mutedSilver
    static let textTertiary = deepMuted
    static let accentPredict = risingViolet
}

enum SimastryGradient {
    static let gold = LinearGradient(
        colors: [SimastryColor.goldLight, SimastryColor.gold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let violet = LinearGradient(
        colors: [
            Color(red: 196/255, green: 164/255, blue: 255/255),
            SimastryColor.risingViolet
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// One icon per concept, used identically everywhere it appears.
enum SimastryIcon {
    static let predict = "waveform"
    static let message = "message.fill"
    static let astrologers = "sparkles"
    static let dailyRead = "sun.max.fill"
    static let moon = "moon.stars.fill"
    static let rising = "sunrise.fill"
    static let method = "checkmark.seal.fill"
    static let timing = "clock.fill"
    static let lens = "text.magnifyingglass"
    static let chart = "point.3.connected.trianglepath.dotted"
    static let quote = "quote.bubble.fill"
    static let streak = "flame.fill"
    static let privacy = "lock.fill"
}

struct PredictionOrbIcon: View {
    let size: CGFloat
    var animated: Bool = true
    var glow: Color = SimastryColor.risingViolet

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        Image("PredictionOrb")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(animated && !reduceMotion ? (breathing ? 1.035 : 0.985) : 1)
            .rotationEffect(.degrees(animated && !reduceMotion ? (breathing ? 2.0 : -1.5) : 0))
            .shadow(color: glow.opacity(animated ? 0.30 : 0.18), radius: size * 0.22)
            .shadow(color: glow.opacity(animated ? 0.18 : 0.10), radius: size * 0.38)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onAppear {
                guard animated, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
    }
}

struct PredictionOrbLabel: View {
    let title: String
    var iconSize: CGFloat = 22
    var animated: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            PredictionOrbIcon(size: iconSize, animated: animated)
            Text(title)
        }
    }
}

struct SimastryConceptIconView: View {
    let name: String
    let size: CGFloat
    var symbolSize: CGFloat? = nil
    var accent: Color
    var animatedPrediction: Bool = false

    var body: some View {
        Group {
            if name == SimastryIcon.predict {
                PredictionOrbIcon(size: size, animated: animatedPrediction, glow: accent)
            } else {
                Image(systemName: name)
                    .font(.system(size: symbolSize ?? size * 0.42, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        .frame(width: size, height: size)
    }
}

extension CelestialRole {
    var accentColor: Color {
        Color(red: accentRed, green: accentGreen, blue: accentBlue)
    }
}

private struct SimastryContentSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    let cornerRadius: CGFloat
    let accent: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let edgeOpacity = contrast == .increased ? 0.34 : 0.14

        content
            .background(
                LinearGradient(
                    colors: reduceTransparency
                        ? [SimastryColor.surfaceElevated, SimastryColor.surfaceElevated]
                        : [SimastryColor.surfaceElevated, SimastryColor.surface],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: shape
            )
            .background(accent?.opacity(0.055) ?? .clear, in: shape)
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                (accent ?? SimastryColor.offWhite).opacity(accent == nil ? edgeOpacity : max(edgeOpacity, 0.28)),
                                .white.opacity(contrast == .increased ? 0.12 : 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: contrast == .increased ? 1.2 : 0.8
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(reduceTransparency ? 0.22 : 0.34), radius: 16, y: 8)
    }
}

private struct SimastryFloatingGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            content
                .background(SimastryColor.surfaceElevated, in: shape)
                .overlay {
                    shape
                        .stroke(SimastryColor.offWhite.opacity(contrast == .increased ? 0.42 : 0.18), lineWidth: contrast == .increased ? 1.2 : 0.8)
                        .allowsHitTesting(false)
                }
        } else if #available(iOS 26.0, *) {
            content
                .background(SimastryColor.surfaceSunken.opacity(0.28), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.07)), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape
                        .stroke(.white.opacity(contrast == .increased ? 0.34 : 0.14), lineWidth: contrast == .increased ? 1.1 : 0.7)
                        .allowsHitTesting(false)
                }
        }
    }
}

private struct SimastryInteractiveGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    let cornerRadius: CGFloat
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            content
                .background(SimastryColor.surfaceElevated, in: shape)
                .background(tint.opacity(0.11), in: shape)
                .overlay {
                    shape
                        .stroke(tint.opacity(contrast == .increased ? 0.65 : 0.34), lineWidth: contrast == .increased ? 1.3 : 0.8)
                        .allowsHitTesting(false)
                }
        } else if #available(iOS 26.0, *) {
            content
                .background(SimastryColor.surfaceSunken.opacity(0.30), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(tint.opacity(0.14)).interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(tint.opacity(0.08), in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape
                        .stroke(tint.opacity(contrast == .increased ? 0.60 : 0.28), lineWidth: contrast == .increased ? 1.2 : 0.8)
                        .allowsHitTesting(false)
                }
        }
    }
}

extension View {
    /// Opaque reading/content surface. This intentionally never uses Liquid
    /// Glass, keeping long-form information calm and legible.
    func contentSurface(
        cornerRadius: CGFloat = SimastryRadius.card,
        accent: Color? = nil
    ) -> some View {
        modifier(SimastryContentSurfaceModifier(cornerRadius: cornerRadius, accent: accent))
    }

    /// Noninteractive glass reserved for floating navigation and chrome.
    func floatingGlass(cornerRadius: CGFloat = SimastryRadius.medium) -> some View {
        modifier(SimastryFloatingGlassModifier(cornerRadius: cornerRadius))
    }

    /// Touch-responsive glass reserved for controls, never reading cards.
    func interactiveGlass(
        cornerRadius: CGFloat = SimastryRadius.medium,
        tint: Color = SimastryColor.offWhite
    ) -> some View {
        modifier(SimastryInteractiveGlassModifier(cornerRadius: cornerRadius, tint: tint))
    }

    @ViewBuilder
    func simastryToolbarGlass() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surfaceSunken.opacity(0.42))
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.055)), in: .rect(cornerRadius: 0))
        } else {
            self
                .background(SimastryColor.surface.opacity(0.92))
                .background(.ultraThinMaterial)
        }
    }

    /// Compatibility alias for older call sites. Build 2 deliberately maps
    /// legacy "glass cards" to the semantic opaque content layer.
    func simastryGlass(cornerRadius: CGFloat = 16) -> some View {
        contentSurface(cornerRadius: cornerRadius)
    }

    /// Compatibility alias for the former lighter glass card.
    func simastryGlassLight(cornerRadius: CGFloat = 16) -> some View {
        contentSurface(cornerRadius: cornerRadius)
    }

    /// - Parameter interactive: pass `true` when the pill is itself the tappable
    ///   surface of a button so iOS 26 Liquid Glass responds to touch. Older OSes
    ///   keep the static material fallback.
    @ViewBuilder
    func simastryGlassPill(interactive: Bool = false) -> some View {
        if interactive {
            self.interactiveGlass(cornerRadius: 999, tint: SimastryColor.offWhite)
        } else {
            self
                .background(SimastryColor.surfaceElevated, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(SimastryColor.offWhite.opacity(0.14), lineWidth: 0.7)
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.24), radius: 10, y: 5)
        }
    }

    /// - Parameter interactive: pass `true` only when this pill is the tappable
    ///   surface of a button, so iOS 26 Liquid Glass responds to touch. Static
    ///   cards keep the default so they don't react like controls.
    @ViewBuilder
    func goldGlassPill(interactive: Bool = false) -> some View {
        if interactive {
            self.interactiveGlass(cornerRadius: 999, tint: SimastryColor.gold)
        } else {
            self
                .background(SimastryColor.surfaceElevated, in: Capsule())
                .background(SimastryColor.gold.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(SimastryColor.goldLight.opacity(0.30), lineWidth: 0.8)
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
        }
    }

    /// - Parameter interactive: pass `true` only when this surface is the
    ///   tappable area of a button. Static cards keep the default.
    @ViewBuilder
    func goldGlassRect(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
        if interactive {
            self.interactiveGlass(cornerRadius: cornerRadius, tint: SimastryColor.gold)
        } else {
            self.contentSurface(cornerRadius: cornerRadius, accent: SimastryColor.gold)
        }
    }

    func tintedGlass(_ color: Color, cornerRadius: CGFloat = 16) -> some View {
        contentSurface(cornerRadius: cornerRadius, accent: color)
    }

    /// Standard opaque content card. Elevated tier, soft top-light, hairline
    /// edge — an object sitting on the background, deliberately NOT glass.
    func surfaceCard(cornerRadius: CGFloat = SimastryRadius.card, accent: Color? = nil) -> some View {
        self
            .background(
                LinearGradient(
                    colors: [SimastryColor.surfaceElevated, SimastryColor.surface],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
	            .overlay(
	                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
	                    .stroke(
                        LinearGradient(
                            colors: [
                                (accent ?? .white).opacity(accent == nil ? 0.14 : 0.30),
                                .white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
	                        ),
	                        lineWidth: 0.8
	                    )
	                    .allowsHitTesting(false)
	            )
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }

    /// Compatibility alias for former hero panels. Hero content is now an
    /// opaque accent surface; Liquid Glass remains reserved for controls.
    func heroGlass(_ accent: Color, cornerRadius: CGFloat = SimastryRadius.panel) -> some View {
        contentSurface(cornerRadius: cornerRadius, accent: accent)
    }

    func glossyCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(SimastryColor.surface.opacity(0.74))
            )
	            .overlay(
	                RoundedRectangle(cornerRadius: cornerRadius)
	                    .fill(Color.white.opacity(0.035))
	                    .allowsHitTesting(false)
	            )
	            .overlay(
	                RoundedRectangle(cornerRadius: cornerRadius)
	                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .white.opacity(0.04), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
	                        ),
	                        lineWidth: 0.5
	                    )
	                    .allowsHitTesting(false)
	            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

enum SimastryRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
    static let card: CGFloat = 22
    static let panel: CGFloat = 28
}

struct SimastryFont {
    // Display — large titles, hero text. Bold for Apple-level confidence.
    static let displayLarge = Font.system(.largeTitle, design: .default, weight: .bold)
    static let displayMedium = Font.system(.title, design: .default, weight: .bold)

    // Brand wordmark — serif italic, used only for "Simastry".
    static let wordmark = Font.system(.largeTitle, design: .serif, weight: .semibold)
    static let wordmarkSmall = Font.system(.title3, design: .serif, weight: .semibold)

    // Title — section headers, card titles
    static let titleLarge = Font.system(.title2, weight: .bold)
    static let titleMedium = Font.system(.title3, weight: .semibold)
    static let titleSmall = Font.system(.headline, weight: .semibold)

    // Metric — Fitness-style rounded numerals
    static let metricLarge = Font.system(.title, design: .rounded, weight: .bold)
    static let metricMedium = Font.system(.title2, design: .rounded, weight: .bold)
    static let metricSmall = Font.system(.headline, design: .rounded, weight: .bold)

    // Body — primary content
    static let bodyLarge = Font.system(.body)
    static let bodyMedium = Font.system(.body)
    static let bodySmall = Font.system(.subheadline)

    // Label — UI labels, buttons, metadata
    static let labelLarge = Font.system(.subheadline, weight: .semibold)
    static let labelMedium = Font.system(.footnote, weight: .medium)
    static let labelSmall = Font.system(.caption, weight: .medium)

    // Caption — timestamps, fine print, legal
    static let caption = Font.system(.caption)
    static let captionSmall = Font.system(.caption2)

    // Tracking/uppercase labels
    static let overline = Font.system(.caption2, weight: .semibold)

    // Micro — capsule badges, status pills, sign tags. Mapped to caption2 so
    // they honor Dynamic Type and never render below the ~11pt legibility
    // floor (these replace raw sub-11pt .system(size:) calls in UI chrome).
    static let micro = Font.system(.caption2)
    static let microMedium = Font.system(.caption2, weight: .medium)
    static let microSemibold = Font.system(.caption2, weight: .semibold)
    static let microBold = Font.system(.caption2, weight: .bold)
}

struct SkeletonShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .animation(
                    reduceMotion ? nil : .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: phase
                )
                .opacity(reduceMotion ? 0 : 1)
            }
            .onAppear {
                guard !reduceMotion else { return }
                phase = 2
            }
    }
}

extension View {
    func skeletonShimmer() -> some View {
        modifier(SkeletonShimmer())
    }
}

enum SimastryDateFormatter {
    static let summaryDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let chatDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let compactDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

struct SpringPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(SimastryMotion.press, value: configuration.isPressed)
    }
}

struct SimastryPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SimastryFont.titleSmall)
            .foregroundStyle(SimastryColor.offWhite)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 15)
            .goldGlassRect(cornerRadius: 18, interactive: true)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(SimastryColor.goldLight.opacity(configuration.isPressed ? 0.36 : 0.24), lineWidth: 0.8)
            }
            .shadow(color: SimastryColor.gold.opacity(configuration.isPressed ? 0.08 : 0.14), radius: 18, x: 0, y: 10)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(SimastryMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SimastryPrimaryButtonStyle {
    static var simastryPrimary: SimastryPrimaryButtonStyle { SimastryPrimaryButtonStyle() }
}

/// Full-width CTA in an arbitrary accent — used where an action must read as
/// its own feature color (e.g. violet Predict) instead of brand gold.
struct SimastryAccentButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let accent: Color
    var textColor: Color = SimastryColor.offWhite

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SimastryFont.titleSmall)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 15)
            .interactiveGlass(cornerRadius: 18, tint: accent)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(accent.opacity(configuration.isPressed ? 0.30 : 0.42), lineWidth: 0.8)
            }
            .shadow(color: accent.opacity(configuration.isPressed ? 0.10 : 0.18), radius: 16, x: 0, y: 8)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(SimastryMotion.press, value: configuration.isPressed)
    }
}

struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let reducedAnimation: Animation?

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? reducedAnimation : animation, value: reduceMotion)
    }
}

extension View {
    /// Stops vertical scroll surfaces from being dragged/rubber-banded
    /// horizontally — a sideways "pull" iOS allows on otherwise-vertical scroll
    /// views. `.basedOnSize` only permits horizontal bounce when content is
    /// genuinely wider than the viewport, so intentional horizontal rows (chips,
    /// pickers) keep scrolling while full-screen vertical content can no longer
    /// be pulled sideways. Applied at a tab or sheet root it covers every scroll
    /// view inside via the environment.
    func lockHorizontalScroll() -> some View {
        scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
}
