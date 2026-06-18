import SwiftUI

struct AgeGateView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var appeared: Bool = false
    @State private var showUnderageMessage: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 32) {
                Spacer()

                // Logo / Name
                VStack(spacing: 16) {
                    GlossyOrbView(
                        signColors: [SimastryColor.gold, SimastryColor.risingViolet],
                        state: .idle,
                        size: 96
                    )

                    Text("Simastry")
                        .font(SimastryFont.displayLarge)
                        .italic()
                        .foregroundStyle(SimastryColor.offWhite)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -16)

                // Heading
                VStack(spacing: 12) {
                    Text(localization.string("ageGate.welcome"))
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(localization.string("ageGate.confirm"))
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .multilineTextAlignment(.center)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                Spacer()

                if showUnderageMessage {
                    // Underage message
                    VStack(spacing: 16) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(SimastryColor.risingViolet)

                        Text(localization.string("ageGate.underage"))
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(24)
                    .simastryGlass(cornerRadius: 22)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    // Buttons
                    VStack(spacing: 14) {
                        GoldButton(localization.string("ageGate.over13")) {
                            HapticManager.buttonPress()
                            withAnimation(.spring(SimastrySpring.smooth)) {
                                viewModel.completeAgeVerification()
                            }
                        }

                        Button {
                            HapticManager.buttonPress()
                            withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                                showUnderageMessage = true
                            }
                        } label: {
                            Text(localization.string("ageGate.under13"))
                                .font(SimastryFont.bodySmall)
                                .foregroundStyle(SimastryColor.mutedSilver)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .simastryGlass(cornerRadius: 16)
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                }

                // Legal note
                Text(localization.string("ageGate.legal"))
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.deepMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
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
}
