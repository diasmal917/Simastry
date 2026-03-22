import SwiftUI
import Photos

struct ShareableCardView: View {
    let viewModel: AppViewModel
    let cardType: ShareableCardType
    let companion: CompanionData?
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AppViewModel, cardType: ShareableCardType, companion: CompanionData? = nil) {
        self.viewModel = viewModel
        self.cardType = cardType
        self.companion = companion
    }
    @State private var isStoryFormat: Bool = true
    @State private var appeared: Bool = false
    @State private var renderedImage: UIImage?

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Close") { dismiss() }
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                Spacer()

                Picker("Format", selection: $isStoryFormat) {
                    Text("Story").tag(true)
                    Text("Post").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ScrollView {
                cardPreview
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
            }

            HStack(spacing: 16) {
                Button(action: saveToPhotos) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Save")
                    }
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .simastryGlassPill()
                }
                .buttonStyle(SpringPressStyle())

                Button(action: shareCard) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.midnight)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .goldGlassPill()
                }
                .buttonStyle(SpringPressStyle())
            }
            .padding(.bottom, 20)
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(SimastrySpring.bouncy).delay(0.2)) {
                appeared = true
            }
        }
    }

    private var resolvedCompanion: CompanionData? {
        companion ?? viewModel.primaryCompanion
    }

    @ViewBuilder
    private var cardPreview: some View {
        let width: CGFloat = isStoryFormat ? 270 : 270
        let height: CGFloat = isStoryFormat ? 480 : 270

        cardContent
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var cardContent: some View {
        switch cardType {
        case .cosmicDNA:
            cosmicDNACard
        case .compatibility:
            compatibilityCard
        case .reading:
            readingCard
        }
    }

    private var cosmicDNACard: some View {
        ZStack {
            cardBackground

            VStack(spacing: 0) {
                Text("S I M A S T R Y")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(2)
                    .padding(.top, isStoryFormat ? 24 : 16)

                Spacer()

                if let sun = viewModel.userSunSign,
                   let moon = viewModel.userMoonSign,
                   let rising = viewModel.userRisingSign {
                    VStack(spacing: isStoryFormat ? 20 : 10) {
                        cardSignRow(role: .sun, sign: sun)
                        cardSignRow(role: .moon, sign: moon)
                        cardSignRow(role: .rising, sign: rising)
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                Text("simastry.app")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold.opacity(0.5))
                    .padding(.bottom, isStoryFormat ? 20 : 12)
            }
        }
    }

    private var compatibilityCard: some View {
        ZStack {
            cardBackground

            VStack(spacing: 0) {
                Text("S I M A S T R Y")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(2)
                    .padding(.top, isStoryFormat ? 24 : 16)

                Spacer()

                if let companion = resolvedCompanion {
                    VStack(spacing: 12) {
                        HStack(spacing: 20) {
                            if let sun = viewModel.userSunSign {
                                ZodiacBadgeView(sign: sun, isSelected: true, size: 40)
                            }

                            Text("\(companion.compatibilityScore)%")
                                .font(SimastryFont.titleLarge)
                                .foregroundStyle(SimastryColor.gold)

                            if let compSun = ZodiacSign(rawValue: companion.sunSign) {
                                ZodiacBadgeView(sign: compSun, isSelected: true, size: 40)
                            }
                        }

                        if let userSun = viewModel.userSunSign,
                           let compSun = ZodiacSign(rawValue: companion.sunSign) {
                            Text(AstrologyTemplates.elementPairingText(
                                element1: userSun.element.rawValue,
                                element2: compSun.element.rawValue
                            ))
                            .font(SimastryFont.bodyLarge)
                            .foregroundStyle(SimastryColor.amber)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer()

                Text("simastry.app")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold.opacity(0.5))
                    .padding(.bottom, isStoryFormat ? 20 : 12)
            }
        }
    }

    private var readingCard: some View {
        ZStack {
            cardBackground

            VStack(spacing: 0) {
                Text("S I M A S T R Y")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(2)
                    .padding(.top, isStoryFormat ? 24 : 16)

                Spacer()

                if let sun = viewModel.userSunSign {
                    VStack(spacing: 12) {
                        ZodiacBadgeView(sign: sun, isSelected: true, size: 48)

                        Text(sun.displayName)
                            .font(SimastryFont.titleMedium)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text(AstrologyTemplates.sunSign[sun.rawValue] ?? "")
                            .font(SimastryFont.bodyLarge)
                            .foregroundStyle(SimastryColor.amber)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 20)
                    }
                }

                Spacer()

                Text("simastry.app")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold.opacity(0.5))
                    .padding(.bottom, isStoryFormat ? 20 : 12)
            }
        }
    }

    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SimastryColor.midnight,
                    Color(red: 15/255, green: 22/255, blue: 41/255),
                    SimastryColor.midnight
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            StarfieldView()
                .opacity(0.6)
        }
    }

    private func cardSignRow(role: CelestialRole, sign: ZodiacSign) -> some View {
        HStack(spacing: 10) {
            CelestialRoleIcon(role: role, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(role.displayName) in \(sign.displayName) \(sign.glyph)")
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(role.accentColor)
                Text(role.subtitle)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
            }

            Spacer()
        }
    }

    @MainActor
    private func renderImage() -> UIImage? {
        let width: CGFloat = isStoryFormat ? 1080 : 1080
        let height: CGFloat = isStoryFormat ? 1920 : 1080
        let scale: CGFloat = width / (isStoryFormat ? 270 : 270)

        let renderer = ImageRenderer(content: cardContent.frame(width: width / scale, height: height / scale))
        renderer.scale = scale
        return renderer.uiImage
    }

    private func saveToPhotos() {
        guard let image = renderImage() else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            if status == .authorized || status == .limited {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                Task { @MainActor in
                    HapticManager.soulFlash()
                    viewModel.showToast("Saved to Photos", subtitle: "Your card is ready to share", isError: false)
                }
            }
        }
    }

    private func shareCard() {
        guard let image = renderImage() else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }
}
