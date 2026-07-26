import Foundation

@MainActor
protocol CalendarOpening {
    func open(_ event: CalendarEventSummary) throws
}
