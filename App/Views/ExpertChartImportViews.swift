import SwiftUI
import PhotosUI

/// Reusable "upload a chart screenshot" card for the signed-in user or a saved
/// person. Uploads to private storage, records an import row, then opens the
/// manual confirm screen. No OCR/vision runs — the user confirms what the
/// screenshot shows, and confirmed details are treated as user-supplied.
struct ExpertChartImportSection: View {
    @Bindable var viewModel: AppViewModel
    let subject: ExpertChartSubject

    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var confirmingImport: ExpertChartImportRecord?

    private var latest: ExpertChartImportRecord? {
        viewModel.latestChartImport(for: subject)
    }

    private var subjectIdentifier: String {
        switch subject {
        case .userSelf: "self"
        case .person: "person"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chart screenshot")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Upload a screenshot from any chart app. You confirm what it shows — nothing is read automatically, and confirmed details count as user-supplied, never app-calculated.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)

            if let latest {
                statusRow(for: latest)
            }

            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                Label(
                    latest == nil ? "Upload chart screenshot" : "Replace screenshot",
                    systemImage: "photo.badge.plus"
                )
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .goldGlassPill(interactive: true)
            }
            .disabled(isUploading)
            .opacity(isUploading ? 0.6 : 1)
            .accessibilityIdentifier("expertAstrologers.chartImport.uploadButton.\(subjectIdentifier)")

            if isUploading {
                HStack(spacing: 8) {
                    ProgressView().tint(SimastryColor.gold).scaleEffect(0.85)
                    Text("Uploading…")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .surfaceCard(cornerRadius: 18, accent: SimastryColor.gold.opacity(0.35))
        .accessibilityIdentifier("expertAstrologers.chartImport.\(subjectIdentifier)")
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                isUploading = true
                defer { isUploading = false }
                guard let data = try? await newItem.loadTransferable(type: Data.self) else {
                    selectedItem = nil
                    return
                }
                let record = await viewModel.uploadExpertChartImage(data, subject: subject)
                selectedItem = nil
                if let record { confirmingImport = record }
            }
        }
        .sheet(item: $confirmingImport) { record in
            ExpertChartConfirmView(viewModel: viewModel, subject: subject, record: record)
        }
    }

    private func statusRow(for record: ExpertChartImportRecord) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: record.isConfirmed ? "checkmark.seal.fill" : "photo.fill")
                .font(SimastryFont.caption)
                .foregroundStyle(record.isConfirmed ? SimastryColor.gold : SimastryColor.mutedSilver)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.isConfirmed ? "Chart details confirmed" : "Screenshot uploaded")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                Text(record.isConfirmed
                     ? "Only the fields you confirmed are shared with the experts."
                     : "Review and confirm what it shows so the experts can use it.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                confirmingImport = record
            } label: {
                Text(record.isConfirmed ? "Edit" : "Review")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .simastryGlassPill(interactive: true)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityIdentifier("expertAstrologers.chartImport.reviewButton.\(subjectIdentifier)")
        }
        .padding(12)
        .background(SimastryColor.surfaceSunken.opacity(0.4), in: .rect(cornerRadius: 14))
    }
}

/// Manual confirm screen. Lists only the backend-whitelisted labels; the user
/// types what the screenshot shows. Saving writes non-empty values to
/// `confirmed_data`. Nothing is auto-extracted, and `extracted_data` is never set.
struct ExpertChartConfirmView: View {
    @Bindable var viewModel: AppViewModel
    let subject: ExpertChartSubject
    let record: ExpertChartImportRecord

    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String]
    @State private var isSaving = false

    init(viewModel: AppViewModel, subject: ExpertChartSubject, record: ExpertChartImportRecord) {
        self.viewModel = viewModel
        self.subject = subject
        self.record = record
        // Seed from any previously confirmed values so editing is non-destructive.
        _values = State(initialValue: record.confirmedData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    fieldGroup(title: "Western placements", fields: ExpertConfirmedChartCatalog.western)
                    fieldGroup(title: "Tradition fields", fields: ExpertConfirmedChartCatalog.tradition)
                }
                .padding(20)
            }
            .navigationTitle("Confirm Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                }
            }
        }
        .presentationBackground { CelestialBackground() }
        .accessibilityIdentifier("expertAstrologers.chartConfirm")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From your screenshot")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold)
                .tracking(1)
            Text("Type only what you can see in the screenshot. These are user-supplied, not app-calculated, and only the fields you confirm here are shared with the experts.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .surfaceCard(cornerRadius: 18)
    }

    private func fieldGroup(title: String, fields: [ExpertConfirmedChartField]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)

            ForEach(fields) { field in
                VStack(alignment: .leading, spacing: 5) {
                    Text(field.label)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.gold.opacity(0.88))
                    TextField(
                        field.placeholder,
                        text: Binding(
                            get: { values[field.key] ?? "" },
                            set: { values[field.key] = $0 }
                        ),
                        axis: .vertical
                    )
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(field.multiline ? 2...4 : 1...2)
                    .padding(12)
                    .background(SimastryColor.surfaceSunken.opacity(0.55), in: .rect(cornerRadius: 14))
                    .accessibilityIdentifier("expertAstrologers.chartConfirm.field.\(field.key)")
                }
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 18)
    }

    private func save() {
        isSaving = true
        Task {
            let ok = await viewModel.confirmExpertChartImport(
                record,
                confirmedValues: values,
                subject: subject
            )
            isSaving = false
            if ok { dismiss() }
        }
    }
}
