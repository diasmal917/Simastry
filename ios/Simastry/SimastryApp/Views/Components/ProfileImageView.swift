import SwiftUI

struct ProfileImageView: View {
    let image: UIImage?
    let size: CGFloat
    let showEditBadge: Bool
    let sunSign: ZodiacSign?
    let sunSignGlyph: String?

    init(image: UIImage?, size: CGFloat, showEditBadge: Bool = false, sunSign: ZodiacSign? = nil, sunSignGlyph: String? = nil) {
        self.image = image
        self.size = size
        self.showEditBadge = showEditBadge
        self.sunSign = sunSign
        self.sunSignGlyph = sunSignGlyph
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        SimastryColor.goldLight,
                                        SimastryColor.gold,
                                        SimastryColor.goldDark
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: size > 60 ? 2.5 : 1.5
                            )
                    )
            } else {
                let cornerRadius = min(size * 0.24, 24)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        SimastryColor.gold.opacity(0.4),
                                        SimastryColor.gold.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                    )
                    .overlay(
                        VStack(spacing: size > 60 ? 4 : 2) {
                            if let glyph = sunSignGlyph, !glyph.isEmpty {
                                Text(glyph)
                                    .font(.system(size: size * 0.4))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [SimastryColor.goldLight, SimastryColor.gold],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: size * 0.2, weight: .medium))
                                    .foregroundStyle((sunSign?.color ?? SimastryColor.gold).opacity(0.78))
                            }

                            if size >= 80 && sunSignGlyph == nil {
                                Text("Add Photo")
                                    .font(SimastryFont.captionSmall)
                                    .foregroundStyle(SimastryColor.gold.opacity(0.5))
                            }
                        }
                    )
            }

            if showEditBadge, image != nil {
                ZStack {
                    Circle()
                        .fill(SimastryColor.midnight)
                        .frame(width: size * 0.28, height: size * 0.28)

                    Circle()
                        .fill(SimastryColor.gold)
                        .frame(width: size * 0.24, height: size * 0.24)

                    Image(systemName: "pencil")
                        .font(.system(size: size * 0.1, weight: .bold))
                        .foregroundStyle(SimastryColor.midnight)
                }
                .offset(x: size * 0.02, y: size * 0.02)
            }
        }
    }
}
