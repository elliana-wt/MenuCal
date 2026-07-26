import Foundation

struct CalendarDay: Identifiable, Equatable {
    let date: Date
    let isInDisplayedMonth: Bool
    let isToday: Bool

    var id: Date { date }
}
