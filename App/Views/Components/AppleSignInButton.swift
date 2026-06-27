import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    let isEnabled: Bool
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    @State private var isPressed: Bool = false

    init(isEnabled: Bool = true, onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.isEnabled = isEnabled
        self.onCompletion = onCompletion
    }

    var body: some View {
        Button(action: {
            HapticManager.buttonPress()
            startAppleSignIn()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)

                Text("Continue with Apple")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 999))
            .overlay {
                RoundedRectangle(cornerRadius: 999)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .disabled(!isEnabled)
        .scaleEffect(isPressed ? 0.985 : 1.0)
        .animation(.spring(SimastrySpring.snappy), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private func startAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate(onCompletion: onCompletion)
        controller.delegate = delegate
        // Keep delegate alive until completion
        AppleSignInDelegate.current = delegate
        controller.performRequests()
    }
}

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    static var current: AppleSignInDelegate?

    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    init(onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.onCompletion = onCompletion
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion(.success(authorization))
        AppleSignInDelegate.current = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion(.failure(error))
        AppleSignInDelegate.current = nil
    }
}
