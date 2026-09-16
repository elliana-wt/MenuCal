import Foundation

/// Reads VEVENTs only; nested alarms and timezone observances are never treated as events.
struct ICalendarDocument: Sendable {
    let title: String?
    let events: [ICalendarEvent]

    init(text: String, timeZone: TimeZone = .autoupdatingCurrent) throws {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var unfolded: [String] = []
        for line in lines {
            if (line.hasPrefix(" ") || line.hasPrefix("\t")), !unfolded.isEmpty {
                unfolded[unfolded.count - 1] += line.dropFirst()
            } else {
                unfolded.append(line.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}")))
            }
        }
        guard unfolded.first == "BEGIN:VCALENDAR", unfolded.contains("END:VCALENDAR") else {
            throw SubscriptionError.invalidCalendar
        }
        var title: String?
        var events: [ICalendarEvent] = []
        var stack: [String] = []
        var properties: [ICalendarProperty] = []
        for line in unfolded {
            guard let property = ICalendarProperty(line) else { continue }
            if property.name == "BEGIN" {
                stack.append(property.value)
                if property.value == "VEVENT" { properties = [] }
            } else if property.name == "END" {
                guard stack.last == property.value else { throw SubscriptionError.invalidCalendar }
                if property.value == "VEVENT" {
                    events.append(try ICalendarEvent(properties: properties, timeZone: timeZone))
                }
                stack.removeLast()
            } else if stack.last == "VEVENT" {
                properties.append(property)
            } else if stack == ["VCALENDAR"], property.name == "X-WR-CALNAME" {
                title = Self.unescape(property.value)
            }
        }
        guard stack.isEmpty else { throw SubscriptionError.invalidCalendar }
        self.title = title
        self.events = events
    }

    static func unescape(_ text: String) -> String {
        var result = ""
        var escaped = false
        for char in text {
            if escaped {
                result.append(char == "n" || char == "N" ? "\n" : char)
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else {
                result.append(char)
            }
        }
        if escaped { result.append("\\") }
        return result
    }

    func occurrences(in range: DateInterval, subscription: CalendarSubscription) -> [SubscribedCalendarEvent] {
        // A detached instance replaces the original occurrence even when moved outside this range.
        let overrides = Dictionary(grouping: events.filter { $0.recurrenceID != nil }, by: \.uid)
        var result: [SubscribedCalendarEvent] = []
        var seen = Set<String>()
        for event in events where !event.cancelled {
            let excluded = Set((overrides[event.uid] ?? []).compactMap(\.recurrenceID))
            for start in event.starts(in: range) {
                if event.recurrenceID == nil && excluded.contains(start) { continue }
                let end: Date
                if event.isAllDay {
                    end = event.calendar.date(byAdding: .day, value: event.dayCount, to: start)!
                } else {
                    end = start.addingTimeInterval(event.duration)
                }
                guard start < range.end, end > range.start || start >= range.start else { continue }
                let id = "\(subscription.id)-\(event.uid)-\(start.timeIntervalSince1970)"
                guard seen.insert(id).inserted else { continue }
                result.append(SubscribedCalendarEvent(
                    summary: CalendarEventSummary(
                        id: id, externalIdentifier: event.uid, title: event.title,
                        startDate: start, endDate: end, isAllDay: event.isAllDay,
                        location: event.location, calendarColor: subscription.isBuiltIn
                            ? CalendarColor(red: 0.64, green: 0.43, blue: 0.29, alpha: 1) : .accent
                    ),
                    subscriptionID: subscription.id, calendarTitle: subscription.title,
                    specialDay: event.specialDay, isBuiltIn: subscription.isBuiltIn
                ))
            }
        }
        return result
    }
}

struct ICalendarProperty: Sendable {
    let name: String
    let parameters: [String: String]
    let value: String

    init?(_ line: String) {
        var quoted = false
        guard let colon = line.indices.first(where: { index in
            if line[index] == "\"" { quoted.toggle() }
            return line[index] == ":" && !quoted
        }) else { return nil }
        let parts = line[..<colon].split(separator: ";")
        guard let first = parts.first else { return nil }
        name = first.uppercased()
        var parameters: [String: String] = [:]
        for part in parts.dropFirst() {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 {
                parameters[pair[0].uppercased()] = String(pair[1]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        self.parameters = parameters
        value = String(line[line.index(after: colon)...])
    }

    func date(timeZone: TimeZone) throws -> Date {
        try Self.date(value, timeZone: resolvedTimeZone(fallback: timeZone))
    }

    func resolvedTimeZone(fallback: TimeZone) throws -> TimeZone {
        guard let name = parameters["TZID"] else { return fallback }
        if let zone = TimeZone(identifier: name) { return zone }
        // Apple sometimes prefixes IANA identifiers with /freeassociation.sourceforge.net/.
        let pieces = name.split(separator: "/")
        for index in pieces.indices {
            if let zone = TimeZone(identifier: pieces[index...].joined(separator: "/")) { return zone }
        }
        throw SubscriptionError.unsupportedCalendar
    }

    static func date(_ value: String, timeZone: TimeZone) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = value.hasSuffix("Z") ? TimeZone(secondsFromGMT: 0)! : timeZone
        formatter.isLenient = false
        formatter.dateFormat = value.count == 8 ? "yyyyMMdd" : value.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss"
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
            throw SubscriptionError.invalidCalendar
        }
        return date
    }
}

struct ICalendarEvent: Sendable {
    let uid: String
    let title: String
    let location: String?
    let start: Date
    let duration: TimeInterval
    let dayCount: Int
    let isAllDay: Bool
    let calendar: Calendar
    let recurrence: ICalendarRecurrence?
    let recurrenceID: Date?
    let exclusions: Set<Date>
    let additions: Set<Date>
    let cancelled: Bool
    let specialDay: String?

