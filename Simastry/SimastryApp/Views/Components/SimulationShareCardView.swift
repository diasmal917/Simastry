import SwiftUI
import Photos

struct SimulationShareCardView: View {
    let result: PredictionResult
    let userSunSign: ZodiacSign?

    @Environment(\.dismiss) private var dismiss
    @State private var isStoryFormat: Bool = true
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Header with close + format picker
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

            // Card preview
            ScrollView {
                cardPreview
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
            }

            // Action buttons
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

    // MARK: - Card Preview (scaled down for on-screen display)

    @ViewBuilder
    private var cardPreview: some View {
        let width: CGFloat = 270
        let height: CGFloat = isStoryFormat ? 480 : 270

        cardContent
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            .padding(.horizontal, 20)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        ZStack {
            cardBackground

            VStack(spacing: 0) {
                // Top branding
                brandingHeader
                    .padding(.top, isStoryFormat ? 28 : 18)

                Spacer()

                // Zodiac matchup glyphs
                signMatchup
                    .padding(.bottom, isStoryFormat ? 20 : 10)

                // Compatibility score ring
                confidenceRing
                    .padding(.bottom, isStoryFormat ? 16 : 8)

                // Teaser excerpt
                teaserExcerpt
                    .padding(.horizontal, 20)
                    .padding(.bottom, isStoryFormat ? 16 : 8)

                // Tone badge
                if let tone = result.tone {
                    toneBadge(tone)
                        .padding(.bottom, isStoryFormat ? 12 : 6)
                }

                Spacer()

                // CTA
                ctaText
                    .padding(.bottom, isStoryFormat ? 16 : 10)

                // Watermark
                watermark
                    .padding(.bottom, isStoryFormat ? 24 : 14)
            }
        }
    }

    // MARK: - Card Subviews

    private var brandingHeader: some View {
        VStack(spacing: 6) {
            Text("SIMASTRY")
                .font(SimastryFont.captionSmall)
                .italic()
                .foregroundStyle(SimastryColor.gold)

            Text("What will they say?")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(0.8)
        }
    }

    private var signMatchup: some View {
        HStack(spacing: isStoryFormat ? 16 : 12) {
            // User sun sign
            signGlyph(
                sign: userSunSign,
                fallbackSystemImage: "sun.max.fill",
                size: isStoryFormat ? 52 : 38
            )

            // Divider symbol
            Image(systemName: "sparkles")
                .font(.system(size: isStoryFormat ? 18 : 14, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)

            // Target sun sign
            signGlyph(
                sign: result.targetSunSign,
                fallbackSystemImage: "sparkles",
                size: isStoryFormat ? 52 : 38
            )
        }
    }

    private func signGlyph(sign: ZodiacSign?, fallbackSystemImage: String, size: CGFloat) -> some View {
        let signColor = sign?.color ?? SimastryColor.risingViolet
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [signColor.opacity(0.5), signColor.opacity(0.15)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size / 2
                        )
                    )
                    .frame(width: size, height: size)

                Circle()
                    .stroke(signColor.opacity(0.5), lineWidth: 1.5)
                    .frame(width: size, height: size)

                if let sign {
                    ZodiacIconView(sign: sign, size: size * 0.64, showsGlow: false)
                } else {
                    Image(systemName: fallbackSystemImage)
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(SimastryColor.offWhite)
                }
            }

