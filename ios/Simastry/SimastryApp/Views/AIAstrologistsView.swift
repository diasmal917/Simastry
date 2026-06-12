import SwiftUI

/// The guides catalog, Netflix-shaped: a featured pane, horizontal shelves
/// of poster cards (Your panel, chart matches, elements), and a dense
/// all-guides grid. Tapping any poster opens the guide's full profile —
/// the directory browses, the profile sells.
struct AIAstrologistsView: View {
    @Bindable var viewModel: AppViewModel
    let initialProfileId: String?

    @State private var pushedProfileId: String?
    @State private var handledInitialPush: Bool = false

    init(viewModel: AppViewModel, initialProfileId: String? = nil) {
        self.viewModel = viewModel
        self.initialProfileId = initialProfileId
    }

    private var profiles: [FactoryCompanionProfile] {
        FactoryCompanionCatalog.all
    }

    private var panelShelf: [FactoryCompanionProfile] {
        viewModel.panelGuideEntries.map(\.profile)
    }

    /// Guides whose lens matches the user's chart — same sign or same
    /// element as any placement — excluding the panel (its own shelf).
    private var matchesShelf: [FactoryCompanionProfile] {
        let panelIds = Set(panelShelf.map(\.id))
        let userSigns = [viewModel.userSunSign, viewModel.userMoonSign, viewModel.userRisingSign].compactMap { $0 }
        guard !userSigns.isEmpty else { return [] }
        let userElements = Set(userSigns.map(\.element))

        return profiles.filter { profile in
            !panelIds.contains(profile.id)
                && (userSigns.contains(profile.sign) || userElements.contains(profile.sign.element))
        }
    }

    private func elementShelf(_ element: ZodiacElement) -> [FactoryCompanionProfile] {
        profiles.filter { $0.sign.element == element }
    }

    private func elementTitle(_ element: ZodiacElement) -> String {
        switch element {
        case .fire: "FIRE — momentum and candor"
        case .earth: "EARTH — proof and patience"
        case .air: "AIR — ideas and timing"
        case .water: "WATER — feeling and depth"
        }
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Every guide is trained in the Simastry Method and reads through one zodiac lens. Tap a face to see their profile.")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)

                    if !panelShelf.isEmpty {
                        shelf(title: "YOUR PANEL", profiles: panelShelf)
                    }

                    if !matchesShelf.isEmpty {
                        shelf(title: "MATCHES YOUR CHART", profiles: matchesShelf)
                    }

                    ForEach(ZodiacElement.allCases, id: \.self) { element in
                        shelf(title: elementTitle(element), profiles: elementShelf(element))
                    }

                    allGuidesGrid

                    Spacer().frame(height: SimastrySpacing.tabBarClearance + 12)
                }
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Guides")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $pushedProfileId) { profileId in
            if let profile = profiles.first(where: { $0.id == profileId }) {
                GuideProfileView(viewModel: viewModel, profile: profile)
            }
        }
        .onAppear {
            guard !handledInitialPush, let initialProfileId else { return }
            handledInitialPush = true
            pushedProfileId = initialProfileId
        }
    }

    // MARK: - Shelves

    private func shelf(title: String, profiles: [FactoryCompanionProfile]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.4)
                .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(profiles) { profile in
                        posterCard(profile)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var allGuidesGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

        return VStack(alignment: .leading, spacing: 10) {
            Text("ALL 24 GUIDES")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.4)
                .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                    posterCard(profile, width: nil)
                        .modifier(DirectoryCardAppear(index: index))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// Netflix-density poster: portrait, name, sign band. Six or more
    /// visible per screen instead of 1.3 credential cards.
    private func posterCard(_ profile: FactoryCompanionProfile, width: CGFloat? = 104) -> some View {
        Button {
            HapticManager.buttonPress()
            pushedProfileId = profile.id
        } label: {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .aspectRatio(0.72, contentMode: .fit)
                    .overlay {
                        Image(profile.profileImageName)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.72)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text(profile.name)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 7)
                            .padding(.bottom, 5)
                    }

                HStack(spacing: 4) {
                    ZodiacIconView(sign: profile.sign, size: 11, showsGlow: false)
                    Text(profile.sign.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(profile.sign.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(profile.sign.color.opacity(0.10))
            }
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(profile.sign.color.opacity(0.30), lineWidth: 0.7)
            }
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(profile.name), \(profile.sign.displayName) Guide. Opens profile.")
    }
}

/// Index-staggered rise-in for grid posters. Lazily created cards
/// (scrolled into view later) animate too, with the delay capped so deep
/// scrolling never feels laggy.
private struct DirectoryCardAppear: ViewModifier {
    let index: Int
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.spring(SimastrySpring.smooth).delay(Double(min(index, 5)) * 0.06)) {
                        appeared = true
                    }
                }
            }
    }
}
