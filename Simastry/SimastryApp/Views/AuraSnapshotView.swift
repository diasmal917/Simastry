import PhotosUI
import SwiftUI
import UIKit

struct AuraSnapshotCard: View {
    let snapshot: AuraSnapshot?
    var compact: Bool = false
    let onOpen: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "camera.filters")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.risingViolet)
                    .frame(width: 32, height: 32)
                    .background(SimastryColor.risingViolet.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("AURA SNAPSHOT")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.risingViolet)
                        .tracking(1.4)

                    Text(snapshot == nil ? "Use a photo’s colors and your chosen mood to tune today’s vibe." : snapshot?.descriptor.displayLine ?? "")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            if let snapshot {
                auraResult(snapshot)
            } else if !compact {
                Text("Optional and local. Simastry reads only palette, brightness, contrast, and the mood you choose.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button {
                    HapticManager.buttonPress()
                    onOpen()
                } label: {
                    Label(snapshot == nil ? "Tune today’s vibe" : "Retake", systemImage: "camera.fill")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(SimastryColor.risingViolet.opacity(0.16), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(SimastryColor.risingViolet.opacity(0.26), lineWidth: 0.7)
                        }
                }
                .buttonStyle(SpringPressStyle())

                if snapshot != nil {
                    Button {
                        HapticManager.buttonPress()
                        onClear()
                    } label: {
                        Text("Clear")
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(SpringPressStyle())
                }
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.risingViolet.opacity(0.7))
        .accessibilityElement(children: .combine)
    }

    private func auraResult(_ snapshot: AuraSnapshot) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            resultRow("Today’s vibe", snapshot.result.todayVibe)
            if !compact {
                resultRow("Best move", snapshot.result.bestMove)
                resultRow("Wear / reset / focus", snapshot.result.wearEatFocus)
                resultRow("If you’re texting them", snapshot.result.textingHint)
            }
            resultRow("Prediction tuning note", snapshot.result.predictionTuningNote)

            Text(AuraSnapshotService.privacyNotice)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(SimastryColor.offWhite.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func resultRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(SimastryFont.overline)
                .tracking(1.0)
                .foregroundStyle(SimastryColor.textSecondary)
            Text(body)
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AuraSnapshotSheet: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var selectedMood: AuraSnapshotMood = .focused
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        pickerPanel
                        if let previewImage {
                            previewPanel(previewImage)
                            moodPanel
                            resultPreview
                        }
                        privacyPanel
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Aura Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await loadPhoto(newItem) }
        }
        .sheet(isPresented: $showCamera) {
            AuraSnapshotCameraPicker(image: $previewImage)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tune today’s vibe from a photo’s colors and the mood you choose.")
                .font(SimastryFont.titleMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)

            Text("Any photo works — Simastry reads only its light, color, and contrast. Your mood chip is chosen by you, not inferred.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .heroGlass(SimastryColor.risingViolet, cornerRadius: 24)
    }

    private var pickerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Label(previewImage == nil ? "Choose photo" : "Choose another", systemImage: "photo.on.rectangle.angled")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(SimastryColor.risingViolet.opacity(0.16), in: Capsule())
                }
                .buttonStyle(SpringPressStyle())

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SimastryColor.offWhite)
                            .frame(width: 48, height: 48)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityLabel("Take photo")
                }
            }

            if isLoadingPhoto {
                Label("Preparing photo locally...", systemImage: "arrow.triangle.2.circlepath")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            if let photoError {
                Text(photoError)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.sunCoral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.risingViolet.opacity(0.55))
    }

    private func previewPanel(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 0.8)
            }
            .accessibilityLabel("Selected Aura Snapshot preview")
    }

    private var moodPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your mood")
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(AuraSnapshotMood.allCases) { mood in
                    Button {
                        HapticManager.buttonPress()
                        selectedMood = mood
                    } label: {
                        Text(mood.title)
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(selectedMood == mood ? SimastryColor.midnight : SimastryColor.offWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selectedMood == mood ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(.white.opacity(0.07)),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(SpringPressStyle())
                }
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.gold.opacity(0.5))
    }

    @ViewBuilder
    private var resultPreview: some View {
        if let previewImage,
           let snapshot = viewModel.auraSnapshotService.makeSnapshot(
            from: previewImage,
            mood: selectedMood,
            userSunSign: viewModel.userSunSign,
            userMoonSign: viewModel.userMoonSign,
            userRisingSign: viewModel.userRisingSign
           ) {
            VStack(alignment: .leading, spacing: 12) {
                AuraSnapshotCard(snapshot: snapshot, compact: true, onOpen: {}, onClear: {})
                    .allowsHitTesting(false)

                Button {
                    HapticManager.buttonPress()
                    _ = viewModel.applyAuraSnapshot(image: previewImage, mood: selectedMood)
                    dismiss()
                } label: {
                    Label("Use this snapshot", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(SimastryAccentButtonStyle(accent: SimastryColor.risingViolet))
            }
        }
    }

    private var privacyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Private by default", systemImage: "lock.fill")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.gold)

            Text(AuraSnapshotService.privacyNotice)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Simastry does not upload this photo, store it by default, identify you, or create face geometry/templates. V1 keeps only today’s palette and mood descriptors on this device; those descriptors may tune AI guidance when you ask for it.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .simastryGlass(cornerRadius: 20)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingPhoto = true
        photoError = nil
        defer {
            isLoadingPhoto = false
            pickerItem = nil
        }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            photoError = "That photo could not be read. Try another image."
            return
        }

        previewImage = resize(image, maxDimension: 900)
    }

    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private struct AuraSnapshotCameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding private var image: UIImage?
        private let dismiss: DismissAction

        init(image: Binding<UIImage?>, dismiss: DismissAction) {
            _image = image
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            image = info[.originalImage] as? UIImage
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
