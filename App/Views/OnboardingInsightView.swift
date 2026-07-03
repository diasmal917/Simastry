import SwiftUI

struct OnboardingInsightView: View {
    @Bindable var viewModel: AppViewModel
    @State private var headerAppeared: Bool = false
    @State private var headlineAppeared: Bool = false
    @State private var bodyAppeared: Bool = false
    @State private var tipAppeared: Bool = false
    @State private var miniCardsAppeared: Bool = false
    @State private var buttonAppeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sunSign: ZodiacSign { viewModel.userSunSign ?? .aries }
    private var moonSign: ZodiacSign { viewModel.userMoonSign ?? .aries }
    private var risingSign: ZodiacSign { viewModel.userRisingSign ?? .aries }

    private var firstName: String? {
        let raw = viewModel.profile?.displayName ?? viewModel.onboardingDisplayName
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "stargazer" else { return nil }
        return trimmed.components(separatedBy: " ").first
    }

    private var communicationType: CommunicationTypeProfile? {
        CommunicationTypeProfile.make(sun: sunSign, moon: moonSign, rising: risingSign)
    }

    private var panelGuides: [PanelMatcher.Entry] {
        PanelMatcher.panelGuides(sun: sunSign, moon: moonSign, rising: risingSign)
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(spacing: 26) {
                    Spacer().frame(height: 28)

                    signGlyphHeader
                        .opacity(headerAppeared ? 1 : 0)
                        .scaleEffect(headerAppeared ? 1 : 0.7)

                    Text("YOUR CHART, READ FOR YOU")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.gold)
                        .tracking(2.4)
                        .opacity(headlineAppeared ? 1 : 0)
                        .offset(y: headlineAppeared ? 0 : 10)

                    personalReadHeadline
                        .opacity(headlineAppeared ? 1 : 0)
                        .offset(y: headlineAppeared ? 0 : 12)

                    communicationTypeCard
                        .opacity(bodyAppeared ? 1 : 0)
                        .offset(y: bodyAppeared ? 0 : 14)

                    placementPanels
                        .opacity(tipAppeared ? 1 : 0)
                        .offset(y: tipAppeared ? 0 : 16)

                    advisoryPanelCard
                        .opacity(miniCardsAppeared ? 1 : 0)
                        .offset(y: miniCardsAppeared ? 0 : 18)

                    Spacer().frame(height: 4)

                    Text("This is a chart-based starting point. Your choices, context, and lived experience matter more than any placement.")
                        .font(SimastryFont.captionSmall)
                        .italic()
                        .foregroundStyle(SimastryColor.deepMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .opacity(buttonAppeared ? 1 : 0)

                    GoldButton(AppConfig.expertAstrologersEnabled ? "Meet Your Experts" : "Meet Your Panel") {
                        Task {
                            await viewModel.saveUserSigns()
                            viewModel.homeSetupPhase = AppConfig.expertAstrologersEnabled ? .complete : .companionSetup
                            if AppConfig.expertAstrologersEnabled {
                                viewModel.openAIAstrologists()
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .opacity(buttonAppeared ? 1 : 0)
                    .offset(y: buttonAppeared ? 0 : 20)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            startStaggeredReveal()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your personal insight based on \(sunSign.displayName) Sun sign")
    }

    // MARK: - Personal Read

    private var personalReadHeadline: some View {
        let opening: Text = firstName.map { Text("\($0), your ") } ?? Text("Your ")

        return (
            opening
            + Text("\(sunSign.displayName) Sun ").foregroundStyle(sunSign.color).bold()
            + Text("\(sunWant(for: sunSign)). Your ")
            + Text("\(moonSign.displayName) Moon ").foregroundStyle(moonSign.color).bold()
            + Text("\(moonRead(for: moonSign)). Your ")
            + Text("\(risingSign.displayName) Rising ").foregroundStyle(risingSign.color).bold()
            + Text("\(risingMove(for: risingSign)).")
        )
        .font(SimastryFont.displayMedium)
        .foregroundStyle(SimastryColor.offWhite)
        .multilineTextAlignment(.center)
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sunWant(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "wants momentum"
        case .taurus: "wants steadiness"
        case .gemini: "wants the conversation alive"
        case .cancer: "wants emotional safety"
        case .leo: "wants warmth back"
        case .virgo: "wants precision"
        case .libra: "wants fairness"
        case .scorpio: "wants the whole truth"
        case .sagittarius: "wants honesty"
        case .capricorn: "wants composure"
        case .aquarius: "wants room to think"
        case .pisces: "wants the feeling named"
        }
    }

    private func moonRead(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "reacts fast, then cools"
        case .taurus: "opens when things feel steady"
        case .gemini: "talks feelings into shape"
        case .cancer: "reads silence deeply"
        case .leo: "softens with warmth"
        case .virgo: "repairs in the details"
        case .libra: "listens for clean tone"
        case .scorpio: "tracks what goes unsaid"
        case .sagittarius: "needs room to feel"
        case .capricorn: "guards its composure"
        case .aquarius: "feels from a distance"
        case .pisces: "absorbs the whole room"
        }
    }

    private func risingMove(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "moves first"
        case .taurus: "steadies the room first"
        case .gemini: "asks first"
        case .cancer: "checks safety first"
        case .leo: "leads with presence"
        case .virgo: "sorts the details first"
        case .libra: "chooses tone first"
        case .scorpio: "scans for truth first"
        case .sagittarius: "answers with candor"
        case .capricorn: "holds back first"
        case .aquarius: "observes first"
        case .pisces: "feels it out first"
        }
    }

    // MARK: - Components

    private var signGlyphHeader: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [sunSign.color.opacity(0.4), sunSign.color.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [sunSign.color.opacity(0.35), sunSign.color.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [sunSign.color.opacity(0.6), sunSign.color.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: sunSign.color.opacity(0.3), radius: 20, y: 4)

            ZodiacIconView(sign: sunSign, size: 58, showsGlow: true)
        }
        .accessibilityLabel("\(sunSign.displayName) sign")
    }

    @ViewBuilder
    private var communicationTypeCard: some View {
        if let communicationType {
            VStack(spacing: 12) {
                Text("COMMUNICATION TYPE")
                    .font(SimastryFont.overline)
                    .foregroundStyle(communicationType.accent)
                    .tracking(1.8)

                Text(communicationType.title)
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .multilineTextAlignment(.center)

                if !communicationType.keywords.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(communicationType.keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(SimastryFont.labelSmall)
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.07), in: Capsule())
                                .overlay {
                                    Capsule().strokeBorder(communicationType.accent.opacity(0.25), lineWidth: 0.6)
                                }
                        }
                    }
                }

                Text(communicationType.summary)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 18)
            .heroGlass(communicationType.accent)
        }
    }

    private var placementPanels: some View {
        VStack(spacing: 10) {
            placementRow(
                icon: SimastryIcon.dailyRead,
                tint: SimastryColor.sunCoral,
                role: "Sun",
                sign: sunSign,
                line: communicationType?.sunSignal ?? ""
            )
            placementRow(
                icon: SimastryIcon.moon,
                tint: SimastryColor.celestialBlue,
                role: "Moon",
                sign: moonSign,
                line: communicationType?.moonSignal ?? ""
            )
            placementRow(
                icon: SimastryIcon.rising,
                tint: SimastryColor.risingViolet,
                role: "Rising",
                sign: risingSign,
                line: communicationType?.risingSignal ?? ""
            )
        }
    }

    private func placementRow(icon: String, tint: Color, role: String, sign: ZodiacSign, line: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(role.uppercased())
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.textTertiary)
                        .tracking(1.2)

                    Text(sign.displayName)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(sign.color)
                }

                Text(line)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your \(role) in \(sign.displayName). \(line)")
    }

    // MARK: - Advisory Panel

    private var advisoryPanelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: SimastryIcon.method)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SimastryColor.goldLight)

            Text(AppConfig.expertAstrologersEnabled ? "YOUR EXPERTS ARE READY" : "YOUR PANEL IS FORMING")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.goldLight)
                .tracking(1.6)

                Spacer()
            }

            Text(AppConfig.expertAstrologersEnabled ? "Five AI astrology specialists can read your question through distinct traditions." : "Three guides, trained in the Simastry Method, are matched to your placements.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if AppConfig.expertAstrologersEnabled {
                    ForEach(ExpertAstrologerRegistry.specialists) { specialist in
                        VStack(spacing: 7) {
                            if let profile = specialist.archivedProfile {
                                Image(profile.profileImageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 54, height: 54, alignment: .top)
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle().strokeBorder(SimastryColor.gold.opacity(0.65), lineWidth: 1.3)
                                    }
                                    .shadow(color: SimastryColor.gold.opacity(0.22), radius: 10, y: 4)
                            } else {
                                Text(specialist.placeholderAvatar)
                                    .font(SimastryFont.titleSmall)
                                    .foregroundStyle(SimastryColor.gold)
                                    .frame(width: 54, height: 54)
                                    .background(SimastryColor.gold.opacity(0.12), in: Circle())
                            }

                            VStack(spacing: 1) {
                                Text(specialist.characterName)
                                    .font(SimastryFont.labelSmall)
                                    .foregroundStyle(SimastryColor.offWhite)
                                    .lineLimit(1)

                                Text(specialist.publicTitle.replacingOccurrences(of: " Astrologer", with: ""))
                                    .font(SimastryFont.captionSmall)
                                    .foregroundStyle(SimastryColor.goldLight)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(specialist.characterName), \(specialist.publicTitle)")
                    }
                } else {
                    ForEach(panelGuides) { entry in
                    VStack(spacing: 7) {
                        Image(entry.profile.profileImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64, alignment: .top)
                            .clipShape(Circle())
                            .overlay {
                                Circle().strokeBorder(entry.sign.color.opacity(0.65), lineWidth: 1.5)
                            }
                            .shadow(color: entry.sign.color.opacity(0.25), radius: 10, y: 4)

                        VStack(spacing: 1) {
                            Text(entry.profile.name)
                                .font(SimastryFont.labelMedium)
                                .foregroundStyle(SimastryColor.offWhite)
                                .lineLimit(1)

                            Text("\(entry.role.displayName) lens")
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(entry.sign.color)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(entry.profile.name), your \(entry.role.displayName) lens guide, \(entry.sign.displayName)")
                    }
                }
            }
        }
        .padding(18)
        .heroGlass(SimastryColor.gold)
    }

    // MARK: - Animation

    private func startStaggeredReveal() {
        if reduceMotion {
            headerAppeared = true
            headlineAppeared = true
            bodyAppeared = true
            tipAppeared = true
            miniCardsAppeared = true
            buttonAppeared = true
            return
        }

        withAnimation(.spring(SimastrySpring.smooth).delay(0.1)) {
            headerAppeared = true
        }
        withAnimation(.spring(SimastrySpring.smooth).delay(0.35)) {
            headlineAppeared = true
        }
        withAnimation(.spring(SimastrySpring.smooth).delay(0.55)) {
            bodyAppeared = true
        }
        withAnimation(.spring(SimastrySpring.smooth).delay(0.75)) {
            tipAppeared = true
        }
        withAnimation(.spring(SimastrySpring.smooth).delay(0.95)) {
            miniCardsAppeared = true
        }
        withAnimation(.spring(SimastrySpring.bouncy).delay(1.2)) {
            buttonAppeared = true
        }
    }
}
