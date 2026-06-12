import SwiftUI

/// Async file-backed image for Moments — decodes off the main thread and
/// memoizes in a shared cache so the grid never blocks on disk I/O.
struct MomentImageView: View {
    let url: URL

    @State private var image: UIImage?

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        ZStack {
            SimastryColor.surfaceSunken

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .task(id: url.path) {
            let key = url.path as NSString
            if let cached = Self.cache.object(forKey: key) {
                image = cached
                return
            }

            let path = url.path
            let loaded = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: path)
            }.value

            if let loaded {
                Self.cache.setObject(loaded, forKey: key)
                withAnimation(.easeOut(duration: 0.15)) {
                    image = loaded
                }
            }
        }
    }
}
