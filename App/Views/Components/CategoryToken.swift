import SwiftUI

/// The six shared reading categories. One icon + one color per category,
/// used identically by Predict's grid and the expert-intake topic chips.
enum SimastryCategoryToken: String, CaseIterable, Identifiable {
    case love, marriage, family, career, money, personal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .love: "Love"
        case .marriage: "Marriage"
        case .family: "Family"
        case .career: "Career"
        case .money: "Money"
        case .personal: "Private"
        }
    }

    var systemImage: String {
        switch self {
        case .love: "heart.fill"
        case .marriage: "link"
        case .family: "house.fill"
        case .career: "chart.line.uptrend.xyaxis"
        case .money: "dollarsign.circle.fill"
        case .personal: "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .love: SimastryColor.sunCoral
        case .marriage: SimastryColor.orchidPink
        case .family: SimastryColor.sageGreen
        case .career: SimastryColor.celestialBlue
        case .money: SimastryColor.gold
        case .personal: SimastryColor.risingViolet
        }
    }
}

struct CategoryTokenChip: View {
    private let systemImage: String
    private let color: Color

    init(token: SimastryCategoryToken) {
        self.systemImage = token.systemImage
        self.color = token.color
    }

    /// For categories with no one-to-one token match (e.g. Predict's
    /// "message outcome" reply type) — same chip shape and size, borrowing
    /// the closest semantic token's color instead of a token identity.
    init(systemImage: String, color: Color) {
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 38, height: 38)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
