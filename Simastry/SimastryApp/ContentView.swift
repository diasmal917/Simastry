import SwiftUI
import Foundation

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                switch viewModel.currentScreen {
                case .landing:
                    LandingView(viewModel: viewModel)
                case .ageGate:
                    AgeGateView(viewModel: viewModel)
                case .firstReadChoice:
                    FirstReadChoiceView(viewModel: viewModel)
                case .firstPrediction:
                    FirstPredictionView(viewModel: viewModel)
                case .firstRead:
                    FirstReadView(viewModel: viewModel)
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

            if showsFloatingOnboardingLanguageMenu {
                VStack {
                    HStack {
                        Spacer()
                        OnboardingLanguageMenu()
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 18)

                    Spacer()
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
        .task {
            #if DEBUG
            if viewModel.applyDebugPreviewStateIfRequested() {
                return
            }
            #endif

            await viewModel.checkAuthState()
            viewModel.consumePendingShortcutDestination()
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                AnalyticsService.shared.endSession()
            } else if newPhase == .active {
                Task {
                    await viewModel.refreshRealtimeSurfaces()
                    viewModel.consumePendingShortcutDestination()
                }
            }
        }
        .onChange(of: viewModel.showUpsell) { _, wantsUpsell in
            guard wantsUpsell, !viewModel.isRevenueCatAvailable else { return }
            viewModel.showUpsell = false
            viewModel.showToast("Beta access active", subtitle: "Purchases are unavailable in this build.", isError: false)
        }
        .sheet(isPresented: upsellBinding) {
            UpsellModalView(viewModel: viewModel)
        }
    }

    private var upsellBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showUpsell && viewModel.isRevenueCatAvailable },
            set: { isPresented in
                if !isPresented {
                    viewModel.showUpsell = false
                }
            }
        )
    }

    private var showsFloatingOnboardingLanguageMenu: Bool {
        switch viewModel.currentScreen {
        case .landing, .ageGate, .firstReadChoice, .firstPrediction, .firstRead, .birthDetails, .signIn, .signUp:
            true
        case .loading, .home:
            false
        }
    }

    private var loadingView: some View {
        ZStack {
            SimastryColor.midnight.ignoresSafeArea()
            VStack(spacing: 16) {
                SimastryWordmark(font: .system(.title2, weight: .bold).italic())
                ProgressView()
                    .tint(SimastryColor.gold)
            }
        }
    }
}

struct OnboardingLanguageMenu: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        Menu {
            ForEach(LocalizationManager.Language.allCases) { language in
                Button {
                    HapticManager.buttonPress()
                    localization.currentLanguage = language
                } label: {
                    Label {
                        Text("\(language.shortCode) · \(language.displayName)")
                    } icon: {
                        if language == localization.currentLanguage {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "globe")
                .font(.system(size: SimastryIconSize.md, weight: .semibold))
            .foregroundStyle(SimastryColor.offWhite)
            .frame(width: 42, height: 42)
            .contentShape(Capsule())
            .simastryGlassPill(interactive: true)
        }
        .menuStyle(.button)
        .accessibilityLabel(localization.string("language.change"))
        .accessibilityValue(localization.currentLanguage.displayName)
    }
}
