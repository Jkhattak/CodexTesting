import Foundation

public struct BusyInterval: Sendable, Hashable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var interval: DateInterval {
        DateInterval(start: start, end: end)
    }
}

public struct TaskAllocation: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var taskID: UUID
    public var start: Date
    public var end: Date
    public var isSplit: Bool

    public init(id: UUID = UUID(), taskID: UUID, start: Date, end: Date, isSplit: Bool = false) {
        self.id = id
        self.taskID = taskID
        self.start = start
        self.end = end
        self.isSplit = isSplit
    }
}

public struct AutoPlanResult: Sendable {
    public var allocations: [TaskAllocation]
    public var unscheduled: [Task]

    public init(allocations: [TaskAllocation], unscheduled: [Task]) {
        self.allocations = allocations
        self.unscheduled = unscheduled
    }
}

public struct AutoPlanner: Sendable {
    private let workHours: WorkHours
    private let calendar: Calendar
    private let minimumSplitMinutes: Int

    public init(workHours: WorkHours, calendar: Calendar = Calendar(identifier: .gregorian), minimumSplitMinutes: Int = 25) {
        self.workHours = workHours
        self.calendar = calendar
        self.minimumSplitMinutes = minimumSplitMinutes
    }

    public func plan(
        tasks: [Task],
        busy: [BusyInterval],
        on day: Date
    ) -> AutoPlanResult {
        guard let workInterval = workDayInterval(for: day) else {
            return AutoPlanResult(allocations: [], unscheduled: tasks)
        }

        var freeSlots = computeFreeSlots(workInterval: workInterval, busy: busy)
        let sortedTasks = tasks.sorted(by: schedulingSortKey)
        var allocations: [TaskAllocation] = []
        var unscheduled: [Task] = []

        for task in sortedTasks {
            var remainingDuration = TimeInterval(task.estimateMinutes * 60)
            var scheduled = false

            slotLoop: for slotIndex in freeSlots.indices {
                if remainingDuration <= 0 { break }

                let slot = freeSlots[slotIndex]
                guard slot.duration > 0 else { continue }

                if remainingDuration <= slot.duration {
                    let start = slot.start
                    let end = start.addingTimeInterval(remainingDuration)
                    allocations.append(TaskAllocation(taskID: task.id, start: start, end: end, isSplit: scheduled))
                    freeSlots[slotIndex] = DateInterval(start: end, end: slot.end)
                    scheduled = true
                    remainingDuration = 0
                    break slotLoop
                } else {
                    let minimumSplit = TimeInterval(minimumSplitMinutes * 60)
                    let leftover = remainingDuration - slot.duration
                    if slot.duration >= minimumSplit && (leftover == 0 || leftover >= minimumSplit) {
                        let start = slot.start
                        let end = slot.end
                        allocations.append(TaskAllocation(taskID: task.id, start: start, end: end, isSplit: true))
                        remainingDuration -= slot.duration
                        freeSlots[slotIndex] = DateInterval(start: slot.end, end: slot.end)
                        continue
                    } else {
                        continue
                    }
                }
            }

            if remainingDuration > 0 {
                unscheduled.append(task)
            }
        }

        allocations.sort { $0.start < $1.start }
        return AutoPlanResult(allocations: allocations, unscheduled: unscheduled)
    }

    private func workDayInterval(for day: Date) -> DateInterval? {
        let weekdayComponent = calendar.component(.weekday, from: day)
        guard workHours.schedulingDays.contains(Weekday(rawValue: weekdayComponent) ?? .monday) else {
            return nil
        }

        var startComponents = calendar.dateComponents([.year, .month, .day], from: day)
        startComponents.hour = workHours.start.hour
        startComponents.minute = workHours.start.minute
        startComponents.second = workHours.start.second

        var endComponents = calendar.dateComponents([.year, .month, .day], from: day)
        endComponents.hour = workHours.end.hour
        endComponents.minute = workHours.end.minute
        endComponents.second = workHours.end.second

        guard
            let startDate = calendar.date(from: startComponents),
            let endDate = calendar.date(from: endComponents),
            endDate > startDate
        else { return nil }

        return DateInterval(start: startDate, end: endDate)
    }

    private func schedulingSortKey(lhs: Task, rhs: Task) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (l?, r?):
            if l != r { return l < r }
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            break
        }

        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }

        return lhs.estimateMinutes > rhs.estimateMinutes
    }

    private func computeFreeSlots(workInterval: DateInterval, busy: [BusyInterval]) -> [DateInterval] {
        var freeSlots = [workInterval]
        let busyIntervals = busy
            .map { $0.interval }
            .compactMap { $0.intersection(with: workInterval) }
            .sorted { $0.start < $1.start }

        for interval in busyIntervals {
            var updated: [DateInterval] = []
            for slot in freeSlots {
                if !slot.intersects(interval) {
                    updated.append(slot)
                    continue
                }

                if interval.start > slot.start {
                    updated.append(DateInterval(start: slot.start, end: interval.start))
                }
                if interval.end < slot.end {
                    updated.append(DateInterval(start: interval.end, end: slot.end))
                }
            }
            freeSlots = updated
        }

        freeSlots = freeSlots.filter { $0.duration > 0 }
        freeSlots.sort { $0.start < $1.start }
        return freeSlots
    }
}

private extension DateInterval {
    func intersection(with other: DateInterval) -> DateInterval? {
        let start = max(self.start, other.start)
        let end = min(self.end, other.end)
        guard start < end else { return nil }
        return DateInterval(start: start, end: end)
    }
}
