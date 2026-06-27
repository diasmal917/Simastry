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
                SimastryWordmark(font: .system(.caption2, weight: .bold).italic(), sparkles: false)
                    .padding(.top, isStoryFormat ? 22 : 14)

                Spacer(minLength: 8)

                if let sun = viewModel.userSunSign {
                    let moon = viewModel.userMoonSign
                    let rising = viewModel.userRisingSign

                    VStack(spacing: isStoryFormat ? 16 : 9) {
                        shareIdentityRow(sun: sun, moon: moon, rising: rising)

                        if let communicationTypeTitle {
                            Text(communicationTypeTitle)
                                .font(isStoryFormat ? SimastryFont.titleMedium : SimastryFont.titleSmall)
                                .foregroundStyle(SimastryColor.offWhite)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        howToTalkBlock(sun: sun, moon: moon, rising: rising)
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 8)

                if let publicUsername {
                    publicUsernameRow(publicUsername)
                        .padding(.bottom, 4)
                }

                Text(AppConfig.websiteDisplayName)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold.opacity(0.5))
                    .padding(.bottom, isStoryFormat ? 18 : 10)
            }
        }
    }

    private func shareIdentityRow(sun: ZodiacSign, moon: ZodiacSign?, rising: ZodiacSign?) -> some View {
        HStack(spacing: isStoryFormat ? 8 : 7) {
            ShareGlyphCircle(
                sign: sun,
                circleSize: isStoryFormat ? 52 : 43,
                iconSize: isStoryFormat ? 48 : 39
            )

            if let moon {
                ShareGlyphCircle(
                    sign: moon,
                    circleSize: isStoryFormat ? 52 : 43,
                    iconSize: isStoryFormat ? 48 : 39
                )
            }

            if let rising {
                ShareGlyphCircle(
                    sign: rising,
                    circleSize: isStoryFormat ? 52 : 43,
                    iconSize: isStoryFormat ? 48 : 39
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shareIdentityAccessibilityLabel(sun: sun, moon: moon, rising: rising))
    }

    private func howToTalkBlock(sun: ZodiacSign, moon: ZodiacSign?, rising: ZodiacSign?) -> some View {
        let copy = CommunicationTemplates.shareCardCopy[sun]

        return VStack(spacing: isStoryFormat ? 9 : 7) {
            Text(shareHowToTalkTitle(sun: sun, moon: moon, rising: rising))
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

    private func shareHowToTalkTitle(sun: ZodiacSign, moon: ZodiacSign?, rising: ZodiacSign?) -> String {
        var title = "How to Talk to \(article(for: sun)) \(sun.displayName)"
        var placements: [String] = []

        if let rising {
            placements.append("\(rising.displayName) Rising")
        }
        if let moon {
            placements.append("\(moon.displayName) Moon")
        }
        if !placements.isEmpty {
            title += " with \(placements.joined(separator: " and "))"
        }

        return title
    }

    private func article(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries, .aquarius:
            return "an"
        default:
            return "a"
        }
    }

    private func shareIdentityAccessibilityLabel(sun: ZodiacSign, moon: ZodiacSign?, rising: ZodiacSign?) -> String {
        var parts = ["Sun \(sun.displayName)"]
        if let moon {
            parts.append("Moon \(moon.displayName)")
        }
        if let rising {
            parts.append("Rising \(rising.displayName)")
        }
        return parts.joined(separator: ", ")
    }

    private var compatibilityCard: some View {
        ZStack {
            cardBackground

            VStack(spacing: 0) {
                SimastryWordmark(font: .system(.caption2, weight: .bold).italic(), sparkles: false)
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

                Text(AppConfig.websiteDisplayName)
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
                SimastryWordmark(font: .system(.caption2, weight: .bold).italic(), sparkles: false)
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

                Text(AppConfig.websiteDisplayName)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold.opacity(0.5))
                    .padding(.bottom, isStoryFormat ? 20 : 12)
            }
        }
    }

    private var publicUsername: String? {
        let normalized = PublicProfile.normalizedUsername(viewModel.publicUsername)
        guard PublicProfile.isValidUsername(normalized) else { return nil }
        return normalized
    }

    private func publicUsernameRow(_ username: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "at")
                .font(.system(size: 8, weight: .semibold))
            Text(username)
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundStyle(SimastryColor.offWhite.opacity(0.62))
        .help("Source: your single Simastry public username.")
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
        guard let image = renderImage() else {
            viewModel.showToast("Couldn't save card", subtitle: "Try again in a moment.", isError: true)
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            if status == .authorized || status == .limited {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                Task { @MainActor in
                    HapticManager.soulFlash()
                    viewModel.showToast("Saved to Photos", subtitle: "Your card is ready to share", isError: false)
                }
            } else {
                Task { @MainActor in
                    viewModel.showToast(
                        "Photos access denied",
                        subtitle: "Allow photo access in Settings to save your card.",
                        isError: true
                    )
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
