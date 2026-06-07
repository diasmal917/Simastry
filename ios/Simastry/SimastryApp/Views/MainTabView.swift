import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.homeSetupPhase == .complete {
                PremiumBottomNavigation(
                    selectedTab: $viewModel.selectedTab,
                    unreadMessageCount: viewModel.unreadMessageCount
                )
                .padding(.horizontal, PremiumBottomNavigationStyle.horizontalPadding)
                .padding(.bottom, PremiumBottomNavigationStyle.bottomPadding)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .move(edge: .bottom))
                )
            }
        }
        .animation(reduceMotion ? nil : .spring(SimastrySpring.smooth), value: viewModel.homeSetupPhase == .complete)
        .onChange(of: viewModel.selectedTab) { _, newTab in
            HapticManager.tabChange()
            if newTab == 2 {
                Task {
                    await viewModel.refreshInbox(showErrors: false)
                }
            }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch viewModel.selectedTab {
        case 0:
            HomeView(viewModel: viewModel)
        case 1:
            CompanionsView(viewModel: viewModel)
        case 2:
            MessagesView(viewModel: viewModel)
        case 3:
            SimulateView(viewModel: viewModel)
        case 4:
            GuidesView(viewModel: viewModel)
        case 5:
            ProfileView(viewModel: viewModel)
        default:
            HomeView(viewModel: viewModel)
        }
    }
}

private enum PremiumBottomNavigationStyle {
    static let barHeight: CGFloat = 78
    static let totalHeight: CGFloat = 104
    static let maxWidth: CGFloat = 360
    static let cornerRadius: CGFloat = 34
    static let horizontalPadding: CGFloat = 14
    static let bottomPadding: CGFloat = 8
    static let sideItemWidth: CGFloat = 44
    static let sideIconSize: CGFloat = 30
    static let centerButtonSize: CGFloat = 62
    static let centerLift: CGFloat = -16
    static let glowOpacity: Double = 0.16
    static let shimmerDuration: Double = 6.5
    static let labelFontSize: CGFloat = 9
}

private struct PremiumBottomNavigation: View {
    @Binding var selectedTab: Int
    let unreadMessageCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: CGFloat = -180

    private let leftItems: [PremiumNavigationItem] = [
        .home,
        .companions
    ]

    private let rightItems: [PremiumNavigationItem] = [
        .messages,
        .profile
    ]

