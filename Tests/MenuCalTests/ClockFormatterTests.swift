import Foundation
import Testing
@testable import MenuCal

struct ClockFormatterTests {
    private let locale = Locale(identifier: "en_US_POSIX")
    private let timeZone = TimeZone(secondsFromGMT: 0)!

    @Test
    func formatsUsingProvidedTemplate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 9, minute: 8, second: 7))!
        let formatter = ClockFormatter(locale: locale, timeZone: timeZone, calendar: calendar)

        #expect(formatter.string(from: date, format: "yyyy-MM-dd HH:mm:ss") == "2026-07-26 09:08:07")
    }

    @Test
    func emptyFormatFallsBackToHoursAndMinutes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 9, minute: 8))!
        let formatter = ClockFormatter(locale: locale, timeZone: timeZone, calendar: calendar)

        #expect(formatter.string(from: date, format: " \n ") == "09:08")
    }

    @Test
    func longOutputIsTruncated() {
        let formatter = ClockFormatter(locale: locale, timeZone: timeZone)
        let literal = String(repeating: "x", count: 60)
        let output = formatter.string(from: Date(timeIntervalSince1970: 0), format: "'\(literal)'")

        #expect(output.count == ClockFormatter.maximumOutputLength)
        #expect(output.hasSuffix("…"))
    }

    @Test
    func newlinesAreCollapsed() {
        let formatter = ClockFormatter(locale: locale, timeZone: timeZone)
        let output = formatter.string(from: Date(timeIntervalSince1970: 0), format: "'top\nbottom'")

        #expect(output == "top bottom")
    }
}
