import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        // Native iOS 26 Liquid Glass tab bar. Using the system `TabView` means
        // the bar is real Liquid Glass, the selected tab sits in the system's
        // soft capsule, and `.tabBarMinimizeBehavior(.onScrollDown)` gives the
        // Instagram-style "settle on scroll-up, minimize on scroll-down" motion
        // — all maintained by the OS. `Tab(_:systemImage:value:)` is iOS 18+.
        TabView(selection: $viewModel.selectedTab) {
            Tab("Today", systemImage: "sun.max.fill", value: AppTab.today) {
                HomeView(viewModel: viewModel)
            }

            Tab("Predict", systemImage: "sparkles", value: AppTab.predict) {
                PredictTabView(viewModel: viewModel)
            }
            .badge(viewModel.predictFollowUpPending ? Text("!") : nil)

            Tab("Talk", systemImage: "bubble.left.and.bubble.right.fill", value: AppTab.messages) {
                MessagesView(viewModel: viewModel)
            }
            .badge(viewModel.unreadMessageCount)

            Tab("People", systemImage: "person.2.fill", value: AppTab.people) {
                PeopleView(viewModel: viewModel)
            }

            Tab("Me", systemImage: "person.crop.circle.fill", value: AppTab.me) {
                ProfileView(viewModel: viewModel)
            }
        }
        .tint(SimastryColor.gold)
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
            HapticManager.tabChange()
            if newTab == .messages {
                Task {
                    await viewModel.refreshInbox(showErrors: false)
                    await viewModel.fetchConnectedProfiles()
                }
            }
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
