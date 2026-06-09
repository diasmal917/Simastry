import SwiftUI

struct ZodiacBadgeView: View {
    let sign: ZodiacSign
    let isSelected: Bool
    let size: CGFloat
    let onTap: () -> Void

    init(sign: ZodiacSign, isSelected: Bool = false, size: CGFloat = 56, onTap: @escaping () -> Void = {}) {
        self.sign = sign
        self.isSelected = isSelected
        self.size = size
        self.onTap = onTap
    }

    var body: some View {
        Button(action: {
            HapticManager.zodiacSelection()
            onTap()
        }) {
            ZStack {
                Circle()
                    .fill(sign.color.opacity(isSelected ? 0.4 : 0.2))
                    .frame(width: size, height: size)

                if isSelected {
                    Circle()
                        .stroke(SimastryColor.gold, lineWidth: 2.5)
                        .frame(width: size + 4, height: size + 4)

                    Circle()
                        .stroke(SimastryColor.gold.opacity(0.3), lineWidth: 1)
                        .frame(width: size + 12, height: size + 12)
                }

                ZodiacIconView(sign: sign, size: size * 0.72, showsGlow: isSelected)
            }
            .opacity(isSelected ? 1.0 : 0.5)
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .animation(.spring(SimastrySpring.bouncy), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct ZodiacGridView: View {
    @Binding var selectedSign: ZodiacSign?
    var roleName: String? = nil
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(ZodiacSign.allCases) { sign in
                VStack(spacing: 4) {
                    ZodiacBadgeView(sign: sign, isSelected: selectedSign == sign) {
                        selectedSign = sign
                    }
                    .accessibilityLabel("Select \(sign.displayName) as \(roleName ?? "zodiac") sign")
                    Text(sign.displayName)
                        .font(.caption2)
                        .foregroundStyle(selectedSign == sign ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                }
            }
        }
        .padding(.horizontal)
    }
}
