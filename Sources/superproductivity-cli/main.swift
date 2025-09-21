import Foundation
import SuperProductivityCore

@main
struct SuperProductivityCLI {
    static func main() async throws {
        var arguments = CommandLine.arguments
        _ = arguments.removeFirst()

        guard let command = arguments.first else {
            printUsage()
            return
        }

        arguments.removeFirst()

        let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("workspace.json")
        let workHours = WorkHours(
            start: DateComponents(hour: 9, minute: 0),
            end: DateComponents(hour: 17, minute: 0),
            schedulingDays: Set([.monday, .tuesday, .wednesday, .thursday, .friday])
        )
        let settings = Settings(workHours: workHours)
        let store = await WorkspaceStore(persistenceURL: fileURL, initialSettings: settings)
        let parser = QuickAddParser()

        switch command {
        case "quickadd":
            let text = arguments.joined(separator: " ")
            guard !text.isEmpty else {
                print("Please provide text to parse")
                return
            }
            let result = parser.parse(text)
            let task = await store.quickAdd(result)
            print("Created task \(task.title) [\(task.priority)] estimate: \(task.estimateMinutes)m")
            if let scheduledStart = task.scheduledStart {
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                print("Scheduled at \(formatter.string(from: scheduledStart))")
            }
        case "tasks":
            let all = await store.allTasks().sorted { $0.createdAt < $1.createdAt }
            if all.isEmpty {
                print("No tasks in workspace.")
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                for task in all {
                    var components: [String] = []
                    components.append("[\(task.status.rawValue.uppercased())]")
                    components.append(task.title)
                    components.append("\(task.estimateMinutes)m")
                    if let due = task.dueDate {
                        components.append("due \(formatter.string(from: due))")
                    }
                    if let scheduled = task.scheduledStart {
                        components.append("starts \(formatter.string(from: scheduled))")
                    }
                    if !task.tags.isEmpty {
                        components.append("tags: \(task.tags.joined(separator: ","))")
                    }
                    print(components.joined(separator: " • "))
                }
            }
        case "autoplan":
            let events = parseEvents(from: arguments)
            let result = await store.autoPlan(day: Date(), calendarEvents: events)
            if result.allocations.isEmpty {
                print("No tasks were scheduled.")
            } else {
                print("Scheduled \(result.allocations.count) blocks:")
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                for allocation in result.allocations {
                    if let task = (await store.allTasks()).first(where: { $0.id == allocation.taskID }) {
                        let start = formatter.string(from: allocation.start)
                        let end = formatter.string(from: allocation.end)
                        print("- \(task.title) \(start)-\(end)\(allocation.isSplit ? " (split)" : "")")
                    }
                }
            }
            if !result.unscheduled.isEmpty {
                print("Unscheduled tasks:")
                for task in result.unscheduled {
                    print("- \(task.title) (\(task.estimateMinutes)m)")
                }
            }
        case "timeline":
            let events = parseEvents(from: arguments)
            let items = await store.timeline(for: Date(), calendarEvents: events)
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            if items.isEmpty {
                print("No timeline items for today.")
            } else {
                for item in items {
                    let start = formatter.string(from: item.start)
                    let end = formatter.string(from: item.end)
                    switch item.kind {
                    case let .calendarEvent(event):
                        print("[Event] \(event.title) \(start)-\(end)")
                    case let .task(task):
                        print("[Task] \(task.title) \(start)-\(end)")
                    case let .habit(habit):
                        print("[Habit] \(habit.title) \(start)-\(end)")
                    case let .focus(session):
                        print("[Focus] \(session.type.rawValue) \(start)-\(end)")
                    }
                }
            }
        case "insights":
            let engine = InsightsEngine()
            let interval = engine.weeklyInterval(containing: Date())
            let snapshot = await store.snapshot()
            let summary = engine.summarize(snapshot: snapshot, interval: interval)
            print("Insights for week starting \(DateFormatter.localizedString(from: interval.start, dateStyle: .short, timeStyle: .none))")
            print("Tasks completed: \(summary.taskCompletionCount)")
            print("Focus minutes: \(summary.totalFocusMinutes) (avg \(String(format: "%.1f", summary.averageFocusMinutes)))")
            if summary.completedTasksByTag.isEmpty {
                print("No tags recorded this week.")
            } else {
                print("Top tags:")
                for (tag, count) in summary.completedTasksByTag.sorted(by: { $0.value > $1.value }) {
                    print("- #\(tag): \(count)")
                }
            }
            if summary.longestHabitStreaks.isEmpty {
                print("No habits configured.")
            } else {
                print("Habit streaks:")
                for (habitID, streak) in summary.longestHabitStreaks {
                    if let habit = snapshot.habits.first(where: { $0.id == habitID }) {
                        print("- \(habit.title): \(streak)")
                    }
                }
            }
        case "search":
            let query = arguments.joined(separator: " ")
            guard !query.isEmpty else {
                print("Provide a query to search.")
                return
            }
            let engine = SearchEngine()
            let results = engine.search(query: query, snapshot: await store.snapshot())
            if results.isEmpty {
                print("No results for \"\(query)\".")
            } else {
                for result in results {
                    print("- \(result.title) [\(label(for: result.kind))]\(result.subtitle.map { " — \($0)" } ?? "")")
                }
            }
        default:
            printUsage()
        }
    }

    private static func printUsage() {
        print("superproductivity-cli <command> [options]")
        print("Commands:")
        print("  quickadd <text>        Parse natural language and create a task")
        print("  tasks                  List all tasks")
        print("  autoplan [--event HH:MM-HH:MM]...")
        print("                        Schedule unslotted tasks around busy events")
        print("  timeline [--event HH:MM-HH:MM]...")
        print("                        Display today's unified timeline")
        print("  insights               View weekly productivity summary")
        print("  search <query>         Search tasks, habits, notes, and sessions")
    }

    private static func parseEvents(from arguments: [String]) -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        var index = 0
        while index < arguments.count {
            if arguments[index] == "--event", index + 1 < arguments.count {
                let descriptor = arguments[index + 1]
                if let event = makeEvent(from: descriptor) {
                    events.append(event)
                }
                index += 2
            } else {
                index += 1
            }
        }
        return events
    }

    private static func makeEvent(from descriptor: String) -> CalendarEvent? {
        let parts = descriptor.split(separator: "-", maxSplits: 1).map { String($0) }
        guard parts.count == 2 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let today = Date()
        guard let startTime = formatter.date(from: parts[0]), let endTime = formatter.date(from: parts[1]) else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        var startComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let startParts = calendar.dateComponents([.hour, .minute], from: startTime)
        startComponents.hour = startParts.hour
        startComponents.minute = startParts.minute
        var endComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let endParts = calendar.dateComponents([.hour, .minute], from: endTime)
        endComponents.hour = endParts.hour
        endComponents.minute = endParts.minute
        guard let startDate = calendar.date(from: startComponents), let endDate = calendar.date(from: endComponents) else { return nil }
        return CalendarEvent(title: "Busy", start: startDate, end: endDate)
    }

    private static func label(for kind: SearchResultKind) -> String {
        switch kind {
        case .task: return "task"
        case .habit: return "habit"
        case .focusSession: return "focus"
        case .note: return "note"
        case .calendarEvent: return "event"
        }
    }
}
