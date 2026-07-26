import Foundation

@MainActor
protocol EventProviding: AnyObject {
    var authorizationStatus: CalendarAuthorization { get }
    var onEventsChanged: (() -> Void)? { get set }

    func requestAccess() async -> Bool
    func events(on date: Date, calendar: Calendar) -> [CalendarEventSummary]
}
