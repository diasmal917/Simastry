import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: AppViewModel

    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                Group {
                    switch viewModel.homeSetupPhase {
                    case .modeSelection:
                        ModeSelectionView(viewModel: viewModel)
                    case .signSelection:
                        SignSelectionView(viewModel: viewModel)
                    case .companionSetup:
                        CompanionSetupView(viewModel: viewModel)
                    case .soulCreation:
                        SoulCreationView(viewModel: viewModel)
                    case .complete:
                        homeContent
                    }
                }
                .animation(.spring(SimastrySpring.smooth), value: viewModel.homeSetupPhase == .complete)
            }
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 16)

                greetingSection

                predictReplyCard

                if let companion = viewModel.primaryCompanion,
                   let companionSign = ZodiacSign(rawValue: companion.sunSign) {
                    communicationFocusCard(companionName: companion.name, companionSign: companionSign)
                }

                featureGrid

                if let companion = viewModel.primaryCompanion {
                    companionCard(companion)
                }

                if let sun = viewModel.userSunSign {
                    todayEnergyCard(sun: sun)
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, 20)
            .onAppear {
                guard !appeared else { return }
                withAnimation(.spring(SimastrySpring.smooth).delay(0.05)) {
                    appeared = true
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var greetingSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingText)
                    .font(.system(size: 14))
                    .foregroundStyle(SimastryColor.mutedSilver)

                if let name = viewModel.profile?.displayName {
                    Text("Hey, \(name)")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)
                } else {
                    Text("Welcome back")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)
                }
            }

            Spacer()

            if let sun = viewModel.userSunSign {
                Text(sun.glyph)
                    .font(.system(size: 28))
                    .foregroundStyle(sun.color)
                    .frame(width: 48, height: 48)
                    .background(sun.color.opacity(0.14), in: Circle())
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    private func communicationFocusCard(companionName: String, companionSign: ZodiacSign) -> some View {
        let guide = CommunicationTemplates.guides[companionSign]
        let tips = guide?.tips ?? []
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let tipIndex = (dayOfYear - 1) % max(tips.count, 1)
        let todayTip = tips.isEmpty ? "Learn their sign to communicate better." : tips[tipIndex]

        return Button {
            HapticManager.buttonPress()
            viewModel.guideFocusSign = companionSign
            viewModel.selectedTab = 3
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SimastryColor.celestialBlue)

                    Text("Today with \(companionName)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)

                    Spacer()

                    Text(companionSign.glyph)
                        .font(.system(size: 18))
                        .foregroundStyle(companionSign.color)
                }

                Text(todayTip)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                if let approach = guide?.bestApproach {
                    Text(approach)
                        .font(.system(size: 13))
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text("Read full guide")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SimastryColor.celestialBlue)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SimastryColor.celestialBlue)
                }
                .padding(.top, 2)
            }
            .padding(20)
            .tintedGlass(SimastryColor.celestialBlue.opacity(0.12), cornerRadius: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(SimastryColor.celestialBlue.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var predictReplyCard: some View {
        Button {
            HapticManager.buttonPress()
            viewModel.selectedTab = 2
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SimastryColor.risingViolet)

                        Text("PREDICT REPLY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(SimastryColor.risingViolet)
                            .tracking(1.2)
                    }

                    Text("What will they say next?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)

                    Text("Paste a conversation and let the stars predict their next text.")
                        .font(.system(size: 13))
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(SimastryColor.risingViolet)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(20)
            .tintedGlass(SimastryColor.risingViolet.opacity(0.14), cornerRadius: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(SimastryColor.risingViolet.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var featureGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            featureGridCard(
                title: "Guides",
                subtitle: "What to say",
                systemImage: "bubble.left.and.bubble.right.fill",
                tint: SimastryColor.celestialBlue
            ) {
                viewModel.selectedTab = 3
            }

            featureGridCard(
                title: "Simulate",
                subtitle: "Test a reply",
                systemImage: "wand.and.stars",
                tint: SimastryColor.risingViolet
            ) {
                viewModel.selectedTab = 2
            }

            featureGridCard(
                title: "Soulmate",
                subtitle: "Find your match",
                systemImage: "heart.circle.fill",
                tint: SimastryColor.sunCoral
            ) {
                viewModel.selectedTab = 0
                viewModel.homeSetupPhase = .modeSelection
            }

            featureGridCard(
                title: "Companions",
                subtitle: "Your circle",
                systemImage: "sparkles",
                tint: SimastryColor.gold
            ) {
                viewModel.selectedTab = 1
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private func featureGridCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 12))

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .simastryGlass(cornerRadius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(tint.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
    }

    private func companionCard(_ companion: CompanionData) -> some View {
        let level = RelationshipLevel.from(messageCount: companion.conversationCount)

        return Button {
            HapticManager.buttonPress()
            viewModel.selectedTab = 1
        } label: {
            HStack(spacing: 14) {
                GlossyOrbView(
                    signColors: [
                        ZodiacSign(rawValue: companion.sunSign)?.color ?? SimastryColor.gold,
                        ZodiacSign(rawValue: companion.moonSign)?.color ?? SimastryColor.celestialBlue
                    ],
                    state: .idle,
                    size: 50
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(companion.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)

                    HStack(spacing: 6) {
                        Text(level.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SimastryColor.midnight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(SimastryColor.gold, in: .capsule)

                        Text("\(companion.conversationCount) sparks")
                            .font(.system(size: 12))
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(companion.compatibilityScore)%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                    Text("match")
                        .font(.system(size: 10))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .padding(18)
            .simastryGlass(cornerRadius: 20)
        }
        .buttonStyle(SpringPressStyle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private func todayEnergyCard(sun: ZodiacSign) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                CelestialRoleIcon(role: .sun, size: 28)
                Text("Your Energy Today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)
                Spacer()
            }

            Text(AstrologyTemplates.sunSign[sun.rawValue] ?? "")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                .lineSpacing(3)
        }
        .padding(18)
        .simastryGlass(cornerRadius: 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }
}
