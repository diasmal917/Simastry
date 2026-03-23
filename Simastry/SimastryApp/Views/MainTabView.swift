import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView(viewModel: viewModel)
            }

            Tab("Companions", systemImage: "sparkles", value: 1) {
                CompanionsView(viewModel: viewModel)
            }

            Tab(value: 2) {
                MessagesView(viewModel: viewModel)
            } label: {
                Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
                    .environment(\.symbolVariants, .fill)
            }
            .badge(viewModel.unreadMessageCount)

            Tab("Predict", systemImage: "wand.and.stars", value: 3) {
                SimulateView(viewModel: viewModel)
            }

            Tab("Guides", systemImage: "book.fill", value: 4) {
                GuidesView(viewModel: viewModel)
            }

            Tab("Profile", systemImage: "person.circle.fill", value: 5) {
                ProfileView(viewModel: viewModel)
            }
        }
        .tint(SimastryColor.gold)
        .onChange(of: viewModel.selectedTab) { _, _ in
            HapticManager.tabChange()
        }
    }
}
