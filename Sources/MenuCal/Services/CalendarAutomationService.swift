import AppKit
import Foundation

enum CalendarAutomationError: LocalizedError {
    case scriptUnavailable
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .scriptUnavailable:
            return "无法创建用于打开系统日历的脚本。"
        case let .executionFailed(message):
            return "无法在系统日历中定位事件：\(message)"
        }
    }
}

@MainActor
struct CalendarAutomationService: CalendarOpening {
    private let calendar = Calendar.autoupdatingCurrent

    func open(_ event: CalendarEventSummary) throws {
        let scriptSource = makeScript(
            externalIdentifier: event.externalIdentifier,
            fallbackDate: event.startDate
        )
        guard let script = NSAppleScript(source: scriptSource) else {
            throw CalendarAutomationError.scriptUnavailable
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = (errorInfo[NSAppleScript.errorMessage] as? String)
                ?? (errorInfo.description)
            throw CalendarAutomationError.executionFailed(message)
        }
    }

    func makeScript(externalIdentifier: String?, fallbackDate: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: fallbackDate)
        let year = components.year ?? 2001
        let month = max(1, min(12, components.month ?? 1))
        let day = components.day ?? 1
        let monthNames = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]

        let lookupBlock: String
        if let externalIdentifier, !externalIdentifier.isEmpty {
            let quotedIdentifier = AppleScriptEscaper.quotedString(externalIdentifier)
            lookupBlock = """
                set eventUID to \(quotedIdentifier)
                repeat with sourceCalendar in calendars
                    try
                        set matches to (every event of sourceCalendar whose uid is eventUID)
                        if (count of matches) > 0 then
                            set targetEvent to item 1 of matches
                            exit repeat
                        end if
                    end try
                end repeat
            """
        } else {
            lookupBlock = ""
        }

        return """
        tell application "Calendar"
            set targetEvent to missing value
        \(lookupBlock)
            activate
            if targetEvent is not missing value then
                show targetEvent
            else
                set targetDate to current date
                set year of targetDate to \(year)
                set month of targetDate to \(monthNames[month - 1])
                set day of targetDate to \(day)
                set time of targetDate to 0
                view calendar at targetDate
            end if
        end tell
        """
    }
}
