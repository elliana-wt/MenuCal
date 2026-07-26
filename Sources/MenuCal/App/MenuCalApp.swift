import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PreferenceKeys.registerDefaults()
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController()

        if CommandLine.arguments.contains("--show-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.statusItemController?.showPopover()
            }
        }
    }
}

@main
struct MenuCalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(loginItemManager: SMLoginItemManager())
        }
    }
}
