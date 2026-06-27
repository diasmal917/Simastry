import Foundation

// MARK: - Invites
// Share-link invite flow without public discovery. Credits are intentionally
// not granted locally; any account benefit needs server-verified redemption.

extension AppViewModel {
    static let personalInviteCodeKey = "simastry_personal_invite_code"

    /// The user's own shareable code, generated once and persisted.
    var personalInviteCode: String {
        if let existing = UserDefaults.standard.string(forKey: Self.personalInviteCodeKey),
           InviteCode.isValid(existing) {
            return existing
        }
        let fresh = InviteCode.generate()
        UserDefaults.standard.set(fresh, forKey: Self.personalInviteCodeKey)
        return fresh
    }

    var personalInviteURL: URL {
        DeepLink.invite(code: personalInviteCode).universalLinkURL
    }

    var inviteShareText: String {
        DeepLink.invite(code: personalInviteCode).shareText
    }

    func requestInviteCodeConfirmation(_ rawCode: String) {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard InviteCode.isValid(code) else {
            showToast("That code doesn't look right", subtitle: "Invite codes are 6–12 letters and numbers.", isError: true)
            return
        }

        guard code != personalInviteCode else {
            showToast("That's your own code", subtitle: "Share it with a friend instead.", isError: true)
            return
        }

        let alreadyReferred = !(referralInfo?.referredBy ?? "").isEmpty
        guard !alreadyReferred else {
            showToast("Invite already saved", subtitle: "One invite code can be saved per account.", isError: true)
            return
        }

        pendingInviteCodeForConfirmation = code
    }

    func confirmPendingInviteCode() {
        guard let code = pendingInviteCodeForConfirmation else { return }
        pendingInviteCodeForConfirmation = nil
        applyInviteCode(code)
    }

    func cancelPendingInviteCode() {
        pendingInviteCodeForConfirmation = nil
    }

    /// Saves an invite code on this device. Prediction credits are not granted
    /// locally because account benefits require server-side verification.
    func applyInviteCode(_ rawCode: String) {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard InviteCode.isValid(code) else {
            showToast("That code doesn't look right", subtitle: "Invite codes are 6–12 letters and numbers.", isError: true)
            return
        }

        guard code != personalInviteCode else {
            showToast("That's your own code", subtitle: "Share it with a friend instead.", isError: true)
            return
        }

        let alreadyReferred = !(referralInfo?.referredBy ?? "").isEmpty
        guard !alreadyReferred else {
            showToast("Invite already saved", subtitle: "One invite code can be saved per account.", isError: true)
            return
        }

        applyReferralCode(code)
        HapticManager.signConfirmed()
        showToast(
            "Invite saved",
            subtitle: "Credits require server verification and are not granted locally.",
            isError: false
        )
    }
}