    var body: some View {
        ZStack {
            navSurface

            HStack(spacing: 4) {
                ForEach(leftItems) { item in
                    sideButton(for: item)
                }

                Spacer(minLength: PremiumBottomNavigationStyle.centerButtonSize + 8)

                ForEach(rightItems) { item in
                    sideButton(for: item)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: PremiumBottomNavigationStyle.barHeight)

            centerButton
                .offset(y: PremiumBottomNavigationStyle.centerLift)
        }
        .frame(maxWidth: PremiumBottomNavigationStyle.maxWidth)
        .frame(height: PremiumBottomNavigationStyle.totalHeight, alignment: .bottom)
        .accessibilityElement(children: .contain)
    }

    private var navSurface: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: PremiumBottomNavigationStyle.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.86),
                            SimastryColor.surface.opacity(0.88),
                            Color.black.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background {
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: PremiumBottomNavigationStyle.cornerRadius, style: .continuous)
                            .fill(.clear)
                            .glassEffect(
                                .regular.tint(SimastryColor.gold.opacity(0.08)),
                                in: .rect(cornerRadius: PremiumBottomNavigationStyle.cornerRadius)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: PremiumBottomNavigationStyle.cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: PremiumBottomNavigationStyle.cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    SimastryColor.goldLight.opacity(0.58),
                                    SimastryColor.gold.opacity(0.22),
                                    SimastryColor.goldDark.opacity(0.34)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: PremiumBottomNavigationStyle.cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                        .blur(radius: 0.2)
                        .mask(
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    shimmer(width: proxy.size.width)
                        .clipShape(
                            RoundedRectangle(cornerRadius: PremiumBottomNavigationStyle.cornerRadius, style: .continuous)
                        )
                }
                .shadow(color: SimastryColor.gold.opacity(0.045), radius: 10, y: 4)
                .shadow(color: .black.opacity(0.52), radius: 22, y: 14)
        }
        .frame(height: PremiumBottomNavigationStyle.barHeight)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            guard !reduceMotion else { return }
            shimmerPhase = -180
            withAnimation(.linear(duration: PremiumBottomNavigationStyle.shimmerDuration).repeatForever(autoreverses: false)) {
                shimmerPhase = 520
            }
        }
    }

    private func shimmer(width: CGFloat) -> some View {
        LinearGradient(
            colors: [
                .clear,
                SimastryColor.goldLight.opacity(reduceMotion ? 0 : 0.11),
                .white.opacity(reduceMotion ? 0 : 0.07),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 62, height: PremiumBottomNavigationStyle.barHeight * 1.35)
        .rotationEffect(.degrees(18))
        .offset(x: shimmerPhase - width / 2)
        .allowsHitTesting(false)
    }

    private var centerButton: some View {
        Button {
            select(.predict)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                SimastryColor.goldLight.opacity(isSelected(.predict) ? 0.36 : 0.18),
                                SimastryColor.gold.opacity(isSelected(.predict) ? 0.18 : 0.08),
                                Color.black.opacity(0.88)
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 58
                        )
                    )

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                SimastryColor.goldLight.opacity(0.88),
                                SimastryColor.gold.opacity(0.62),
                                SimastryColor.goldDark.opacity(0.50)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected(.predict) ? 1.7 : 1.2
                    )

                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    .padding(6)

                Image(systemName: "sparkle")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .white,
                                SimastryColor.goldLight,
                                SimastryColor.gold
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: SimastryColor.gold.opacity(0.55), radius: 8)
            }
            .frame(width: PremiumBottomNavigationStyle.centerButtonSize, height: PremiumBottomNavigationStyle.centerButtonSize)
            .background {
                Circle()
                    .fill(SimastryColor.gold.opacity(isSelected(.predict) ? PremiumBottomNavigationStyle.glowOpacity : 0.13))
                    .blur(radius: isSelected(.predict) ? 13 : 7)
            }
            .overlay(alignment: .bottom) {
                Text(PremiumNavigationItem.predict.title)
                    .font(.system(size: PremiumBottomNavigationStyle.labelFontSize, weight: .semibold))
                    .foregroundStyle(isSelected(.predict) ? SimastryColor.goldLight : SimastryColor.mutedSilver)
                    .offset(y: 18)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(PremiumNavigationItem.predict.accessibilityLabel)
        .accessibilityAddTraits(isSelected(.predict) ? [.isSelected] : [])
    }

    private func sideButton(for item: PremiumNavigationItem) -> some View {
        Button {
            select(item)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    iconPlate(for: item)

                    if item == .messages, unreadMessageCount > 0 {
                        Text(unreadMessageCount > 9 ? "9+" : "\(unreadMessageCount)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 15, height: 15)
                            .background(SimastryColor.sunCoral, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }

                Text(item.title)
                    .font(.system(size: PremiumBottomNavigationStyle.labelFontSize, weight: isSelected(item) ? .semibold : .medium))
                    .foregroundStyle(isSelected(item) ? SimastryColor.goldLight : SimastryColor.mutedSilver)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: PremiumBottomNavigationStyle.sideItemWidth, height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityAddTraits(isSelected(item) ? [.isSelected] : [])
    }

    private func iconPlate(for item: PremiumNavigationItem) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: item.plateColors(isSelected: isSelected(item)),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            item.tint.opacity(isSelected(item) ? 0.80 : 0.46),
                            SimastryColor.goldDark.opacity(0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected(item) ? 1.1 : 0.7
                )

            if item == .messages {
                Image(systemName: item.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .white,
                                SimastryColor.celestialBlue.opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: SimastryColor.celestialBlue.opacity(0.45), radius: 5)
            } else {
                Image(systemName: item.systemImage)
                    .font(.system(size: item == .companions ? 15 : 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isSelected(item)
                                ? [.white, item.tint, SimastryColor.gold]
                                : [SimastryColor.goldLight.opacity(0.84), item.tint.opacity(0.70)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(width: PremiumBottomNavigationStyle.sideIconSize, height: PremiumBottomNavigationStyle.sideIconSize)
        .shadow(color: item.tint.opacity(isSelected(item) ? 0.20 : 0.08), radius: isSelected(item) ? 7 : 3, y: 2)
    }

    private func select(_ item: PremiumNavigationItem) {
        guard selectedTab != item.tab else {
            HapticManager.buttonPress()
            return
        }

        selectedTab = item.tab
    }

    private func isSelected(_ item: PremiumNavigationItem) -> Bool {
        selectedTab == item.tab
    }
}

private enum PremiumNavigationItem: Int, CaseIterable, Identifiable {
    case home
    case companions
    case predict
    case messages
    case profile

    var id: Int { rawValue }

    var tab: Int {
        switch self {
        case .home: 0
        case .companions: 1
        case .messages: 2
        case .predict: 3
        case .profile: 5
        }
    }

    var title: String {
        switch self {
        case .home: "Home"
        case .companions: "Cast"
        case .predict: "Predict"
        case .messages: "DMs"
        case .profile: "Me"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .home: "Home"
        case .companions: "Companions"
        case .predict: "Predict"
        case .messages: "Messages"
        case .profile: "About me"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .companions: "sparkles"
        case .predict: "sparkle"
        case .messages: "bubble.left.fill"
        case .profile: "person.fill"
        }
    }

    var tint: Color {
        switch self {
        case .home: SimastryColor.goldLight
        case .companions: SimastryColor.gold
        case .predict: SimastryColor.goldLight
        case .messages: SimastryColor.celestialBlue
        case .profile: SimastryColor.goldLight
        }
    }

    func plateColors(isSelected: Bool) -> [Color] {
        if self == .messages {
            return isSelected
                ? [
                    SimastryColor.celestialBlue.opacity(0.92),
                    Color(red: 0.02, green: 0.24, blue: 0.62).opacity(0.92),
                    Color.black.opacity(0.74)
                ]
                : [
                    SimastryColor.celestialBlue.opacity(0.22),
                    Color.black.opacity(0.82)
                ]
        }

        return isSelected
            ? [
                SimastryColor.goldLight.opacity(0.30),
                tint.opacity(0.18),
                Color.black.opacity(0.84)
            ]
            : [
                Color.white.opacity(0.05),
                Color.black.opacity(0.78)
            ]
    }
}
