import Foundation
import Testing
@testable import MenuCal

struct CalendarEventSummaryTests {
    @Test
    func allDayEventsSortBeforeTimedEvents() {
        let base = Date(timeIntervalSinceReferenceDate: 1_000)
        let timed = event(id: "timed", title: "Timed", start: base, allDay: false)
        let allDay = event(id: "all-day", title: "All day", start: base.addingTimeInterval(3_600), allDay: true)

        #expect(CalendarEventSummary.sortedForDisplay([timed, allDay]).map(\.id) == ["all-day", "timed"])
    }

    @Test
    func timedEventsSortByStartThenEnd() {
        let base = Date(timeIntervalSinceReferenceDate: 1_000)
        let later = event(id: "later", title: "Later", start: base.addingTimeInterval(60), allDay: false)
        let longer = event(id: "longer", title: "Longer", start: base, duration: 120, allDay: false)
        let shorter = event(id: "shorter", title: "Shorter", start: base, duration: 60, allDay: false)

        #expect(
            CalendarEventSummary.sortedForDisplay([later, longer, shorter]).map(\.id)
                == ["shorter", "longer", "later"]
        )
    }

    private func event(
        id: String,
        title: String,
        start: Date,
        duration: TimeInterval = 60,
        allDay: Bool
    ) -> CalendarEventSummary {
        CalendarEventSummary(
            id: id,
            externalIdentifier: id,
            title: title,
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            isAllDay: allDay,
            location: nil,
            calendarColor: .accent
        )
    }
}
