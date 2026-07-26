import Foundation
import Testing
@testable import MenuCal

struct CalendarGridBuilderTests {
    @Test
    func alwaysBuildsSixWeeksStartingOnConfiguredWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let builder = CalendarGridBuilder(calendar: calendar)
        let month = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15))!

        let days = builder.days(containing: month, today: month)

        #expect(days.count == 42)
        #expect(calendar.component(.weekday, from: days[0].date) == 2)
        #expect(calendar.component(.day, from: days[0].date) == 26)
        #expect(calendar.component(.month, from: days[0].date) == 1)
    }

    @Test
    func leapDayAppearsInFebruaryGrid() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let builder = CalendarGridBuilder(calendar: calendar)
        let month = calendar.date(from: DateComponents(year: 2024, month: 2, day: 1))!

        let days = builder.days(containing: month)

        #expect(days.contains {
            calendar.component(.year, from: $0.date) == 2024
                && calendar.component(.month, from: $0.date) == 2
                && calendar.component(.day, from: $0.date) == 29
        })
    }

    @Test
    func gridCrossesYearBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let builder = CalendarGridBuilder(calendar: calendar)
        let month = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!

        let days = builder.days(containing: month)

        #expect(days.contains {
            calendar.component(.year, from: $0.date) == 2026
        })
    }

    @Test
    func weekdaySymbolsRespectFirstWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 2

        let symbols = CalendarGridBuilder(calendar: calendar).weekdaySymbols()

        #expect(symbols.first == "M")
        #expect(symbols.count == 7)
    }
}
