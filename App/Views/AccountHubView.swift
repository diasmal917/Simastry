import SwiftUI
import UIKit

nonisolated enum AppSheetDestination: String, Identifiable, Hashable, Sendable {
    case accountHub

    var id: String { rawValue }
}

enum AccountHubRoute: Hashable {
    case fullProfile
    case birthChart
    case journal
    case guidanceStyle
    case settings
    case methodology
    case expertKnowledge
    case companionMemory
    case legacyCompanions
    case expertArchive
}

struct AccountHubView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AccountHubRootView(viewModel: viewModel)
                .navigationDestination(for: AccountHubRoute.self) { route in
                    destination(for: route)
                }
        }
        .tint(SimastryColor.gold)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .lockHorizontalScroll()
        .accessibilityAction(.escape, dismissHub)
        .onAppear(perform: moveVoiceOverFocusToSheet)
    }

    @ViewBuilder
    private func destination(for route: AccountHubRoute) -> some View {
        switch route {
        case .fullProfile:
            AccountProfileView(viewModel: viewModel)
        case .birthChart:
            AccountBirthChartView(viewModel: viewModel)
        case .journal:
            SavedInsightsView(viewModel: viewModel, embeddedInNavigationStack: true)
        case .guidanceStyle:
            GuidanceStyleView(viewModel: viewModel)
        case .settings:
            SimastrySettingsView(viewModel: viewModel, embeddedInNavigationStack: true)
        case .methodology:
            AccountMethodologyView()
        case .expertKnowledge:
            ExpertKnowledgeView(viewModel: viewModel, embeddedInNavigationStack: true)
        case .companionMemory:
            CompanionMemoryControlsView(viewModel: viewModel)
        case .legacyCompanions:
            LegacyCompanionArchiveView(viewModel: viewModel)
        case .expertArchive:
            ExpertArchiveView(viewModel: viewModel)
        }
    }

    private func dismissHub() {
        dismiss()
    }

    private func moveVoiceOverFocusToSheet() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
}

private struct AccountHubRootView: View {
    @Bindable var viewModel: AppViewModel
    @AppStorage(GuidanceStyle.storageKey) private var guidanceStyleRawValue = GuidanceStyle.practical.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SimastrySpacing.xl) {
                AccountProfileSummary(viewModel: viewModel)

                AccountHubSection(title: "Your Simastry") {
                    NavigationLink(value: AccountHubRoute.birthChart) {
                        AccountHubRowLabel(
                            title: "Birth chart",
                            subtitle: viewModel.birthChartContextSummary,
                            systemImage: "point.3.connected.trianglepath.dotted",
                            accent: SimastryColor.gold
                        )
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityIdentifier("accountHub.birthChart")

                    AccountHubDivider()

                    NavigationLink(value: AccountHubRoute.journal) {
                        AccountHubRowLabel(
                            title: "Private journal",
                            subtitle: "Lines you saved on this device",
                            systemImage: "bookmark.fill",
                            accent: SimastryColor.celestialBlue
                        )
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityIdentifier("accountHub.journal")

                    AccountHubDivider()

                    NavigationLink(value: AccountHubRoute.guidanceStyle) {
                        AccountHubRowLabel(
                            title: "Guidance style",
                            subtitle: GuidanceStyle(rawValue: guidanceStyleRawValue)?.title ?? GuidanceStyle.practical.title,
                            systemImage: "slider.horizontal.3",
                            accent: SimastryColor.risingViolet
                        )
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityIdentifier("accountHub.guidanceStyle")
                }

                AccountHubSection(title: "App & privacy") {
                    if viewModel.experienceMode.isCompanionExperience {
                        NavigationLink(value: AccountHubRoute.companionMemory) {
                            AccountHubRowLabel(
                                title: "Companion memory & sync",
                                subtitle: "Review, edit, delete, or stop future private sync",
                                systemImage: "brain.head.profile",
                                accent: SimastryColor.risingViolet
                            )
                        }
                        .buttonStyle(SpringPressStyle())
                        .accessibilityIdentifier("accountHub.companionMemory")

                        AccountHubDivider()
                    }

                    NavigationLink(value: AccountHubRoute.settings) {
                        AccountHubRowLabel(
                            title: "Settings and privacy",
                            subtitle: "Notifications, data, and account controls",
                            systemImage: "gearshape.fill",
                            accent: SimastryColor.sageGreen
                        )
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityIdentifier("accountHub.settings")

                    AccountHubDivider()

                    NavigationLink(value: AccountHubRoute.methodology) {
                        AccountHubRowLabel(
                            title: "How Simastry works",
                            subtitle: "What is observed, calculated, or interpreted",
                            systemImage: "info.circle.fill",
                            accent: SimastryColor.sunCoral
                        )
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityIdentifier("accountHub.methodology")
                }

                if hasExpertArchive {
                    AccountHubSection(title: "Past consultations") {
                        NavigationLink(value: AccountHubRoute.expertArchive) {
                            AccountHubRowLabel(
                                title: "Expert archive",
                                subtitle: "Read-only history · export or delete",
                                systemImage: "archivebox.fill",
                                accent: SimastryColor.celestialBlue
                            )
                        }
                        .buttonStyle(SpringPressStyle())
                        .accessibilityIdentifier("accountHub.expertArchive")
                    }
                }

                if !viewModel.companionPivotState.legacyRecords.isEmpty {
                    AccountHubSection(title: "Legacy records") {
                        NavigationLink(value: AccountHubRoute.legacyCompanions) {
                            AccountHubRowLabel(
                                title: "Previous companions",
                                subtitle: "Read-only local records · never identity-matched",
                                systemImage: "tray.full.fill",
                                accent: SimastryColor.risingViolet
                            )
                        }
                        .buttonStyle(SpringPressStyle())
                        .accessibilityIdentifier("accountHub.legacyCompanions")
                    }
                }

                AccountHubSection(title: "Human help") {
                    Button(action: openAstrologerDirectory) {
                        AccountHubRowLabel(
                            title: "Find a human astrologer",
                            subtitle: "Continue with an independent professional",
                            systemImage: "person.crop.circle.badge.checkmark",
                            accent: SimastryColor.orchidPink,
                            trailingSystemImage: "arrow.up.right"
                        )
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityHint("Opens an external directory.")
                    .accessibilityIdentifier("accountHub.humanAstrologer")
                }

                Text("Your chart, journal, and private settings stay grouped here. Opening Account never changes the tab you were using.")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SimastrySpacing.xs)
            }
            .padding(.horizontal, SimastrySpacing.lg)
            .padding(.top, SimastrySpacing.sm)
            .padding(.bottom, SimastrySpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background { CelestialBackground() }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Close Account Hub")
            }
        }
        .accessibilityIdentifier("accountHub.screen")
    }

    private func openAstrologerDirectory() {
        HapticManager.buttonPress()
        openURL(AppConfig.astrologerDirectoryURL)
    }

    private var hasExpertArchive: Bool {
        !viewModel.specialistMessages.isEmpty
            || !viewModel.specialistConsultationResponses.isEmpty
    }
}
