import Foundation

public struct QuickAddResult: Sendable {
    public var title: String
    public var durationMinutes: Int?
    public var scheduledStart: Date?
    public var dueDate: Date?
    public var priority: TaskPriority?
    public var project: String?
    public var tags: [String]

    public init(
        title: String,
        durationMinutes: Int? = nil,
        scheduledStart: Date? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority? = nil,
        project: String? = nil,
        tags: [String] = []
    ) {
        self.title = title
        self.durationMinutes = durationMinutes
        self.scheduledStart = scheduledStart
        self.dueDate = dueDate
        self.priority = priority
        self.project = project
        self.tags = tags
    }
}

public struct QuickAddParser: Sendable {
    public var calendar: Calendar
    public var locale: Locale
    public var timeZone: TimeZone

    public init(calendar: Calendar = Calendar(identifier: .gregorian), locale: Locale = .current, timeZone: TimeZone = .current) {
        var calendar = calendar
        calendar.locale = locale
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.locale = locale
        self.timeZone = timeZone
    }

    public func parse(_ input: String, referenceDate: Date = Date()) -> QuickAddResult {
        var working = input
        let tags = extract(pattern: #"#([\p{L}0-9_-]+)"#, from: &working)
        let projectTokens = extract(pattern: #"@([\p{L}0-9_-]+)"#, from: &working)

        var priority: TaskPriority?
        var durationMinutes: Int?

        let tokens = working
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }
        var consumed = Set<Int>()

        var scheduledDay: Date?
        var scheduledTime: (hour: Int, minute: Int)?
        var dueDate: Date?

        for index in tokens.indices {
            guard !consumed.contains(index) else { continue }
            let rawToken = tokens[index]
            let token = rawToken.lowercased()

            if priority == nil, let parsedPriority = mapPriority(token) {
                priority = parsedPriority
                consumed.insert(index)
                continue
            }

            if durationMinutes == nil, let minutes = parseDurationToken(rawToken) {
                durationMinutes = minutes
                consumed.insert(index)
                continue
            }

            if let date = parseDayToken(token, reference: referenceDate) {
                scheduledDay = date
                consumed.insert(index)
                continue
            }

            if token == "due", index + 1 < tokens.count {
                let nextToken = tokens[index + 1]
                if let due = parseDueToken(nextToken.lowercased(), reference: referenceDate) {
                    dueDate = due
                    consumed.formUnion([index, index + 1])
                    continue
                } else if let parsed = parseExplicitDate(nextToken, reference: referenceDate) {
                    dueDate = parsed
                    consumed.formUnion([index, index + 1])
                    continue
                }
            }

            if let time = parseTimeToken(token) {
                scheduledTime = time
                consumed.insert(index)
                continue
            }

            if let explicitDate = parseExplicitDate(rawToken, reference: referenceDate) {
                scheduledDay = explicitDate
                consumed.insert(index)
                continue
            }
        }

        if dueDate == nil {
            for index in tokens.indices where !consumed.contains(index) {
                let token = tokens[index].lowercased()
                if token.starts(with: "due"), token.count > 3 {
                    let suffix = String(token.dropFirst(3))
                    if let due = parseDueToken(suffix, reference: referenceDate) {
                        dueDate = due
                        consumed.insert(index)
                    }
                }
            }
        }

        var scheduledStart: Date?
        if let day = scheduledDay {
            if let time = scheduledTime {
                scheduledStart = combine(day: day, time: time)
            } else {
                scheduledStart = day
            }
        }

        let titleTokens = tokens.enumerated()
            .filter { !consumed.contains($0.offset) }
            .map { $0.element }
        let title = titleTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        return QuickAddResult(
            title: title.isEmpty ? input.trimmingCharacters(in: .whitespacesAndNewlines) : title,
            durationMinutes: durationMinutes,
            scheduledStart: scheduledStart,
            dueDate: dueDate,
            priority: priority,
            project: projectTokens.first,
            tags: tags
        )
    }

    private func extract(pattern: String, from text: inout String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        var results: [String] = []
        for match in matches.reversed() {
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 0), in: text), let valueRange = Range(match.range(at: 1), in: text) else { continue }
            results.append(String(text[valueRange]))
            text.removeSubrange(range)
        }
        return results.reversed()
    }

    private func extractSingle(pattern: String, from text: inout String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange), match.numberOfRanges > 0 else {
            return nil
        }
        if let range = Range(match.range(at: 0), in: text) {
            let token = String(text[range])
            text.removeSubrange(range)
            return token
        }
        return nil
    }

    private func mapPriority(_ token: String) -> TaskPriority? {
        switch token.lowercased() {
        case "p1", "high":
            return .high
        case "p2", "med", "medium":
            return .medium
        case "p3", "low":
            return .low
        default:
            return nil
        }
    }

    private func parseDurationToken(_ token: String) -> Int? {
        let pattern = #"^(\d+)(m|min|minutes|h|hr|hrs|hour|hours)$"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: token, options: [], range: NSRange(token.startIndex..<token.endIndex, in: token)),
            let valueRange = Range(match.range(at: 1), in: token),
            let unitRange = Range(match.range(at: 2), in: token),
            let value = Int(token[valueRange])
        else { return nil }
        let unit = token[unitRange].lowercased()
        if unit.contains("h") {
            return value * 60
        }
        return value
    }

    private func parseDayToken(_ token: String, reference: Date) -> Date? {
        switch token {
        case "today":
            return calendar.startOfDay(for: reference)
        case "tmrw", "tomorrow":
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: reference) else { return nil }
            return calendar.startOfDay(for: tomorrow)
        default:
            if let weekday = parseWeekday(token) {
                return nextOccurrence(of: weekday, from: reference, includeToday: false)
            }
            return nil
        }
    }

    private func parseDueToken(_ token: String, reference: Date) -> Date? {
        if let weekday = parseWeekday(token) {
            return nextOccurrence(of: weekday, from: reference, includeToday: true)
        }
        return parseExplicitDate(token, reference: reference)
    }

    private func parseExplicitDate(_ token: String, reference: Date) -> Date? {
        let sanitized = token.replacingOccurrences(of: ",", with: "")
        let formats = ["M/d", "M/d/yy", "M/d/yyyy", "MMM d", "MMM d yyyy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateFormat = format
            if let date = formatter.date(from: sanitized) {
                let yearless = format == "M/d" || format == "MMM d"
                if yearless {
                    let components = calendar.dateComponents([.year], from: reference)
                    var dateComponents = calendar.dateComponents([.month, .day], from: date)
                    dateComponents.year = components.year
                    if let resolved = calendar.date(from: dateComponents) {
                        if resolved < reference {
                            return calendar.date(byAdding: .year, value: 1, to: resolved)
                        }
                        return resolved
                    }
                }
                return date
            }
        }
        return nil
    }

    private func parseTimeToken(_ token: String) -> (hour: Int, minute: Int)? {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mma"

        var normalized = token.replacingOccurrences(of: " ", with: "")
        if normalized.contains("am") || normalized.contains("pm") {
            normalized = normalized.replacingOccurrences(of: ":", with: "")
            if normalized.count <= 4 {
                let meridiem = String(normalized.suffix(2))
                let hourPart = String(normalized.dropLast(2))
                if let hourValue = Int(hourPart) {
                    if hourPart.count <= 2 {
                        return convert(hour: hourValue, minute: 0, meridiem: meridiem)
                    } else if hourPart.count == 3 {
                        let hour = Int(hourPart.prefix(1)) ?? 0
                        let minute = Int(hourPart.suffix(2)) ?? 0
                        return convert(hour: hour, minute: minute, meridiem: meridiem)
                    } else if hourPart.count == 4 {
                        let hour = Int(hourPart.prefix(2)) ?? 0
                        let minute = Int(hourPart.suffix(2)) ?? 0
                        return convert(hour: hour, minute: minute, meridiem: meridiem)
                    }
                }
            }
        }

        if token.contains(":") {
            let pieces = token.split(separator: ":")
            guard pieces.count == 2, let hour = Int(pieces[0]), let minuteToken = pieces.last else { return nil }
            var minuteValueString = String(minuteToken)
            var meridiem: String?
            if minuteValueString.lowercased().hasSuffix("am") || minuteValueString.lowercased().hasSuffix("pm") {
                meridiem = String(minuteValueString.suffix(2))
                minuteValueString = String(minuteValueString.dropLast(2))
            }
            guard let minute = Int(minuteValueString) else { return nil }
            if let meridiem {
                return convert(hour: hour, minute: minute, meridiem: meridiem)
            }
            if (0..<24).contains(hour) && (0..<60).contains(minute) {
                return (hour: hour, minute: minute)
            }
        } else if let value = Int(token), (0..<24).contains(value) {
            return (hour: value, minute: 0)
        }

        return nil
    }

    private func convert(hour: Int, minute: Int, meridiem: String) -> (hour: Int, minute: Int)? {
        var resolvedHour = hour % 12
        if meridiem.lowercased() == "pm" {
            resolvedHour += 12
        }
        return (hour: resolvedHour, minute: minute)
    }

    private func combine(day: Date, time: (hour: Int, minute: Int)) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components)
    }

    private func parseWeekday(_ token: String) -> Weekday? {
        let trimmed = token.trimmingCharacters(in: .punctuationCharacters)
        for weekday in Weekday.allCases {
            let name = calendar.weekdaySymbols[weekday.rawValue - 1].lowercased()
            let shortName = calendar.shortWeekdaySymbols[weekday.rawValue - 1].lowercased()
            if name.hasPrefix(trimmed) || shortName.hasPrefix(trimmed) {
                return weekday
            }
        }
        return nil
    }

    private func nextOccurrence(of weekday: Weekday, from reference: Date, includeToday: Bool) -> Date? {
        let components = calendar.dateComponents([.weekday, .year, .month, .day], from: reference)
        guard let currentWeekday = components.weekday else { return nil }
        let delta = (weekday.rawValue - currentWeekday + 7) % 7
        let daysToAdd = (delta == 0 && !includeToday) ? 7 : delta
        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: reference))
    }
}
