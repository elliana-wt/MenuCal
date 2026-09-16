import Foundation
import Testing
@testable import MenuCal

struct ICalendarTests {
    private let zone = TimeZone(identifier: "Asia/Shanghai")!
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = zone
        return result
    }
    private func date(_ value: String) throws -> Date { try ICalendarProperty.date(value, timeZone: zone) }
    private func document(_ body: String) throws -> ICalendarDocument {
        try ICalendarDocument(text: "BEGIN:VCALENDAR\nVERSION:2.0\n\(body)\nEND:VCALENDAR", timeZone: zone)
    }
    private func event(_ body: String) throws -> ICalendarDocument {
        try document("BEGIN:VEVENT\nUID:test\nSUMMARY:测试\n\(body)\nEND:VEVENT")
    }
    private func events(_ document: ICalendarDocument, from: String = "20260901", to: String = "20261101") throws -> [SubscribedCalendarEvent] {
        document.occurrences(in: DateInterval(start: try date(from), end: try date(to)), subscription: .chinaHolidays)
    }

    @Test func appleHolidaySpanAndMakeupDay() throws {
        let doc = try document("""
        BEGIN:VEVENT
        UID:mid-autumn
        DTSTART;VALUE=DATE:20260925
        DTEND;VALUE=DATE:20260928
        SUMMARY;LANGUAGE=zh_CN:中秋节（休）
        X-APPLE-SPECIAL-DAY:WORK-HOLIDAY
        END:VEVENT
        BEGIN:VEVENT
        UID:workday
        DTSTART;VALUE=DATE:20260920
        SUMMARY:国庆节（班）
        X-APPLE-SPECIAL-DAY:ALTERNATE-WORKDAY
        END:VEVENT
        """)
        let occurrences = try events(doc)
        let holiday = try #require(occurrences.first { $0.holidayLabel == "休·中秋" })
        #expect(holiday.occurs(on: try date("20260925"), calendar: calendar))
        #expect(holiday.occurs(on: try date("20260927"), calendar: calendar))
        #expect(!holiday.occurs(on: try date("20260928"), calendar: calendar))
        #expect(occurrences.contains { $0.holidayLabel == "班·国庆" })
    }

    @Test func appleYearlyRuleRespectsCountAndDefaultAllDayEnd() throws {
        let doc = try event("DTSTART;VALUE=DATE:20240101\nRRULE:FREQ=YEARLY;COUNT=6")
        let occurrences = try events(doc, from: "20240101", to: "20310101")
        #expect(occurrences.count == 6)
        #expect(occurrences.last?.summary.startDate == (try date("20290101")))
        #expect(occurrences.first?.summary.endDate == (try date("20240102")))
    }

    @Test func unfoldsAndUnescapesWithoutReadingAlarmSummary() throws {
        let doc = try document("""
        X-WR-CALNAME:私人日历
        BEGIN:VEVENT
        UID:escaped
        DTSTART:20260916T010000Z
        DTEND:20260916T020000Z
        SUMMARY:项目\\,讨论
         和复盘\\n第二行
        LOCATION:会议室\\;A
        BEGIN:VALARM
        SUMMARY:不应成为标题
        END:VALARM
        END:VEVENT
        """)
        let summary = try #require(events(doc).first?.summary)
        #expect(doc.title == "私人日历")
        #expect(summary.title == "项目,讨论和复盘\n第二行")
        #expect(summary.location == "会议室;A")
        #expect(summary.startDate == (try date("20260916T090000")))
    }

    @Test func weeklyExclusionsAdditionsMovedAndCancelledInstances() throws {
        let doc = try document("""
        BEGIN:VEVENT
        UID:weekly
        DTSTART;TZID=Asia/Shanghai:20260907T090000
        DURATION:PT1H
        RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=6
        EXDATE;TZID=Asia/Shanghai:20260909T090000
        RDATE;TZID=Asia/Shanghai:20260912T090000
        END:VEVENT
        BEGIN:VEVENT
        UID:weekly
        RECURRENCE-ID;TZID=Asia/Shanghai:20260914T090000
        DTSTART;TZID=Asia/Shanghai:20260915T100000
        DURATION:PT1H
        SUMMARY:改期
        END:VEVENT
        BEGIN:VEVENT
        UID:weekly
        RECURRENCE-ID;TZID=Asia/Shanghai:20260916T090000
        STATUS:CANCELLED
        END:VEVENT
        """)
        let occurrences = try events(doc)
        #expect(occurrences.count == 5)
        #expect(!occurrences.contains { $0.summary.startDate == (try? date("20260914T090000")) })
        #expect(!occurrences.contains { $0.summary.startDate == (try? date("20260916T090000")) })
        #expect(occurrences.contains { $0.summary.title == "改期" })
    }

    @Test func monthlyLastWeekdayAndInvalidMonthDates() throws {
        let doc = try event("DTSTART:20260731T090000\nRRULE:FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1;COUNT=4")
        let starts = try events(doc, from: "20260701", to: "20261101").map { $0.summary.startDate }
        #expect(starts == (try ["20260731T090000", "20260831T090000", "20260930T090000", "20261030T090000"].map(date)))
        let every31st = try event("DTSTART;VALUE=DATE:20260131\nRRULE:FREQ=MONTHLY;COUNT=3")
        #expect(try events(every31st, from: "20260101", to: "20260701").map { $0.summary.startDate } == ["20260131", "20260331", "20260531"].map(date))
    }

    @Test func untilInclusiveAndDSTLocalTime() throws {
        let doc = try event("DTSTART;TZID=America/New_York:20261031T090000\nDURATION:PT1H\nRRULE:FREQ=DAILY;UNTIL=20261102T140000Z")
        let occurrences = try events(doc, from: "20261030", to: "20261105")
        #expect(occurrences.count == 3)
        #expect(occurrences[1].summary.startDate.timeIntervalSince(occurrences[0].summary.startDate) == 25 * 3600)
    }

    @Test func rejectsInvalidAndUnsupportedFeeds() throws {
        #expect(throws: SubscriptionError.self) { try ICalendarDocument(text: "<html>Sign in</html>") }
        #expect(throws: SubscriptionError.self) { try event("DTSTART;VALUE=DATE:20260230") }
        #expect(throws: SubscriptionError.self) { try event("DTSTART:20260901T090000\nRRULE:FREQ=HOURLY") }
        #expect(throws: SubscriptionError.self) { try event("DTSTART;TZID=Unknown/Zone:20260901T090000") }
        #expect(throws: SubscriptionError.self) { try event("DTSTART:20260901T090000\nDURATION:P9223372036854775807W") }
    }

    @Test func urlValidationAndWebcalConversion() throws {
        #expect(try CalendarSubscription.normalizedURL(" webcal://example.com/private.ics?token=abc ").absoluteString == "https://example.com/private.ics?token=abc")
        #expect(throws: SubscriptionError.self) { try CalendarSubscription.normalizedURL("file:///tmp/test.ics") }
        #expect(throws: SubscriptionError.self) { try CalendarSubscription.normalizedURL("https://") }
        #expect(throws: SubscriptionError.self) { try CalendarSubscription.normalizedURL("http://example.com/test.ics") }
        #expect(throws: SubscriptionError.self) { try CalendarSubscription.normalizedURL("https://name:password@example.com/test.ics") }
    }
}
