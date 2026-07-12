import Foundation

nonisolated struct RateLimitReservation: Hashable, Sendable {
    let idempotencyKey: UUID
}

/// A reservation-based limiter. Pending submissions count immediately, while a
/// failed or cancelled request releases its slot. This closes the old
/// check-then-record race that let rapid taps start multiple paid generations.
actor RateLimiter {
    struct Config: Sendable {
        var maxPerMinute: Int
        var maxPerHour: Int
        var maxPerDay: Int
    }

    private let config: Config
    private var committedTimestamps: [Date] = []
    private var pending: [UUID: Date] = [:]
    private var committedKeys: Set<UUID> = []

    init(config: Config) {
        self.config = config
    }

    func reserve(idempotencyKey: UUID = UUID(), now: Date = Date()) -> RateLimitReservation? {
        prune(now: now)

        if pending[idempotencyKey] != nil || committedKeys.contains(idempotencyKey) {
            return nil
        }

        let activeTimestamps = committedTimestamps + Array(pending.values)
        guard isUnderLimit(activeTimestamps, now: now) else { return nil }

        pending[idempotencyKey] = now
        return RateLimitReservation(idempotencyKey: idempotencyKey)
    }

    /// Returns true only for the single transition from reserved to committed.
    @discardableResult
    func commit(_ reservation: RateLimitReservation, now: Date = Date()) -> Bool {
        prune(now: now)
        guard pending.removeValue(forKey: reservation.idempotencyKey) != nil,
              !committedKeys.contains(reservation.idempotencyKey) else {
            return false
        }
        committedKeys.insert(reservation.idempotencyKey)
        committedTimestamps.append(now)
        return true
    }

    @discardableResult
    func cancel(_ reservation: RateLimitReservation) -> Bool {
        pending.removeValue(forKey: reservation.idempotencyKey) != nil
    }

    // Compatibility for older call sites. New submissions must use reserve.
    func checkLimit(now: Date = Date()) -> Bool {
        prune(now: now)
        return isUnderLimit(committedTimestamps + Array(pending.values), now: now)
    }

    func recordAction(now: Date = Date()) {
        prune(now: now)
        committedTimestamps.append(now)
    }

    func waitMessage() -> String {
        "Give it a moment, then try again."
    }

    private func isUnderLimit<S: Sequence>(_ timestamps: S, now: Date) -> Bool where S.Element == Date {
        let values = Array(timestamps)
        let minute = values.filter { now.timeIntervalSince($0) < 60 }.count
        let hour = values.filter { now.timeIntervalSince($0) < 3_600 }.count
        let day = values.filter { now.timeIntervalSince($0) < 86_400 }.count
        return minute < config.maxPerMinute && hour < config.maxPerHour && day < config.maxPerDay
    }

    private func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-86_400)
        committedTimestamps.removeAll { $0 < cutoff }
        pending = pending.filter { $0.value >= cutoff }

        // Keys only exist to make commit idempotent during the process lifetime.
        // Cap their memory without weakening active reservation semantics.
        if committedKeys.count > 2_048 {
            committedKeys.removeAll(keepingCapacity: true)
        }
    }
}

nonisolated struct PredictionSubmissionToken: Hashable, Sendable {
    let idempotencyKey: UUID
    fileprivate let reservation: RateLimitReservation
}

nonisolated enum PredictionSubmissionError: LocalizedError, Sendable {
    case alreadySubmitting
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .alreadySubmitting:
            "A reading is already in progress."
        case .rateLimited:
            "Give it a moment, then try again."
        }
    }
}

/// Owns the exact-once submission state. `commit` returning true is the only
/// authorization for the caller to consume a paid or bonus credit.
actor PredictionSubmissionCoordinator {
    static let shared = PredictionSubmissionCoordinator()

    private var activeToken: PredictionSubmissionToken?
    private var isAcquiring = false
    private var committedKeys: Set<UUID> = []

    func acquire(using limiter: RateLimiter) async throws -> PredictionSubmissionToken {
        guard activeToken == nil, !isAcquiring else {
            throw PredictionSubmissionError.alreadySubmitting
        }

        isAcquiring = true
        defer { isAcquiring = false }

        let key = UUID()
        guard let reservation = await limiter.reserve(idempotencyKey: key) else {
            throw PredictionSubmissionError.rateLimited
        }

        let token = PredictionSubmissionToken(idempotencyKey: key, reservation: reservation)
        activeToken = token
        return token
    }

    /// Commits both the active submission and limiter exactly once.
    func commit(_ token: PredictionSubmissionToken, using limiter: RateLimiter) async -> Bool {
        guard activeToken == token, !committedKeys.contains(token.idempotencyKey) else { return false }
        guard await limiter.commit(token.reservation) else { return false }

        committedKeys.insert(token.idempotencyKey)
        activeToken = nil
        return true
    }

    func cancel(_ token: PredictionSubmissionToken, using limiter: RateLimiter) async {
        guard activeToken == token else { return }
        _ = await limiter.cancel(token.reservation)
        activeToken = nil
    }
}
