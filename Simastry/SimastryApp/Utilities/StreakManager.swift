import Foundation
import Combine

/// Tracks daily check-in streaks to drive retention.
@MainActor
final class StreakManager: ObservableObject {
    static let shared = StreakManager()

    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var lastCheckIn: Date?
    @Published var checkedInToday: Bool = false

    private let currentStreakKey = "currentStreak"
    private let longestStreakKey = "longestStreak"
    private let lastCheckInKey = "lastCheckInDate"

    private init() {
        loadStreak()
    }

    /// Call when the user opens the app / home screen
    func recordCheckIn() {
        let today = Calendar.current.startOfDay(for: Date())

        if let lastDate = lastCheckIn {
            let lastDay = Calendar.current.startOfDay(for: lastDate)

            if lastDay == today {
                // Already checked in today
                checkedInToday = true
                return
            }

            let daysBetween = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween == 1 {
                // Consecutive day — extend streak
                currentStreak += 1
            } else {
                // Streak broken — reset
                currentStreak = 1
            }
        } else {
            // First ever check-in
            currentStreak = 1
        }

        checkedInToday = true
        lastCheckIn = today

        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        saveStreak()
    }

    /// Milestone messages for streak achievements
    var streakMessage: String? {
        switch currentStreak {
        case 3: return "3 days in a row! You're building a habit"
        case 7: return "One week streak! Your communication habit is forming"
        case 14: return "Two weeks strong! Your chart awareness is growing"
        case 30: return "30-day streak! You're building real pattern awareness"
        case 50: return "50 days! Astrologers wish they were this consistent"
        case 100: return "100 days! Your relationship intuition is getting sharper"
        case 365: return "One year! That's serious consistency"
        default: return nil
        }
    }

    /// Whether the current streak count is a milestone worth celebrating
    var isMilestone: Bool {
        [3, 7, 14, 30, 50, 100, 365].contains(currentStreak)
    }

    /// Short encouragement for the home screen
    var streakEncouragement: String {
        switch currentStreak {
        case 0: return "Start your streak today"
        case 1: return "Day 1 — come back tomorrow to build your streak"
        case 2...6: return "\(currentStreak)-day streak — keep it going!"
        case 7...13: return "\(currentStreak)-day streak"
        case 14...29: return "\(currentStreak) days! You're on fire"
        case 30...99: return "\(currentStreak)-day streak! Incredible"
        default: return "\(currentStreak) days! Legendary"
        }
    }

    /// Returns whether each of the last 7 days was a check-in day.
    /// Index 0 = 6 days ago, index 6 = today.
    func last7DaysCheckedIn() -> [Bool] {
        guard let lastDate = lastCheckIn else {
            return Array(repeating: false, count: 7)
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)

        // Build an array: for each of the last 7 days, determine if it was checked-in.
        // We know the streak is `currentStreak` consecutive days ending on `lastCheckIn`.
        // If the streak is broken and currentStreak was reset, only
        // the last check-in date counts.

        var result = Array(repeating: false, count: 7)

        for i in 0..<7 {
            // daysAgo: index 0 = 6 days ago, index 6 = today
            let daysAgo = 6 - i
            let targetDay = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let targetDayStart = calendar.startOfDay(for: targetDay)

            // The checked-in range is from (lastCheckIn - (currentStreak-1) days) to lastCheckIn
            if currentStreak > 0 {
                let streakStart = calendar.date(byAdding: .day, value: -(currentStreak - 1), to: lastDay)!
                let streakStartDay = calendar.startOfDay(for: streakStart)

                if targetDayStart >= streakStartDay && targetDayStart <= lastDay {
                    result[i] = true
                }
            }
        }

        return result
    }

    private func loadStreak() {
        currentStreak = UserDefaults.standard.integer(forKey: currentStreakKey)
        longestStreak = UserDefaults.standard.integer(forKey: longestStreakKey)
        if let date = UserDefaults.standard.object(forKey: lastCheckInKey) as? Date {
            lastCheckIn = date
            let today = Calendar.current.startOfDay(for: Date())
            let lastDay = Calendar.current.startOfDay(for: date)
            checkedInToday = (lastDay == today)

            // Check if streak is broken (more than 1 day gap)
            let daysBetween = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysBetween > 1 {
                currentStreak = 0
                saveStreak()
            }
        }
    }

    private func saveStreak() {
        UserDefaults.standard.set(currentStreak, forKey: currentStreakKey)
        UserDefaults.standard.set(longestStreak, forKey: longestStreakKey)
        UserDefaults.standard.set(lastCheckIn, forKey: lastCheckInKey)
    }

    func reset() {
        currentStreak = 0
        longestStreak = 0
        lastCheckIn = nil
        checkedInToday = false
        UserDefaults.standard.removeObject(forKey: currentStreakKey)
        UserDefaults.standard.removeObject(forKey: longestStreakKey)
        UserDefaults.standard.removeObject(forKey: lastCheckInKey)
    }
}
