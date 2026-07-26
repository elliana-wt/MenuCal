import Foundation

struct ClockFormatter {
    static let fallbackFormat = "HH:mm"
    static let maximumOutputLength = 40
    static let maximumTemplateLength = 80

    let locale: Locale
    let timeZone: TimeZone
    let calendar: Calendar

    init(
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.locale = locale
        self.timeZone = timeZone
        self.calendar = calendar
    }

    func normalizedFormat(_ format: String) -> String {
        let trimmed = format.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Self.fallbackFormat }
        return String(trimmed.prefix(Self.maximumTemplateLength))
    }

    func string(from date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = calendar
        formatter.dateFormat = normalizedFormat(format)

        let rawValue = formatter.string(from: date)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let value = rawValue.isEmpty ? Self.fallbackString(from: date, locale: locale, timeZone: timeZone, calendar: calendar) : rawValue

        guard value.count > Self.maximumOutputLength else { return value }
        return String(value.prefix(Self.maximumOutputLength - 1)) + "…"
    }

    private static func fallbackString(
        from date: Date,
        locale: Locale,
        timeZone: TimeZone,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = calendar
        formatter.dateFormat = fallbackFormat
        return formatter.string(from: date)
    }
}
