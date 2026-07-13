import SwiftUI

/// The Compass "live instrument" hero: a Now dial (one glanceable line for
/// the current window), a Today strip (tappable timeline of the day's 3–5
/// honest windows), and an inline detail card explaining the selected
/// window. All three read `DayWindowsResult` — computed once per day-key by
/// the caller and passed down as a cached value; nothing here touches the
/// ephemeris.
///
/// Trust note: every string surfaced here comes straight from `DayWindow`
/// (engine facts + `DayWindowCopy` bank). Nothing in this file invents
/// language or degree/clock phrasing beyond what the engine already
/// produced.

// MARK: - Shared helpers

private let compassClockFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter
}()

private func compassToken(for tokenID: String) -> SimastryCategoryToken? {
    SimastryCategoryToken(rawValue: tokenID)
}

private func compassTint(for tokenID: String) -> Color {
    compassToken(for: tokenID)?.color ?? SimastryColor.gold
}

private func compassIcon(for tokenID: String) -> String {
    compassToken(for: tokenID)?.systemImage ?? "sparkles"
}

private func compassTimeRangeText(_ interval: DateInterval) -> String {
    "\(compassClockFormatter.string(from: interval.start)) – \(compassClockFormatter.string(from: interval.end))"
}

private func compassSegmentAccessibilityLabel(_ window: DayWindow, isCurrent: Bool) -> String {
    let base = "\(compassClockFormatter.string(from: window.interval.start))–\(compassClockFormatter.string(from: window.interval.end)), \(window.title)"
    return isCurrent ? "\(base), current" : base
}

// MARK: - Now dial

/// One airport-board line: the current window's title, "until h:mm a", a
/// token tick, and a thin day-progress arc. The engine's `window(at:)` tiles
/// the whole local day, so this is never blank once `result` has loaded; a
/// subtle shimmer placeholder covers the brief gap before the first compute
/// (or the moment right after a midnight rollover, before the recompute
/// lands).
struct CompassNowDial: View {
    let result: DayWindowsResult?
    let now: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentWindow: DayWindow? {
        guard let result else { return nil }
        return result.window(at: now)
    }

    var body: some View {
        Group {
            if let result, let window = currentWindow {
                dialLine(result: result, window: window)
            } else {
                placeholderLine
            }
        }
        .padding(SimastrySpacing.md)
        .floatingGlass(cornerRadius: SimastryRadius.panel)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("compass.now")
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let window = currentWindow else { return "Today's windows, loading" }
        return "\(window.title). Until \(compassClockFormatter.string(from: window.interval.end))."
    }

    @ViewBuilder
    private func dialLine(result: DayWindowsResult, window: DayWindow) -> some View {
        let tint = compassTint(for: window.tokenID)
        let icon = compassIcon(for: window.tokenID)
        let untilText = "until \(compassClockFormatter.string(from: window.interval.end))"

        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: SimastrySpacing.sm) {
                    tokenTick(tint: tint, systemImage: icon)
                    Text(window.title)
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(1)
                    Spacer(minLength: SimastrySpacing.xs)
                    Text(untilText)
                        .font(SimastryFont.metricSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .monospacedDigit()
                        .fixedSize()
                }

                VStack(alignment: .leading, spacing: SimastrySpacing.xxs) {
                    HStack(spacing: SimastrySpacing.sm) {
                        tokenTick(tint: tint, systemImage: icon)
                        Text(window.title)
                            .font(SimastryFont.titleLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(untilText)
                        .font(SimastryFont.metricSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .monospacedDigit()
                }
            }

            dayProgressArc(windows: result.windows, dayInterval: result.dayInterval)
        }
    }

    private func tokenTick(tint: Color, systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(tint.opacity(0.16), in: Circle())
    }

    private var placeholderLine: some View {
        HStack(spacing: SimastrySpacing.sm) {
            Circle()
                .fill(SimastryColor.surfaceElevated)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: SimastrySpacing.xxs) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(SimastryColor.surfaceElevated)
                    .frame(width: 190, height: 22)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(SimastryColor.surfaceElevated)
                    .frame(width: 110, height: 14)
            }
            Spacer(minLength: 0)
        }
        .skeletonShimmer()
    }

    // MARK: Progress arc

    private func dayProgressArc(windows: [DayWindow], dayInterval: DateInterval) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                CompassDialArcShape()
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
                    let fractions = arcFractions(for: window, in: dayInterval)
                    CompassDialArcShape()
                        .trim(from: fractions.from, to: fractions.to)
                        .stroke(compassTint(for: window.tokenID).opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }

                let point = compassArcPoint(at: arcProgress(dayInterval: dayInterval), in: geo.size)
                Circle()
                    .fill(SimastryColor.offWhite)
                    .frame(width: 6, height: 6)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(point)
                    .animation(reduceMotion ? nil : SimastryMotion.stateChange, value: point)
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }

    private func arcFractions(for window: DayWindow, in dayInterval: DateInterval) -> (from: CGFloat, to: CGFloat) {
        guard dayInterval.duration > 0 else { return (0, 0) }
        let from = window.interval.start.timeIntervalSince(dayInterval.start) / dayInterval.duration
        let to = window.interval.end.timeIntervalSince(dayInterval.start) / dayInterval.duration
        return (CGFloat(min(max(from, 0), 1)), CGFloat(min(max(to, 0), 1)))
    }

    private func arcProgress(dayInterval: DateInterval) -> Double {
        guard dayInterval.duration > 0 else { return 0 }
        return min(max(now.timeIntervalSince(dayInterval.start) / dayInterval.duration, 0), 1)
    }
}

