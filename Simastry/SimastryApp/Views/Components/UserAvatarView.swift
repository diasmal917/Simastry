import SwiftUI

struct UserAvatarView: View {
    let urlString: String?
    let initials: String
    let accent: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.36),
                            SimastryColor.plum.opacity(0.46),
                            SimastryColor.midnight.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackInitials
                    case .empty:
                        ProgressView()
                            .tint(SimastryColor.gold)
                    @unknown default:
                        fallbackInitials
                    }
                }
            } else {
                fallbackInitials
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.22), radius: size * 0.18, x: 0, y: size * 0.09)
    }

    private var fallbackInitials: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .semibold, design: .serif))
            .foregroundStyle(SimastryColor.cream)
    }
}

extension SearchableUserProfile {
    var initials: String {
        (displayName.hasPrefix("@") ? username : displayName)
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
    }
}
