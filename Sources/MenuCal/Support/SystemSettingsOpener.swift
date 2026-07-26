import AppKit
import Foundation

@MainActor
enum SystemSettingsOpener {
    static func openCalendarPrivacy() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
    }

    static func openAutomationPrivacy() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    static func openLoginItems() {
        open("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
    }

    private static func open(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}
