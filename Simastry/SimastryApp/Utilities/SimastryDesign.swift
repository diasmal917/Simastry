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

    static let tabBarClearance: CGFloat = 72
}

struct SimastrySpring {
    static let snappy = Spring(response: 0.35, dampingRatio: 0.82)
    static let smooth = Spring(response: 0.55, dampingRatio: 0.86)
    static let bouncy = Spring(response: 0.70, dampingRatio: 0.65)
    static let grounded = Spring(response: 0.45, dampingRatio: 0.90)
    static let drift = Spring(response: 1.20, dampingRatio: 0.95)
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

extension CelestialRole {
    var accentColor: Color {
        Color(red: accentRed, green: accentGreen, blue: accentBlue)
    }
}

extension View {
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

    @ViewBuilder
    func simastryGlass(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surfaceSunken.opacity(0.30), in: .rect(cornerRadius: cornerRadius))
                .background(SimastryColor.surface.opacity(0.18), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.085)), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.22), .white.opacity(0.075), .white.opacity(0.035)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                )
                .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
        } else {
            self
                .background(SimastryColor.surface.opacity(0.72), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .white.opacity(0.06), .white.opacity(0.035)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.65
                        )
                )
                .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        }
    }

    @ViewBuilder
    func simastryGlassLight(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surfaceSunken.opacity(0.20), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.045)), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.16), .white.opacity(0.055), .white.opacity(0.025)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                )
        } else {
            self
                .background(SimastryColor.surface.opacity(0.46), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.12), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        }
    }

    /// - Parameter interactive: pass `true` when the pill is itself the tappable
    ///   surface of a button so iOS 26 Liquid Glass responds to touch. Older OSes
    ///   keep the static material fallback.
    @ViewBuilder
    func simastryGlassPill(interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surfaceSunken.opacity(0.28), in: Capsule())
                .background(SimastryColor.surface.opacity(0.16), in: Capsule())
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.075)).interactive(interactive), in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.20), .white.opacity(0.07), .white.opacity(0.035)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                )
                .shadow(color: .black.opacity(0.20), radius: 12, y: 6)
        } else {
            self
                .background(SimastryColor.surface.opacity(0.68), in: .capsule)
                .background(.ultraThinMaterial, in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.16), .white.opacity(0.055)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                )
        }
    }

    /// - Parameter interactive: pass `true` only when this pill is the tappable
    ///   surface of a button, so iOS 26 Liquid Glass responds to touch. Static
    ///   cards keep the default so they don't react like controls.
    @ViewBuilder
    func goldGlassPill(interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surfaceSunken.opacity(0.34), in: Capsule())
                .background(SimastryColor.gold.opacity(0.055), in: Capsule())
                .glassEffect(.regular.tint(SimastryColor.gold.opacity(0.16)).interactive(interactive), in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.24),
                                    SimastryColor.goldLight.opacity(0.38),
                                    SimastryColor.gold.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.85
                        )
                )
                .shadow(color: .black.opacity(0.26), radius: 16, y: 8)
                .shadow(color: SimastryColor.gold.opacity(0.12), radius: 18, y: 8)
        } else {
            self
                .background(SimastryColor.surface.opacity(0.76), in: Capsule())
                .background(SimastryColor.gold.opacity(0.065), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.16),
                                    SimastryColor.goldLight.opacity(0.30),
                                    SimastryColor.gold.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                )
                .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
        }
    }

    /// - Parameter interactive: pass `true` only when this surface is the
    ///   tappable area of a button. Static cards keep the default.
    @ViewBuilder
    func goldGlassRect(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surfaceSunken.opacity(0.34), in: .rect(cornerRadius: cornerRadius))
                .background(SimastryColor.gold.opacity(0.055), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(SimastryColor.gold.opacity(0.14)).interactive(interactive), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.22),
                                    SimastryColor.goldLight.opacity(0.34),
                                    SimastryColor.gold.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.85
                        )
                )
                .shadow(color: .black.opacity(0.26), radius: 18, y: 10)
                .shadow(color: SimastryColor.gold.opacity(0.10), radius: 18, y: 8)
        } else {
            self
                .background(SimastryColor.surface.opacity(0.78), in: .rect(cornerRadius: cornerRadius))
                .background(SimastryColor.gold.opacity(0.055), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.14),
                                    SimastryColor.goldLight.opacity(0.26),
                                    SimastryColor.gold.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.65
                        )
                )
                .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        }
    }

    @ViewBuilder
    func tintedGlass(_ color: Color, cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surfaceSunken.opacity(0.30), in: .rect(cornerRadius: cornerRadius))
                .background(color.opacity(0.055), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(color.opacity(0.12)), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.18), color.opacity(0.24), .white.opacity(0.045)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                )
                .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        } else {
            self
                .background(SimastryColor.surface.opacity(0.78), in: .rect(cornerRadius: cornerRadius))
                .background(color.opacity(0.045), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.12), color.opacity(0.20), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                )
                .shadow(color: .black.opacity(0.20), radius: 14, y: 8)
        }
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
            )
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }

    /// High-value glass panel with an accent presence — reserve for the one or
    /// two surfaces per screen that deserve material emphasis.
    @ViewBuilder
    func heroGlass(_ accent: Color, cornerRadius: CGFloat = SimastryRadius.panel) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(
                    LinearGradient(
                        colors: [accent.opacity(0.20), accent.opacity(0.05), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .background(SimastryColor.surfaceElevated.opacity(0.24), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(accent.opacity(0.18)), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [accent.opacity(0.45), .white.opacity(0.07)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                )
                .shadow(color: accent.opacity(0.18), radius: 22, y: 10)
        } else {
            self
                .background(
                    LinearGradient(
                        colors: [accent.opacity(0.20), accent.opacity(0.05), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .background(SimastryColor.surfaceElevated.opacity(0.92), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [accent.opacity(0.40), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: accent.opacity(0.16), radius: 22, y: 10)
        }
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
                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: phase
                )
            }
            .onAppear { phase = 2 }
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(SimastrySpring.snappy), value: configuration.isPressed)
    }
}

struct SimastryPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SimastryFont.titleSmall)
            .foregroundStyle(SimastryColor.offWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .goldGlassRect(cornerRadius: 18, interactive: true)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(SimastryColor.goldLight.opacity(configuration.isPressed ? 0.36 : 0.24), lineWidth: 0.8)
            }
            .shadow(color: SimastryColor.gold.opacity(configuration.isPressed ? 0.08 : 0.14), radius: 18, x: 0, y: 10)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(SimastrySpring.snappy), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SimastryPrimaryButtonStyle {
    static var simastryPrimary: SimastryPrimaryButtonStyle { SimastryPrimaryButtonStyle() }
}

/// Full-width CTA in an arbitrary accent — used where an action must read as
/// its own feature color (e.g. violet Predict) instead of brand gold.
struct SimastryAccentButtonStyle: ButtonStyle {
    let accent: Color
    var textColor: Color = SimastryColor.offWhite

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SimastryFont.titleSmall)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .tintedGlass(accent, cornerRadius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(accent.opacity(configuration.isPressed ? 0.30 : 0.42), lineWidth: 0.8)
            }
            .shadow(color: accent.opacity(configuration.isPressed ? 0.10 : 0.18), radius: 16, x: 0, y: 8)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(SimastrySpring.snappy), value: configuration.isPressed)
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
