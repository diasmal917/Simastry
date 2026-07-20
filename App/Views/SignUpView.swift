import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isAuthenticating: Bool = false
    @State private var appeared: Bool = false
    @FocusState private var focusedField: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field: Hashable {
        case email, password
    }

    var body: some View {
        ZStack {
            // Still ink, matching the setup flow this screen concludes.
            SimastryColor.pureBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: navigateBack) {
                        Image(systemName: "chevron.left")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localization.string("common.back"))

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)

                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                VStack(spacing: 8) {
                                    Text(localization.string("auth.signUp.title"))
                                        .font(SimastryFont.displayMedium)
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(localization.string("auth.signUp.subtitle"))
                                        .font(SimastryFont.bodySmall)
                                        .foregroundStyle(SimastryColor.mutedSilver)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.top, 28)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: reduceMotion || appeared ? 0 : 20)
                                .animation(titleRevealAnimation, value: appeared)

                                Spacer(minLength: 32)

                                VStack(spacing: 16) {
                                    AppleSignInButton(isEnabled: !isAuthenticating) { result in
                                        guard !isAuthenticating else { return }
                                        isAuthenticating = true
                                        Task {
                                            await viewModel.handleAppleSignIn(result)
                                            await saveBirthDataAfterAuth()
                                            isAuthenticating = false
                                        }
                                    }

                                    GoogleSignInButton(isEnabled: !isAuthenticating) {
                                        Task {
                                            isAuthenticating = true
                                            await viewModel.signInWithGoogle()
                                            await saveBirthDataAfterAuth()
                                            isAuthenticating = false
                                        }
                                    }

                                    dividerRow

                                    VStack(spacing: 12) {
                                        authField(title: localization.string("common.email"), text: $email, field: .email, isSecure: false)
                                            .id(Field.email)
                                        authField(title: localization.string("common.password"), text: $password, field: .password, isSecure: true)
                                            .id(Field.password)
                                    }
                                    .padding(16)
                                    .background(.white.opacity(0.06), in: .rect(cornerRadius: 22))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 22)
                                            .stroke(.white.opacity(0.12), lineWidth: 1)
                                    }

                                    GoldButton(localization.string("auth.signUp.button"), isEnabled: !email.isEmpty && !password.isEmpty && !isAuthenticating) {
                                        focusedField = nil
                                        Task {
                                            isAuthenticating = true
                                            await viewModel.createAccountWithEmail(email: email, password: password)
                                            await saveBirthDataAfterAuth()
                                            isAuthenticating = false
                                        }
                                    }

                                    Button(action: showSignIn) {
                                        Text(localization.string("landing.signIn"))
                                            .font(SimastryFont.labelMedium)
                                            .foregroundStyle(SimastryColor.offWhite)
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("auth.signUp.signIn")
                                }
                                .opacity(appeared ? 1 : 0)
                                .offset(y: reduceMotion || appeared ? 0 : 24)
                                .animation(formRevealAnimation, value: appeared)

                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lock.shield.fill")
                                        .font(SimastryFont.labelSmall)
                                        .foregroundStyle(SimastryColor.gold.opacity(0.7))

                                    Text(localization.string("auth.privacy"))
                                        .font(SimastryFont.caption)
                                        .foregroundStyle(.white.opacity(0.68))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.top, 16)
                                .padding(.bottom, 32)
                            }
                            .frame(maxWidth: 560)
                            .frame(minHeight: geometry.size.height)
                            .padding(.horizontal, 24)
                            .frame(maxWidth: .infinity)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: focusedField) { _, field in
                            guard let field else { return }
                            if reduceMotion {
                                proxy.scrollTo(field, anchor: .center)
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(field, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(SimastrySpring.smooth).delay(0.12)) {
                appeared = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(localization.string("common.done")) { focusedField = nil }
            }
        }
    }

    private var titleRevealAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(SimastrySpring.smooth)
    }

    private var formRevealAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(SimastrySpring.smooth).delay(0.08)
    }

    private func navigateBack() {
        focusedField = nil

        // Returning to setup must also rewind the persisted resume stage; a
        // raw screen assignment would immediately send the user back here.
        if viewModel.onboardingProgress.hasStarted {
            viewModel.reopenOnboardingBeforeAccount()
            return
        }

        navigate(to: viewModel.isAgeVerified ? .firstPrediction : .landing)
    }

    private func showSignIn() {
        focusedField = nil
        navigate(to: .signIn)
    }

    private func navigate(to screen: AppScreen) {
        if reduceMotion {
            viewModel.currentScreen = screen
        } else {
            withAnimation(.spring(SimastrySpring.smooth)) {
                viewModel.currentScreen = screen
            }
        }
    }

    private var dividerRow: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
            Text(localization.string("common.or"))
                .font(SimastryFont.labelMedium)
                .foregroundStyle(.white.opacity(0.6))
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func authField(title: String, text: Binding<String>, field: Field, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(SimastryFont.overline)
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
                .kerning(0.5)

            Group {
                if isSecure {
                    SecureField(title, text: text)
                        .focused($focusedField, equals: field)
                } else {
                    TextField(title, text: text)
                        .focused($focusedField, equals: field)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                }
            }
            .textContentType(isSecure ? .newPassword : .emailAddress)
            .submitLabel(isSecure ? .go : .next)
            .onSubmit {
                if !isSecure {
                    focusedField = .password
                } else {
                    focusedField = nil
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .tint(.white)
        }
    }

    private func saveBirthDataAfterAuth() async {
        guard viewModel.isAuthenticated else { return }
        await viewModel.saveUserSigns()
    }
}
