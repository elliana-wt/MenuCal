import Foundation
import Testing
@testable import MenuCal

@MainActor
struct CalendarStoreTests {
    @Test
    func refreshQueriesEventsWhenAuthorized() {
        let provider = MockEventProvider()
        provider.authorization = .fullAccess
        provider.stubbedEvents = [sampleEvent]
        let store = CalendarStore(provider: provider)
        let date = Date(timeIntervalSinceReferenceDate: 2_000)

        store.refresh(for: date)

        #expect(store.events == [sampleEvent])
        #expect(provider.lastRequestedDate == date)
    }

    @Test
    func refreshClearsEventsWhenDenied() {
        let provider = MockEventProvider()
        provider.authorization = .fullAccess
        provider.stubbedEvents = [sampleEvent]
        let store = CalendarStore(provider: provider)
        store.refresh(for: Date())
        provider.authorization = .denied

        provider.onEventsChanged?()

        #expect(store.authorization == .denied)
        #expect(store.events.isEmpty)
    }

    @Test
    func requestAccessRefreshesAfterGrant() async {
        let provider = MockEventProvider()
        provider.authorization = .notDetermined
        provider.grantAccess = true
        provider.stubbedEvents = [sampleEvent]
        let store = CalendarStore(provider: provider)

        await store.requestAccess(for: Date())

        #expect(store.authorization == .fullAccess)
        #expect(store.events == [sampleEvent])
    }

    private var sampleEvent: CalendarEventSummary {
        CalendarEventSummary(
            id: "event",
            externalIdentifier: "uid",
            title: "Event",
            startDate: Date(timeIntervalSinceReferenceDate: 2_000),
            endDate: Date(timeIntervalSinceReferenceDate: 2_060),
            isAllDay: false,
            location: nil,
            calendarColor: .accent
        )
    }
}

@MainActor
private final class MockEventProvider: EventProviding {
    var authorization: CalendarAuthorization = .notDetermined
    var grantAccess = false
    var stubbedEvents: [CalendarEventSummary] = []
    var lastRequestedDate: Date?
    var onEventsChanged: (() -> Void)?

    var authorizationStatus: CalendarAuthorization {
        authorization
    }

    func requestAccess() async -> Bool {
        if grantAccess {
            authorization = .fullAccess
        }
        return grantAccess
    }

    func events(on date: Date, calendar: Calendar) -> [CalendarEventSummary] {
        lastRequestedDate = date
        return stubbedEvents
    }
}
