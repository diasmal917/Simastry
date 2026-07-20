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

    private enum Field: Hashable {
        case email, password
    }

    var body: some View {
        ZStack {
            // Still ink, matching the setup flow this screen concludes.
            SimastryColor.pureBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        HapticManager.buttonPress()
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            // Back into the setup flow when one is underway;
                            // guests who came from the Compass return there.
                            if viewModel.onboardingProgress.hasStarted {
                                viewModel.currentScreen = .onboarding
                            } else if viewModel.isAgeVerified {
                                viewModel.currentScreen = .firstPrediction
                            } else {
                                viewModel.currentScreen = .landing
                            }
                        }
                    } label: {
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

                VStack(spacing: 8) {
                    Text(localization.string("auth.signUp.title"))
                        .font(SimastryFont.displayMedium)
                        .foregroundStyle(.white)

                    Text(localization.string("auth.signUp.subtitle"))
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(SimastrySpring.smooth), value: appeared)

                Spacer()

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
                        authField(title: localization.string("common.password"), text: $password, field: .password, isSecure: true)
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
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(.spring(SimastrySpring.bouncy).delay(0.15), value: appeared)

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.gold.opacity(0.7))

                    Text(localization.string("auth.privacy"))
                        .font(SimastryFont.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }
                .padding(.top, 16)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.spring(SimastrySpring.smooth).delay(0.2)) {
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
