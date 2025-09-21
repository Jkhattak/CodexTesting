import Foundation

public enum SearchResultKind: Sendable, Hashable {
    case task(Task)
    case habit(Habit)
    case focusSession(FocusSession)
    case note(Note)
    case calendarEvent(CalendarEvent)
}

public struct SearchResult: Identifiable, Sendable, Hashable {
    public var id: UUID
    public var title: String
    public var subtitle: String?
    public var kind: SearchResultKind
    public var relevance: Double

    public init(id: UUID = UUID(), title: String, subtitle: String? = nil, kind: SearchResultKind, relevance: Double) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.relevance = relevance
    }
}

public struct SearchEngine: Sendable {
    public init() {}

    public func search(query: String, snapshot: WorkspaceSnapshot, events: [CalendarEvent] = [], limit: Int = 20) -> [SearchResult] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        var results: [SearchResult] = []

        for task in snapshot.tasks {
            let score = score(text: task.title, query: normalized) + score(text: task.notes ?? "", query: normalized)
            if score > 0 {
                let subtitle = task.dueDate.map { "Due \(Self.format($0))" }
                results.append(SearchResult(title: task.title, subtitle: subtitle, kind: .task(task), relevance: score))
            }
        }

        for habit in snapshot.habits {
            let score = score(text: habit.title, query: normalized)
            if score > 0 {
                results.append(SearchResult(title: habit.title, subtitle: "Streak: \(habit.streak)", kind: .habit(habit), relevance: score))
            }
        }

        for note in snapshot.notes {
            let score = score(text: note.title + " " + note.body, query: normalized)
            if score > 0 {
                results.append(SearchResult(title: note.title, subtitle: "Note", kind: .note(note), relevance: score))
            }
        }

        for session in snapshot.focusSessions {
            let description = session.taskID.flatMap { taskID in
                snapshot.tasks.first(where: { $0.id == taskID })?.title
            }
            let title = description ?? "Focus Session"
            let score = score(text: title, query: normalized)
            if score > 0 {
                let subtitle: String
                if let end = session.end {
                    let minutes = Int(end.timeIntervalSince(session.start) / 60)
                    subtitle = "\(minutes)m • \(Self.format(session.start))"
                } else {
                    subtitle = "In progress"
                }
                results.append(SearchResult(title: title, subtitle: subtitle, kind: .focusSession(session), relevance: score))
            }
        }

        for event in events {
            let score = score(text: event.title, query: normalized)
            if score > 0 {
                let subtitle = "\(Self.format(event.start))"
                results.append(SearchResult(title: event.title, subtitle: subtitle, kind: .calendarEvent(event), relevance: score))
            }
        }

        return Array(results.sorted { lhs, rhs in
            if lhs.relevance == rhs.relevance {
                return lhs.title < rhs.title
            }
            return lhs.relevance > rhs.relevance
        }.prefix(limit))
    }

    private func score(text: String, query: String) -> Double {
        let haystack = text.lowercased()
        guard haystack.contains(query) else { return 0 }
        var score: Double = haystack == query ? 2 : 1
        let words = haystack.split(separator: " ")
        for word in words where word.hasPrefix(query) {
            score += 0.5
        }
        return score
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private static func format(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
