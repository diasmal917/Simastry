import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AppViewModel

    private var tabSelection: Binding<Int> {
        Binding(
            get: {
                if viewModel.selectedTab == 3 || viewModel.selectedTab == 4 {
                    return 2
                }
                return viewModel.selectedTab
            },
            set: { newValue in
                viewModel.selectedTab = newValue
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Gram", systemImage: "camera.fill", value: 0) {
                HomeView(viewModel: viewModel)
            }

            Tab("Cast", systemImage: "person.2.fill", value: 1) {
                CompanionsView(viewModel: viewModel)
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
        .onAppear {
            normalizeSelection(viewModel.selectedTab)
        }
        .onChange(of: viewModel.selectedTab) { _, newTab in
            normalizeSelection(newTab)
            HapticManager.tabChange()
            if newTab == 2 {
                Task {
                    await viewModel.refreshInbox(showErrors: false)
                }
            }
        }
    }

    private func normalizeSelection(_ tab: Int) {
        guard tab == 3 || tab == 4 else { return }
        viewModel.selectedTab = 2
    }
}