/// A shallow bow spanning its container, used only as a decorative
/// day-progress track. `trim(from:to:)` renders the token-colored segments;
/// the "now" dot's position is computed separately via `compassArcPoint`.
private struct CompassDialArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.minY + rect.height * 0.8
        let start = CGPoint(x: rect.minX, y: y)
        let end = CGPoint(x: rect.maxX, y: y)
        let control = CGPoint(x: rect.midX, y: rect.minY)
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

private func compassArcPoint(at fraction: Double, in size: CGSize) -> CGPoint {
    let t = CGFloat(min(max(fraction, 0), 1))
    let y = size.height * 0.8
    let start = CGPoint(x: 0, y: y)
    let end = CGPoint(x: size.width, y: y)
    let control = CGPoint(x: size.width / 2, y: 0)
    let mt = 1 - t
    let x = mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x
    let py = mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
    return CGPoint(x: x, y: py)
}

// MARK: - Today strip

/// A tappable timeline of the day's windows. Segments are proportional to
/// duration with a clamp-and-renormalize pass so no segment falls below a
/// 44pt tap target. At accessibility Dynamic Type sizes the strip becomes a
/// vertical list of token-colored rows instead — a horizontal strip of
/// 44pt-minimum chips cannot fit legibly at AX3/AX5 line heights.
struct CompassTodayStrip: View {
    let result: DayWindowsResult?
    @Binding var selection: String?
    let now: Date

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            // `.contain` makes the strip its own identified container, so the
            // identifier does NOT propagate down and overwrite the
            // per-segment identifiers (SwiftUI stamps a container id onto
            // descendant elements of plain stacks otherwise).
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("compass.timeline")
    }

    @ViewBuilder
    private var content: some View {
        // Gate on the cached result actually covering "now", mirroring the
        // dial's `window(at:)` behavior: right at midnight (or in the brief
        // gap before the first compute lands) `result` may still describe
        // yesterday, and showing yesterday's segments with the progress dot
        // pinned at 100% reads as broken rather than loading.
        if let result, !result.windows.isEmpty, result.dayInterval.contains(now) {
            if dynamicTypeSize.isAccessibilitySize {
                verticalList(result: result)
            } else {
                horizontalStrip(result: result)
            }
        } else {
            placeholderStrip
        }
    }

    private var placeholderStrip: some View {
        RoundedRectangle(cornerRadius: SimastryRadius.medium, style: .continuous)
            .fill(SimastryColor.surfaceElevated.opacity(0.6))
            .frame(height: 64)
            .skeletonShimmer()
    }

    // MARK: Horizontal (regular Dynamic Type)

    private func horizontalStrip(result: DayWindowsResult) -> some View {
        GeometryReader { geo in
            let widths = segmentWidths(windows: result.windows, totalWidth: geo.size.width, minWidth: 44)
            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .topLeading) {
                    hourTicks(dayInterval: result.dayInterval, totalWidth: geo.size.width)
                    progressDot(dayInterval: result.dayInterval, totalWidth: geo.size.width)
                }
                .frame(width: geo.size.width, height: 10)

                HStack(spacing: 3) {
                    ForEach(Array(result.windows.enumerated()), id: \.offset) { index, window in
                        segmentButton(window: window, index: index)
                            .frame(width: index < widths.count ? widths[index] : nil)
                    }
                }
                .frame(height: 60)
            }
        }
        .frame(height: 74)
    }

    /// Proportional widths clamped to `minWidth` then renormalized: any
    /// segment under the minimum is fixed at `minWidth`, and the remaining
    /// width is redistributed among the still-flexible segments by their
    /// relative duration. Bounded to `windows.count` passes since each
    /// iteration either fixes at least one more segment or terminates.
    private func segmentWidths(windows: [DayWindow], totalWidth: CGFloat, minWidth: CGFloat) -> [CGFloat] {
        guard !windows.isEmpty, totalWidth > 0 else { return [] }
        let spacing: CGFloat = 3
        let usableWidth = max(totalWidth - spacing * CGFloat(windows.count - 1), minWidth * CGFloat(windows.count))
        let totalDuration = windows.reduce(0) { $0 + $1.interval.duration }
        guard totalDuration > 0 else {
            return Array(repeating: usableWidth / CGFloat(windows.count), count: windows.count)
        }

        var widths = windows.map { usableWidth * CGFloat($0.interval.duration / totalDuration) }
        var fixed = Set<Int>()

        for _ in windows.indices {
            var fixedTotal: CGFloat = 0
            var flexibleIndices: [Int] = []
            var flexibleTotal: CGFloat = 0

            for index in widths.indices {
                if !fixed.contains(index), widths[index] < minWidth {
                    widths[index] = minWidth
                    fixed.insert(index)
                }
                if fixed.contains(index) {
                    fixedTotal += widths[index]
                } else {
                    flexibleIndices.append(index)
                    flexibleTotal += widths[index]
                }
            }

            guard !flexibleIndices.isEmpty, flexibleTotal > 0 else { break }
            let remaining = usableWidth - fixedTotal
            guard remaining > 0 else { break }
            let scale = remaining / flexibleTotal
            var anyDroppedBelowMin = false
            for index in flexibleIndices {
                widths[index] *= scale
                if widths[index] < minWidth { anyDroppedBelowMin = true }
            }
            if !anyDroppedBelowMin { break }
        }
        return widths
    }

    private func segmentButton(window: DayWindow, index: Int) -> some View {
        let tint = compassTint(for: window.tokenID)
        let icon = compassIcon(for: window.tokenID)
        let isSelected = selection == window.id
        let isCurrent = window.interval.contains(now)

        return Button {
            HapticManager.zodiacSelection()
            withAnimation(reduceMotion ? nil : SimastryMotion.stateChange) {
                selection = isSelected ? nil : window.id
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 44, minHeight: 44)
                .interactiveGlass(cornerRadius: SimastryRadius.small, tint: tint)
                .overlay {
                    RoundedRectangle(cornerRadius: SimastryRadius.small, style: .continuous)
                        .strokeBorder(tint.opacity(isSelected ? 0.85 : 0), lineWidth: 1.6)
                }
        }
        .buttonStyle(CompassPressStyle())
        .accessibilityLabel(compassSegmentAccessibilityLabel(window, isCurrent: isCurrent))
        .accessibilityIdentifier("compass.timeline.segment.\(index)")
    }

    private func hourTicks(dayInterval: DateInterval, totalWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(tickFractions(dayInterval: dayInterval), id: \.self) { fraction in
                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 1, height: 5)
                    .offset(x: totalWidth * fraction, y: 0)
            }
        }
        .frame(width: totalWidth, height: 5, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func tickFractions(dayInterval: DateInterval) -> [CGFloat] {
        guard dayInterval.duration > 0 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var fractions: [CGFloat] = []
        for hour in stride(from: 0, to: 24, by: 3) {
            guard let tickDate = calendar.date(byAdding: .hour, value: hour, to: dayInterval.start),
                  dayInterval.contains(tickDate) else { continue }
            fractions.append(CGFloat(tickDate.timeIntervalSince(dayInterval.start) / dayInterval.duration))
        }
        return fractions
    }

    private func progressDot(dayInterval: DateInterval, totalWidth: CGFloat) -> some View {
        let fraction: CGFloat = dayInterval.duration > 0
            ? CGFloat(min(max(now.timeIntervalSince(dayInterval.start) / dayInterval.duration, 0), 1))
            : 0
        return Circle()
            .fill(SimastryColor.offWhite)
            .frame(width: 7, height: 7)
            .shadow(color: .black.opacity(0.32), radius: 2)
            .offset(x: totalWidth * fraction - 3.5, y: -1)
            .frame(width: totalWidth, height: 5, alignment: .topLeading)
            .animation(reduceMotion ? nil : SimastryMotion.stateChange, value: fraction)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Vertical (accessibility Dynamic Type)

    private func verticalList(result: DayWindowsResult) -> some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
            ForEach(Array(result.windows.enumerated()), id: \.offset) { index, window in
                verticalRow(window: window, index: index)
            }
        }
    }

    private func verticalRow(window: DayWindow, index: Int) -> some View {
        let tint = compassTint(for: window.tokenID)
        let icon = compassIcon(for: window.tokenID)
        let isSelected = selection == window.id
        let isCurrent = window.interval.contains(now)

        return Button {
            HapticManager.zodiacSelection()
            withAnimation(reduceMotion ? nil : SimastryMotion.stateChange) {
                selection = isSelected ? nil : window.id
            }
        } label: {
            HStack(alignment: .top, spacing: SimastrySpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(window.title)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(compassTimeRangeText(window.interval))
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Spacer(minLength: 0)

                if isCurrent {
                    Circle()
                        .fill(tint)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
            }
            .padding(SimastrySpacing.sm)
            .frame(minHeight: 44)
            .interactiveGlass(cornerRadius: SimastryRadius.small, tint: tint)
            .overlay {
                RoundedRectangle(cornerRadius: SimastryRadius.small, style: .continuous)
                    .strokeBorder(tint.opacity(isSelected ? 0.85 : 0), lineWidth: 1.6)
            }
        }
        .buttonStyle(CompassPressStyle())
        .accessibilityLabel(compassSegmentAccessibilityLabel(window, isCurrent: isCurrent))
        .accessibilityIdentifier("compass.timeline.segment.\(index)")
    }
}

