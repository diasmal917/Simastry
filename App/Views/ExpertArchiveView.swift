import SwiftUI

/// Signed-out archive-mode handoff. It never reopens active consultations; it
/// simply lets an existing user authenticate to reach their conditional
/// read-only archive in Account.
struct ExpertArchiveOnboardingView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        ZStack {
            CelestialBackground()
            VStack(spacing: SimastrySpacing.lg) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                Text("Expert consultations are archived")
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .multilineTextAlignment(.center)
                Text("New expert readings are closed. Sign in to view, export, or delete any consultation history already connected to your account.")
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                GoldButton("Continue to sign in") {
                    viewModel.currentScreen = .signIn
                }
            }
            .padding(28)
        }
        .accessibilityIdentifier("expertArchive.onboarding")
    }
}

/// Conditional, read-only access to consultations created before the primary
/// companion pilot. It deliberately uses neutral symbols instead of reviving
/// any expert portrait or active-consultation affordance.
struct ExpertArchiveView: View {
    @Bindable var viewModel: AppViewModel

    @State private var confirmsDeletion = false
    @State private var isDeleting = false
    @State private var deletionNotice: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SimastrySpacing.lg) {
                archiveNotice

                if let deletionNotice {
                    Text(deletionNotice)
                        .font(SimastryFont.caption)
                        .foregroundStyle(Color.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, SimastrySpacing.xs)
                }

                if archiveItems.isEmpty {
                    ContentUnavailableView(
                        "Archive empty",
                        systemImage: "archivebox",
                        description: Text("No past expert consultations remain on this account.")
                    )
                    .foregroundStyle(SimastryColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    ForEach(archiveItems) { item in
                        archiveCard(item)
                    }

                    archiveControls
                }
            }
            .padding(SimastrySpacing.lg)
            .padding(.bottom, SimastrySpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { CelestialBackground() }
        .navigationTitle("Expert archive")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete expert archive?", isPresented: $confirmsDeletion) {
            Button("Cancel", role: .cancel) {}
            Button("Delete permanently", role: .destructive) {
                deleteArchive()
            }
        } message: {
            Text("This permanently deletes the original expert messages, consultations, intake, and uploaded expert-chart images. It cannot be undone.")
        }
        .accessibilityIdentifier("expertArchive.screen")
    }

    private var archiveNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Read-only archive", systemImage: "lock.fill")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.gold)
            Text("These are your original consultations. The five experts are no longer available for new readings; their records have not been merged into companion histories.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SimastrySpacing.lg)
        .contentSurface(cornerRadius: SimastryRadius.card, accent: SimastryColor.gold)
    }

    private func archiveCard(_ item: ExpertArchiveItem) -> some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            HStack(alignment: .top, spacing: SimastrySpacing.sm) {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimastryColor.celestialBlue)
                    .frame(width: 34, height: 34)
                    .background(SimastryColor.celestialBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.tradition)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.textPrimary)
                    Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.textTertiary)
                }
                Spacer(minLength: 0)
                Text("ARCHIVED")
                    .font(SimastryFont.overline)
                    .tracking(1)
                    .foregroundStyle(SimastryColor.textTertiary)
            }

            if let question = item.question {
                archiveText(label: "You", text: question)
            }
            archiveText(label: item.responseLabel, text: item.response)
        }
        .padding(SimastrySpacing.lg)
        .contentSurface(cornerRadius: SimastryRadius.card)
        .accessibilityElement(children: .contain)
    }

    private func archiveText(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textTertiary)
                .tracking(1)
            Text(text)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var archiveControls: some View {
        VStack(spacing: SimastrySpacing.sm) {
            ShareLink(item: exportText, preview: SharePreview("Simastry expert archive")) {
                Label("Export archive", systemImage: "square.and.arrow.up")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .interactiveGlass(cornerRadius: SimastryRadius.medium, tint: SimastryColor.celestialBlue)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityIdentifier("expertArchive.export")

            Button(role: .destructive) {
                confirmsDeletion = true
            } label: {
                Label(isDeleting ? "Deleting…" : "Delete archive", systemImage: "trash")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(Color.red.opacity(0.9))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: SimastryRadius.medium))
            }
            .buttonStyle(SpringPressStyle())
            .disabled(isDeleting)
            .accessibilityIdentifier("expertArchive.delete")

        }
    }

    private var archiveItems: [ExpertArchiveItem] {
        let messages = viewModel.specialistMessages.map { message in
            ExpertArchiveItem(
                id: "message-\(message.id.uuidString)",
                tradition: traditionName(message.specialistId),
                timestamp: message.timestamp,
                question: nil,
                responseLabel: message.role == .user ? "You" : "Archived response",
                response: message.content
            )
        }
        let consultations = viewModel.specialistConsultationResponses.compactMap { response -> ExpertArchiveItem? in
            guard let text = response.specialistResponse ?? response.errorMessage else { return nil }
            return ExpertArchiveItem(
                id: "consultation-\(response.id.uuidString)",
                tradition: traditionName(response.specialistId),
                timestamp: response.timestamp,
                question: response.userQuestion,
                responseLabel: "Archived response",
                response: text
            )
        }
        return (messages + consultations).sorted { $0.timestamp > $1.timestamp }
    }

    private func traditionName(_ specialistId: String) -> String {
        guard let specialist = ExpertAstrologerRegistry.specialist(id: specialistId) else {
            return "Past astrology consultation"
        }
        return specialist.tradition
    }

    private var exportText: String {
        let header = "Simastry expert archive\nExported \(Date().formatted(date: .long, time: .shortened))\n"
        return archiveItems.reduce(header) { partial, item in
            var block = "\n---\n\(item.tradition) · \(item.timestamp.formatted(date: .abbreviated, time: .shortened))\n"
            if let question = item.question { block += "You: \(question)\n" }
            block += "\(item.responseLabel): \(item.response)\n"
            return partial + block
        }
    }

    private func deleteArchive() {
        isDeleting = true
        deletionNotice = nil
        Task {
            defer { isDeleting = false }
            do {
                let storageCleanupConfirmed = try await viewModel.deleteExpertArchive()
                if !storageCleanupConfirmed {
                    deletionNotice = "The archive records were deleted. Cleanup of one or more private chart images could not be confirmed and will be retried during account deletion."
                }
            } catch {
                deletionNotice = "Nothing was removed because the database transaction could not be confirmed. \(error.localizedDescription)"
            }
        }
    }
}

private struct ExpertArchiveItem: Identifiable {
    let id: String
    let tradition: String
    let timestamp: Date
    let question: String?
    let responseLabel: String
    let response: String
}
