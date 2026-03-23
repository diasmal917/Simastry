import SwiftUI

struct OnboardingInsightView: View {
    @Bindable var viewModel: AppViewModel
    @State private var headerAppeared: Bool = false
    @State private var headlineAppeared: Bool = false
    @State private var bodyAppeared: Bool = false
    @State private var tipAppeared: Bool = false
    @State private var miniCardsAppeared: Bool = false
    @State private var buttonAppeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sunSign: ZodiacSign { viewModel.userSunSign ?? .aries }
    private var moonSign: ZodiacSign { viewModel.userMoonSign ?? .aries }
    private var risingSign: ZodiacSign { viewModel.userRisingSign ?? .aries }

    private var insight: [String: String] {
        AstrologyTemplates.personalInsights[sunSign.rawValue] ?? [:]
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 32)

                    // MARK: - Sun Sign Glyph Header
                    signGlyphHeader
                        .opacity(headerAppeared ? 1 : 0)
                        .scaleEffect(headerAppeared ? 1 : 0.7)

                    // MARK: - Eyebrow
                    Text("HERE'S WHAT WE SEE IN YOU")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.gold)
                        .tracking(2.4)
                        .opacity(headlineAppeared ? 1 : 0)
                        .offset(y: headlineAppeared ? 0 : 10)

                    // MARK: - Headline
                    Text(insight["headline"] ?? "Your cosmic profile")
                        .font(SimastryFont.displayLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .multilineTextAlignment(.center)
                        .opacity(headlineAppeared ? 1 : 0)
                        .offset(y: headlineAppeared ? 0 : 12)

                    // MARK: - Body Text
                    Text(insight["body"] ?? "")
                        .font(SimastryFont.bodyLarge)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 8)
                        .opacity(bodyAppeared ? 1 : 0)
                        .offset(y: bodyAppeared ? 0 : 14)

                    // MARK: - Social Tip Card
                    socialTipCard
                        .opacity(tipAppeared ? 1 : 0)
                        .offset(y: tipAppeared ? 0 : 16)

                    // MARK: - Moon & Rising Mini Cards
                    HStack(spacing: 12) {
                        miniPlacementCard(
                            role: "Moon",
                            sign: moonSign,
                            description: "How you process emotions"
                        )

                        miniPlacementCard(
                            role: "Rising",
                            sign: risingSign,
                            description: "How people first experience you"
                        )
                    }
                    .opacity(miniCardsAppeared ? 1 : 0)
                    .offset(y: miniCardsAppeared ? 0 : 18)

                    Spacer().frame(height: 8)

                    // MARK: - Continue Button
                    GoldButton("Continue to Simastry") {
                        Task {
                            await viewModel.saveUserSigns()
                            viewModel.homeSetupPhase = .companionSetup
                        }
                    }
                    .padding(.horizontal, 4)
                    .opacity(buttonAppeared ? 1 : 0)
                    .offset(y: buttonAppeared ? 0 : 20)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            startStaggeredReveal()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your personal insight based on \(sunSign.displayName) Sun sign")
    }

    // MARK: - Components

    private var signGlyphHeader: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [sunSign.color.opacity(0.4), sunSign.color.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [sunSign.color.opacity(0.35), sunSign.color.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [sunSign.color.opacity(0.6), sunSign.color.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: sunSign.color.opacity(0.3), radius: 20, y: 4)

            Text(sunSign.glyph)
                .font(.system(size: 44))
                .foregroundStyle(sunSign.color)
        }
        .accessibilityLabel("\(sunSign.displayName) sign glyph")
    }

    private var socialTipCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("Social Tip")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.gold)
            }

            Text(insight["socialTip"] ?? "")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .simastryGlass(cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(SimastryColor.gold.opacity(0.15), lineWidth: 1)
        }
        .accessibilityLabel("Social tip: \(insight["socialTip"] ?? "")")
    }

    private func miniPlacementCard(role: String, sign: ZodiacSign, description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(sign.glyph)
                    .font(.system(size: 20))
                    .foregroundStyle(sign.color)

                Text(role)
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.2)
                    .textCase(.uppercase)
            }

            Text(sign.displayName)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)

            Text(description)
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tintedGlass(sign.color.opacity(0.10), cornerRadius: 18)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(sign.color.opacity(0.15), lineWidth: 1)
        }
        .accessibilityLabel("Your \(role) in \(sign.displayName): \(description)")
    }

    // MARK: - Animation

    private func startStaggeredReveal() {
        if reduceMotion {
            headerAppeared = true
            headlineAppeared = true
            bodyAppeared = true
            tipAppeared = true
            miniCardsAppeared = true
            buttonAppeared = true
            return
        }

        withAnimation(.spring(SimastrySpring.smooth).delay(0.1)) {
            headerAppeared = true
        }
        withAnimation(.spring(SimastrySpring.smooth).delay(0.35)) {
            headlineAppeared = true
        }
        withAnimation(.spring(SimastrySpring.smooth).delay(0.55)) {
            bodyAppeared = true
        }
        withAnimation(.spring(SimastrySpring.smooth).delay(0.75)) {
            tipAppeared = true
        }
        withAnimation(.spring(SimastrySpring.smooth).delay(0.95)) {
            miniCardsAppeared = true
        }
        withAnimation(.spring(SimastrySpring.bouncy).delay(1.2)) {
            buttonAppeared = true
        }
    }
}
