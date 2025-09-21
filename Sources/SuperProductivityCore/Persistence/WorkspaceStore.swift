import Foundation

public actor WorkspaceStore {
    private var tasks: [UUID: Task]
    private var habits: [UUID: Habit]
    private var focusSessions: [UUID: FocusSession]
    private var notes: [UUID: Note]
    private var settings: Settings
    private var taskAllocations: [UUID: [TaskAllocation]]

    private let persistenceURL: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        persistenceURL: URL? = nil,
        initialSettings: Settings
    ) async {
        self.persistenceURL = persistenceURL
        self.tasks = [:]
        self.habits = [:]
        self.focusSessions = [:]
        self.notes = [:]
        self.settings = initialSettings
        self.taskAllocations = [:]

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        if let persistenceURL, FileManager.default.fileExists(atPath: persistenceURL.path) {
            await loadFromDisk()
        }
    }

    // MARK: Persistence

    public func snapshot() -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            tasks: Array(tasks.values),
            habits: Array(habits.values),
            focusSessions: Array(focusSessions.values),
            notes: Array(notes.values),
            settings: settings,
            allocations: taskAllocations
        )
    }

    public func save() async {
        guard let persistenceURL else { return }
        do {
            let data = try encoder.encode(snapshot())
            try data.write(to: persistenceURL, options: [.atomic])
        } catch {
            print("Failed to save workspace: \(error)")
        }
    }

    private func loadFromDisk() async {
        guard let persistenceURL else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            let snapshot = try decoder.decode(WorkspaceSnapshot.self, from: data)
            self.tasks = Dictionary(uniqueKeysWithValues: snapshot.tasks.map { ($0.id, $0) })
            self.habits = Dictionary(uniqueKeysWithValues: snapshot.habits.map { ($0.id, $0) })
            self.focusSessions = Dictionary(uniqueKeysWithValues: snapshot.focusSessions.map { ($0.id, $0) })
            self.notes = Dictionary(uniqueKeysWithValues: snapshot.notes.map { ($0.id, $0) })
            self.settings = snapshot.settings
            self.taskAllocations = snapshot.allocations
        } catch {
            print("Failed to load workspace: \(error)")
        }
    }

    // MARK: Tasks

    @discardableResult
    public func addTask(_ task: Task) async -> Task {
        tasks[task.id] = task
        await save()
        return task
    }

    @discardableResult
    public func quickAdd(_ result: QuickAddResult) async -> Task {
        var estimate = result.durationMinutes ?? settings.defaultDurationMinutes
        if estimate <= 0 { estimate = settings.defaultDurationMinutes }

        let task = Task(
            title: result.title,
            priority: result.priority ?? .medium,
            estimateMinutes: estimate,
            scheduledStart: result.scheduledStart,
            scheduledEnd: result.scheduledStart.map { $0.addingTimeInterval(TimeInterval(estimate * 60)) },
            dueDate: result.dueDate,
            project: result.project,
            tags: result.tags
        )
        tasks[task.id] = task
        if let scheduledStart = result.scheduledStart {
            let allocation = TaskAllocation(taskID: task.id, start: scheduledStart, end: scheduledStart.addingTimeInterval(TimeInterval(estimate * 60)))
            taskAllocations[task.id] = [allocation]
        }
        await save()
        return task
    }

    public func updateTask(_ task: Task) async {
        tasks[task.id] = task
        await save()
    }

    public func allTasks() -> [Task] {
        Array(tasks.values)
    }

    public func unscheduledTasks() -> [Task] {
        tasks.values.filter { $0.scheduledStart == nil }
    }

    public func completeTask(id: UUID) async {
        guard var task = tasks[id] else { return }
        task.status = .done
        task.updatedAt = Date()
        tasks[id] = task
        await save()
    }

    // MARK: Habits

    @discardableResult
    public func addHabit(_ habit: Habit) async -> Habit {
        habits[habit.id] = habit
        await save()
        return habit
    }

    public func completeHabit(_ habitID: UUID, on date: Date = Date()) async {
        guard var habit = habits[habitID] else { return }
        let calendar = Calendar(identifier: .gregorian)
        let lastCompletionDay = habit.lastCompleted.map { calendar.startOfDay(for: $0) }
        let today = calendar.startOfDay(for: date)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)

        if lastCompletionDay == yesterday {
            habit.streak += 1
        } else if lastCompletionDay != today {
            habit.streak = 1
        }
        habit.lastCompleted = date
        habits[habitID] = habit
        await save()
    }

    // MARK: Focus Sessions

    @discardableResult
    public func startFocusSession(taskID: UUID?, minutes: Int, type: FocusSessionType) async -> FocusSession {
        let session = FocusSession(taskID: taskID, start: Date(), plannedMinutes: minutes, type: type)
        focusSessions[session.id] = session
        await save()
        return session
    }

    public func endFocusSession(id: UUID) async {
        guard var session = focusSessions[id] else { return }
        session.end = Date()
        if let end = session.end {
            session.actualMinutes = Int(end.timeIntervalSince(session.start) / 60)
        }
        focusSessions[id] = session
        await save()
    }

    // MARK: Notes

    @discardableResult
    public func addNote(_ note: Note) async -> Note {
        notes[note.id] = note
        await save()
        return note
    }

    // MARK: Settings

    public func updateSettings(_ settings: Settings) async {
        self.settings = settings
        await save()
    }

    public func currentSettings() -> Settings {
        settings
    }

    // MARK: Scheduling

    public func autoPlan(day: Date, calendarEvents: [CalendarEvent]) async -> AutoPlanResult {
        let busy = calendarEvents.map { BusyInterval(start: $0.start, end: $0.end) }
        let planner = AutoPlanner(workHours: settings.workHours)
        let candidates = tasks.values.filter { task in
            task.status == .todo && task.scheduledStart == nil && task.estimateMinutes > 0
        }
        let result = planner.plan(tasks: candidates, busy: busy, on: day)

        var bounds: [UUID: (start: Date, end: Date)] = [:]
        for allocation in result.allocations {
            let entry = bounds[allocation.taskID]
            if let existing = entry {
                let start = min(existing.start, allocation.start)
                let end = max(existing.end, allocation.end)
                bounds[allocation.taskID] = (start, end)
            } else {
                bounds[allocation.taskID] = (allocation.start, allocation.end)
            }
            var segments = taskAllocations[allocation.taskID, default: []]
            segments.append(allocation)
            segments.sort { $0.start < $1.start }
            taskAllocations[allocation.taskID] = segments
        }

        for (taskID, range) in bounds {
            if var task = tasks[taskID] {
                task.scheduledStart = range.start
                task.scheduledEnd = range.end
                tasks[taskID] = task
            }
        }

        await save()
        return result
    }

    // MARK: Timeline

    public func timeline(for day: Date, calendarEvents: [CalendarEvent]) -> [TimelineItem] {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? day

        var items: [TimelineItem] = []

        for event in calendarEvents {
            guard event.end > startOfDay && event.start < endOfDay else { continue }
            let start = max(event.start, startOfDay)
            let end = min(event.end, endOfDay)
            items.append(TimelineItem(kind: .calendarEvent(event), start: start, end: end))
        }

        for task in tasks.values where task.status != .done {
            if let allocations = taskAllocations[task.id] {
                for allocation in allocations where allocation.start < endOfDay && allocation.end > startOfDay {
                    let start = max(allocation.start, startOfDay)
                    let end = min(allocation.end, endOfDay)
                    items.append(TimelineItem(kind: .task(task), start: start, end: end))
                }
            } else if let start = task.scheduledStart, let end = task.scheduledEnd {
                if end > startOfDay && start < endOfDay {
                    let start = max(start, startOfDay)
                    let end = min(end, endOfDay)
                    items.append(TimelineItem(kind: .task(task), start: start, end: end))
                }
            }
        }

        for habit in habits.values {
            if let instance = habitInstance(for: habit, on: day) {
                let time = instance.scheduledTime ?? startOfDay
                let end = time.addingTimeInterval(TimeInterval(max(15, habit.targetValue) * 60))
                items.append(TimelineItem(kind: .habit(instance), start: time, end: end))
            }
        }

        for session in focusSessions.values {
            let endValue = session.end ?? Date()
            guard session.start < endOfDay, endValue > startOfDay else { continue }
            let start = max(session.start, startOfDay)
            let sessionEnd = min(endValue, endOfDay)
            items.append(TimelineItem(kind: .focus(session), start: start, end: sessionEnd))
        }

        items.sort { $0.start < $1.start }
        return items
    }

    private func habitInstance(for habit: Habit, on day: Date) -> HabitInstance? {
        guard isHabitScheduled(habit, on: day) else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: day)
        let scheduledTime: Date?
        if let reminder = habit.reminderTime {
            scheduledTime = calendar.date(bySettingHour: reminder.hour ?? 9, minute: reminder.minute ?? 0, second: 0, of: day)
        } else {
            scheduledTime = startOfDay.addingTimeInterval(60 * 60 * 8) // default 8AM
        }
        return HabitInstance(habitID: habit.id, title: habit.title, scheduledTime: scheduledTime, targetValue: habit.targetValue)
    }

    private func isHabitScheduled(_ habit: Habit, on day: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let weekdayIndex = calendar.component(.weekday, from: day)
        let weekday = Weekday(rawValue: weekdayIndex) ?? .monday
        switch habit.cadence {
        case .daily:
            return true
        case .weekdays:
            return weekday != .saturday && weekday != .sunday
        case let .custom(days):
            return days.contains(weekday)
        }
    }
}

public struct WorkspaceSnapshot: Codable, Sendable {
    public var tasks: [Task]
    public var habits: [Habit]
    public var focusSessions: [FocusSession]
    public var notes: [Note]
    public var settings: Settings
    public var allocations: [UUID: [TaskAllocation]]

    public init(tasks: [Task], habits: [Habit], focusSessions: [FocusSession], notes: [Note], settings: Settings, allocations: [UUID: [TaskAllocation]]) {
        self.tasks = tasks
        self.habits = habits
        self.focusSessions = focusSessions
        self.notes = notes
        self.settings = settings
        self.allocations = allocations
    }
}
