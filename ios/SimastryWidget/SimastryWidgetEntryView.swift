import SwiftUI
import WidgetKit

struct SimastryWidgetEntryView: View {
    var entry: SimastryWidgetEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            smallView
        }
    }

    // MARK: - Deep Link URL

    private var deepLinkURL: URL {
        URL(string: "simastry://companions") ?? URL(string: "simastry://home")!
    }

    // MARK: - Colors (standalone, no dependency on main app module)

    private static let midnight = Color(red: 10/255, green: 14/255, blue: 26/255)
    private static let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private static let offWhite = Color(red: 240/255, green: 237/255, blue: 230/255)
    private static let mutedSilver = Color(red: 148/255, green: 163/255, blue: 184/255)
    private static let surface = Color(red: 17/255, green: 24/255, blue: 39/255)

    // MARK: - System Small

    private var smallView: some View {
        ZStack {
            LinearGradient(
                colors: [Self.midnight, Self.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if entry.isEmpty {
                emptySmallView
            } else {
                VStack(spacing: 6) {
                    // Zodiac glyphs
                    HStack(spacing: 4) {
                        Text(entry.userGlyph)
                            .font(.title3)
                        Text("×")
                            .font(.caption)
                            .foregroundStyle(Self.mutedSilver)
                        Text(entry.companionGlyph)
                            .font(.title3)
                    }
                    .foregroundStyle(Self.gold)

                    // Score
                    Text("\(entry.score)%")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(Self.offWhite)

                    // Companion name
                    Text(entry.companionName)
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(Self.mutedSilver)
                        .lineLimit(1)

                    // Label
                    Text("DAILY COMPATIBILITY")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(Self.gold.opacity(0.7))
                }
                .padding(12)
            }
        }
        .widgetURL(deepLinkURL)
    }

    private var emptySmallView: some View {
        VStack(spacing: 8) {
            Text("✦")
                .font(.title)
                .foregroundStyle(Self.gold)
            Text("Add a companion\nin Simastry")
                .font(.system(.caption, design: .serif))
                .foregroundStyle(Self.mutedSilver)
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }

    // MARK: - System Medium

    private var mediumView: some View {
        ZStack {
            LinearGradient(
                colors: [Self.midnight, Self.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if entry.isEmpty {
                emptyMediumView
            } else {
                HStack(spacing: 16) {
                    // Left side — score
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Text(entry.userGlyph)
                                .font(.title3)
                            Text("×")
                                .font(.caption)
                                .foregroundStyle(Self.mutedSilver)
                            Text(entry.companionGlyph)
                                .font(.title3)
                        }
                        .foregroundStyle(Self.gold)

                        Text("\(entry.score)%")
                            .font(.system(size: 40, weight: .bold, design: .serif))
                            .foregroundStyle(Self.offWhite)

                        Text(entry.companionName)
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(Self.mutedSilver)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)

                    // Divider
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Self.gold.opacity(0.3))
                        .frame(width: 1, height: 60)

                    // Right side — insight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TODAY'S VIBE")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Self.gold.opacity(0.8))

                        Text(entry.dailyInsight)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Self.offWhite.opacity(0.9))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        Text("DAILY COMPATIBILITY")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(Self.gold.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
        }
        .widgetURL(deepLinkURL)
    }

    private var emptyMediumView: some View {
        HStack(spacing: 12) {
            Text("✦")
                .font(.largeTitle)
                .foregroundStyle(Self.gold)
            VStack(alignment: .leading, spacing: 4) {
                Text("Simastry")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Self.offWhite)
                Text("Add a companion to see your daily compatibility score")
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(Self.mutedSilver)
            }
        }
        .padding(16)
    }

    // MARK: - Accessory Circular (Lock Screen)

    private var circularView: some View {
        if entry.isEmpty {
            return AnyView(
                ZStack {
                    AccessoryWidgetBackground()
                    Text("✦")
                        .font(.title3)
                }
            )
        }

        return AnyView(
            Gauge(value: Double(entry.score), in: 0...100) {
                Text("✦")
                    .font(.caption2)
            } currentValueLabel: {
                Text("\(entry.score)")
                    .font(.system(.body, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)
        )
    }

    // MARK: - Accessory Rectangular (Lock Screen)

    private var rectangularView: some View {
        if entry.isEmpty {
            return AnyView(
                HStack {
                    Text("✦")
                    Text("Open Simastry")
                        .font(.caption)
                }
            )
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.companionGlyph)
                    Text(entry.companionName)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(entry.score)%")
                        .fontWeight(.bold)
                }
                .font(.caption)

                Text(entry.dailyInsight)
                    .font(.caption2)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        )
    }

    // MARK: - Accessory Inline (Lock Screen)

    private var inlineView: some View {
        if entry.isEmpty {
            return Text("✦ Simastry")
        }
        return Text("\(entry.userGlyph) \(entry.score)% \(entry.companionGlyph) \(entry.companionName)")
    }
}
