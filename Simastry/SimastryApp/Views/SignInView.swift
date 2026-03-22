import SwiftUI
import AuthenticationServices

struct SignInView: View {
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
                            viewModel.currentScreen = .landing
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to landing")

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)

                VStack(spacing: 8) {
                    Text("Welcome back")
                        .font(SimastryFont.displayMedium)
                        .foregroundStyle(.white)

                    Text("Sign in to your Simastry account")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .padding(.top, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(SimastrySpring.smooth), value: appeared)

                Spacer()

                VStack(spacing: 16) {
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

                    GoldButton("Sign In", isEnabled: !email.isEmpty && !password.isEmpty && !isAuthenticating) {
                        focusedField = nil
                        Task {
                            isAuthenticating = true
                            defer { isAuthenticating = false }
                            await viewModel.signInWithEmail(email: email, password: password)
                        }
                    }

                    dividerRow

                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        guard !isAuthenticating else { return }
                        isAuthenticating = true
                        Task {
                            await viewModel.handleAppleSignIn(result)
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
                            defer { isAuthenticating = false }
                            await viewModel.signInWithGoogle()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(.spring(SimastrySpring.bouncy).delay(0.15), value: appeared)

                Spacer()
                    .frame(height: 50)
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
            .textContentType(isSecure ? .password : .emailAddress)
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
}
