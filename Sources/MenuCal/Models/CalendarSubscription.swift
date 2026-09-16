import Foundation

struct CalendarSubscription: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    let url: URL
    var isEnabled: Bool
    let isBuiltIn: Bool

    static let chinaHolidays = CalendarSubscription(
        id: UUID(uuidString: "0A000000-0000-0000-0000-000000000001")!,
        title: "中国法定节假日与调休",
        url: URL(string: "https://calendars.icloud.com/holidays/cn_zh.ics")!,
        isEnabled: true,
        isBuiltIn: true
    )

    static func normalizedURL(_ input: String) throws -> URL {
        guard var parts = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parts.scheme?.lowercased(),
              ["https", "webcal"].contains(scheme),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil else {
            throw SubscriptionError.invalidURL
        }
        parts.scheme = scheme == "webcal" ? "https" : scheme
        parts.fragment = nil
        guard let url = parts.url else { throw SubscriptionError.invalidURL }
        return url
    }
}

enum SubscriptionError: LocalizedError {
    case invalidURL, duplicate, invalidCalendar, unsupportedCalendar, downloadFailed, tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidURL: "请输入有效的 https 或 webcal 日历订阅链接。"
        case .duplicate: "这个日历已经订阅。"
        case .invalidCalendar: "链接未返回有效的 iCalendar（ICS）日历，请确认使用的是订阅链接。"
        case .unsupportedCalendar: "此日历包含暂不支持的重复规则或时区，无法完整显示。可先订阅到系统日历，再通过系统日程查看。"
        case .downloadFailed: "无法获取日历，请检查网络和订阅链接后重试。"
        case .tooLarge: "日历文件超过 10 MB，暂时无法订阅。"
        }
    }
}

struct SubscribedCalendarEvent: Identifiable, Sendable {
    let summary: CalendarEventSummary
    let subscriptionID: UUID
    let calendarTitle: String
    let specialDay: String?
    let isBuiltIn: Bool
    var id: String { summary.id }

    var holidayLabel: String? {
        guard isBuiltIn else { return nil }
        let title = summary.title
        if specialDay == "ALTERNATE-WORKDAY" { return "班·" + shortHolidayName }
        if specialDay == "WORK-HOLIDAY" { return "休·" + shortHolidayName }
        return Self.statutoryHolidays.contains(title) ? shortHolidayName : nil
    }

    var holidayPriority: Int {
        specialDay == "ALTERNATE-WORKDAY" ? 0 : specialDay == "WORK-HOLIDAY" ? 1 : 2
    }

    private var shortHolidayName: String {
        summary.title.replacingOccurrences(of: "（休）", with: "")
            .replacingOccurrences(of: "（班）", with: "")
            .replacingOccurrences(of: "节", with: "")
    }

    private static let statutoryHolidays: Set<String> = [
        "元旦", "除夕", "春节", "清明节", "劳动节", "端午节", "中秋节", "国庆节"
    ]

    func occurs(on date: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return summary.startDate < end && (summary.endDate > start || summary.startDate >= start)
    }
}
