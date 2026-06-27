import Foundation

actor RateLimiter {
    struct Config {
        var maxPerMinute: Int
        var maxPerHour: Int
        var maxPerDay: Int
    }

    private let config: Config
    private var timestamps: [Date] = []

    init(config: Config) {
        self.config = config
    }

    func checkLimit() -> Bool {
        prune()
        let now = Date()
        let minute = timestamps.filter { now.timeIntervalSince($0) < 60 }.count
        let hour = timestamps.filter { now.timeIntervalSince($0) < 3600 }.count
        let day = timestamps.filter { now.timeIntervalSince($0) < 86400 }.count
        return minute < config.maxPerMinute && hour < config.maxPerHour && day < config.maxPerDay
    }

    func recordAction() {
        prune()
        timestamps.append(Date())
    }

    func waitMessage() -> String {
        "Give it a moment, then try again."
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-86400)
        timestamps.removeAll { $0 < cutoff }
    }
}
