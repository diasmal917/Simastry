import SwiftUI

struct AccountProfileSummary: View {
    @Bindable var viewModel: AppViewModel
    @ScaledMetric(relativeTo: .title2) private var avatarSize: CGFloat = 64

    private var displayName: String {
        let profileName = viewModel.profile?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !profileName.isEmpty { return profileName }

        let onboardingName = viewModel.onboardingDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !onboardingName.isEmpty { return onboardingName }

        let socialName = viewModel.socialDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return socialName.isEmpty ? "Your profile" : socialName
    }

    private var birthTimeUnavailable: Bool {
        viewModel.onboardingBirthTimePrecision == .unknown
            || viewModel.natalChartRecord?.birthTimePrecision == .unknown
            || (viewModel.natalChartRecord == nil && viewModel.onboardingBirthTime == nil)
    }

    private var placements: [AccountPlacement] {
        let chart = viewModel.natalChartRecord
        return [
            AccountPlacement(
                role: "Sun",
                sign: viewModel.userSunSign,
                displayValue: chart?.sunEstimate.displayValue,
                systemImage: "sun.max.fill",
                accent: SimastryColor.sunCoral
            ),
            AccountPlacement(
                role: "Moon",
                sign: viewModel.userMoonSign,
                displayValue: chart?.moonEstimate.displayValue,
                systemImage: "moon.stars.fill",
                accent: SimastryColor.celestialBlue
            ),
            AccountPlacement(
                role: "Rising",
                sign: birthTimeUnavailable ? nil : viewModel.userRisingSign,
                displayValue: birthTimeUnavailable ? nil : chart?.risingEstimate?.displayValue,
                systemImage: "sunrise.fill",
                accent: SimastryColor.risingViolet
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.lg) {
            HStack(alignment: .center, spacing: SimastrySpacing.md) {
                ProfileImageView(
                    image: viewModel.profileImage,
                    size: avatarSize,
                    sunSign: viewModel.userSunSign
                )
                .overlay {
                    Circle()
                        .strokeBorder((viewModel.userSunSign?.color ?? SimastryColor.gold).opacity(0.44), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
                    Text(displayName)
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    AccountEvidenceBadge(
                        title: viewModel.birthChartProvenance.title,
                        systemImage: placements.contains(where: { $0.displayValue == nil }) ? "circle.lefthalf.filled" : "checkmark.seal.fill",
                        tint: placements.contains(where: { $0.displayValue == nil }) ? SimastryColor.amber : SimastryColor.textSecondary
                    )

                    Text(viewModel.birthChartContextSummary)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: SimastrySpacing.xs) {
                    ForEach(placements) { placement in
                        AccountPlacementPill(placement: placement)
                    }
                }

                VStack(spacing: SimastrySpacing.xs) {
                    ForEach(placements) { placement in
                        AccountPlacementPill(placement: placement)
                    }
                }
            }

            NavigationLink(value: AccountHubRoute.fullProfile) {
                HStack(spacing: SimastrySpacing.xs) {
                    Text("View full profile")
                        .font(SimastryFont.labelLarge)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(SimastryFont.labelMedium.weight(.semibold))
                }
                .foregroundStyle(SimastryColor.goldLight)
                .frame(minHeight: 44)
                .padding(.horizontal, SimastrySpacing.md)
                .interactiveGlass(cornerRadius: SimastryRadius.medium, tint: SimastryColor.gold)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityIdentifier("accountHub.fullProfile")
        }
        .padding(SimastrySpacing.lg)
        .contentSurface(cornerRadius: SimastryRadius.panel, accent: viewModel.userSunSign?.color ?? SimastryColor.gold)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Profile summary for \(displayName). \(viewModel.birthChartContextSummary).")
    }
}

struct AccountHubSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
            Text(title.uppercased())
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textTertiary)
                .tracking(1.3)
                .padding(.horizontal, SimastrySpacing.xs)

            VStack(spacing: 0) {
                content
            }
            .contentSurface(cornerRadius: SimastryRadius.large)
        }
    }
}

struct AccountHubRowLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    var trailingSystemImage = "chevron.right"

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 38

    var body: some View {
        HStack(alignment: .center, spacing: SimastrySpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: iconSize, height: iconSize)
                .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SimastryFont.bodyLarge.weight(.semibold))
                    .foregroundStyle(SimastryColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: SimastrySpacing.xs)

            Image(systemName: trailingSystemImage)
                .font(SimastryFont.caption.weight(.semibold))
                .foregroundStyle(SimastryColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SimastrySpacing.md)
        .padding(.vertical, SimastrySpacing.sm)
        .frame(minHeight: 64)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct AccountHubDivider: View {
    var body: some View {
        Divider()
            .overlay(SimastryColor.offWhite.opacity(0.08))
            .padding(.leading, 66)
            .accessibilityHidden(true)
    }
}

struct AccountPlacement: Identifiable {
    let role: String
    let sign: ZodiacSign?
    let displayValue: String?
    let systemImage: String
    let accent: Color

    var id: String { role }

    init(
        role: String,
        sign: ZodiacSign?,
        displayValue: String? = nil,
        systemImage: String,
        accent: Color
    ) {
        self.role = role
        self.sign = sign
        self.displayValue = displayValue ?? sign?.displayName
        self.systemImage = systemImage
        self.accent = accent
    }
}

private struct AccountPlacementPill: View {
    let placement: AccountPlacement

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: placement.displayValue == nil ? "questionmark" : placement.systemImage)
                .font(SimastryFont.caption.weight(.semibold))
                .foregroundStyle(placement.sign?.color ?? SimastryColor.textTertiary)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(placement.role)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.textTertiary)

                Text(placement.displayValue ?? "Not set")
                    .font(SimastryFont.caption.weight(.semibold))
                    .foregroundStyle(SimastryColor.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder((placement.sign?.color ?? SimastryColor.textTertiary).opacity(0.18), lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(placement.role), \(placement.displayValue ?? "not available")")
    }
}

struct AccountEvidenceBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(SimastryFont.captionSmall.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10), in: Capsule())
            .fixedSize(horizontal: true, vertical: true)
    }
}
