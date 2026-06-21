import SwiftUI
import UIKit

struct SimastrySettingsView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var walletAddressInput: String = ""
    @State private var showingPhantomInfo = false
    @State private var showingReadOnlyInfo = false
    @State private var showingClearDataConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingExportShare = false
    @State private var exportFileURL: URL?

    private var trimmedWalletInput: String {
        walletAddressInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var walletInputIsValid: Bool {
        AppViewModel.isSupportedPublicWalletAddress(trimmedWalletInput)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        accountSection
                        notificationsSection
                        appearanceSection
                        auraWalletSection
                        privacySection
                        aboutSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
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
            walletAddressInput = viewModel.auraWalletPublicAddress
        }
        .alert("Read-only Aura wallet", isPresented: $showingReadOnlyInfo) {
            Button("OK") {}
        } message: {
            Text("Simastry uses only the public wallet address to read which Zodiacs you hold, so your Aura can reflect them. Holdings never unlock app features, and Simastry cannot move funds, request signatures, request approvals, or make transactions.")
        }
        .alert("Phantom wallet", isPresented: $showingPhantomInfo) {
            Button("OK") {}
        } message: {
            Text("Production Phantom support should use the official Phantom SDK or deeplink flow to request only the public address. This prototype keeps the safe path available now: paste a public wallet address for read-only display context.")
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .frame(width: 42, height: 42)
                    .simastryGlass(cornerRadius: SimastryRadius.medium)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("Privacy, Aura, notifications, and app preferences.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
        }
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
                    Text("Private reminders")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("Subtle chart-signal reminders and daily picks. No private conversation content in previews.")
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
                get: { viewModel.isDarkMode },
                set: { isDark in
                    HapticManager.themeToggle()
                    viewModel.isDarkMode = isDark
                }
            )) {
                Label(viewModel.isDarkMode ? "Dark appearance" : "Light appearance", systemImage: viewModel.isDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
            }
            .tint(SimastryColor.gold)
            .padding(14)
            .simastryGlass(cornerRadius: 16)

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
                        .background(SimastryColor.gold.opacity(0.10), in: .rect(cornerRadius: SimastryRadius.small))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Read-only wallet for Aura")
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.offWhite)
                        Text("Lets your Aura reflect the Zodiacs you hold. Display only — holdings never unlock app features, and Simastry cannot sign, approve, or move anything.")
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    showingPhantomInfo = true
                } label: {
                    settingRow(
                        icon: "p.circle.fill",
                        title: "Connect Phantom",
                        detail: "SDK-ready read-only public address flow",
                        tint: SimastryColor.risingViolet,
                        showsChevron: true
                    )
                }
                .buttonStyle(SpringPressStyle())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Public wallet address")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.deepMuted)
                        .tracking(1)
                        .textCase(.uppercase)

                    TextField("Paste Solana or 0x address", text: $walletAddressInput, axis: .vertical)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(SimastryColor.offWhite)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Color.white.opacity(0.05), in: .rect(cornerRadius: SimastryRadius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: SimastryRadius.medium)
                                .stroke(walletBorderColor, lineWidth: 0.8)
                        }

                    if !trimmedWalletInput.isEmpty {
                        Text(walletInputIsValid ? "Address format looks valid." : "Paste a public Solana address or 0x EVM address.")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(walletInputIsValid ? SimastryColor.gold : SimastryColor.amber)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        walletAddressInput = UIPasteboard.general.string ?? ""
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(SimastryColor.mutedSilver)

                    Button {
                        viewModel.saveAuraWalletPublicAddress(walletAddressInput)
                    } label: {
                        Label(viewModel.hasAuraWalletContext ? "Update" : "Save", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SimastryColor.gold)
                    .disabled(!walletInputIsValid)
                }

                if viewModel.hasAuraWalletContext {
                    VStack(alignment: .leading, spacing: 10) {
                        settingRow(
                            icon: "checkmark.seal.fill",
                            title: "Saved wallet",
                            detail: viewModel.auraWalletShortAddress,
                            tint: SimastryColor.gold
                        )

                        Toggle("Reflect this wallet in Aura", isOn: $viewModel.useAuraWalletForAura)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                            .tint(SimastryColor.gold)

                        Button(role: .destructive) {
                            walletAddressInput = ""
                            viewModel.clearAuraWalletContext()
                        } label: {
                            Label("Remove wallet", systemImage: "xmark.circle")
                        }
                        .font(SimastryFont.labelLarge)
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
            }
            .padding(16)
            .glossyCard(cornerRadius: 20)
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
    }
}

private struct SettingsActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
