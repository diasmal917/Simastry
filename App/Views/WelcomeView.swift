import SwiftUI

/// The first screen: a quiet, content-first welcome. One promise, one real
/// product example, three ways in. No orbs, no orbiting zodiac, no spectacle —
/// the example exchange materializes once and then holds still.
struct WelcomeView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Drives the one-shot entrance. Flips false→true exactly once.
    @State private var appeared = false
    /// The example reply lands a beat after the example message, once.
    @State private var replyAppeared = false
    @State private var ageSheetDestination: AppViewModel.PostAgeDestination?

    var body: some View {
        ZStack {
            SimastryColor.pureBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    reveal(step: 0) {
                        SimastryWordmark(font: .headline.bold().italic(), sparkles: false)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 24)

                    reveal(step: 1) { headlineBlock }
                        .padding(.top, 44)

                    reveal(step: 2) { exampleExchange }
                        .padding(.top, 36)

                    // At accessibility text sizes a pinned bar would consume
                    // the screen, so the actions ride in the scrolling flow.
                    if dynamicTypeSize.isAccessibilitySize {
                        reveal(step: 3) { actionsBlock }
                            .padding(.top, 36)
                    }

                    Spacer(minLength: 44)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !dynamicTypeSize.isAccessibilitySize {
                reveal(step: 3) { actionsBlock }
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .background {
                        LinearGradient(
                            colors: [.black.opacity(0), .black.opacity(0.85), .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                        .allowsHitTesting(false)
                    }
            }
        }
        .sheet(item: $ageSheetDestination) { destination in
            AgeDisclosureSheet(
                onConfirm: {
                    ageSheetDestination = nil
                    viewModel.confirmAdultAge(then: destination)
                },
                onDecline: {
                    ageSheetDestination = nil
                }
            )
        }
        .onAppear {
            appeared = true
            if reduceMotion {
                replyAppeared = true
            } else {
                // The reply materializes once the message has settled — a
                // single hand-off, never a loop.
                withAnimation(.spring(SimastrySpring.settle).delay(0.75)) {
                    replyAppeared = true
                }
            }
        }
        .task {
            // Guest widgets and Siri read today's windows even before any
            // account exists; publishing stays a silent side effect here.
            await viewModel.publishDayWindowsForWidget()
        }
    }

    // MARK: - Content

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Understand people.\nSay what you mean.")
                .font(.system(.largeTitle, design: .default, weight: .bold))
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(-1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("A private AI companion helps you prepare for real conversations—with astrology as context, never certainty.")
                .font(.body)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A restrained example of the product: one ask, one answer. The pair is
    /// a single element for VoiceOver so it reads as a conversation.
    private var exampleExchange: some View {
        VStack(alignment: .leading, spacing: 10) {
            exampleBubble(
                text: "“I need to set a boundary without making this a fight.”",
                label: "You",
                isUser: true
            )

            exampleBubble(
                text: "“Let’s make it clear without making it cold.”",
                label: "Simastry · AI",
                isUser: false
            )
            .opacity(replyAppeared ? 1 : 0)
            .offset(y: reduceMotion || replyAppeared ? 0 : 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Example. You: I need to set a boundary without making this a fight. Simastry, an AI companion, replies: Let's make it clear without making it cold."
        )
    }

    private func exampleBubble(text: String, label: String, isUser: Bool) -> some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 5) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(SimastryColor.textTertiary)

            Text(text)
                .font(.callout)
                .foregroundStyle(isUser ? SimastryColor.offWhite : SimastryColor.offWhite.opacity(0.92))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(
                    isUser ? Color.white.opacity(0.10) : SimastryColor.gold.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(isUser ? .leading : .trailing, 34)
    }

    // MARK: - Actions

    private var actionsBlock: some View {
        VStack(spacing: 10) {
            Button {
                HapticManager.buttonPress()
                beginSetup()
            } label: {
                Text(viewModel.onboardingProgress.hasStarted ? "Continue setup" : "Get started")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityIdentifier("welcome.getStarted")

            Button {
                HapticManager.buttonPress()
                beginGuestCompass()
            } label: {
                Text("Try today’s Compass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SimastryColor.offWhite)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .simastryGlass(cornerRadius: 24)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityIdentifier("welcome.guestCompass")

            Button {
                HapticManager.buttonPress()
                withAnimation(SimastryMotion.stateChange) {
                    viewModel.currentScreen = .signIn
                }
            } label: {
                Text(localization.string("landing.alreadyHaveAccount"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .frame(minHeight: 44)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityIdentifier("welcome.signIn")

            Text("AI guidance • Private by design • 18+")
                .font(.caption2.weight(.medium))
                .foregroundStyle(SimastryColor.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .padding(.bottom, 8)
        }
    }

    private func beginSetup() {
        guard viewModel.isAgeVerified else {
            ageSheetDestination = .setupFlow
            return
        }
        viewModel.beginSetupFlow()
    }

    private func beginGuestCompass() {
        // Guests who later sign up from the Compass still land on Compass —
        // the persisted intent preserves that existing behavior.
        viewModel.firstReadOnboardingIntent = .predict
        guard viewModel.isAgeVerified else {
            ageSheetDestination = .guestCompass
            return
        }
        withAnimation(SimastryMotion.stateChange) {
            viewModel.currentScreen = .firstPrediction
        }
    }

    /// One-shot entrance: opacity + a short rise on a critically damped
    /// spring, stepped 60ms apart. Reduce Motion collapses it to a crossfade.
    private func reveal(step: Int, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (appeared ? 0 : 10))
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2)
                    : .spring(SimastrySpring.settle).delay(Double(step) * 0.06),
                value: appeared
            )
    }
}

extension AppViewModel.PostAgeDestination: Identifiable {
    var id: String {
        switch self {
        case .guestCompass: "guestCompass"
        case .setupFlow: "setupFlow"
        }
    }
}

/// The 18+ and AI disclosure, presented as a concise native sheet. Confirming
/// writes the versioned attestation; declining simply returns to the welcome.
private struct AgeDisclosureSheet: View {
    let onConfirm: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Before we begin")
                    .font(.title2.bold())
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(.top, 28)
                    .accessibilityAddTraits(.isHeader)

                Text("Simastry is for adults 18+. It offers AI guidance—not therapy, professional advice, or emergency support. You remain in control of every decision.")
                    .font(.body)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                actionColumn
                    .padding(.top, 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(SimastryColor.midnight)
    }

    private var actionColumn: some View {
        VStack(spacing: 10) {
            Button {
                HapticManager.buttonPress()
                onConfirm()
            } label: {
                Text("I’m 18 or older")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityIdentifier("ageGate.over18")

            Button {
                HapticManager.buttonPress()
                onDecline()
            } label: {
                Text("Not now")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityIdentifier("ageGate.notNow")

            HStack(spacing: 14) {
                Link("Terms", destination: AppConfig.termsOfServiceURL)
                Text("·").accessibilityHidden(true)
                Link("Privacy", destination: AppConfig.privacyPolicyURL)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(SimastryColor.textTertiary)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
    }
}

#Preview {
    WelcomeView(viewModel: AppViewModel())
}
