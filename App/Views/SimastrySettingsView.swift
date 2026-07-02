import SwiftUI
import UIKit

struct SimastrySettingsView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var walletAddressInput: String = ""
    @State private var savedAuraWalletInputLabel: String = ""
    @State private var showingReadOnlyInfo = false
    @State private var showingClearDataConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingExportShare = false
    @State private var exportFileURL: URL?
    @State private var lastWalletSaveActionAt: Date?

    private var trimmedWalletInput: String {
        walletAddressInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var walletInputIsValid: Bool {
        AppViewModel.canParseAuraWalletInput(trimmedWalletInput)
    }

    private var walletInputSummary: String {
        AppViewModel.auraWalletInputSummary(trimmedWalletInput)
    }

    private var hasVisibleAuraWalletContext: Bool {
        viewModel.hasAuraWalletContext || !savedAuraWalletInputLabel.isEmpty
    }

    var body: some View {
        NavigationStack {
            // Celestial backdrop comes from `.presentationBackground` so the
            // scroll content insets below the nav bar instead of running up under
            // it (a full-bleed ZStack layer here clipped the first section).
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    accountSection
                    auraWalletSection
                    notificationsSection
                    appearanceSection
                    privacySection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
        }
        .onAppear {
            walletAddressInput = viewModel.auraWalletTotalZodiacs > 0 ? "" : viewModel.auraWalletPublicAddress
            savedAuraWalletInputLabel = viewModel.auraWalletDisplayLabel
            #if DEBUG
            if walletAddressInput.isEmpty, let testPasteboardValue = Self.uiTestPasteboardValue {
                walletAddressInput = testPasteboardValue
            }
            #endif
        }
        .alert("Read-only Aura wallet", isPresented: $showingReadOnlyInfo) {
            Button("OK") {}
        } message: {
            Text("Simastry stores only a public address and per-sign Zodiac counts. Wallet checks are sent through Simastry's backend so the app is not calling public RPC endpoints directly. Holdings tune Aura bars for display only; Simastry cannot sign, approve, move funds, or make transactions.")
        }
        .confirmationDialog("Clear local Simastry data from this device?", isPresented: $showingClearDataConfirmation, titleVisibility: .visible) {
            Button("Clear Local Data", role: .destructive) {
                viewModel.clearLocalDeviceData()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes on-device messages, notes, wallet context, cached profile image, and local preferences. Your Simastry account is not deleted.")
        }
        .confirmationDialog("Delete your Simastry account?", isPresented: $showingDeleteAccountConfirmation, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                Task {
                    await viewModel.deleteAccount()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This attempts to remove account data from Simastry services and clears this device. Use Clear Local Data if you only want to reset this device.")
        }
        .sheet(isPresented: $showingExportShare) {
            if let exportFileURL {
                SettingsActivityView(activityItems: [exportFileURL])
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var accountSection: some View {
        settingsSection("Account") {
            settingRow(
                icon: "crown.fill",
                title: "Plan",
                detail: viewModel.isRevenueCatAvailable ? (viewModel.profile?.tier ?? "free").capitalized : "Beta",
                tint: SimastryColor.gold
            )

            if viewModel.isRevenueCatAvailable {
                Button {
                    if (viewModel.profile?.tier ?? "free") == "free" {
                        viewModel.showUpsell = true
                    } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                } label: {
                    settingRow(
                        icon: "sparkles",
                        title: (viewModel.profile?.tier ?? "free") == "free" ? "Upgrade Simastry" : "Manage Subscription",
                        detail: "Unlock more messages and chart tools",
                        tint: SimastryColor.gold,
                        showsChevron: true
                    )
                }
                .buttonStyle(SpringPressStyle())
            } else {
                settingRow(
                    icon: "sparkles",
                    title: "Beta Access",
                    detail: "Purchases are unavailable in this build",
                    tint: SimastryColor.gold
                )
            }

            Button(role: .destructive) {
                Task {
                    await viewModel.signOut()
                    dismiss()
                }
            } label: {
                settingRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    detail: "Leave this device session",
                    tint: .red.opacity(0.82)
                )
            }
            .buttonStyle(SpringPressStyle())
        }
    }

    private var notificationsSection: some View {
        settingsSection("Notifications") {
            Toggle(isOn: Binding(
                get: { viewModel.privateNotificationsEnabled },
                set: { isEnabled in
                    viewModel.privateNotificationsEnabled = isEnabled
                    Task { await viewModel.setupNotifications() }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily morning note")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("One note each morning, composed from your saved chart signals and today's sky. Off by default; no conversation content in previews.")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .tint(SimastryColor.gold)
            .padding(14)
            .simastryGlass(cornerRadius: 16)
        }
    }

    private var appearanceSection: some View {
        settingsSection("App") {
            Toggle(isOn: Binding(
                get: { viewModel.conversationSuggestionsEnabled },
                set: { isEnabled in
                    HapticManager.buttonPress()
                    viewModel.conversationSuggestionsEnabled = isEnabled
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Conversation suggestions")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("Show suggested questions and replies above the message composer.")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(SimastryColor.gold)
            .padding(14)
            .simastryGlass(cornerRadius: 16)

            Menu {
                ForEach(LocalizationManager.Language.allCases) { language in
                    Button {
                        localization.currentLanguage = language
                    } label: {
                        if localization.currentLanguage == language {
                            Label(language.displayName, systemImage: "checkmark")
                        } else {
                            Text(language.displayName)
                        }
                    }
                }
            } label: {
                settingRow(
                    icon: "globe",
                    title: "Language",
                    detail: localization.currentLanguage.displayName,
                    tint: SimastryColor.gold,
                    showsChevron: true
                )
            }
            .buttonStyle(SpringPressStyle())
        }
    }

    private var auraWalletSection: some View {
        settingsSection("Aura Wallet") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                        .frame(width: 40, height: 40)
                        .background(SimastryColor.gold.opacity(0.10), in: .rect(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Read-only wallet for Aura")
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.offWhite)
                        Text("Paste a Solana or Base public address. Simastry checks official Zodiacs through its backend and uses the counts only to tune your Aura bars.")
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Wallet or Zodiac holdings")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.deepMuted)
                        .tracking(1)
                        .textCase(.uppercase)

                    TextField("Paste address or Aries x3, Taurus x1", text: $walletAddressInput, axis: .vertical)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(SimastryColor.offWhite)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(Color.white.opacity(0.05), in: .rect(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(walletBorderColor, lineWidth: 0.8)
                        }
                        .accessibilityIdentifier("settings.auraWallet.addressField")

                    if !trimmedWalletInput.isEmpty {
                        Text(walletInputIsValid ? (walletInputSummary.isEmpty ? "Address format looks valid. Simastry will check official Zodiacs securely." : walletInputSummary) : "Paste a public Solana/Base address or explicit Zodiac counts like Aries x3.")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(walletInputIsValid ? SimastryColor.gold : SimastryColor.amber)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        pasteWalletAddressFromClipboard()
                    } label: {
                        walletActionLabel("Paste", systemImage: "doc.on.clipboard", isPrimary: false)
                    }
                    .buttonStyle(.plain)
                    .contentShape(.rect)
                    .accessibilityIdentifier("settings.auraWallet.pasteButton")

                    Button {
                        saveWalletAddressFromInput()
                    } label: {
                        walletActionLabel(viewModel.isAuraWalletRefreshing ? "Checking" : (hasVisibleAuraWalletContext ? "Update" : "Save"), systemImage: viewModel.isAuraWalletRefreshing ? "arrow.clockwise" : "checkmark", isPrimary: true)
                    }
                    .buttonStyle(.plain)
                    .contentShape(.rect)
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            saveWalletAddressFromInput()
                        }
                    )
                    .opacity(walletInputIsValid ? 1 : 0.42)
                    .disabled(!walletInputIsValid || viewModel.isAuraWalletRefreshing)
                    .accessibilityIdentifier("settings.auraWallet.saveButton")
                }

                if hasVisibleAuraWalletContext {
                    VStack(alignment: .leading, spacing: 10) {
                        settingRow(
                            icon: "checkmark.seal.fill",
                            title: "Saved Aura input",
                            detail: viewModel.auraWalletDisplayLabel,
                            tint: SimastryColor.gold
                        )

                        if viewModel.auraWalletTotalZodiacs > 0 {
                            Text(auraWalletStatusText)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(SimastryColor.mutedSilver)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if viewModel.isAuraWalletRefreshing {
                            Text("Checking official Zodiacs through Simastry's backend...")
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(SimastryColor.mutedSilver)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if !viewModel.auraWalletPublicAddress.isEmpty {
                            Text("No Zodiac count has been found yet. You can update again or paste counts manually.")
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(SimastryColor.mutedSilver)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Toggle("Reflect this wallet in Aura", isOn: $viewModel.useAuraWalletForAura)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                            .tint(SimastryColor.gold)
                            .accessibilityIdentifier("settings.auraWallet.reflectToggle")

                        Button {
                            walletAddressInput = ""
                            savedAuraWalletInputLabel = ""
                            viewModel.clearAuraWalletContext()
                        } label: {
                            Label("Remove wallet", systemImage: "xmark.circle")
                                .font(SimastryFont.labelLarge.weight(.semibold))
                                .foregroundStyle(.red.opacity(0.92))
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(.red.opacity(0.10), in: Capsule())
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.auraWallet.removeButton")
                    }
                    .padding(14)
                    .simastryGlass(cornerRadius: 16)
                }

                Button {
                    showingReadOnlyInfo = true
                } label: {
                    Label("What read-only means", systemImage: "info.circle")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.gold)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.auraWallet.readOnlyInfoButton")
            }
            .padding(16)
            .glossyCard(cornerRadius: 20)
        }
    }

    private var auraWalletStatusText: String {
        switch viewModel.auraWalletLookupStatus {
        case .found:
            return viewModel.auraWalletSummaryLine
        case .manualCountsActive:
            return "\(viewModel.auraWalletSummaryLine) Manual counts are active until official lookup succeeds."
        case .notFound:
            return "No official Zodiacs were found for this address."
        case .unavailable:
            return "Secure wallet lookup is unavailable right now. Manual counts can tune Aura meanwhile."
        case .checking:
            return "Checking official Zodiacs through Simastry's backend..."
        case .idle:
            return viewModel.auraWalletSummaryLine
        }
    }

    private var privacySection: some View {
        settingsSection("Privacy & Data") {
            Button {
                if let url = viewModel.exportUserData() {
                    exportFileURL = url
                    showingExportShare = true
                }
            } label: {
                settingRow(
                    icon: "square.and.arrow.up",
                    title: "Export My Data",
                    detail: "Includes settings and Aura wallet context",
                    tint: SimastryColor.celestialBlue,
                    showsChevron: true
                )
            }
            .buttonStyle(SpringPressStyle())

            Link(destination: AppConfig.privacyPolicyURL) {
                settingRow(
                    icon: "lock.shield.fill",
                    title: "Privacy Policy",
                    detail: "How Simastry treats sensitive data",
                    tint: SimastryColor.mutedSilver,
                    showsChevron: true
                )
            }

            Button(role: .destructive) {
                showingClearDataConfirmation = true
            } label: {
                settingRow(
                    icon: "trash.fill",
                    title: "Clear Local Data",
                    detail: "Remove only on-device data",
                    tint: .red.opacity(0.82)
                )
            }
            .buttonStyle(SpringPressStyle())

            Button(role: .destructive) {
                showingDeleteAccountConfirmation = true
            } label: {
                settingRow(
                    icon: "person.crop.circle.badge.xmark",
                    title: "Delete Account",
                    detail: "Remote deletion and device reset",
                    tint: .red.opacity(0.92)
                )
            }
            .buttonStyle(SpringPressStyle())
        }
    }

    private var aboutSection: some View {
        settingsSection("About") {
            settingRow(
                icon: "point.3.connected.trianglepath.dotted",
                title: "Method Layer",
                detail: "Astronomy calculates. Astrology interprets. Simastry translates into communication guidance.",
                tint: SimastryColor.gold
            )

            settingRow(
                icon: "text.book.closed.fill",
                title: "For reflection",
                detail: "Simastry offers guidance for reflection and entertainment. It is not professional, medical, legal, or financial advice.",
                tint: SimastryColor.mutedSilver
            )

            settingRow(
                icon: "sparkles",
                title: "Simastry",
                detail: "Version \(appVersion)",
                tint: SimastryColor.gold
            )
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var walletBorderColor: Color {
        if trimmedWalletInput.isEmpty {
            return Color.white.opacity(0.10)
        }
        return walletInputIsValid ? SimastryColor.gold.opacity(0.55) : SimastryColor.amber.opacity(0.7)
    }

    private func walletActionLabel(_ title: String, systemImage: String, isPrimary: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(SimastryFont.labelLarge.weight(.semibold))
            .foregroundStyle(isPrimary ? SimastryColor.midnight : SimastryColor.offWhite)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                isPrimary ? SimastryColor.gold : SimastryColor.deepMuted.opacity(0.50),
                in: Capsule()
            )
            .contentShape(.rect)
    }

    private func pasteWalletAddressFromClipboard() {
        let pasted: String
        #if DEBUG
        if let testPasteboardValue = Self.uiTestPasteboardValue {
            pasted = testPasteboardValue
        } else {
            pasted = UIPasteboard.general.string ?? ""
        }
        #else
        pasted = UIPasteboard.general.string ?? ""
        #endif

        walletAddressInput = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !walletAddressInput.isEmpty else {
            viewModel.showToast("Clipboard empty", subtitle: "Copy a public wallet address or Zodiac holdings, then paste again.", isError: true)
            return
        }
        guard walletInputIsValid else {
            viewModel.showToast("Aura input not ready", subtitle: "Paste a public wallet address or Zodiac counts like Aries x3.", isError: true)
            return
        }
        saveWalletAddressFromInput()
    }

    private func saveWalletAddressFromInput() {
        let now = Date()
        if let lastWalletSaveActionAt,
           now.timeIntervalSince(lastWalletSaveActionAt) < 0.25 {
            return
        }
        lastWalletSaveActionAt = now
        viewModel.saveAuraWalletInput(walletAddressInput)
        if walletInputIsValid {
            savedAuraWalletInputLabel = viewModel.auraWalletDisplayLabel
            let shouldLookupAddress = !viewModel.auraWalletPublicAddress.isEmpty
            if shouldLookupAddress {
                Task {
                    await viewModel.refreshAuraWalletHoldingsFromAddress()
                    savedAuraWalletInputLabel = viewModel.auraWalletDisplayLabel
                    walletAddressInput = viewModel.auraWalletTotalZodiacs > 0
                        ? ""
                        : viewModel.auraWalletPublicAddress
                }
            } else {
                walletAddressInput = viewModel.auraWalletTotalZodiacs > 0
                    ? ""
                    : viewModel.auraWalletPublicAddress
            }
        }
    }

    #if DEBUG
    private static var uiTestPasteboardValue: String? {
        if let value = ProcessInfo.processInfo.environment["SIMASTRY_UI_PASTEBOARD_TEXT"], !value.isEmpty {
            return value
        }
        let arguments = ProcessInfo.processInfo.arguments
        guard let marker = arguments.firstIndex(of: "-SimastryUITestPasteWallet"),
              arguments.indices.contains(marker + 1) else {
            return nil
        }
        return arguments[marker + 1]
    }
    #endif

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.mutedSilver)

            VStack(spacing: 10) {
                content()
            }
        }
    }

    private func settingRow(
        icon: String,
        title: String,
        detail: String,
        tint: Color,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.10), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                Text(detail)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.deepMuted)
            }
        }
        .padding(14)
        .simastryGlass(cornerRadius: 16)
        .contentShape(.rect)
    }
}

private struct SettingsActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
