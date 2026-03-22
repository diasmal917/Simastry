import SwiftUI

struct RelationshipBadgeView: View {
    let level: RelationshipLevel
    let messageCount: Int
    let size: CGFloat

    init(level: RelationshipLevel, messageCount: Int, size: CGFloat = 48) {
        self.level = level
        self.messageCount = messageCount
        self.size = size
    }

    private var ringColor: Color {
        switch level {
        case .stranger: SimastryColor.mutedSilver.opacity(0.4)
        case .acquaintance: Color(red: 180/255, green: 140/255, blue: 90/255)
        case .familiar: Color(red: 192/255, green: 192/255, blue: 200/255)
        case .close: SimastryColor.gold
        case .bonded: SimastryColor.gold
        case .soulbound: SimastryColor.gold
        }
    }

    private var showShimmer: Bool {
        level == .bonded || level == .soulbound
    }

    var progress: Double {
        guard let next = level.nextThreshold else { return 1.0 }
        let current = level.threshold
        let range = next - current
        guard range > 0 else { return 1.0 }
        return min(1.0, Double(messageCount - current) / Double(range))
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .stroke(ringColor, lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .fill(ringColor.opacity(0.3))
                    }

                Text("Level \(level.rawValue)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ringColor)

                Text(level.name)
                    .font(.system(size: 12))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            if level != .soulbound {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(SimastryColor.mutedSilver.opacity(0.15))
                            .frame(height: 4)

                        Capsule()
                            .fill(ringColor)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
    }
}
