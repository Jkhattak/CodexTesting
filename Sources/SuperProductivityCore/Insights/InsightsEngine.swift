import Foundation

public struct InsightSummary: Sendable {
    public var interval: DateInterval
    public var taskCompletionCount: Int
    public var totalFocusMinutes: Int
    public var averageFocusMinutes: Double
    public var longestHabitStreaks: [UUID: Int]
    public var completedTasksByTag: [String: Int]

    public init(interval: DateInterval, taskCompletionCount: Int, totalFocusMinutes: Int, averageFocusMinutes: Double, longestHabitStreaks: [UUID: Int], completedTasksByTag: [String: Int]) {
        self.interval = interval
        self.taskCompletionCount = taskCompletionCount
        self.totalFocusMinutes = totalFocusMinutes
        self.averageFocusMinutes = averageFocusMinutes
        self.longestHabitStreaks = longestHabitStreaks
        self.completedTasksByTag = completedTasksByTag
    }
}

public struct InsightsEngine: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    public func summarize(snapshot: WorkspaceSnapshot, interval: DateInterval) -> InsightSummary {
        let tasks = snapshot.tasks.filter { task in
            task.status == .done && task.updatedAt >= interval.start && task.updatedAt <= interval.end
        }

        let completionCount = tasks.count
        let tagCounts = tasks.reduce(into: [String: Int]()) { partialResult, task in
            for tag in task.tags {
                partialResult[tag, default: 0] += 1
            }
        }

        let sessions = snapshot.focusSessions.filter { session in
            guard let end = session.end else { return false }
            return (session.start < interval.end && end >= interval.start)
        }

        var focusTotal = 0
        for session in sessions {
            if let end = session.end {
                focusTotal += Int(end.timeIntervalSince(session.start) / 60)
            }
        }
        let averageFocus = sessions.isEmpty ? 0 : Double(focusTotal) / Double(sessions.count)

        let streaks = snapshot.habits.reduce(into: [UUID: Int]()) { partialResult, habit in
            partialResult[habit.id] = habit.streak
        }

        return InsightSummary(
            interval: interval,
            taskCompletionCount: completionCount,
            totalFocusMinutes: focusTotal,
            averageFocusMinutes: averageFocus,
            longestHabitStreaks: streaks,
            completedTasksByTag: tagCounts
        )
    }

    public func weeklyInterval(containing date: Date) -> DateInterval {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        let end = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? date
        return DateInterval(start: startOfWeek, end: end)
    }
}
