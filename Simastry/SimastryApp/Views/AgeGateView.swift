import SwiftUI

struct AgeGateView: View {
    @Bindable var viewModel: AppViewModel
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
                    Text("Welcome to Simastry")
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text("To use Simastry, please confirm your age.")
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

                        Text("Simastry is designed for users 13 and older. Please come back when you're old enough!")
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
                        GoldButton("I am 13 or older") {
                            HapticManager.buttonPress()
                            viewModel.verifyAge()
                        }

                        Button {
                            HapticManager.buttonPress()
                            withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                                showUnderageMessage = true
                            }
                        } label: {
                            Text("I am under 13")
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
                Text("By continuing, you confirm that you are at least 13 years of age.")
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
