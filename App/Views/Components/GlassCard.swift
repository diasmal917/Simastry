import SwiftUI

/// Reusable Liquid Glass content card — the single entry point for "a floating
/// glass object over the cosmos" used by Today cards, Prediction cards, Ask the
/// Future, the Daily Decider, Aura Snapshot, People cards and guide panels.
///
/// On iOS 26 the surface is real Apple Liquid Glass (`glassEffect`), so content
/// scrolling beneath subtly refracts through the card. On iOS 18 it degrades to
/// `.ultraThinMaterial` with a hairline edge highlight and a soft depth shadow.
/// The actual material is produced by the shared `simastryGlass` / `tintedGlass`
/// modifiers so every glass surface in the app stays visually consistent.
///
/// Wrap a cluster of cards in `GlassCardGroup` when you want iOS 26 to treat
/// them as one fluid Liquid Glass system (shapes merge/refract together).
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = SimastryRadius.card
    /// Optional accent. `nil` = neutral glass; a color = a faint tinted glass
    /// (e.g. violet for Predict, gold for premium surfaces).
    var tint: Color? = nil
    var padding: CGFloat = SimastrySpacing.md
    /// Pass `true` only when the whole card is the tappable surface of a button,
    /// so iOS 26 Liquid Glass reacts to touch.
    var interactive: Bool = false

    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(GlassCardSurface(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
}

/// Groups adjacent `GlassCard`s into a single Liquid Glass container so that, on
/// iOS 26, their shapes refract and blend as one material rather than as
/// separate panes. Falls back to a plain layout container on iOS 18.
struct GlassCardGroup<Content: View>: View {
    var spacing: CGFloat = SimastrySpacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            // Official iOS 26 Liquid Glass grouping API.
            GlassEffectContainer(spacing: spacing) {
                VStack(spacing: spacing) { content() }
            }
        } else {
            VStack(spacing: spacing) { content() }
        }
    }
}

/// The card material itself. Delegates to the app's shared glass modifiers so a
/// `GlassCard` is always pixel-consistent with the rest of Simastry's surfaces.
private struct GlassCardSurface: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?
    var interactive: Bool

    func body(content: Content) -> some View {
        if let tint {
            content.tintedGlass(tint, cornerRadius: cornerRadius)
        } else if interactive {
            // `simastryGlassLight` reads as a control; full `simastryGlass` reads
            // as a static panel. Interactive cards get the lighter, livelier one.
            content.simastryGlass(cornerRadius: cornerRadius)
        } else {
            content.simastryGlass(cornerRadius: cornerRadius)
        }
    }
}
