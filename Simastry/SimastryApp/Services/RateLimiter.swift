import Foundation

/// Rate limiter to prevent API cost spikes.
/// Enforces per-minute and per-hour limits on expensive operations.
actor RateLimiter {
    struct Config {
        let maxPerMinute: Int
        let maxPerHour: Int
        let maxPerDay: Int
    }

    private var timestamps: [Date] = []
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    /// Check if an action is allowed. Returns true if within limits.
    func checkLimit() -> Bool {
        let now = Date()
        // Clean old entries
        timestamps.removeAll { now.timeIntervalSince($0) > 86400 }

        let lastMinute = timestamps.filter { now.timeIntervalSince($0) < 60 }
        let lastHour = timestamps.filter { now.timeIntervalSince($0) < 3600 }

        if lastMinute.count >= config.maxPerMinute { return false }
        if lastHour.count >= config.maxPerHour { return false }
        if timestamps.count >= config.maxPerDay { return false }

        return true
    }

    /// Record that an action was taken
    func recordAction() {
        timestamps.append(Date())
    }

    /// Get remaining actions for each window
    func remaining() -> (minute: Int, hour: Int, day: Int) {
        let now = Date()
        timestamps.removeAll { now.timeIntervalSince($0) > 86400 }

        let lastMinute = timestamps.filter { now.timeIntervalSince($0) < 60 }
        let lastHour = timestamps.filter { now.timeIntervalSince($0) < 3600 }

        return (
            max(0, config.maxPerMinute - lastMinute.count),
            max(0, config.maxPerHour - lastHour.count),
            max(0, config.maxPerDay - timestamps.count)
        )
    }

    /// Human-readable wait time message
    func waitMessage() async -> String {
        let now = Date()
        let lastMinute = timestamps.filter { now.timeIntervalSince($0) < 60 }

        if lastMinute.count >= config.maxPerMinute {
            if let oldest = lastMinute.first {
                let waitSeconds = Int(60 - now.timeIntervalSince(oldest))
                return "Too many requests. Please wait \(waitSeconds) seconds."
            }
        }

        let lastHour = timestamps.filter { now.timeIntervalSince($0) < 3600 }
        if lastHour.count >= config.maxPerHour {
            return "Hourly limit reached. Please try again later."
        }

        return "Daily limit reached. Come back tomorrow!"
    }
}