    init(properties: [ICalendarProperty], timeZone: TimeZone) throws {
        func property(_ name: String) -> ICalendarProperty? { properties.first { $0.name == name } }
        guard let uid = property("UID")?.value,
              let startProperty = property("DTSTART") ?? property("RECURRENCE-ID") else {
            throw SubscriptionError.invalidCalendar
        }
        self.uid = uid
        title = ICalendarDocument.unescape(property("SUMMARY")?.value ?? "无标题日程")
        location = property("LOCATION").map { ICalendarDocument.unescape($0.value) }
        isAllDay = startProperty.parameters["VALUE"] == "DATE" || startProperty.value.count == 8
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = isAllDay ? timeZone : startProperty.value.hasSuffix("Z")
            ? TimeZone(secondsFromGMT: 0)! : try startProperty.resolvedTimeZone(fallback: timeZone)
        self.calendar = calendar
        start = try startProperty.date(timeZone: calendar.timeZone)
        let end: Date
        if let endProperty = property("DTEND") {
            end = try endProperty.date(timeZone: calendar.timeZone)
        } else if let duration = property("DURATION")?.value {
            end = try Self.end(start: start, duration: duration, calendar: calendar)
        } else {
            end = isAllDay ? calendar.date(byAdding: .day, value: 1, to: start)! : start
        }
        guard end >= start else { throw SubscriptionError.invalidCalendar }
        duration = end.timeIntervalSince(start)
        dayCount = max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 1)
        recurrence = try property("RRULE").map { try ICalendarRecurrence($0.value, timeZone: calendar.timeZone) }
        recurrenceID = try property("RECURRENCE-ID")?.date(timeZone: calendar.timeZone)
        if property("RECURRENCE-ID")?.parameters["RANGE"] != nil || property("EXRULE") != nil {
            throw SubscriptionError.unsupportedCalendar
        }
        func dates(_ name: String) throws -> Set<Date> {
            var result = Set<Date>()
            for p in properties where p.name == name {
                let zone = try p.resolvedTimeZone(fallback: calendar.timeZone)
                for value in p.value.split(separator: ",") {
                    if value.contains("/") { throw SubscriptionError.unsupportedCalendar }
                    result.insert(try ICalendarProperty.date(String(value), timeZone: zone))
                }
            }
            return result
        }
        exclusions = try dates("EXDATE")
        additions = try dates("RDATE")
        cancelled = property("STATUS")?.value == "CANCELLED"
        specialDay = property("X-APPLE-SPECIAL-DAY")?.value
    }

    func starts(in range: DateInterval) -> [Date] {
        let earliest = range.start.addingTimeInterval(-max(duration, Double(dayCount) * 90_000))
        var starts: Set<Date> = [start]
        if let recurrence, recurrenceID == nil {
            starts.formUnion(recurrence.dates(starting: start, through: range.end, after: earliest, calendar: calendar))
        }
        starts.formUnion(additions)
        return starts.subtracting(exclusions).filter { $0 >= earliest && $0 < range.end }.sorted()
    }

    private static func end(start: Date, duration: String, calendar: Calendar) throws -> Date {
        let pattern = #"^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(duration.startIndex..., in: duration)
        guard let match = regex.firstMatch(in: duration, range: range), duration != "P", duration != "PT" else {
            throw SubscriptionError.invalidCalendar
        }
        func number(_ index: Int) throws -> Int {
            guard let range = Range(match.range(at: index), in: duration) else { return 0 }
            guard let value = Int(duration[range]), (0...10_000_000).contains(value) else {
                throw SubscriptionError.invalidCalendar
            }
            return value
        }
        let days = try number(1) * 7 + number(2)
        guard days < 100_000, let end = calendar.date(byAdding: .day, value: days, to: start) else {
            throw SubscriptionError.invalidCalendar
        }
        return try end.addingTimeInterval(Double(number(3)) * 3600 + Double(number(4)) * 60 + Double(number(5)))
    }
}
