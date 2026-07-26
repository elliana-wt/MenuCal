import Foundation

struct CalendarColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    static let accent = CalendarColor(red: 0.16, green: 0.50, blue: 0.95, alpha: 1)
}

struct CalendarEventSummary: Identifiable, Equatable, Sendable {
    let id: String
    let externalIdentifier: String?
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let calendarColor: CalendarColor

    static func sortedForDisplay(_ events: [Self]) -> [Self] {
        events.sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay {
                return lhs.isAllDay
            }
            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }
            if lhs.endDate != rhs.endDate {
                return lhs.endDate < rhs.endDate
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}
