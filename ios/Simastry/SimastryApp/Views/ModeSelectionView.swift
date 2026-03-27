import SwiftUI

struct ModeSelectionView: View {
    @Bindable var viewModel: AppViewModel
    @State private var appeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 16)

                    OnboardingProgressView(
                        eyebrow: "Begin",
                        title: "Choose your first connection",
                        subtitle: viewModel.hasCompletedSigns
                            ? "Your signs are ready. Pick the kind of relationship you want to explore first."
                            : "Start with the kind of relationship you want to explore. We'll discover your signs next.",
                        step: 1,
                        totalSteps: 3,
                        labels: ["Path", "Signs", "Companion"]
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

                    VStack(spacing: 16) {
                        modeCard(
                            mode: .simulateAnyone,
                            tint: Color.purple.opacity(0.15),
                            badge: "Pro",
                            delay: 0.1
                        )

                        HStack(spacing: 16) {
                            modeCard(
                                mode: .soulmate,
                                tint: Color.pink.opacity(0.1),
                                badge: nil,
                                delay: 0.15
                            )

                            modeCard(
                                mode: .bestie,
                                tint: SimastryColor.celestialBlue.opacity(0.1),
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
                Image(systemName: "sparkles")
                    .foregroundStyle(SimastryColor.gold)
            }

            Text("Choose the vibe you want, discover your big three, and bring a companion to life.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                pill("Pick a path")
                pill("Find your signs")
                pill("Create your orb")
            }
        }
        .padding(18)
        .simastryGlass(cornerRadius: 22)
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(SimastryColor.gold.opacity(0.16), lineWidth: 1)
        }
    }

    private func pill(_ title: String) -> some View {
        Text(title)
            .font(SimastryFont.labelSmall)
            .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.06), in: .capsule)
    }

    private var isProUser: Bool {
        let tier = viewModel.profile?.tier ?? "free"
        return tier == "pro"
    }

    @ViewBuilder
    private func modeCard(mode: CompanionMode, tint: Color, badge: String?, delay: Double) -> some View {
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(mode.displayName)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Spacer()

                    if let badge {
                        Text(badge)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.midnight)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(SimastryColor.gold, in: .capsule)
                    }
                }

                Text(mode.subtitle)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Text(modeSupportText(mode))
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tintedGlass(tint)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            }
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
            "Build a romantic cosmic match shaped by your signs and emotional chemistry."
        case .bestie:
            "Create a playful, supportive companion with easy warmth and great banter."
        }
    }
}
