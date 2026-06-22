import SwiftUI

/// Invite-a-friend entry point. Account credits are not granted locally;
/// any benefit needs server-verified redemption.
struct InviteFriendsCard: View {
    enum Style {
        case full
        case compact
    }

    @Bindable var viewModel: AppViewModel
    var style: Style = .full

    var body: some View {
        switch style {
        case .full:
            fullCard
        case .compact:
            compactRow
        }
    }

    // MARK: - Full

    private var fullCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: SimastryIconSize.md, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .frame(width: 38, height: 38)
                    .background(SimastryColor.gold.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite a friend to Simastry")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text("Share your link so they can start with their own chart.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }

            Text("Your invite code helps connect referrals once server verification is active.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                codeChip

                ShareLink(
                    item: viewModel.personalInviteURL,
                    message: Text(viewModel.inviteShareText)
                ) {
                    HStack(spacing: 7) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                        Text("Share invite")
                            .font(SimastryFont.labelLarge)
                    }
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SimastryGradient.gold, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
                    }
                }
                .buttonStyle(SpringPressStyle())
            }

            Text("Credits are not granted locally.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.gold.opacity(0.7))
    }

    private var codeChip: some View {
        Button {
            UIPasteboard.general.string = viewModel.personalInviteCode
            HapticManager.buttonPress()
            viewModel.showToast("Code copied", subtitle: "Send it to a friend.", isError: false)
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.personalInviteCode)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(SimastryColor.goldLight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold.opacity(0.8))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(SimastryColor.gold.opacity(0.10), in: Capsule())
            .overlay {
                Capsule().strokeBorder(SimastryColor.gold.opacity(0.28), lineWidth: 0.7)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Your invite code \(viewModel.personalInviteCode). Tap to copy.")
    }

    // MARK: - Compact

    private var compactRow: some View {
        ShareLink(
            item: viewModel.personalInviteURL,
            message: Text(viewModel.inviteShareText)
        ) {
            HStack(spacing: 9) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("Invite a friend to Simastry")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                    .foregroundStyle(SimastryColor.goldLight)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(SimastryColor.gold.opacity(0.09), in: Capsule())
            .overlay {
                Capsule().strokeBorder(SimastryColor.gold.opacity(0.24), lineWidth: 0.7)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Invite a friend to Simastry.")
    }
}
