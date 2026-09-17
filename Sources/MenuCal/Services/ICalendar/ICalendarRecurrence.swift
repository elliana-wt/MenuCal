import Foundation

/// Common RFC 5545 day-based rules. Unsupported rule parts fail explicitly rather than losing events.
struct ICalendarRecurrence: Sendable {
    let frequency: Calendar.Component
    let interval: Int
    let count: Int?
    let until: Date?
    let months: [Int]
    let monthDays: [Int]
    let weekdays: [(ordinal: Int?, weekday: Int)]
    let positions: [Int]
    let firstWeekday: Int

    init(_ text: String, timeZone: TimeZone) throws {
        var values: [String: String] = [:]
        for part in text.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            guard pair.count == 2, values[String(pair[0])] == nil else { throw SubscriptionError.invalidCalendar }
            values[String(pair[0])] = String(pair[1])
        }
        let supported: Set<String> = ["FREQ", "INTERVAL", "COUNT", "UNTIL", "BYMONTH", "BYMONTHDAY", "BYDAY", "BYSETPOS", "WKST"]
        guard Set(values.keys).isSubset(of: supported) else { throw SubscriptionError.unsupportedCalendar }
        switch values["FREQ"] {
        case "DAILY": frequency = .day
        case "WEEKLY": frequency = .weekOfYear
        case "MONTHLY": frequency = .month
        case "YEARLY": frequency = .year
        default: throw SubscriptionError.unsupportedCalendar
        }
        func positive(_ name: String) throws -> Int? {
            guard let raw = values[name] else { return nil }
            guard let number = Int(raw), (1...100_000).contains(number) else { throw SubscriptionError.invalidCalendar }
            return number
        }
        interval = try positive("INTERVAL") ?? 1
        count = try positive("COUNT")
        until = try values["UNTIL"].map { try ICalendarProperty.date($0, timeZone: timeZone) }
        func integers(_ name: String, bound: Int, signed: Bool) throws -> [Int] {
            guard let raw = values[name] else { return [] }
            return try raw.split(separator: ",", omittingEmptySubsequences: false).map {
                guard let number = Int($0), number != 0, number >= (signed ? -bound : 1), number <= bound else {
                    throw SubscriptionError.invalidCalendar
                }
                return number
            }
        }
        months = try integers("BYMONTH", bound: 12, signed: false)
        monthDays = try integers("BYMONTHDAY", bound: 31, signed: true)
        positions = try integers("BYSETPOS", bound: 366, signed: true)
        let names = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
        weekdays = try (values["BYDAY"]?.split(separator: ",") ?? []).map { raw in
            guard let day = names.firstIndex(of: String(raw.suffix(2))) else { throw SubscriptionError.invalidCalendar }
            let prefix = raw.dropLast(2)
            let ordinal = prefix.isEmpty ? nil : Int(prefix)
            if !prefix.isEmpty && (ordinal == nil || ordinal == 0 || !(-53...53).contains(ordinal!)) {
                throw SubscriptionError.invalidCalendar
            }
            return (ordinal, day + 1)
        }
        if let raw = values["WKST"] {
            guard let day = names.firstIndex(of: raw) else { throw SubscriptionError.invalidCalendar }
            firstWeekday = day + 1
        } else { firstWeekday = 2 }
        if (frequency == .day || frequency == .weekOfYear) && weekdays.contains(where: { $0.ordinal != nil }) {
            throw SubscriptionError.unsupportedCalendar
        }
        if frequency == .weekOfYear && !monthDays.isEmpty { throw SubscriptionError.unsupportedCalendar }
    }

    func dates(starting start: Date, through end: Date, after earliest: Date, calendar input: Calendar) -> [Date] {
        var calendar = input
        calendar.firstWeekday = firstWeekday
        guard let firstPeriod = calendar.dateInterval(of: frequency, for: start)?.start else { return [] }
        let startParts = calendar.dateComponents([.month, .day, .weekday, .hour, .minute, .second], from: start)
        var result: [Date] = []
        var occurrenceCount = 0
        var period = firstPeriod
        // Unbounded rules can jump to the requested window without walking decades of history.
        if count == nil, earliest > start,
           let distance = calendar.dateComponents([frequency], from: firstPeriod, to: earliest).value(for: frequency),
           let jumped = calendar.date(byAdding: frequency, value: max(0, distance / interval - 1) * interval, to: firstPeriod) {
            period = jumped
        }
        for _ in 0..<100_000 {
            if period >= end || (until.map { period > $0 } ?? false) { break }
            guard let periodEnd = calendar.date(byAdding: frequency, value: 1, to: period) else { break }
            var day = period
            var candidates: [Date] = []
            while day < periodEnd {
                let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: day)
                let monthLength = calendar.range(of: .day, in: .month, for: day)!.count
                var matches = months.isEmpty || months.contains(parts.month!)
                if !monthDays.isEmpty {
                    matches = matches && monthDays.contains { ($0 > 0 ? $0 : monthLength + $0 + 1) == parts.day! }
                }
                if !weekdays.isEmpty {
                    matches = matches && weekdays.contains { rule in
                        guard rule.weekday == parts.weekday else { return false }
                        guard let ordinal = rule.ordinal else { return true }
                        let withinYear = frequency == .year && months.isEmpty
                        let dayNumber = withinYear ? calendar.ordinality(of: .day, in: .year, for: day)! : parts.day!
                        let length = withinYear ? calendar.range(of: .day, in: .year, for: day)!.count : monthLength
                        return ordinal > 0 ? (dayNumber - 1) / 7 + 1 == ordinal : -((length - dayNumber) / 7 + 1) == ordinal
                    }
                }
                if frequency == .weekOfYear && weekdays.isEmpty {
                    matches = matches && parts.weekday == startParts.weekday
                }
                if frequency == .month || frequency == .year {
                    if weekdays.isEmpty && monthDays.isEmpty { matches = matches && parts.day == startParts.day }
                    if frequency == .year && months.isEmpty && weekdays.isEmpty && monthDays.isEmpty {
                        matches = matches && parts.month == startParts.month
                    }
                }
                if matches {
                    var dateParts = parts
                    dateParts.weekday = nil
                    dateParts.hour = startParts.hour
                    dateParts.minute = startParts.minute
                    dateParts.second = startParts.second
                    if let date = calendar.date(from: dateParts),
                       calendar.dateComponents([.hour, .minute, .second], from: date).hour == startParts.hour {
                        candidates.append(date)
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            if !positions.isEmpty {
                candidates = Array(Set(positions.compactMap { position in
                    let index = position > 0 ? position - 1 : candidates.count + position
                    return candidates.indices.contains(index) ? candidates[index] : nil
                })).sorted()
            }
            for candidate in candidates where candidate >= start {
                if candidate >= end || (until.map { candidate > $0 } ?? false) { return result }
                occurrenceCount += 1
                if let count, occurrenceCount > count { return result }
                if candidate >= earliest { result.append(candidate) }
            }
            guard let next = calendar.date(byAdding: frequency, value: interval, to: period) else { break }
            period = next
        }
        return result
    }
}
