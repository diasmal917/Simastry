import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        tabContainer
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

    /// On iOS 26 the system tab bar renders its own Liquid Glass — forcing a
    /// material would paint over it, so only the older OSes get the manual
    /// translucent treatment.
    @ViewBuilder
    private var tabContainer: some View {
        if #available(iOS 26.0, *) {
            tabView
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabView
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
        }
    }

    private var tabView: some View {
        TabView(selection: $viewModel.selectedTab) {
            Tab("Today", systemImage: "sun.max.fill", value: AppTab.today) {
                HomeView(viewModel: viewModel)
            }

            Tab(value: AppTab.messages) {
                MessagesView(viewModel: viewModel)
            } label: {
                Label("Messages", systemImage: "message.fill")
                    .environment(\.symbolVariants, .fill)
            }
            .badge(viewModel.unreadMessageCount)

            Tab("People", systemImage: "person.2.fill", value: AppTab.people) {
                PeopleView(viewModel: viewModel)
            }

            Tab("Me", systemImage: "person.crop.circle.fill", value: AppTab.me) {
                ProfileView(viewModel: viewModel)
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
