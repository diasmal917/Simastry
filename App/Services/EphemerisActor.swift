import Foundation

/// The single serialization domain for every raw Swiss Ephemeris call.
///
/// The vendored C library keeps its entire state in one process-global struct
/// (`swed`, sweph.h) and its build disables the thread-local-storage macro on
/// Apple platforms (sweodef.h), so concurrent `swe_*` calls — including the
/// ones hidden inside `Coordinate`, `RiseTime`, `SetTime`, and `HouseCusps`
/// inits — are a data race on shared globals and open file handles.
///
/// The actor runs on its own executor so ephemeris computation stays off the
/// main thread (the day-windows hero must not stall first paint). Every
/// ephemeris touchpoint is isolated here:
/// - `DayWindowsEngine`, `TransitEngine`, and the daily composers are
///   `@EphemerisActor` — callers hop through the actor from any context.
/// - `BirthChartService` keeps its `@MainActor` facade but hops its raw
///   `Coordinate`/`HouseCusps` sampling onto this actor internally.
///
/// Regression guards live in `DayWindowsEngineTests`: an executor-identity
/// assertion (the domain must NOT be the main executor) and a concurrency
/// stress test that hammers the engine while charts compute, asserting
/// byte-equality with serial baselines.
@globalActor
actor EphemerisActor {
    static let shared = EphemerisActor()

    private init() {}
}
