import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AppViewModel

    /// Tabs are built lazily on first visit, then kept alive so each surface
    /// preserves its scroll position and in-flight state across tab switches —
    /// the behaviour the system `TabView` gave us before the custom nav.
    @State private var visitedTabs: Set<AppTab> = [.today]

    var body: some View {
        ZStack {
            ForEach(AppTab.visualOrder) { tab in
                if visitedTabs.contains(tab) {
                    content(for: tab)
                        .opacity(viewModel.selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(viewModel.selectedTab == tab)
                        .accessibilityHidden(viewModel.selectedTab != tab)
                        .zIndex(viewModel.selectedTab == tab ? 1 : 0)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(
                selection: $viewModel.selectedTab,
                unreadCount: viewModel.unreadMessageCount,
                predictFollowUp: viewModel.predictFollowUpPending,
                // Read the shared chrome here in MainTabView's body so the
                // Observation dependency is registered and the safeAreaInset
                // content re-renders when the minimize state flips.
                isMinimized: TabBarChrome.shared.isMinimized
            )
        }
        .tint(SimastryColor.gold)
        .onAppear { visitedTabs.insert(viewModel.selectedTab) }
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
        .onChange(of: viewModel.selectedTab) { _, newTab in
            visitedTabs.insert(newTab)
            // Restore the full bar whenever the user changes tabs so a tab is
            // never first revealed with a minimized (compact-pill) nav.
            TabBarChrome.shared.isMinimized = false
            HapticManager.tabChange()
            if newTab == .messages {
                Task {
                    await viewModel.refreshInbox(showErrors: false)
                    await viewModel.fetchConnectedProfiles()
                }
            }
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            HomeView(viewModel: viewModel)
        case .predict:
            PredictTabView(viewModel: viewModel)
        case .messages:
            MessagesView(viewModel: viewModel)
        case .people:
            PeopleView(viewModel: viewModel)
        case .me:
            ProfileView(viewModel: viewModel)
        }
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

/// First-class Predict surface. `SimulateView` already owns the full guided
/// flow (question type, details, orb generation, result, outcome rating), so
/// the tab just hosts it in its own navigation context.
struct PredictTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            SimulateView(viewModel: viewModel)
        }
    }
}
