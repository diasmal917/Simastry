import SwiftUI

/// The user's work-style read from their own chart signals — the career
/// lens. Patterns for reflection, never a forecast.
struct CareerReadView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var bossSign: ZodiacSign?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let sun = viewModel.userSunSign {
                        heroCard(sun: sun)
                        pressureCard
                        firstWeekCard
                        strengthsAndWatchOut(sun: sun)
                        bossDecoder
                        methodPanel
                        honestyFooter
                    } else {
                        missingChartCard
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            // Backdrop via `.presentationBackground` so content insets below the
            // nav bar (no full-bleed ZStack layer that would clip the top).
            .navigationTitle("Career Read")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private func heroCard(sun: ZodiacSign) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("HOW YOU WORK")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.5)

                Spacer()

                ZodiacIconView(sign: sun, size: 26, showsGlow: true)
            }

            Text(CareerTemplates.workStyle[sun] ?? "")
                .font(SimastryFont.bodyLarge)
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroGlass(SimastryColor.gold, cornerRadius: 22)
    }

    @ViewBuilder
    private var pressureCard: some View {
        if let moon = viewModel.userMoonSign, let line = CareerTemplates.underPressure[moon] {
            readCard(
                title: "UNDER PRESSURE",
                icon: "gauge.with.needle.fill",
                tint: SimastryColor.celestialBlue,
                signal: "\(moon.displayName) Moon",
                body: line
            )
        }
    }

    @ViewBuilder
    private var firstWeekCard: some View {
        if let rising = viewModel.userRisingSign, let line = CareerTemplates.firstWeekRead[rising] {
            readCard(
                title: "THE FIRST-WEEK READ",
                icon: "person.crop.rectangle.badge.plus",
                tint: SimastryColor.risingViolet,
                signal: "\(rising.displayName) Rising",
                body: line
            )
        }
    }

    private func strengthsAndWatchOut(sun: ZodiacSign) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("STRENGTHS ON PAPER AND IN ROOMS")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            HStack(spacing: 8) {
                ForEach(CareerTemplates.strengths[sun] ?? [], id: \.self) { strength in
                    Text(strength)
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(SimastryColor.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(SimastryColor.gold.opacity(0.22), lineWidth: 0.6)
                        }
                }
            }

            if let watchOut = CareerTemplates.watchOut[sun] {
                VStack(alignment: .leading, spacing: 5) {
                    Text("WORTH WATCHING")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.amber)
                        .tracking(1)

                    Text(watchOut)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.82))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SimastryColor.amber.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    /// Pick the boss's (or any colleague's) sign and get the existing
    /// how-to-talk guidance through a work lens.
    private var bossDecoder: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.celestialBlue)

                Text("DECODE YOUR BOSS")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            Text("Know their sign? Tap it for the approach that works on them.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ZodiacSign.allCases) { sign in
                        VStack(spacing: 5) {
                            ZodiacBadgeView(sign: sign, isSelected: bossSign == sign, size: 40) {
                                withAnimation(.spring(SimastrySpring.snappy)) {
                                    bossSign = bossSign == sign ? nil : sign
                                }
                            }
                            .accessibilityLabel("Decode a \(sign.displayName) boss")

                            Text(sign.displayName)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(bossSign == sign ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                        }
                        .frame(width: 52)
                    }
                }
            }
            .scrollIndicators(.hidden)

            if let bossSign, let guide = CommunicationTemplates.guides[bossSign] {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A \(bossSign.displayName) boss")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(guide.bestApproach)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(guide.avoid)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.amber.opacity(0.9))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("For the raise or the pitch, open their playbook in People.")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.textTertiary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(bossSign.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
        .animation(.spring(SimastrySpring.smooth), value: bossSign)
    }

    private var methodPanel: some View {
        MethodLayerPanel(
            title: "Why this read",
            summary: "Your Sun maps decision and leadership style, your Moon maps how pressure lands, your Rising maps the first impression colleagues form.",
            signals: methodSignals,
            footer: "Astronomy calculates placements. Astrology interprets them. Simastry translates them into workplace communication guidance.",
            accent: viewModel.userSunSign?.color ?? SimastryColor.gold
        )
    }

    private var methodSignals: [MethodSignal] {
        var signals: [MethodSignal] = []
        if let sun = viewModel.userSunSign {
            signals.append(MethodSignal(label: "Sun", detail: "\(sun.displayName) work style", systemImage: "sun.max.fill", tint: sun.color))
        }
        if let moon = viewModel.userMoonSign {
            signals.append(MethodSignal(label: "Moon", detail: "\(moon.displayName) pressure response", systemImage: "moon.stars.fill", tint: moon.color))
        }
        if let rising = viewModel.userRisingSign {
            signals.append(MethodSignal(label: "Rising", detail: "\(rising.displayName) first impression", systemImage: "arrow.up.right.circle.fill", tint: rising.color))
        }
        return signals
    }

    private var honestyFooter: some View {
        Text("Patterns for reflection, not a verdict on your career — your chart describes style, never destiny.")
            .font(SimastryFont.captionSmall)
            .foregroundStyle(SimastryColor.textTertiary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var missingChartCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)

            Text("Set your signs first")
                .font(SimastryFont.titleMedium)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Your Career Read is built from your Sun, Moon, and Rising — add them on the Today tab to unlock it.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glossyCard(cornerRadius: 22)
    }

    private func readCard(title: String, icon: String, tint: Color, signal: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)

                Spacer()

                Text(signal)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.12), in: Capsule())
            }

            Text(body)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }
}
