import Foundation

/// Archive facade for the original 24-guide Simastry system.
/// The underlying catalog, prompts, routes, assets, calibration, and message
/// history remain in place; this wrapper gives future builds an explicit
/// restoration point without copying or deleting legacy data.
nonisolated enum LegacyGuideRegistry {
    static let archivedGuides: [FactoryCompanionProfile] = FactoryCompanionCatalog.all

    static func guide(id: String) -> FactoryCompanionProfile? {
        archivedGuides.first { $0.id == id }
    }
}
