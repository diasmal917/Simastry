import SwiftUI

/// Value-first landing: one calm promise, one real product briefing, and a
/// guest Compass path before chart setup or account creation. The celestial
/// atmosphere stays expressive while the information layer behaves like a
/// precise instrument panel.
struct CrystalLandingView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 760

            ZStack {
                MoodMeshBackground()
                activationPage(compact: compact)
            }
        }
        .preferredColorScheme(.dark)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.01 : 0.20)) {
                appeared = true
            }
        }
    }

    private func activationPage(compact: Bool) -> some View {
        ScrollView {
            VStack(spacing: compact ? 14 : 18) {
                SimastryWordmark(font: .title3.bold().italic())
                    .padding(.top, compact ? 8 : 14)

                VStack(spacing: 8) {
                    Text("Know what to say.\nTo anyone.")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Private guidance for difficult conversations. Astrology is optional and always labeled.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.64))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                liveBriefingCard(compact: compact)

                VStack(spacing: 10) {
                    CrystalPrimaryButton(title: "Try Compass — no account needed") {
                        beginGuestCompass()
                    }
                    .accessibilityIdentifier("landing.crystal.cta")

                    Button {
                        HapticManager.buttonPress()
                        beginChartOnboarding()
                    } label: {
                        Label("Build my chart instead", systemImage: "circle.hexagongrid")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .landingGlassCapsule(emphasis: .cta)
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityIdentifier("landing.crystal.chartCTA")

                    Button {
                        HapticManager.buttonPress()
                        withAnimation(SimastryMotion.stateChange) {
                            viewModel.currentScreen = .signIn
                        }
                    } label: {
                        Text(localization.string("landing.alreadyHaveAccount"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.74))
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("landing.crystal.signIn")
                }

                HStack(spacing: 7) {
                    Image(systemName: "lock.fill")
                    Text("Your first reading stays on this iPhone")
                    Text("•")
                    Link("Privacy", destination: AppConfig.privacyPolicyURL)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func liveBriefingCard(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            HStack {
                Label("LIVE BRIEFING", systemImage: "location.north.circle.fill")
                    .font(.caption2.bold())
                    .tracking(1.2)
                    .foregroundStyle(CrystalMood.gold)
                Spacer()
                Text("GENERAL LENS")
                    .font(.caption2.bold())
                    .tracking(0.8)
                    .foregroundStyle(SimastryColor.celestialBlue)
            }

            briefingRow(
                title: "THEIR MESSAGE",
                body: "“haha yeah maybe, this week is kind of crazy”",
                icon: "text.bubble"
            )

            Divider().overlay(.white.opacity(0.10))

            briefingRow(
                title: "TAKEAWAY",
                body: "Interested, but not committing yet.",
                icon: "scope"
            )

            briefingRow(
                title: "NEXT MOVE",
                body: "Offer one specific day without chasing.",
                icon: "arrow.up.forward"
            )
        }
        .padding(compact ? 15 : 17)
        .landingGlass(cornerRadius: 24, emphasis: .card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Example Compass briefing. Their message: haha yeah maybe, this week is kind of crazy. "
            + "Takeaway: Interested, but not committing yet. "
            + "Next move: Offer one specific day without chasing. General lens."
        )
    }

    private func briefingRow(title: String, body: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CrystalMood.gold)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption2.bold())
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.48))
                Text(body)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func beginGuestCompass() {
        viewModel.firstReadOnboardingIntent = .predict
        withAnimation(SimastryMotion.stateChange) {
            viewModel.currentScreen = viewModel.isAgeVerified ? .firstPrediction : .ageGate
        }
    }

    private func beginChartOnboarding() {
        viewModel.firstReadOnboardingIntent = .astrologer
        withAnimation(SimastryMotion.stateChange) {
            viewModel.currentScreen = viewModel.isAgeVerified ? .birthDetails : .ageGate
        }
    }
}

/// Flighty-inspired high-contrast primary action: immediately readable, while
/// the adjacent optional chart action uses interactive Liquid Glass.
struct CrystalPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(SpringPressStyle())
    }
}

#Preview {
    CrystalLandingView(viewModel: AppViewModel())
}
