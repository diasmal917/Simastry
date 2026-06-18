import Foundation

/// Matches the user's placements to their advisory panel of guides.
nonisolated enum PanelMatcher {
    struct Entry: Identifiable, Sendable {
        let role: CelestialRole
        let sign: ZodiacSign
        let profile: FactoryCompanionProfile

        var id: String { profile.id }
    }

    /// One guide per placement, deduped so shared signs surface both
    /// companions of that sign instead of repeating one. Nil placements are
    /// skipped; if nothing resolves, the featured guide stands in as the
    /// Sun lens so the panel is never empty.
    static func panelGuides(sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) -> [Entry] {
        var used = Set<String>()
        let placements: [(CelestialRole, ZodiacSign?)] = [(.sun, sun), (.moon, moon), (.rising, rising)]

        let entries: [Entry] = placements.compactMap { role, sign in
            guard let sign else { return nil }
            let candidates = FactoryCompanionCatalog.all.filter { $0.sign == sign }
            guard let pick = candidates.first(where: { !used.contains($0.id) }) ?? candidates.first else {
                return nil
            }
            used.insert(pick.id)
            return Entry(role: role, sign: sign, profile: pick)
        }

        if entries.isEmpty {
            let fallback = FactoryCompanionCatalog.featured
            return [Entry(role: .sun, sign: fallback.sign, profile: fallback)]
        }
        return entries
    }
}
