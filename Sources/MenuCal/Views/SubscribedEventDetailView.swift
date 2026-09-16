import SwiftUI

struct SubscribedEventDetailView: View {
    let event: SubscribedCalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(event.calendarTitle, systemImage: "calendar.badge.clock")
                .font(.caption).foregroundStyle(.secondary)
            Text(event.summary.title).font(.headline).textSelection(.enabled)
            Text(dateDescription).font(.callout)
            if let location = event.summary.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse").font(.callout).textSelection(.enabled)
            }
            Text("只读订阅 · 在设置中管理")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 280, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var dateDescription: String {
        let summary = event.summary
        if summary.isAllDay {
            let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: summary.endDate) ?? summary.startDate
            let start = summary.startDate.formatted(date: .abbreviated, time: .omitted)
            if Calendar.current.isDate(summary.startDate, inSameDayAs: lastDay) { return "\(start) · 全天" }
            return "\(start) – \(lastDay.formatted(date: .abbreviated, time: .omitted)) · 全天"
        }
        return "\(summary.startDate.formatted(date: .abbreviated, time: .shortened)) – \(summary.endDate.formatted(date: .abbreviated, time: .shortened))"
    }
}
