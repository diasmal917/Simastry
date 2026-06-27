import SwiftUI

/// App-wide backdrop: the pastel zodiac wallpaper (`ZodiacWallpaper`) that the
/// landing screen introduces, now the standard across every screen so the look
/// stays consistent from first launch through the whole app.
///
/// A legibility veil sits over the art — light enough that the pastel zodiac
/// icons still read through, dark enough that text and glass cards on top keep
/// their contrast on content-dense screens.
struct CelestialBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black

            CosmicDriftImage(animated: !reduceMotion)
                .ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.46), location: 0),
                    .init(color: .black.opacity(0.34), location: 0.22),
                    .init(color: .black.opacity(0.44), location: 0.6),
                    .init(color: .black.opacity(0.58), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
