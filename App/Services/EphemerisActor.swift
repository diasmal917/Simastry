import Foundation

/// The single serialization domain for every raw Swiss Ephemeris call.
///
/// The vendored C library keeps its entire state in one process-global struct
/// (`swed`, sweph.h) and its build disables the thread-local-storage macro on
/// Apple platforms (sweodef.h), so concurrent `swe_*` calls — including the
/// ones hidden inside `Coordinate`, `RiseTime`, `SetTime`, and `HouseCusps`
/// inits — are a data race on shared globals and open file handles.
///
/// This global actor is deliberately bound to the main executor:
/// - Every pre-existing touchpoint already runs there: `BirthChartService` is
///   a `@MainActor` facade, and `TransitEngine`/the daily composers are
///   pinned `@MainActor` and consumed synchronously from SwiftUI views.
///   Sharing the executor makes `@EphemerisActor` and `@MainActor` one and
///   the same serialization domain, so raw ephemeris access cannot
///   interleave — by construction, not by convention.
/// - `DayWindowsEngine` gets the async, type-enforced boundary Stage 2 needs:
///   callers hop through this actor from any context and can never race the
///   synchronous facades.
///
/// If ephemeris work ever needs to leave the main thread, rebind this actor
/// to its own executor AND migrate the `@MainActor` ephemeris facades onto it
/// in the same change. The executor-identity assertion and the concurrency
/// stress test in `DayWindowsEngineTests` go red if the domains are split.
@globalActor
actor EphemerisActor {
    static let shared = EphemerisActor()

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        MainActor.sharedUnownedExecutor
    }

    private init() {}
}
