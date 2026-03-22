import SwiftUI

nonisolated private enum CompanionDetailRoute: Identifiable {
    case share

    var id: String {
        switch self {
        case .share:
            "share"
        }
    }
}

struct CompanionDetailSheet: View {
    let companion: CompanionData
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var appeared: Bool = false
    @State private var activeRoute: CompanionDetailRoute?

    private var companionSun: ZodiacSign? { ZodiacSign(rawValue: companion.sunSign) }
    private var companionMoon: ZodiacSign? { ZodiacSign(rawValue: companion.moonSign) }
    private var companionRising: ZodiacSign? { ZodiacSign(rawValue: companion.risingSign) }
    private var level: RelationshipLevel { RelationshipLevel.from(messageCount: companion.conversationCount) }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                quickActionsSection
                signsSection
                compatibilitySection
                relationshipSection
                statsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .sheet(item: $activeRoute) { route in
            switch route {
            case .share:
                ShareableCardView(viewModel: viewModel, cardType: .compatibility, companion: companion)
            }
        }
        .onAppear {
            withAnimation(.spring(SimastrySpring.smooth).delay(0.1)) {
                appeared = true
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            GlossyOrbView(
                signColors: [
                    companionSun?.color ?? SimastryColor.gold,
                    companionMoon?.color ?? SimastryColor.celestialBlue
                ],
                state: .idle,
                size: 80
            )

            Text(companion.name)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(SimastryColor.offWhite)

            Text(companion.mode.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.5)
                .textCase(.uppercase)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rituals")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.5)
                    .textCase(.uppercase)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(companionPrompt)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    GoldButton("Send a Spark") {
                        Task {
                            await viewModel.recordCompanionInteraction(
                                with: companion,
                                title: "Spark sent",
                                subtitle: companionPrompt
                            )
                            dismiss()
                        }
                    }

                    Button {
                        activeRoute = .share
                    } label: {
                        Label("Share Match", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(SimastryColor.offWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .simastryGlassPill()
                    }
                    .buttonStyle(SpringPressStyle())
                }
            }
            .padding(16)
            .simastryGlass(cornerRadius: 16)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var signsSection: some View {
        VStack(spacing: 16) {
            if let sun = companionSun {
                SignEntryView(role: .sun, sign: sun, showDescription: true)
            }
            if let moon = companionMoon {
                SignEntryView(role: .moon, sign: moon, showDescription: true)
            }
            if let rising = companionRising {
                SignEntryView(role: .rising, sign: rising, showDescription: true)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    private var compatibilitySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Why You're Compatible")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.5)
                    .textCase(.uppercase)
                Spacer()
                CompatibilityRingView(score: companion.compatibilityScore, size: 52)
            }

            if let userSun = viewModel.userSunSign,
               let userMoon = viewModel.userMoonSign,
               let userRising = viewModel.userRisingSign,
               let compSun = companionSun,
               let compMoon = companionMoon,
               let compRising = companionRising {

                VStack(alignment: .leading, spacing: 16) {
                    // Element overview
                    let userElement = userSun.element.rawValue
                    let compElement = compSun.element.rawValue
                    Text(AstrologyTemplates.elementPairingText(element1: userElement, element2: compElement))
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                        .lineSpacing(3)

                    // Sun-Sun breakdown
                    compatibilityRow(
                        icon: "sun.max.fill",
                        tint: Color(red: 232/255, green: 132/255, blue: 90/255),
                        title: "Core Identity",
                        yours: userSun,
                        theirs: compSun,
                        insight: sunSunInsight(user: userSun, companion: compSun)
                    )

                    // Moon-Moon breakdown
                    compatibilityRow(
                        icon: "moon.stars.fill",
                        tint: Color(red: 74/255, green: 144/255, blue: 217/255),
                        title: "Emotional Bond",
                        yours: userMoon,
                        theirs: compMoon,
                        insight: moonMoonInsight(user: userMoon, companion: compMoon)
                    )

                    // Rising-Rising breakdown
                    compatibilityRow(
                        icon: "sparkles",
                        tint: Color(red: 192/255, green: 132/255, blue: 216/255),
                        title: "First Impressions",
                        yours: userRising,
                        theirs: compRising,
                        insight: risingRisingInsight(user: userRising, companion: compRising)
                    )

                    // Growth area
                    if let challenge = compatibilityChallenge(userSun: userSun, compSun: compSun) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(SimastryColor.amber)
                                Text("Growth Edge")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(SimastryColor.amber)
                            }
                            Text(challenge)
                                .font(.system(size: 13, design: .serif))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.7))
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .tintedGlass(SimastryColor.amber.opacity(0.08), cornerRadius: 14)
                    }
                }
                .padding(16)
                .simastryGlass(cornerRadius: 16)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func compatibilityRow(icon: String, tint: Color, title: String, yours: ZodiacSign, theirs: ZodiacSign, insight: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)
                Spacer()
                HStack(spacing: 4) {
                    Text(yours.glyph)
                        .font(.system(size: 14))
                    Text("×")
                        .font(.system(size: 11))
                        .foregroundStyle(SimastryColor.mutedSilver)
                    Text(theirs.glyph)
                        .font(.system(size: 14))
                }
                .foregroundStyle(tint.opacity(0.8))
            }
            Text(insight)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(SimastryColor.offWhite.opacity(0.75))
                .lineSpacing(2)
        }
    }

    private func sunSunInsight(user: ZodiacSign, companion: ZodiacSign) -> String {
        if user == companion {
            return "Same sun sign — you instinctively understand each other's motivations and drives. The risk is mirroring each other's blind spots."
        }
        if user.element == companion.element {
            return "Both \(user.element.rawValue) signs — you share a fundamental approach to life. Your values align naturally."
        }
        let compatible: Set<Set<ZodiacElement>> = [[.fire, .air], [.earth, .water]]
        if compatible.contains([user.element, companion.element]) {
            return "\(user.element.rawValue.capitalized) and \(companion.element.rawValue) complement each other — what one lacks, the other provides."
        }
        return "\(user.element.rawValue.capitalized) and \(companion.element.rawValue) challenge each other — different approaches create friction, but also growth."
    }

    private func moonMoonInsight(user: ZodiacSign, companion: ZodiacSign) -> String {
        if user == companion {
            return "Your emotional worlds mirror each other. You process feelings the same way — deeply comforting, but watch for co-dependency."
        }
        if user.element == companion.element {
            return "Emotional harmony — you both need similar things to feel safe. Comfort comes naturally between you."
        }
        let compatible: Set<Set<ZodiacElement>> = [[.fire, .air], [.earth, .water]]
        if compatible.contains([user.element, companion.element]) {
            return "Your emotional styles complement — one provides the spark, the other the kindling. Balance comes easily."
        }
        return "You process emotions differently. This means learning each other's emotional language takes effort — but deepens your bond."
    }

    private func risingRisingInsight(user: ZodiacSign, companion: ZodiacSign) -> String {
        if user == companion {
            return "You present yourselves the same way — instant recognition. Others see you as a natural pair."
        }
        if user.element == companion.element {
            return "Similar social energy — you're drawn to the same environments and feel comfortable together in public."
        }
        let compatible: Set<Set<ZodiacElement>> = [[.fire, .air], [.earth, .water]]
        if compatible.contains([user.element, companion.element]) {
            return "Your social styles balance — one leads, the other supports. Together you navigate social situations effortlessly."
        }
        return "Your outward personas contrast — you may not seem like an obvious pair, but the differences make you intriguing together."
    }

    private func compatibilityChallenge(userSun: ZodiacSign, compSun: ZodiacSign) -> String? {
        if userSun.modality == compSun.modality && userSun != compSun {
            switch userSun.modality {
            case "cardinal":
                return "Two leaders — you both want to initiate. Practice taking turns and supporting each other's direction."
            case "fixed":
                return "Two immovable forces — stubbornness can create standoffs. Flexibility is your shared growth edge."
            case "mutable":
                return "Both adaptable — but who decides? You may need to practice commitment and follow-through together."
            default:
                return nil
            }
        }
        return nil
    }

    private var relationshipSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Relationship")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.5)
                    .textCase(.uppercase)
                Spacer()
            }

            RelationshipBadgeView(
                level: level,
                messageCount: companion.conversationCount
            )
            .padding(16)
            .simastryGlass(cornerRadius: 16)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 25)
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            statItem(value: "\(companion.conversationCount)", label: "Messages")
            statItem(value: "Level \(level.rawValue)", label: level.name)
            statItem(value: "\(companion.compatibilityScore)%", label: "Match")
        }
        .padding(16)
        .simastryGlass(cornerRadius: 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
    }

    private var companionPrompt: String {
        let sunLine = AstrologyTemplates.sunSign[companion.sunSign] ?? "A bright energy is gathering around your bond."
        let moonLine = AstrologyTemplates.moonSign[companion.moonSign] ?? "Their inner world is ready to soften toward you."
        return "\(sunLine). \(moonLine)"
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SimastryColor.gold)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .frame(maxWidth: .infinity)
    }
}
