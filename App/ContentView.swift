import SwiftUI
import Foundation

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var showResumeLoading = false
    @State private var shouldShowResumeLoadingOnActive = false
    @State private var resumeLoadingTask: Task<Void, Never>?
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

            if showResumeLoading {
                RacingZodiacLoadingView(mode: .resume)
                    .transition(.opacity)
                    .zIndex(20)
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
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
                shouldShowResumeLoadingOnActive = viewModel.currentScreen != .loading
                AnalyticsService.shared.endSession()
            } else if newPhase == .inactive {
                shouldShowResumeLoadingOnActive = viewModel.currentScreen != .loading
            } else if newPhase == .active {
                let shouldShowResume = shouldShowResumeLoadingIfNeeded()
                resumeLoadingTask?.cancel()
                resumeLoadingTask = Task {
                    if shouldShowResume {
                        Task {
                            try? await Task.sleep(for: .milliseconds(1400))
                            await MainActor.run {
                                hideResumeLoading()
                            }
                        }
                    }
                    await viewModel.refreshRealtimeSurfaces()
                    viewModel.consumePendingShortcutDestination()
                    if shouldShowResume {
                        await MainActor.run {
                            hideResumeLoading()
                        }
                    }
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
        RacingZodiacLoadingView(mode: .initialLoading)
    }

    @discardableResult
    private func shouldShowResumeLoadingIfNeeded() -> Bool {
        guard shouldShowResumeLoadingOnActive, viewModel.currentScreen != .loading else {
            shouldShowResumeLoadingOnActive = false
            return false
        }
        shouldShowResumeLoadingOnActive = false

        withAnimation(.easeOut(duration: 0.16)) {
            showResumeLoading = true
        }
        return true
    }

    private func hideResumeLoading() {
        guard showResumeLoading else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            showResumeLoading = false
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
                .font(.system(size: 16, weight: .semibold))
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

enum RacingZodiacLoadingMode {
    case initialLoading
    case resume
}

struct RacingZodiacLoadingView: View {
    let mode: RacingZodiacLoadingMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var zoomed = false
    @State private var settled = false
    @State private var glow = false
    @State private var showTimeoutFallback = false

    var body: some View {
        ZStack {
            SimastryColor.pureBlack.ignoresSafeArea()

            RadialGradient(
                colors: [
                    SimastryColor.celestialBlue.opacity(0.34),
                    SimastryColor.pureBlack.opacity(0.0)
                ],
                center: .center,
                startRadius: 24,
                endRadius: 360
            )
            .ignoresSafeArea()
            .opacity(glow ? 0.74 : 0.4)

            Text("Simastry")
                .font(.system(size: 72, weight: .bold).italic())
                .foregroundStyle(SimastryColor.offWhite)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .shadow(color: SimastryColor.gold.opacity(glow ? 0.5 : 0.14), radius: glow ? 32 : 12, y: glow ? 10 : 4)
                .scaleEffect(wordmarkScale)
                .opacity(wordmarkOpacity)
                .blur(radius: wordmarkBlur)
                .accessibilityHidden(true)

            if mode == .initialLoading {
                VStack(spacing: 18) {
                    Spacer()

                    SimastryWordmark(font: .system(size: 68, weight: .bold).italic())
                        .minimumScaleFactor(0.62)
                        .lineLimit(1)
                        .shadow(color: SimastryColor.gold.opacity(0.28), radius: 22, y: 7)

                    ProgressView()
                        .tint(SimastryColor.gold)
                        .scaleEffect(1.08)

                    if showTimeoutFallback {
                        Text("Still loading your session. If this takes much longer, check your connection and reopen Simastry.")
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 58)
                }
                .padding(.horizontal, 24)
                .opacity(stableLoadingOpacity)
            }
        }
        .clipped()
        .onAppear(perform: runAnimation)
        .task {
            guard mode == .initialLoading else { return }
            try? await Task.sleep(for: .seconds(8))
            showTimeoutFallback = true
        }
        .accessibilityLabel(mode == .initialLoading ? "Loading Simastry" : "Returning to Simastry")
        .accessibilityAddTraits(.isImage)
    }

    private var wordmarkScale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        return zoomed ? 7.4 : 0.88
    }

    private var wordmarkOpacity: Double {
        guard !reduceMotion else { return mode == .initialLoading ? 0.0 : 1.0 }
        return zoomed ? 0.0 : 1.0
    }

    private var wordmarkBlur: CGFloat {
        guard !reduceMotion else { return 0 }
        return zoomed ? 6.0 : 0
    }

    private var stableLoadingOpacity: Double {
        if reduceMotion { return 1.0 }
        return settled ? 1.0 : 0.0
    }

    private func runAnimation() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.22)) {
                glow = true
                settled = true
            }
            return
        }

        withAnimation(.timingCurve(0.08, 0.84, 0.12, 1.0, duration: mode == .initialLoading ? 0.84 : 0.72)) {
            zoomed = true
            glow = true
        }

        guard mode == .initialLoading else { return }

        Task {
            try? await Task.sleep(nanoseconds: 520_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.24)) {
                    settled = true
                }
            }
        }
    }
}
