import SwiftUI

struct AccountProfileView: View {
    @Bindable var viewModel: AppViewModel
    @AppStorage(GuidanceStyle.storageKey) private var guidanceStyleRawValue = GuidanceStyle.practical.rawValue

    private var birthTimeUnavailable: Bool {
        viewModel.onboardingBirthTimePrecision == .unknown
            || viewModel.natalChartRecord?.birthTimePrecision == .unknown
            || (viewModel.natalChartRecord == nil && viewModel.onboardingBirthTime == nil)
    }

    private var communicationProfile: CommunicationTypeProfile? {
        CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: birthTimeUnavailable ? nil : viewModel.userRisingSign
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SimastrySpacing.lg) {
                identitySection
                chartProvenanceSection
                communicationSection
                personalizationSection
                dataControlsSection
            }
            .padding(SimastrySpacing.lg)
            .padding(.bottom, SimastrySpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { CelestialBackground() }
        .navigationTitle("About you")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("accountProfile.screen")
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.md) {
            AccountProfileSectionTitle(
                title: "Identity",
                subtitle: "The details you chose to share with Simastry."
            )

            HStack(spacing: SimastrySpacing.md) {
                ProfileImageView(image: viewModel.profileImage, size: 58, sunSign: viewModel.userSunSign)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profileDisplayName)
                        .font(SimastryFont.titleMedium)
                        .foregroundStyle(SimastryColor.textPrimary)
                    Text("Private by default")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(SimastrySpacing.lg)
        .contentSurface(cornerRadius: SimastryRadius.card)
    }

    private var chartProvenanceSection: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.md) {
            AccountProfileSectionTitle(
                title: "Chart provenance",
                subtitle: "What you entered, what is saved, and what remains unavailable."
            )

            AccountProvenanceRow(
                title: "Birth date",
                value: birthDateLabel,
                evidence: birthDateLabel == "Not provided" ? "Not available" : "User-confirmed",
                systemImage: "calendar"
            )
            AccountProvenanceRow(
                title: "Birth time",
                value: birthTimeLabel,
                evidence: birthTimeUnavailable ? "User-confirmed unknown" : "User-confirmed",
                systemImage: "clock"
            )
            AccountProvenanceRow(
                title: "Birth place",
                value: birthPlaceLabel,
                evidence: birthPlaceLabel == "Not provided" ? "Not available" : "User-confirmed",
                systemImage: "mappin.and.ellipse"
            )

            Divider().overlay(.white.opacity(0.08))

            Text(chartProvenanceDisclosure)
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if birthTimeUnavailable {
                Label("Rising and houses unavailable", systemImage: "exclamationmark.circle.fill")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SimastrySpacing.lg)
        .contentSurface(cornerRadius: SimastryRadius.card, accent: SimastryColor.gold)
    }

    @ViewBuilder
    private var communicationSection: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.md) {
            AccountProfileSectionTitle(
                title: "Communication patterns",
                subtitle: "A reflective lens, not a fact or diagnosis."
            )

            if let communicationProfile {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(communicationProfile.title)
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.textPrimary)
                        Spacer()
                        AccountEvidenceBadge(title: "General lens", systemImage: "sparkles", tint: communicationProfile.accent)
                    }

                    VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
                        Text(communicationProfile.title)
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.textPrimary)
                        AccountEvidenceBadge(title: "General lens", systemImage: "sparkles", tint: communicationProfile.accent)
                    }
                }

                Text(communicationProfile.summary)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Practical guidance works without a complete chart. Add chart context only when you want a more personalized reflection.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SimastrySpacing.lg)
        .contentSurface(cornerRadius: SimastryRadius.card, accent: communicationProfile?.accent)
    }

    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
            AccountProfileSectionTitle(
                title: "Personalization",
                subtitle: "Choose the language that feels useful to you."
            )
            .padding(.horizontal, SimastrySpacing.xs)
            .padding(.bottom, SimastrySpacing.xs)

            NavigationLink(value: AccountHubRoute.guidanceStyle) {
                AccountHubRowLabel(
                    title: "Guidance style",
                    subtitle: GuidanceStyle(rawValue: guidanceStyleRawValue)?.title ?? GuidanceStyle.practical.title,
                    systemImage: "slider.horizontal.3",
                    accent: SimastryColor.risingViolet
                )
            }
            .buttonStyle(SpringPressStyle())
        }
        .padding(.vertical, SimastrySpacing.sm)
        .contentSurface(cornerRadius: SimastryRadius.card)
    }

    private var dataControlsSection: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
            AccountProfileSectionTitle(
                title: "Data controls",
                subtitle: "Inspect what is stored and change or remove it."
            )
            .padding(.horizontal, SimastrySpacing.xs)
            .padding(.bottom, SimastrySpacing.xs)

            NavigationLink(value: AccountHubRoute.companionMemory) {
                AccountHubRowLabel(
                    title: "Companion memory",
                    subtitle: "Review, edit, delete, or keep memories local",
                    systemImage: "lock.shield.fill",
                    accent: SimastryColor.celestialBlue
                )
            }
            .buttonStyle(SpringPressStyle())

            AccountHubDivider()

            NavigationLink(value: AccountHubRoute.settings) {
                AccountHubRowLabel(
                    title: "Settings and privacy",
                    subtitle: "Export, clear, or manage your data",
                    systemImage: "hand.raised.fill",
                    accent: SimastryColor.sageGreen
                )
            }
            .buttonStyle(SpringPressStyle())
        }
        .padding(.vertical, SimastrySpacing.sm)
        .contentSurface(cornerRadius: SimastryRadius.card)
    }

    private var profileDisplayName: String {
        let profileName = viewModel.profile?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !profileName.isEmpty { return profileName }
        let onboardingName = viewModel.onboardingDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return onboardingName.isEmpty ? "Your profile" : onboardingName
    }

    private var birthDateLabel: String {
        if let rawDate = viewModel.natalChartRecord?.birthDate, !rawDate.isEmpty { return rawDate }
        return viewModel.onboardingBirthday?.formatted(date: .long, time: .omitted) ?? "Not provided"
    }

    private var birthTimeLabel: String {
        guard !birthTimeUnavailable else { return "Unknown" }
        let time = viewModel.natalChartRecord?.birthTime
            ?? viewModel.onboardingBirthTime?.formatted(date: .omitted, time: .shortened)
            ?? "Not provided"
        guard viewModel.onboardingBirthTimePrecision == .approximate
                || viewModel.natalChartRecord?.birthTimePrecision == .approximate else { return time }
        if let minutes = viewModel.natalChartRecord?.birthTimeUncertaintyMinutes
            ?? viewModel.onboardingBirthTimeUncertaintyMinutes {
            return "\(time) · about ±\(minutes) min"
        }
        return "\(time) · approximate"
    }

    private var birthPlaceLabel: String {
        let value = (viewModel.natalChartRecord?.birthPlace ?? viewModel.onboardingBirthplace)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Not provided" : value
    }

    private var chartProvenanceDisclosure: String {
        switch viewModel.birthChartProvenance {
        case .calculated:
            "Placements labeled Calculated come from the saved birth details and calculation version on file. Simastry does not show Rising or houses when birth time is unknown."
        case .userConfirmed:
            "These placements were confirmed by you. Simastry keeps user-confirmed information distinct from calculated evidence."
        case .previouslySaved:
            "Your existing sign fields are shown as Previously saved until their source is confirmed. Simastry does not show Rising or houses when birth time is unknown."
        case .generalLens:
            "No calculated chart is on file. Guidance can still work as a practical, general lens."
        }
    }
}
