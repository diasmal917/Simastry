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
    /// The real thing, before any tap: today's windows computed on-device
    /// with zero personal data (nil natal, nil location, practical style),
    /// exactly like the guest Compass one screen later.
    @State private var dayWindows: DayWindowsResult?
    @State private var computedDayWindowsKey: String?

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

                TimelineView(.everyMinute) { context in
                    nowLineCard(compact: compact, now: context.date)
                        .task(id: DailyGuidance.dateKey(for: context.date)) {
                            guard computedDayWindowsKey != DailyGuidance.dateKey(for: context.date) else { return }
                            let inputs = DayWindowsEngine.Inputs(
                                date: context.date,
                                timeZone: .current,
                                natalSun: nil,
                                natalMoon: nil,
                                natalRising: nil,
                                style: .practical
                            )
                            dayWindows = await DayWindowsEngine.windows(for: inputs)
                            computedDayWindowsKey = DailyGuidance.dateKey(for: context.date)
                        }
                }

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

    /// The real current window, or a shimmer while the first compute lands.
    /// Never a canned briefing: if there is nothing computed to show (which
    /// only happens for a stale cross-midnight result), the card disappears
    /// and the static promise above carries the screen.
    @ViewBuilder
    private func nowLineCard(compact: Bool, now: Date) -> some View {
        if let line = LandingNowLine.compose(result: dayWindows, now: now) {
            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                nowLineKicker

                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: compassIcon(for: line.window))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(compassTint(for: line.window.tokenID))
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(line.window.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(line.untilText)
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }

                Text("Computed from today’s sky · on this device.")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(compact ? 15 : 17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .landingGlass(cornerRadius: 24, emphasis: .card)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("landing.nowLine")
            .accessibilityLabel(
                "Right now: \(line.window.title). \(line.untilText). Computed from today's sky on this device."
            )
        } else if dayWindows == nil {
            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                nowLineKicker
                HStack(spacing: 11) {
                    Circle()
                        .fill(.white.opacity(0.10))
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.white.opacity(0.10))
                            .frame(width: 210, height: 18)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.white.opacity(0.10))
                            .frame(width: 110, height: 13)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(compact ? 15 : 17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .landingGlass(cornerRadius: 24, emphasis: .card)
            .skeletonShimmer()
            .accessibilityLabel("Computing today's windows")
        }
    }

    private var nowLineKicker: some View {
        Label("RIGHT NOW", systemImage: "location.north.circle.fill")
            .font(.caption2.bold())
            .tracking(1.2)
            .foregroundStyle(CrystalMood.gold)
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

/// The landing's current-window line, composed from the same engine output
/// the dial renders. Pure and testable: the real active window in the
/// dial's "until h:mm a" format, or nil whenever there is nothing computed
/// to show — the landing never substitutes canned data.
nonisolated enum LandingNowLine {
    struct Line: Equatable {
        let window: DayWindow
        let untilText: String
    }

    static func compose(result: DayWindowsResult?, now: Date) -> Line? {
        guard let result, let window = result.window(at: now) else { return nil }
        return Line(window: window, untilText: "until \(landingClockFormatter.string(from: window.interval.end))")
    }
}

private let landingClockFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter
}()

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
