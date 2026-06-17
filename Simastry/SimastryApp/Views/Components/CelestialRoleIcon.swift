import SwiftUI

struct CelestialRoleIcon: View {
    let role: CelestialRole
    let size: CGFloat

    init(role: CelestialRole, size: CGFloat = 32) {
        self.role = role
        self.size = size
    }

    var body: some View {
        Image(systemName: role.iconName)
            .font(.system(size: size * 0.55))
            .foregroundStyle(role.accentColor)
            .frame(width: size, height: size)
            .background(role.accentColor.opacity(0.15))
            .clipShape(Circle())
    }
}

struct SignEntryView: View {
    let role: CelestialRole
    let sign: ZodiacSign
    let showDescription: Bool

    init(role: CelestialRole, sign: ZodiacSign, showDescription: Bool = true) {
        self.role = role
        self.sign = sign
        self.showDescription = showDescription
    }

    var body: some View {
        HStack(spacing: 14) {
            CelestialRoleIcon(role: role, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(role.displayName) in \(sign.displayName)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(role.accentColor)
                    Text(sign.glyph)
                        .font(.system(size: 14))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.7))
                }

                Text(role.subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SimastryColor.offWhite)

                if showDescription {
                    let templates: [String: String] = {
                        switch role {
                        case .sun: return AstrologyTemplates.sunSign
                        case .moon: return AstrologyTemplates.moonSign
                        case .rising: return AstrologyTemplates.risingSign
                        }
                    }()
                    Text(templates[sign.rawValue] ?? "")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                        .lineSpacing(2)
                }
            }

            Spacer()
        }
    }
}
