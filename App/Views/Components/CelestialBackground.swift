import SwiftUI

/// App-wide backdrop used on every screen *past* the landing flow: a deep,
/// matte deep-space starfield (`SpaceWallpaper`). The landing screen keeps its
/// own pastel zodiac introduction (`ZodiacWallpaper`); from there on the app
/// settles into this calmer, near-black cosmos so Liquid Glass surfaces read as
/// luminous objects floating over space rather than over a busy illustration.
///
/// A light legibility veil sits over the art — the wallpaper is already
/// near-black, so the veil only needs to deepen the lower third where dense
/// content and the floating tab bar sit.
struct CelestialBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black

            // Held perfectly still in-app (no Ken Burns zoom) so the starfield
            // reads as a calm, fixed cosmos rather than drifting under content.
            // The landing screen keeps its own slow drift.
            CosmicDriftImage(animated: false, imageName: "SpaceWallpaper")
                .ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.18), location: 0),
                    .init(color: .black.opacity(0.10), location: 0.28),
                    .init(color: .black.opacity(0.22), location: 0.66),
                    .init(color: .black.opacity(0.40), location: 1)
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
