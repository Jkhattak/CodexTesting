import Foundation

// MARK: - Enumerations

public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case todo
    case doing
    case done
}

public enum TaskPriority: Int, Codable, CaseIterable, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum HabitCadence: Codable, Sendable, Hashable {
    case daily
    case weekdays
    case custom([Weekday])
}

public enum HabitTargetType: String, Codable, CaseIterable, Sendable {
    case count
    case minutes
}

public enum FocusSessionType: String, Codable, CaseIterable, Sendable {
    case pomodoro
    case custom
}

public enum Theme: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public enum Weekday: Int, Codable, CaseIterable, Sendable, Hashable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public var calendarComponent: Int {
        rawValue
    }
}

// MARK: - Supporting Types

public struct ChecklistItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var isComplete: Bool

    public init(id: UUID = UUID(), title: String, isComplete: Bool = false) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
    }
}

public struct WorkHours: Codable, Hashable, Sendable {
    public var start: DateComponents
    public var end: DateComponents
    public var schedulingDays: Set<Weekday>

    public init(start: DateComponents, end: DateComponents, schedulingDays: Set<Weekday>) {
        self.start = start
        self.end = end
        self.schedulingDays = schedulingDays
    }
}

public struct Checklist: Codable, Hashable, Sendable {
    public var items: [ChecklistItem]

    public init(items: [ChecklistItem] = []) {
        self.items = items
    }
}

// MARK: - Entities

public struct Task: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String?
    public var status: TaskStatus
    public var priority: TaskPriority
    public var estimateMinutes: Int
    public var scheduledStart: Date?
    public var scheduledEnd: Date?
    public var dueDate: Date?
    public var project: String?
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var parentTaskID: UUID?
    public var checklist: [ChecklistItem]

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        status: TaskStatus = .todo,
        priority: TaskPriority = .medium,
        estimateMinutes: Int = 30,
        scheduledStart: Date? = nil,
        scheduledEnd: Date? = nil,
        dueDate: Date? = nil,
        project: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        parentTaskID: UUID? = nil,
        checklist: [ChecklistItem] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.estimateMinutes = estimateMinutes
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.dueDate = dueDate
        self.project = project
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.parentTaskID = parentTaskID
        self.checklist = checklist
    }

    public var isScheduled: Bool {
        scheduledStart != nil && scheduledEnd != nil
    }

    public var estimatedDuration: TimeInterval {
        TimeInterval(estimateMinutes * 60)
    }

    public func updatingSchedule(start: Date?, end: Date?) -> Task {
        var copy = self
        copy.scheduledStart = start
        copy.scheduledEnd = end
        copy.updatedAt = Date()
        return copy
    }

    public func updatingStatus(_ status: TaskStatus) -> Task {
        var copy = self
        copy.status = status
        copy.updatedAt = Date()
        return copy
    }
}

public struct Habit: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var cadence: HabitCadence
    public var targetType: HabitTargetType
    public var targetValue: Int
    public var reminderTime: DateComponents?
    public var streak: Int
    public var lastCompleted: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        cadence: HabitCadence,
        targetType: HabitTargetType,
        targetValue: Int,
        reminderTime: DateComponents? = nil,
        streak: Int = 0,
        lastCompleted: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.cadence = cadence
        self.targetType = targetType
        self.targetValue = targetValue
        self.reminderTime = reminderTime
        self.streak = streak
        self.lastCompleted = lastCompleted
    }
}

public struct FocusSession: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var taskID: UUID?
    public var start: Date
    public var end: Date?
    public var plannedMinutes: Int
    public var actualMinutes: Int
    public var type: FocusSessionType
    public var notes: String?

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        start: Date,
        end: Date? = nil,
        plannedMinutes: Int,
        actualMinutes: Int = 0,
        type: FocusSessionType,
        notes: String? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.start = start
        self.end = end
        self.plannedMinutes = plannedMinutes
        self.actualMinutes = actualMinutes
        self.type = type
        self.notes = notes
    }
}

public struct Note: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var links: [LinkReference]
    public var pinned: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        links: [LinkReference] = [],
        pinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.links = links
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct LinkReference: Codable, Hashable, Sendable {
    public enum ReferenceType: String, Codable, Sendable {
        case task
        case habit
        case note
        case url
    }

    public var type: ReferenceType
    public var identifier: UUID?
    public var url: URL?

    public init(type: ReferenceType, identifier: UUID? = nil, url: URL? = nil) {
        self.type = type
        self.identifier = identifier
        self.url = url
    }
}

public struct Settings: Codable, Sendable {
    public var workHours: WorkHours
    public var defaultDurationMinutes: Int
    public var calendarIntegration: Bool
    public var remindersWrite: Bool
    public var theme: Theme
    public var notificationsAllowed: Bool

    public init(
        workHours: WorkHours,
        defaultDurationMinutes: Int = 30,
        calendarIntegration: Bool = true,
        remindersWrite: Bool = false,
        theme: Theme = .system,
        notificationsAllowed: Bool = true
    ) {
        self.workHours = workHours
        self.defaultDurationMinutes = defaultDurationMinutes
        self.calendarIntegration = calendarIntegration
        self.remindersWrite = remindersWrite
        self.theme = theme
        self.notificationsAllowed = notificationsAllowed
    }
}

// MARK: - Timeline

public struct TimelineItem: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case calendarEvent(CalendarEvent)
        case task(Task)
        case habit(HabitInstance)
        case focus(FocusSession)
    }

    public var id: UUID
    public var kind: Kind
    public var start: Date
    public var end: Date

    public init(id: UUID = UUID(), kind: Kind, start: Date, end: Date) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
    }
}

public struct CalendarEvent: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool

    public init(id: UUID = UUID(), title: String, start: Date, end: Date, isAllDay: Bool = false) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }
}

public struct HabitInstance: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var habitID: UUID
    public var title: String
    public var scheduledTime: Date?
    public var targetValue: Int

    public init(id: UUID = UUID(), habitID: UUID, title: String, scheduledTime: Date?, targetValue: Int) {
        self.id = id
        self.habitID = habitID
        self.title = title
        self.scheduledTime = scheduledTime
        self.targetValue = targetValue
    }
}
