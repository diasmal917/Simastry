import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AppViewModel

    private var tabSelection: Binding<Int> {
        Binding(
            get: {
                normalizedTab(viewModel.selectedTab)
            },
            set: { newValue in
                viewModel.selectedTab = normalizedTab(newValue)
            }
        )
    }

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
                Text("This will add \(AppViewModel.inviteRewardPredictions) welcome predictions to this account. Invite credits still need server verification before launch.")
            }
            .onAppear {
            normalizeSelection(viewModel.selectedTab)
        }
        .onChange(of: viewModel.selectedTab) { _, newTab in
            let normalized = normalizedTab(newTab)
            if normalized != newTab {
                viewModel.selectedTab = normalized
                return
            }
            HapticManager.tabChange()
            if normalized == 2 {
                Task {
                    await viewModel.refreshInbox(showErrors: false)
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
        } else {
            tabView
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
        }
    }

    private var tabView: some View {
        TabView(selection: tabSelection) {
            Tab("Today", systemImage: "sun.max.fill", value: 0) {
                HomeView(viewModel: viewModel)
            }

            Tab(value: 2) {
                MessagesView(viewModel: viewModel)
            } label: {
                Label("Messages", systemImage: "message.fill")
                    .environment(\.symbolVariants, .fill)
            }
            .badge(viewModel.unreadMessageCount)

            Tab("People", systemImage: "person.2.fill", value: 1) {
                PeopleView(viewModel: viewModel)
            }

            Tab("Me", systemImage: "person.crop.circle.fill", value: 5) {
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

    private func normalizedTab(_ tab: Int) -> Int {
        tab == 3 || tab == 4 ? 0 : tab
    }

    private func normalizeSelection(_ tab: Int) {
        let normalized = normalizedTab(tab)
        guard normalized != tab else { return }
        viewModel.selectedTab = normalized
    }
}
