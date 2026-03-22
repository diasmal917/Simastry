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
                Text("Compatibility")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.5)
                    .textCase(.uppercase)
                Spacer()
            }

            if let userSun = viewModel.userSunSign, let compSun = companionSun {
                let userElement = userSun.element.rawValue
                let compElement = compSun.element.rawValue
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your \(userElement) meets their \(compElement)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(SimastryColor.offWhite)
                        Spacer()
                        CompatibilityRingView(score: companion.compatibilityScore, size: 44)
                    }

                    Text(AstrologyTemplates.elementPairingText(element1: userElement, element2: compElement))
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                        .lineSpacing(3)
                }
                .padding(16)
                .simastryGlass(cornerRadius: 16)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
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
