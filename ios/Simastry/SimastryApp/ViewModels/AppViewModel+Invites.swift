import Foundation

// MARK: - Invites
// Share-link invite flow without public discovery. The reward is framed as a
// gift to the invitee — inviter-side credit needs server-verified redemption
// and is deferred to the backend phase.

extension AppViewModel {
    static let personalInviteCodeKey = "simastry_personal_invite_code"
    static let inviteRewardGrantedKey = "simastry_invite_reward_granted"
    static let inviteRewardPredictions = 5

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

    /// Redeems an invite code on this device: records the referrer and grants
    /// the welcome predictions, each at most once.
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
        let alreadyGranted = UserDefaults.standard.bool(forKey: Self.inviteRewardGrantedKey)
        guard !alreadyReferred, !alreadyGranted else {
            showToast("Invite already applied", subtitle: "Welcome gifts apply once per account.", isError: true)
            return
        }

        applyReferralCode(code)
        UserDefaults.standard.set(true, forKey: Self.inviteRewardGrantedKey)
        addBonusPredictions(Self.inviteRewardPredictions)
        HapticManager.signConfirmed()
        showToast(
            "Welcome gift unlocked",
            subtitle: "\(Self.inviteRewardPredictions) free predictions added to your account.",
            isError: false
        )
    }
}
