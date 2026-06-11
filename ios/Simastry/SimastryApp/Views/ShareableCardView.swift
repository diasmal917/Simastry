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
        case .cosmicDNA, .conversationGuide:
            // One consolidated card: signs + how to talk. The two types share
            // it so every entry point produces the same artifact.
            simastryCard
        case .compatibility:
            compatibilityCard
        case .reading:
            readingCard
        }
    }

    private var communicationTypeTitle: String? {
        CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )?.title
    }

    private var simastryCard: some View {
        ZStack {
            cardBackground

            VStack(spacing: 0) {
                Text("S I M A S T R Y")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(2)
                    .padding(.top, isStoryFormat ? 22 : 14)

                if isStoryFormat, viewModel.profileImage != nil {
                    ProfileImageView(image: viewModel.profileImage, size: 44, sunSign: viewModel.userSunSign)
                        .padding(.top, 10)
                }

                Spacer(minLength: 8)

                if let sun = viewModel.userSunSign,
                   let moon = viewModel.userMoonSign,
                   let rising = viewModel.userRisingSign {
                    VStack(spacing: isStoryFormat ? 16 : 9) {
                        ShareGlyphTrio(
                            sun: sun,
                            moon: moon,
                            rising: rising,
                            circleSize: isStoryFormat ? 58 : 46,
                            iconSize: isStoryFormat ? 34 : 26,
                            spacing: isStoryFormat ? 12 : 8
                        )

                        if let communicationTypeTitle {
                            Text(communicationTypeTitle)
                                .font(isStoryFormat ? SimastryFont.titleMedium : SimastryFont.titleSmall)
                                .foregroundStyle(SimastryColor.offWhite)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        howToTalkBlock(sun: sun)
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 8)

                if !viewModel.socialLinks.isEmpty {
                    socialLinksRow
                        .padding(.bottom, 4)
                }

                Text(AppConfig.universalLinkHost)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold.opacity(0.5))
                    .padding(.bottom, isStoryFormat ? 18 : 10)
            }
        }
    }

    private func howToTalkBlock(sun: ZodiacSign) -> some View {
        let copy = CommunicationTemplates.shareCardCopy[sun]

        return VStack(spacing: isStoryFormat ? 9 : 7) {
            Text("How to Talk to a \(sun.displayName)")
                .font(isStoryFormat ? SimastryFont.titleSmall : SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let copy {
                shareCallout(title: "Best Approach", body: copy.approach, tint: SimastryColor.gold)
                if isStoryFormat {
                    shareCallout(title: "What to Avoid", body: copy.avoid, tint: SimastryColor.amber)
                }
            }
        }
    }

    private func shareCallout(title: String, body: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(tint)
                .tracking(1)

            Text(body)
                .font(isStoryFormat ? SimastryFont.bodySmall : SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
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
                                ShareGlyphCircle(sign: sun, circleSize: 44, iconSize: 26)
                            }

                            Text("\(companion.compatibilityScore)%")
                                .font(SimastryFont.titleLarge)
                                .foregroundStyle(SimastryColor.gold)

                            if let compSun = ZodiacSign(rawValue: companion.sunSign) {
                                ShareGlyphCircle(sign: compSun, circleSize: 44, iconSize: 26)
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
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer()

                Text(AppConfig.universalLinkHost)
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
                        ShareGlyphCircle(sign: sun, circleSize: 52, iconSize: 30)

                        Text(sun.displayName)
                            .font(SimastryFont.titleMedium)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text(AstrologyTemplates.sunSign[sun.rawValue] ?? "")
                            .font(SimastryFont.bodyLarge)
                            .foregroundStyle(SimastryColor.amber)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                    }
                }

                Spacer()

                Text(AppConfig.universalLinkHost)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold.opacity(0.5))
                    .padding(.bottom, isStoryFormat ? 20 : 12)
            }
        }
    }

    /// Small row of social icons with usernames for shareable cards
    private var socialLinksRow: some View {
        HStack(spacing: 12) {
            if let ig = viewModel.socialLinks.instagram, !ig.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 8))
                    Text("@\(ig)")
                        .font(.system(size: 8))
                }
                .foregroundStyle(SimastryColor.offWhite.opacity(0.6))
            }
            if let tt = viewModel.socialLinks.tiktok, !tt.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 8))
                    Text("@\(tt)")
                        .font(.system(size: 8))
                }
                .foregroundStyle(SimastryColor.offWhite.opacity(0.6))
            }
            if let tw = viewModel.socialLinks.twitter, !tw.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "at")
                        .font(.system(size: 8))
                    Text("@\(tw)")
                        .font(.system(size: 8))
                }
                .foregroundStyle(SimastryColor.offWhite.opacity(0.6))
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

        let deepLink = deepLinkForCard
        var items: [Any] = [image]

        // Append the share text + universal link so recipients land in the app
        if let deepLink {
            items.append("\(deepLink.shareText)\n\(deepLink.universalLinkURL.absoluteString)")
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
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

    /// Builds the appropriate `DeepLink` for the current card type so the
    /// share sheet includes a URL that routes recipients into the app.
    private var deepLinkForCard: DeepLink? {
        switch cardType {
        case .compatibility:
            guard let userSun = viewModel.userSunSign,
                  let comp = resolvedCompanion,
                  let compSun = ZodiacSign(rawValue: comp.sunSign) else { return nil }
            return .compatibility(userSign: userSun.rawValue, companionSign: compSun.rawValue)

        case .conversationGuide:
            guard let sun = viewModel.userSunSign else { return nil }
            return .guide(sign: sun.rawValue)

        case .reading:
            guard let sun = viewModel.userSunSign else { return nil }
            return .guide(sign: sun.rawValue)

        case .cosmicDNA:
            return .home
        }
    }
}
