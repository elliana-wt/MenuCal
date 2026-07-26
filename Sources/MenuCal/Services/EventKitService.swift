@preconcurrency import EventKit
import AppKit
import Foundation

@MainActor
final class EventKitService: NSObject, EventProviding {
    private let eventStore: EKEventStore
    var onEventsChanged: (() -> Void)?

    override init() {
        eventStore = EKEventStore()
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventStoreDidChange),
            name: .EKEventStoreChanged,
            object: eventStore
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var authorizationStatus: CalendarAuthorization {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .fullAccess, .authorized:
            return .fullAccess
        case .restricted:
            return .restricted
        case .denied, .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func events(on date: Date, calendar: Calendar) -> [CalendarEventSummary] {
        guard authorizationStatus == .fullAccess else { return [] }

        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let summaries = eventStore.events(matching: predicate)
            .filter { $0.status != .canceled }
            .map(Self.summary(from:))

        return CalendarEventSummary.sortedForDisplay(summaries)
    }

    @objc
    private func eventStoreDidChange() {
        eventStore.refreshSourcesIfNecessary()
        onEventsChanged?()
    }

    private static func summary(from event: EKEvent) -> CalendarEventSummary {
        let color = event.calendar.cgColor
            .flatMap(NSColor.init(cgColor:))?
            .usingColorSpace(.sRGB)

        let eventColor = CalendarColor(
            red: color.map { Double($0.redComponent) } ?? CalendarColor.accent.red,
            green: color.map { Double($0.greenComponent) } ?? CalendarColor.accent.green,
            blue: color.map { Double($0.blueComponent) } ?? CalendarColor.accent.blue,
            alpha: color.map { Double($0.alphaComponent) } ?? CalendarColor.accent.alpha
        )

        let occurrenceKey = String(event.occurrenceDate?.timeIntervalSinceReferenceDate ?? event.startDate.timeIntervalSinceReferenceDate)
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier

        return CalendarEventSummary(
            id: "\(identifier)-\(occurrenceKey)",
            externalIdentifier: event.calendarItemExternalIdentifier,
            title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "无标题日程",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            location: event.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            calendarColor: eventColor
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
