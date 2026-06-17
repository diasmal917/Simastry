import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @Bindable var viewModel: AppViewModel
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
            CelestialBackground()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        HapticManager.buttonPress()
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            viewModel.currentScreen = .birthDetails
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)

                VStack(spacing: 8) {
                    Text("Create your account")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(.white)

                    Text("Save your birth chart and unlock your reading")
                        .font(.system(size: 15))
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
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        guard !isAuthenticating else { return }
                        isAuthenticating = true
                        Task {
                            await viewModel.handleAppleSignIn(result)
                            await saveBirthDataAfterAuth()
                            isAuthenticating = false
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(.rect(cornerRadius: 999))
                    .disabled(isAuthenticating)
                    .opacity(isAuthenticating ? 0.72 : 1)

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
                        authField(title: "Email", text: $email, field: .email, isSecure: false)
                        authField(title: "Password", text: $password, field: .password, isSecure: true)
                    }
                    .padding(16)
                    .background(.white.opacity(0.06), in: .rect(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }

                    GoldButton("Create Account", isEnabled: !email.isEmpty && !password.isEmpty && !isAuthenticating) {
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
                        .font(.system(size: 13))
                        .foregroundStyle(SimastryColor.gold.opacity(0.7))

                    Text("We never share or sell your data.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
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
                Button("Done") { focusedField = nil }
            }
        }
    }

    private var dividerRow: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
            Text("or")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func authField(title: String, text: Binding<String>, field: Field, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
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
