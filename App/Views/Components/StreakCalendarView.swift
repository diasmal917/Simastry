import SwiftUI

/// Shows 7 circles representing the last 7 days of check-in activity.
/// Filled gold circle = checked in, empty circle with border = missed, today = highlighted ring.
struct StreakCalendarView: View {
    let currentStreak: Int
    let lastCheckIn: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var checkedInDays: [Bool] {
        StreakManager.shared.last7DaysCheckedIn()
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    dayCircle(index: index)
                    if index < 6 {
                        Spacer(minLength: 0)
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(dayLabel(for: index))
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(isToday(index) ? SimastryColor.gold : SimastryColor.mutedSilver)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCircle(index: Int) -> some View {
        let isChecked = checkedInDays[index]
        let today = isToday(index)
        let size: CGFloat = 28

        ZStack {
            if isChecked {
                Circle()
                    .fill(SimastryColor.gold)
                    .frame(width: size, height: size)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SimastryColor.midnight)
            } else {
                Circle()
                    .strokeBorder(
                        today ? SimastryColor.gold.opacity(0.6) : SimastryColor.mutedSilver.opacity(0.3),
                        lineWidth: today ? 1.5 : 1
                    )
                    .frame(width: size, height: size)
            }

            if today && !isChecked {
                Circle()
                    .strokeBorder(SimastryColor.gold.opacity(0.4), lineWidth: 1)
                    .frame(width: size + 6, height: size + 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func isToday(_ index: Int) -> Bool {
        index == 6 // Last position is today
    }

    private func dayLabel(for index: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        let daysAgo = 6 - index
        guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let label = formatter.string(from: date)
        // Return first letter only for compactness
        return String(label.prefix(1))
    }
}
