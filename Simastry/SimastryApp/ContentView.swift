import SwiftUI
import Foundation

struct ContentView: View {
    @State private var viewModel = AppViewModel()

    var body: some View {
        ZStack {
            Group {
                switch viewModel.currentScreen {
                case .landing:
                    LandingView(viewModel: viewModel)
                case .birthDetails:
                    BirthDetailsView(viewModel: viewModel)
                case .signUp:
                    SignUpView(viewModel: viewModel)
                case .signIn:
                    SignInView(viewModel: viewModel)
                case .loading:
                    loadingView
                case .home:
                    MainTabView(viewModel: viewModel)
                }
            }
            .animation(.spring(SimastrySpring.smooth), value: viewModel.currentScreen == .home)

            ToastOverlay(message: $viewModel.toastMessage)
        }
        .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
        .task {
            await viewModel.checkAuthState()
            if let pendingDeepLinkURL = AppDelegate.pendingDeepLinkURL {
                AppDelegate.pendingDeepLinkURL = nil
                viewModel.handleDeepLink(pendingDeepLinkURL)
            }
        }
        .onOpenURL { url in
            Task {
                await viewModel.handleIncomingURL(url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .simastryDeepLinkReceived)) { notification in
            guard let url = notification.object as? URL else { return }
            viewModel.handleDeepLink(url)
        }
        .sheet(isPresented: $viewModel.showUpsell) {
            UpsellModalView(viewModel: viewModel)
        }
    }

    private var loadingView: some View {
        ZStack {
            SimastryColor.midnight.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("S I M A S T R Y")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(1)
                ProgressView()
                    .tint(SimastryColor.gold)
            }
        }
    }
}
