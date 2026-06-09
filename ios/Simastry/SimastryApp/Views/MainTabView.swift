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
        TabView(selection: tabSelection) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView(viewModel: viewModel)
            }

            Tab("People", systemImage: "person.2.fill", value: 1) {
                PeopleView(viewModel: viewModel)
            }

            Tab(value: 2) {
                MessagesView(viewModel: viewModel)
            } label: {
                Label("Messages", systemImage: "message.fill")
                    .environment(\.symbolVariants, .fill)
            }
            .badge(viewModel.unreadMessageCount)

            Tab("Me", systemImage: "person.crop.circle.fill", value: 5) {
                ProfileView(viewModel: viewModel)
            }
        }
        .tint(SimastryColor.gold)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
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

    private func normalizedTab(_ tab: Int) -> Int {
        tab == 3 || tab == 4 ? 0 : tab
    }

    private func normalizeSelection(_ tab: Int) {
        let normalized = normalizedTab(tab)
        guard normalized != tab else { return }
        viewModel.selectedTab = normalized
    }
}
