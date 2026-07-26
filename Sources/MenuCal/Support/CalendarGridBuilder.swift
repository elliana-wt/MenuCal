import Foundation

struct CalendarGridBuilder {
    var calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func startOfMonth(containing date: Date) -> Date {
        let components = calendar.dateComponents([.era, .year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    func days(containing month: Date, today: Date = Date()) -> [CalendarDay] {
        let firstOfMonth = startOfMonth(containing: month)
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: firstOfMonth) ?? firstOfMonth

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            return CalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: firstOfMonth, toGranularity: .month),
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
    }

    func weekdaySymbols() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }
}
