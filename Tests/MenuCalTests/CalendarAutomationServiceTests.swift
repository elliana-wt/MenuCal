import AppKit
import Foundation
import Testing
@testable import MenuCal

@MainActor
struct CalendarAutomationServiceTests {
    @Test
    func scriptEscapesIdentifierAndShowsMatchingEvent() {
        let service = CalendarAutomationService()
        let script = service.makeScript(
            externalIdentifier: "uid\"with\\characters",
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        #expect(script.contains("set eventUID to \"uid\\\"with\\\\characters\""))
        #expect(script.contains("show targetEvent"))
        expectScriptCompiles(script)
    }

    @Test
    func scriptFallsBackToSelectedDateWhenIdentifierIsMissing() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let fallbackDate = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 26)
        )!

        let script = CalendarAutomationService().makeScript(
            externalIdentifier: nil,
            fallbackDate: fallbackDate
        )

        #expect(script.contains("set year of targetDate to 2026"))
        #expect(script.contains("set month of targetDate to July"))
        #expect(script.contains("set day of targetDate to 26"))
        #expect(script.contains("view calendar at targetDate"))
        expectScriptCompiles(script)
    }

    private func expectScriptCompiles(_ source: String) {
        let script = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        #expect(script != nil)
        #expect(script?.compileAndReturnError(&errorInfo) == true)
        #expect(errorInfo == nil)
    }
}
