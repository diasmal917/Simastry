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
    @State private var calibratedGuideIds: Set<String> = []

    init(viewModel: AppViewModel, initialProfileId: String? = nil) {
        self.viewModel = viewModel
        self.initialProfileId = initialProfileId
    }

    private static let profiles = FactoryCompanionCatalog.all

    private var panelShelf: [FactoryCompanionProfile] {
        viewModel.panelGuideEntries.map(\.profile)
    }

    private var directoryData: GuideDirectoryData {
        GuideDirectoryData(
            profiles: Self.profiles,
            panelProfiles: panelShelf,
            userSigns: [viewModel.userSunSign, viewModel.userMoonSign, viewModel.userRisingSign].compactMap { $0 }
        )
    }

    private func elementTitle(_ element: ZodiacElement) -> String {
        switch element {
        case .fire: "FIRE — momentum and candor"
        case .earth: "EARTH — proof and patience"
        case .air: "AIR — ideas and timing"
        case .water: "WATER — feeling and depth"
        }
    }

    @ViewBuilder
    var body: some View {
        if AppConfig.expertAstrologersEnabled {
            ExpertAstrologersView(viewModel: viewModel)
        } else {
            legacyDirectory
        }
    }

    private var legacyDirectory: some View {
        let data = directoryData

        return ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Every guide is an AI trained in the Simastry Method, reading through one zodiac lens. Tap a face to see their profile.")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)

                    if !data.panelProfiles.isEmpty {
                        shelf(title: "YOUR GUIDES", profiles: data.panelProfiles)
                    }

                    if !data.matchesShelf.isEmpty {
                        shelf(title: "MATCHES YOUR CHART", profiles: data.matchesShelf)
                    }

                    ForEach(ZodiacElement.allCases, id: \.self) { element in
                        shelf(title: elementTitle(element), profiles: data.elementShelf(element))
                    }

                    allGuidesGrid(profiles: data.profiles)

                    Spacer().frame(height: SimastrySpacing.tabBarEndClearance)
                }
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("guides.directory.screen")
        }
        .navigationTitle("Guides")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $pushedProfileId) { profileId in
            if let profile = data.profile(withId: profileId) {
                GuideProfileView(viewModel: viewModel, profile: profile)
            }
        }
        .onAppear {
            refreshCalibratedGuideIds()
            guard !handledInitialPush, let initialProfileId else { return }
            handledInitialPush = true
            pushedProfileId = initialProfileId
        }
        .onChange(of: pushedProfileId) {
            refreshCalibratedGuideIds()
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
                LazyHStack(spacing: 10) {
                    ForEach(profiles) { profile in
                        posterCard(profile, isCalibrated: calibratedGuideIds.contains(profile.id))
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func allGuidesGrid(profiles: [FactoryCompanionProfile]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

        return VStack(alignment: .leading, spacing: 10) {
            Text("ALL 24 GUIDES")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.4)
                .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                    posterCard(profile, width: nil, isCalibrated: calibratedGuideIds.contains(profile.id))
                        .modifier(DirectoryCardAppear(index: index))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// Netflix-density poster: portrait, name, sign band. Six or more
    /// visible per screen instead of 1.3 credential cards.
    private func posterCard(_ profile: FactoryCompanionProfile, width: CGFloat? = 104, isCalibrated: Bool) -> some View {
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
                    .overlay(alignment: .topTrailing) {
                        OnlineStatusDot()
                            .padding(7)
                    }
                    .overlay(alignment: .topLeading) {
                        if isCalibrated {
                            calibratedCardBadge
                                .padding(7)
                        }
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
                        .font(SimastryFont.microSemibold)
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
        .accessibilityIdentifier("guides.directory.card.\(profile.id)")
    }

    private func refreshCalibratedGuideIds() {
        calibratedGuideIds = GuideCalibrationStore.shared.calibratedGuideIds(in: Self.profiles.map(\.id))
    }

    private var calibratedCardBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "slider.horizontal.3")
                .font(SimastryFont.microBold)
            Text("Calibrated")
                .font(SimastryFont.microSemibold)
        }
        .foregroundStyle(SimastryColor.midnight)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(SimastryColor.gold.opacity(0.92), in: Capsule())
        .accessibilityHidden(true)
    }

}

private struct GuideDirectoryData {
    let profiles: [FactoryCompanionProfile]
    let panelProfiles: [FactoryCompanionProfile]
    let matchesShelf: [FactoryCompanionProfile]

    private let profilesByElement: [ZodiacElement: [FactoryCompanionProfile]]
    private let profilesById: [String: FactoryCompanionProfile]

    init(
        profiles: [FactoryCompanionProfile],
        panelProfiles: [FactoryCompanionProfile],
        userSigns: [ZodiacSign]
    ) {
        self.profiles = profiles
        self.panelProfiles = panelProfiles
        profilesByElement = Dictionary(grouping: profiles, by: \.sign.element)
        profilesById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        let panelIds = Set(panelProfiles.map(\.id))
        let userElements = Set(userSigns.map(\.element))
        matchesShelf = userSigns.isEmpty ? [] : profiles.filter { profile in
            !panelIds.contains(profile.id)
                && (userSigns.contains(profile.sign) || userElements.contains(profile.sign.element))
        }
    }

    func elementShelf(_ element: ZodiacElement) -> [FactoryCompanionProfile] {
        profilesByElement[element, default: []]
    }

    func profile(withId id: String) -> FactoryCompanionProfile? {
        profilesById[id]
    }
}

private struct OnlineStatusDot: View {
    private let green = Color(red: 0.31, green: 0.94, blue: 0.52)

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(green.opacity(0.28), lineWidth: 1)
                .frame(width: 10, height: 10)

            Circle()
                .fill(green)
                .frame(width: 6, height: 6)
                .overlay {
                    Circle()
                        .strokeBorder(.black.opacity(0.58), lineWidth: 0.8)
                }
                .shadow(color: green.opacity(0.34), radius: 2, y: 1)
        }
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
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
