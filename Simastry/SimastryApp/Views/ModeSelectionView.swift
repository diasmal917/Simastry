import SwiftUI

struct ModeSelectionView: View {
    @Bindable var viewModel: AppViewModel
    @State private var appeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 16)

                    OnboardingProgressView(
                        eyebrow: "Begin",
                        title: "Choose your first guide",
                        subtitle: viewModel.hasCompletedSigns
                            ? "Your chart signals are ready. Pick the voice that should translate them into message guidance."
                            : "Start with the kind of guidance you want. We'll calculate your communication type next.",
                        step: 1,
                        totalSteps: 3,
                        labels: ["Path", "Signs", "Guide"]
                    )
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(reduceMotion ? .default : .spring(SimastrySpring.smooth), value: appeared)

                    valueCard
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(reduceMotion ? .default : .spring(SimastrySpring.smooth).delay(0.05), value: appeared)

                    VStack(spacing: 14) {
                        modeCard(
                            mode: .simulateAnyone,
                            icon: SimastryIcon.predict,
                            accent: SimastryColor.risingViolet,
                            badge: "Pro",
                            delay: 0.1
                        )

                        HStack(spacing: 14) {
                            modeCard(
                                mode: .soulmate,
                                icon: "heart.fill",
                                accent: SimastryColor.sunCoral,
                                badge: nil,
                                delay: 0.15
                            )

                            modeCard(
                                mode: .bestie,
                                icon: SimastryIcon.message,
                                accent: SimastryColor.celestialBlue,
                                badge: nil,
                                delay: 0.2
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(SimastrySpring.smooth).delay(0.2)) {
                    appeared = true
                }
            }
        }
    }

    private var valueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Start in under a minute")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
            } icon: {
                Image(systemName: SimastryIcon.astrologers)
                    .foregroundStyle(SimastryColor.gold)
            }

            Text("Choose a path, calculate your big three, and turn Sun, Moon, and Rising into a communication type.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                pill("Pick a path")
                pill("Calculate signs")
                pill("Meet your guide")
            }
        }
        .padding(18)
        .surfaceCard(cornerRadius: 22)
    }

    private func pill(_ title: String) -> some View {
        Text(title)
            .font(SimastryFont.labelSmall)
            .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.06), in: .capsule)
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
    }

    private var isProUser: Bool {
        guard viewModel.isRevenueCatAvailable else { return true }
        let tier = viewModel.profile?.tier ?? "free"
        return tier == "pro"
    }

    @ViewBuilder
    private func modeCard(mode: CompanionMode, icon: String, accent: Color, badge: String?, delay: Double) -> some View {
        Button(action: {
            HapticManager.buttonPress()
            if mode == .simulateAnyone && !isProUser {
                viewModel.showToast("Pro feature", subtitle: "Simulate Anyone requires Simastry Pro", isError: true)
                viewModel.showUpsell = true
                return
            }
            viewModel.selectedMode = mode
            if viewModel.hasCompletedSigns {
                viewModel.homeSetupPhase = .companionSetup
            } else {
                viewModel.homeSetupPhase = .signSelection
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    SimastryConceptIconView(
                        name: icon,
                        size: icon == SimastryIcon.predict ? 38 : 40,
                        symbolSize: 17,
                        accent: accent,
                        animatedPrediction: icon == SimastryIcon.predict && appeared
                    )
                        .frame(width: 40, height: 40)
                        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Spacer()

                    if let badge {
                        Text(badge)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.midnight)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(SimastryGradient.gold, in: .capsule)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(mode.displayName)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(mode.subtitle)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(modeSupportText(mode))
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.62))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(cornerRadius: 20, accent: accent)
        }
        .buttonStyle(SpringPressStyle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(reduceMotion ? .default : .spring(SimastrySpring.bouncy).delay(delay), value: appeared)
    }

    private func modeSupportText(_ mode: CompanionMode) -> String {
        switch mode {
        case .simulateAnyone:
            "Practice a conversation, rehearse an outcome, or explore a dynamic before it happens."
        case .soulmate:
            "A charismatic guide lens for love, texting, timing, and emotional guidance."
        case .bestie:
            "A playful, supportive guide with easy warmth and great banter."
        }
    }
}
