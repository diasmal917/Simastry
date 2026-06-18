import SwiftUI

struct MomentImageView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [SimastryColor.gold.opacity(0.30), SimastryColor.risingViolet.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}
