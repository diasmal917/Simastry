import SwiftUI
import RevenueCat

struct UpsellModalView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var offerings: Offerings?
    @State private var isPurchasing: Bool = false
    @State private var appeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTier: String = "plus"

    private var isRevenueCatAvailable: Bool {
        viewModel.isRevenueCatAvailable
    }

    private var currentTier: String {
        viewModel.profile?.tier ?? "free"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                freeTierBenefits
                tierCards
                restoreButton
                subscriptionDisclaimer
            }
            .padding(.horizontal, 20)
            // Clears the sheet drag indicator so the hero icon/title never crowds it.
            .padding(.top, 36)
            .padding(.bottom, 40)
        }
        .presentationContentInteraction(.scrolls)
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            AnalyticsService.shared.track(.upsellShown)
            if isRevenueCatAvailable {
                offerings = try? await Purchases.shared.offerings()
            }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(SimastrySpring.smooth)) {
                    appeared = true
                }
            }
        }
        .onDisappear {
            AnalyticsService.shared.track(.upsellDismissed)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [SimastryColor.goldLight, SimastryColor.gold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .symbolEffect(.variableColor.iterative, isActive: appeared)

            Text("Unlock the Full Cosmos")
                .font(SimastryFont.titleLarge)
                .foregroundStyle(
                    LinearGradient(
                        colors: [SimastryColor.offWhite, SimastryColor.goldLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Choose your path among the stars")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var freeTierBenefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FREE INCLUDES")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.5)

            HStack(spacing: 16) {
                freeChip("10 msgs/day")
                freeChip(AppConfig.expertAstrologersEnabled ? "5 AI experts" : "1 companion")
                freeChip("Chart context")
            }

            HStack(spacing: 16) {
                freeChip("Shareable cards")
                freeChip("Message tools")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private var tierCards: some View {
        VStack(spacing: 14) {
            plusCard
            proCard
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
    }

    private var plusCard: some View {
        let isActive = currentTier == "plus"

        return Button(action: { selectedTier = "plus" }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SIMASTRY+")
                            .font(SimastryFont.overline)
                            .italic()
                            .foregroundStyle(SimastryColor.gold)

                        Text(priceText(for: "plus", fallback: "$6.99 / month"))
                            .font(SimastryFont.titleMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                    }

                    Spacer()

                    if isActive {
                        activeBadge
                    } else if selectedTier == "plus" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(SimastryColor.gold)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    featureRow("Unlimited messages", icon: "message.fill")
                    featureRow(AppConfig.expertAstrologersEnabled ? "Five expert astrologers" : "Up to 3 companions", icon: "person.3.fill")
                    featureRow("Chart-grounded replies", icon: "scope")
                    featureRow("Full communication guidance", icon: "bubble.left.and.bubble.right.fill")
                    featureRow("Daily transit readings", icon: "sun.horizon.fill")
                }

                if !isActive {
                    subscribeAction(tier: "plus")
                }
            }
            .padding(20)
            .glossyCard(cornerRadius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selectedTier == "plus" ? SimastryColor.gold.opacity(0.4) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Subscribe to Plus plan")
    }

    private var proCard: some View {
        let isActive = currentTier == "pro"

        return Button(action: { selectedTier = "pro" }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("SIMASTRY PRO")
                                .font(SimastryFont.overline)
                                .italic()
                                .foregroundStyle(SimastryColor.gold)

                            Text("BEST VALUE")
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(Color(red: 20/255, green: 18/255, blue: 12/255))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [SimastryColor.goldDark, SimastryColor.gold, SimastryColor.goldLight],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: .capsule
                                )
                        }

                        Text(priceText(for: "pro", fallback: "$14.99 / month"))
                            .font(SimastryFont.titleMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                    }

                    Spacer()

                    if isActive {
                        activeBadge
                    } else if selectedTier == "pro" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(SimastryColor.gold)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    featureRow("Everything in Plus", icon: "checkmark.seal.fill")
                    featureRow(AppConfig.expertAstrologersEnabled ? "Unlimited expert consultations" : "Unlimited companions", icon: "person.crop.circle.badge.plus")
                    featureRow("Priority AI responses", icon: "bolt.fill")
                    featureRow("Advanced compatibility insights", icon: "chart.xyaxis.line")
                }

                if !isActive {
                    subscribeAction(tier: "pro")
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(SimastryColor.gold.opacity(0.04))
            )
            .glossyCard(cornerRadius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                SimastryColor.goldLight.opacity(selectedTier == "pro" ? 0.5 : 0.15),
                                SimastryColor.gold.opacity(selectedTier == "pro" ? 0.3 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: selectedTier == "pro" ? 1 : 0.5
                    )
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Subscribe to Pro plan")
    }

    @ViewBuilder
    private func subscribeAction(tier: String) -> some View {
        if selectedTier == tier {
            if !isRevenueCatAvailable {
                GoldButton("Plans coming soon", isEnabled: false) {}
            } else if let pkg = package(for: tier) {
                GoldButton("Subscribe", isEnabled: !isPurchasing) {
                    Task { await purchasePackage(pkg, type: tier) }
                }
            } else {
                GoldButton("Subscribe") {
                    viewModel.showToast("Something shifted", subtitle: "Try again in a moment", isError: true)
                }
            }
        }
    }

    private var activeBadge: some View {
        Text("ACTIVE")
            .font(SimastryFont.captionSmall)
            .foregroundStyle(Color(red: 20/255, green: 18/255, blue: 12/255))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                LinearGradient(
                    colors: [SimastryColor.goldDark, SimastryColor.gold, SimastryColor.goldLight],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: .capsule
            )
    }

    @ViewBuilder
    private var restoreButton: some View {
        if isRevenueCatAvailable {
            Button(action: {
                Task { await viewModel.restorePurchases() }
            }) {
                Text("Restore Purchases")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .buttonStyle(.plain)
            .opacity(appeared ? 1 : 0)
        }
    }

    private func freeChip(_ text: String) -> some View {
        Text(text)
            .font(SimastryFont.labelSmall)
            .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.06), in: .capsule)
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SimastryColor.goldLight)
                .frame(width: 18)
            Text(text)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite)
        }
    }

    private func priceText(for tier: String, fallback: String) -> String {
        guard let package = package(for: tier) else { return fallback }
        return "\(package.storeProduct.localizedPriceString) / month"
    }

    private func package(for tier: String) -> Package? {
        let packages = rankedPackages

        if let matchedPackage = packages.first(where: { packageMatchesTier($0, tier: tier) }) {
            return matchedPackage
        }

        switch tier {
        case "plus":
            return packages.first
        case "pro":
            return packages.count > 1 ? packages.last : nil
        default:
            return nil
        }
    }

    private var rankedPackages: [Package] {
        guard let current = offerings?.current else { return [] }
        return current.availablePackages.sorted {
            NSDecimalNumber(decimal: $0.storeProduct.price).compare(NSDecimalNumber(decimal: $1.storeProduct.price)) == .orderedAscending
        }
    }

    private func packageMatchesTier(_ package: Package, tier: String) -> Bool {
        let searchableText = [
            package.identifier,
            package.storeProduct.productIdentifier,
            package.storeProduct.localizedTitle,
        ]
            .joined(separator: " ")
            .lowercased()

        switch tier {
        case "plus":
            return searchableText.contains("plus")
        case "pro":
            return searchableText.contains("pro")
        default:
            return false
        }
    }

    private var subscriptionDisclaimer: some View {
        VStack(spacing: 8) {
            Text("Subscriptions auto-renew monthly unless cancelled at least 24 hours before the end of the current period. Your Apple ID account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Link("Terms of Service", destination: AppConfig.termsOfServiceURL)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Link("EULA", destination: AppConfig.eulaURL)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
        }
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
    }

    private func purchasePackage(_ package: Package, type: String) async {
        guard isRevenueCatAvailable else {
            viewModel.showToast("Subscriptions unavailable", subtitle: "Purchases are not available in this build yet.", isError: true)
            return
        }

        if type == currentTier {
            viewModel.showToast("You're already on \(currentTier.capitalized)", subtitle: "No changes needed", isError: false)
            return
        }

        isPurchasing = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                viewModel.updateTierFromCustomerInfo(result.customerInfo)
                viewModel.showToast("Welcome to the cosmos", subtitle: "Your subscription is active", isError: false)
                HapticManager.soulFlash()
                dismiss()
            }
        } catch {
            viewModel.showToast("Purchase interrupted", subtitle: "Try again", isError: true)
        }
        isPurchasing = false
    }
}