// MARK: - Window detail card

/// Inline reading card explaining the selected window: title, time range,
/// rationale, the sky-fact derivation, an evidence badge, and the scope
/// line. Opaque `contentSurface` per D6 — this is reading content, not
/// instrument chrome.
struct CompassWindowDetailCard: View {
    let window: DayWindow
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.md) {
            HStack(alignment: .top, spacing: SimastrySpacing.sm) {
                VStack(alignment: .leading, spacing: SimastrySpacing.xxs) {
                    Text(window.title)
                        .font(SimastryFont.titleMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(compassTimeRangeText(window.interval))
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Spacer(minLength: SimastrySpacing.sm)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(CompassPressStyle())
                .accessibilityLabel("Close window detail")
                .accessibilityIdentifier("compass.window.close")
            }

            Text(window.rationale)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
                Text("HOW THIS IS COMPUTED")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.2)
                Text(window.derivation)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AccountEvidenceBadge(
                title: window.evidence.basis.title,
                systemImage: "checkmark.seal.fill",
                tint: SimastryColor.sageGreen
            )

            Text("Today only. Windows suggest what an hour favors — never outcomes.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SimastrySpacing.md)
        .contentSurface(cornerRadius: SimastryRadius.card, accent: compassTint(for: window.tokenID))
        // `.contain` keeps the close button's own identifier intact.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compass.window.detail")
    }
}

// MARK: - Bearings row

/// One tappable "bearing": a pre-composed reading the user can run (or
/// begin) in a single tap. `SimulateView` owns the label/question pairing
/// and the tap behavior — topic bearings prefill the draft and immediately
/// submit through the existing credit-gated flow; person bearings prefill
/// and expand the composer instead so the user can add context first. This
/// type is purely a rendering contract; nothing here decides what happens
/// on tap.
struct CompassBearingItem: Identifiable {
    let id: String
    let title: String
    let question: String
    let systemImage: String
    let tokenID: String
    let action: () -> Void
}

/// A horizontally scrolling row of one-tap readings, sitting between the
/// Today strip and the (now demoted) composer. D7: the dial and strip above
/// are free and unlimited; a tap here is the one thing in Compass that
/// spends a credit, so every card previews the exact question it will ask
/// and the footer says so plainly before anything fires.
struct CompassBearingsRow: View {
    let items: [CompassBearingItem]
    let creditCaption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
            ScrollView(.horizontal) {
                HStack(spacing: SimastrySpacing.xs) {
                    ForEach(items) { item in
                        bearingCard(item)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)

            footer
        }
    }

    private func bearingCard(_ item: CompassBearingItem) -> some View {
        let tint = compassTint(for: item.tokenID)

        return Button(action: item.action) {
            VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.16), in: Circle())

                Text(item.title)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1)

                Text(item.question)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 168, alignment: .leading)
            .padding(SimastrySpacing.sm)
            .frame(minHeight: 44)
            .interactiveGlass(cornerRadius: SimastryRadius.medium, tint: tint)
        }
        .buttonStyle(CompassPressStyle())
        .accessibilityLabel("\(item.title). \(item.question)")
        .accessibilityIdentifier(item.id)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let creditCaption {
                Text(creditCaption)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            Text("Creates one reading")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)
        }
    }
}
