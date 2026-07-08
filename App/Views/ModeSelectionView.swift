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
                        title: AppConfig.expertAstrologersEnabled ? "Choose your path" : "Choose your first guide",
                        subtitle: onboardingSubtitle,
                        step: 1,
                        totalSteps: 3,
                        labels: AppConfig.expertAstrologersEnabled ? ["Path", "Chart", "Experts"] : ["Path", "Signs", "Guide"]
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
                .padding(.bottom, SimastrySpacing.tabBarEndClearance)
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

            Text(AppConfig.expertAstrologersEnabled
                ? "Choose a path, calculate your chart signals, and bring your question to five expert AI astrologers."
                : "Choose a path, calculate your big three, and turn Sun, Moon, and Rising into a communication type.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                pill("Pick a path")
                pill(AppConfig.expertAstrologersEnabled ? "Calculate chart" : "Calculate signs")
                pill(AppConfig.expertAstrologersEnabled ? "Meet experts" : "Meet your guide")
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
            .simastryGlassPill()
    }

    private var isProUser: Bool {
        guard viewModel.isRevenueCatAvailable else { return true }
        let tier = viewModel.profile?.tier ?? "free"
        return tier == "pro"
    }

    private var onboardingSubtitle: String {
        if AppConfig.expertAstrologersEnabled {
            return viewModel.hasCompletedSigns
                ? "Your chart signals are ready. Start with expert astrologers, reply guidance, or a future read."
                : "Start with what you need today. We'll calculate your chart signals next, then introduce the expert astrologers."
        }
        return viewModel.hasCompletedSigns
            ? "Your chart signals are ready. Pick the voice that should translate them into message guidance."
            : "Start with the kind of guidance you want. We'll calculate your communication type next."
    }

    @ViewBuilder
    private func modeCard(mode: CompanionMode, icon: String, accent: Color, badge: String?, delay: Double) -> some View {
        Button(action: {
            HapticManager.buttonPress()
            handleModeSelection(mode)
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
                    Text(modeTitle(mode))
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(modeSubtitle(mode))
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

    private func handleModeSelection(_ mode: CompanionMode) {
        if mode == .simulateAnyone && !isProUser {
            viewModel.showToast("Pro feature", subtitle: "Predict The Future requires Simastry Pro", isError: true)
            viewModel.showUpsell = true
            return
        }

        viewModel.selectedMode = mode
        guard AppConfig.expertAstrologersEnabled else {
            viewModel.homeSetupPhase = viewModel.hasCompletedSigns ? .companionSetup : .signSelection
            return
        }

        guard viewModel.hasCompletedSigns else {
            viewModel.homeSetupPhase = .signSelection
            return
        }

        viewModel.homeSetupPhase = .complete
        switch mode {
        case .simulateAnyone:
            viewModel.openPredict()
        case .soulmate:
            viewModel.openAIAstrologists()
        case .bestie:
            viewModel.openAIAstrologists(question: "What should I reply back?", autoRunEveryone: false)
        }
    }

    private func modeTitle(_ mode: CompanionMode) -> String {
        guard AppConfig.expertAstrologersEnabled else { return mode.displayName }
        switch mode {
        case .simulateAnyone:
            return "Predict The Future"
        case .soulmate:
            return "Ask Expert Astrologers"
        case .bestie:
            return "Reply Guidance"
        }
    }

    private func modeSubtitle(_ mode: CompanionMode) -> String {
        guard AppConfig.expertAstrologersEnabled else { return mode.subtitle }
        switch mode {
        case .simulateAnyone:
            return "Explore timing and outcomes"
        case .soulmate:
            return "Consult five astrology traditions"
        case .bestie:
            return "Get help with what to say next"
        }
    }

    private func modeSupportText(_ mode: CompanionMode) -> String {
        if AppConfig.expertAstrologersEnabled {
            switch mode {
            case .simulateAnyone:
                return "Use this when you want a quick read on timing, direction, or what may unfold."
            case .soulmate:
                return "Ask once, then choose Leyla, Mateo, Naomi, Soren, Nadia, or Everyone mode."
            case .bestie:
                return "Bring a real message into the expert flow and shape a reply with astrological context."
            }
        }

        switch mode {
        case .simulateAnyone:
            return "Practice a conversation, rehearse an outcome, or explore a dynamic before it happens."
        case .soulmate:
            return "A charismatic guide lens for love, texting, timing, and emotional guidance."
        case .bestie:
            return "A playful, supportive guide with easy warmth and great banter."
        }
    }
}