            if let sign = sign {
                Text(sign.displayName)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(signColor)
            }
        }
    }

    private var confidenceRing: some View {
        ZStack {
            Circle()
                .stroke(SimastryColor.mutedSilver.opacity(0.2), lineWidth: 2.5)

            Circle()
                .trim(from: 0, to: Double(result.confidence) / 100.0)
                .stroke(
                    AngularGradient(
                        colors: [SimastryColor.gold, SimastryColor.amber, SimastryColor.gold],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(result.confidence)%")
                    .font(.system(size: isStoryFormat ? 14 : 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(SimastryColor.gold)
                Text("fit")
                    .font(.system(size: isStoryFormat ? 7 : 5, weight: .medium))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .frame(width: isStoryFormat ? 52 : 38, height: isStoryFormat ? 52 : 38)
    }

    private var teaserExcerpt: some View {
        let teaser = truncatedTeaser(result.predictedMessage, maxLength: 80)
        return VStack(spacing: 6) {
            Text("\"\(teaser)\"")
                .font(.system(isStoryFormat ? .callout : .caption, design: .serif))
                .foregroundStyle(SimastryColor.offWhite)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .lineLimit(3)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, isStoryFormat ? 12 : 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SimastryRadius.medium)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: SimastryRadius.medium)
                        .stroke(SimastryColor.gold.opacity(0.12), lineWidth: 0.5)
                )
        )
    }

    private func toneBadge(_ tone: SimulationTone) -> some View {
        let toneColor = result.targetSunSign?.color ?? SimastryColor.risingViolet
        return Text(tone.displayName)
            .font(SimastryFont.captionSmall)
            .foregroundStyle(toneColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(toneColor.opacity(0.14), in: .capsule)
    }

    private var ctaText: some View {
        HStack(spacing: 4) {
            Text("See the full reading")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.gold.opacity(0.8))
            Image(systemName: "arrow.right")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(SimastryColor.gold.opacity(0.8))
        }
    }

    private var watermark: some View {
        Text(AppConfig.universalLinkHost)
            .font(SimastryFont.captionSmall)
            .foregroundStyle(SimastryColor.gold.opacity(0.45))
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        ZStack {
            // Deep gradient
            LinearGradient(
                colors: [
                    Color(red: 14/255, green: 10/255, blue: 30/255),
                    SimastryColor.midnight,
                    Color(red: 8/255, green: 18/255, blue: 38/255),
                    SimastryColor.midnight,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Accent glow from target sign color
            let accentColor = result.targetSunSign?.color ?? SimastryColor.risingViolet
            RadialGradient(
                colors: [accentColor.opacity(0.12), .clear],
                center: .init(x: 0.5, y: 0.3),
                startRadius: 20,
                endRadius: 200
            )

            // Gold accent glow at bottom
            RadialGradient(
                colors: [SimastryColor.gold.opacity(0.06), .clear],
                center: .init(x: 0.5, y: 0.85),
                startRadius: 10,
                endRadius: 160
            )

            // Starfield
            StarfieldView()
                .opacity(0.5)
        }
    }

    // MARK: - Helpers

    private func truncatedTeaser(_ text: String, maxLength: Int) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count <= maxLength {
            return cleaned
        }

        // Try to break at sentence boundary
        let truncated = String(cleaned.prefix(maxLength))
        if let lastPeriod = truncated.lastIndex(of: ".") {
            let candidate = String(truncated[truncated.startIndex...lastPeriod])
            if candidate.count >= 30 {
                return candidate
            }
        }

        // Break at last space
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[truncated.startIndex..<lastSpace]) + "..."
        }

        return truncated + "..."
    }

    // MARK: - Rendering & Sharing

    @MainActor
    private func renderImage() -> UIImage? {
        let width: CGFloat = isStoryFormat ? 1080 : 1080
        let height: CGFloat = isStoryFormat ? 1920 : 1080
        let scale: CGFloat = width / 270

        let renderer = ImageRenderer(
            content: cardContent
                .frame(width: width / scale, height: height / scale)
        )
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
                }
            }
        }
    }

    private func shareCard() {
        guard let image = renderImage() else { return }

        var items: [Any] = [image]
        if let deepLink = shareDeepLink {
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

    private var shareDeepLink: DeepLink? {
        if let targetSign = result.targetSunSign {
            return .guide(sign: targetSign.rawValue)
        }
        return .home
    }
}
