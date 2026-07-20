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

    /// Shared ring tint so compact chips and the full badge can't drift.
    static func ringColor(for level: RelationshipLevel) -> Color {
        switch level {
        case .stranger: SimastryColor.mutedSilver.opacity(0.4)
        case .acquaintance: Color(red: 180/255, green: 140/255, blue: 90/255)
        case .familiar: Color(red: 192/255, green: 192/255, blue: 200/255)
        case .close: SimastryColor.gold
        case .bonded: SimastryColor.gold
        case .deepTrust: SimastryColor.gold
        }
    }

    private var ringColor: Color {
        Self.ringColor(for: level)
    }

    private var showShimmer: Bool {
        level == .bonded || level == .deepTrust
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
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(ringColor)

                Text(level.name)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            if level != .deepTrust {
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

/// One-line level chip for thread headers — name + tinted dot.
struct RelationshipLevelChip: View {
    let level: RelationshipLevel

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(RelationshipBadgeView.ringColor(for: level))
                .frame(width: 5, height: 5)

            Text(level.name)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(RelationshipBadgeView.ringColor(for: level))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(RelationshipBadgeView.ringColor(for: level).opacity(0.12), in: Capsule())
        .accessibilityLabel("Bond level: \(level.name)")
    }
}
