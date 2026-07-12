import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var activeSheet: AppSheetDestination?
    @State private var handledAccountHubRequest = 0

    var body: some View {
        // Native iOS 26 Liquid Glass tab bar. Using the system `TabView` means
        // the bar is real Liquid Glass, the selected tab sits in the system's
        // soft capsule, and `.tabBarMinimizeBehavior(.onScrollDown)` gives the
        // Instagram-style "settle on scroll-up, minimize on scroll-down" motion
        // — all maintained by the OS. `Tab(_:systemImage:value:)` is iOS 18+.
        TabView(selection: $viewModel.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.today) {
                HomeView(viewModel: viewModel)
            }

            Tab("Compass", systemImage: "location.north.circle", value: AppTab.predict) {
                PredictTabView(viewModel: viewModel)
            }
            .badge(viewModel.predictFollowUpPending ? Text("1") : nil)

            Tab("Talk", systemImage: "bubble.left.and.bubble.right.fill", value: AppTab.messages) {
                MessagesView(viewModel: viewModel)
            }
            .badge(viewModel.unreadMessageCount)

            Tab("People", systemImage: "person.2.fill", value: AppTab.people) {
                PeopleView(viewModel: viewModel)
            }
        }
        .tint(SimastryColor.gold)
        .accessibilityHidden(activeSheet != nil)
        // Vertical surfaces across every tab (and their pushed screens) must not
        // be draggable sideways; horizontal rows still scroll because their
        // content overflows.
        .lockHorizontalScroll()
        .alert("Apply invite code?", isPresented: inviteConfirmationBinding) {
            Button("Not now", role: .cancel) {
                viewModel.cancelPendingInviteCode()
            }
            Button("Apply") {
                viewModel.confirmPendingInviteCode()
            }
        } message: {
            Text("This saves the invite code on this device. Credits require server verification and are not granted locally.")
        }
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case .accountHub:
                AccountHubView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
                    .presentationBackground {
                        CelestialBackground()
                    }
            }
        }
        .onAppear {
            presentAccountHubIfRequested()
        }
        .onChange(of: viewModel.profileDrawerRouteRequest) {
            presentAccountHubIfRequested()
        }
        .onChange(of: viewModel.selectedTab) { _, newTab in
            HapticManager.tabChange()
            if newTab == .messages {
                Task {
                    await viewModel.refreshInbox(showErrors: false)
                    await viewModel.fetchConnectedProfiles()
                }
            }
        }
    }

    private func presentAccountHubIfRequested() {
        guard viewModel.profileDrawerRouteRequest > handledAccountHubRequest else { return }
        handledAccountHubRequest = viewModel.profileDrawerRouteRequest
        activeSheet = .accountHub
    }

    private var inviteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingInviteCodeForConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelPendingInviteCode()
                }
            }
        )
    }
}

struct AppTabFloatingHeader<Trailing: View>: View {
    @Bindable var viewModel: AppViewModel
    @ViewBuilder var trailing: () -> Trailing

    init(viewModel: AppViewModel, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.viewModel = viewModel
        self.trailing = trailing
    }

    var body: some View {
        // Lives inside each tab's `.safeAreaInset(edge: .top)`, so it always
        // reserves its own space — scrolled content can never collide with it.
        HStack(alignment: .center, spacing: 12) {
            Button {
                HapticManager.buttonPress()
                viewModel.openAccountHub()
            } label: {
                ProfileImageView(
                    image: viewModel.profileImage,
                    size: 48,
                    sunSign: viewModel.userSunSign
                )
                .background(.white.opacity(0.08), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder((viewModel.userSunSign?.color ?? SimastryColor.gold).opacity(0.5), lineWidth: 1.2)
                }
                .shadow(color: (viewModel.userSunSign?.color ?? SimastryColor.gold).opacity(0.22), radius: 12, y: 5)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Open Account Hub")
            .accessibilityHint("Shows your profile, chart, journal, settings, and help without leaving this tab.")
            .accessibilityIdentifier("app.header.profileButton")

            Text(viewModel.selectedTab.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .accessibilityIdentifier("app.header.tabTitle")

            Spacer(minLength: 12)

            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Fades the wallpaper up through the status bar for legibility.
            LinearGradient(
                colors: [.black.opacity(0.55), .black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }
}

/// Shared trailing-slot icon for `AppTabFloatingHeader` — a gold glyph on a
/// glass circle sized to a full 44pt tap target. Used by Talk (search) and
/// People (search, add) so both tabs share one implementation.
struct HeaderActionIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(SimastryColor.gold)
            .frame(width: 44, height: 44)
            .interactiveGlass(cornerRadius: 22, tint: SimastryColor.gold)
    }
}

struct HomeHeaderGreetingSummary: View {
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var formattedDate: String {
        SimastryDateFormatter.summaryDate.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formattedDate.uppercased())
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textTertiary)
                .tracking(1.4)

            Text(greetingText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SimastryColor.offWhite)
        }
        .multilineTextAlignment(.trailing)
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.header.greetingSummary")
    }
}

/// First-class Compass surface. `SimulateView` owns the progressive
/// flow (question type, details, orb generation, result, outcome rating), so
/// the tab just hosts it in its own navigation context.
struct PredictTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            SimulateView(viewModel: viewModel, showsTabHeader: true)
        }
    }
}
