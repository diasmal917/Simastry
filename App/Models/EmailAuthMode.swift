import Foundation

nonisolated enum EmailAuthMode: String, CaseIterable, Identifiable, Sendable {
    case signIn = "Sign In"
    case createAccount = "Create Account"

    var id: String { rawValue }

    var buttonTitle: String {
        switch self {
        case .signIn:
            "Continue with Email"
        case .createAccount:
            "Create Account"
        }
    }

    var helperText: String {
        switch self {
        case .signIn:
            "Use the email and password you already set up for Simastry."
        case .createAccount:
            "Create your Simastry login with email and password."
        }
    }

    var alternateMode: EmailAuthMode {
        switch self {
        case .signIn:
            .createAccount
        case .createAccount:
            .signIn
        }
    }

    var alternatePrompt: String {
        switch self {
        case .signIn:
            "New to Simastry?"
        case .createAccount:
            "Already have an account?"
        }
    }

    var alternateActionTitle: String {
        alternateMode.rawValue
    }
}
