import SwiftUI

struct SignRevealView: View {
    @Bindable var viewModel: AppViewModel
    @State private var sunRevealed: Bool = false
    @State private var moonRevealed: Bool = false
    @State private var risingRevealed: Bool = false
    @State private var buttonRevealed: Bool = false

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 32) {
                Spacer()

                if let sun = viewModel.userSunSign {
                    SignEntryView(role: .sun, sign: sun)
                        .opacity(sunRevealed ? 1 : 0)
                        .offset(x: sunRevealed ? 0 : -40)
                        .animation(.spring(SimastrySpring.smooth), value: sunRevealed)
                }

                if let moon = viewModel.userMoonSign {
                    SignEntryView(role: .moon, sign: moon)
                        .opacity(moonRevealed ? 1 : 0)
                        .offset(x: moonRevealed ? 0 : 40)
                        .animation(.spring(SimastrySpring.smooth).delay(0.4), value: moonRevealed)
                }

                if let rising = viewModel.userRisingSign {
                    SignEntryView(role: .rising, sign: rising)
                        .opacity(risingRevealed ? 1 : 0)
                        .offset(y: risingRevealed ? 0 : 30)
                        .animation(.spring(SimastrySpring.smooth).delay(0.8), value: risingRevealed)
                }

                if risingRevealed {
                    revealMethodLayer
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.top, -8)
                }

                Spacer()

                VStack(spacing: 12) {
                    GoldButton("This Is Me") {
                        viewModel.homeSetupPhase = .onboardingInsight
                    }

                    SecondaryButton(title: "Edit Signs") {
                        viewModel.userSunSign = nil
                        viewModel.userMoonSign = nil
                        viewModel.userRisingSign = nil
                        viewModel.homeSetupPhase = .signSelection
                    }
                }
                .opacity(buttonRevealed ? 1 : 0)
                .offset(y: buttonRevealed ? 0 : 20)
                .animation(.spring(SimastrySpring.bouncy).delay(1.4), value: buttonRevealed)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            sunRevealed = true
            HapticManager.signConfirmed()
            Task {
                try? await Task.sleep(for: .seconds(0.4))
                moonRevealed = true
                HapticManager.signConfirmed()
                try? await Task.sleep(for: .seconds(0.4))
                risingRevealed = true
                HapticManager.signConfirmed()
                try? await Task.sleep(for: .seconds(0.6))
                buttonRevealed = true
            }
        }
    }

    private var revealMethodLayer: some View {
        MethodLayerPanel(
            title: "Signals used",
            summary: "Your birth date, exact time, and birthplace calculate the chart. Sun shows core drive, Moon shows emotional needs, and Rising shows first instinct.",
            signals: revealSignals,
            footer: "Astronomy calculates placements. Traditional astrology interprets them. Simastry turns that into communication guidance.",
            accent: SimastryColor.gold
        )
    }

    private var revealSignals: [MethodSignal] {
        var signals: [MethodSignal] = []

        if let sun = viewModel.userSunSign {
            signals.append(
                MethodSignal(
                    label: "Sun",
                    detail: "\(sun.displayName) drive",
                    systemImage: "sun.max.fill",
                    tint: sun.color
                )
            )
        }

        if let moon = viewModel.userMoonSign {
            signals.append(
                MethodSignal(
                    label: "Moon",
                    detail: "\(moon.displayName) emotion",
                    systemImage: "moon.stars.fill",
                    tint: moon.color
                )
            )
        }

        if let rising = viewModel.userRisingSign {
            signals.append(
                MethodSignal(
                    label: "Rising",
                    detail: "\(rising.displayName) instinct",
                    systemImage: "sparkles",
                    tint: rising.color
                )
            )
        }

        return signals
    }
}
