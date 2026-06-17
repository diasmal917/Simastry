import SwiftUI

struct ModeSelectionView: View {
    @Bindable var viewModel: AppViewModel
    @State private var appeared: Bool = false

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
                    .animation(.spring(SimastrySpring.smooth), value: appeared)

                    valueCard
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(.spring(SimastrySpring.smooth).delay(0.05), value: appeared)

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
            withAnimation(.spring(SimastrySpring.smooth).delay(0.2)) {
                appeared = true
            }
        }
    }

    private var valueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Start in under a minute")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(SimastryColor.gold)
            }

            Text("Choose the vibe you want, discover your big three, and bring a companion to life.")
                .font(.system(size: 14))
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
            .font(.system(size: 12, weight: .medium))
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
                viewModel.presentUpgradePrompt(
                    title: "Pro feature",
                    subtitle: "Simulate Anyone requires Simastry Pro"
                )
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
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(SimastryColor.offWhite)

                    Spacer()

                    if let badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SimastryColor.midnight)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(SimastryColor.gold, in: .capsule)
                    }
                }

                Text(mode.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(SimastryColor.mutedSilver)

                Text(modeSupportText(mode))
                    .font(.system(size: 12))
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
        .animation(.spring(SimastrySpring.bouncy).delay(delay), value: appeared)
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

struct SpringPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(SimastrySpring.snappy), value: configuration.isPressed)
    }
}
