import AppKit
import SwiftUI
import Testing
@testable import MenuCal

@MainActor
struct SettingsWindowControllerTests {
    @Test
    func nativeToolbarTracksSidebarAndPreservesStateWhenClosed() throws {
        _ = NSApplication.shared
        let controller = SettingsWindowController(
            loginItemManager: SettingsTestLoginItemManager(),
            appUpdater: SettingsTestUpdater(),
            frameAutosaveName: nil
        )
        let window = try #require(controller.window)
        let content = try #require(window.contentViewController)

        let split = try #require(content as? NSSplitViewController)
        let toolbar = try #require(window.toolbar)
        window.contentView?.layoutSubtreeIfNeeded()
        #expect(toolbar.items.contains { $0.itemIdentifier == .toggleSidebar })
        let tracking = try #require(toolbar.items.compactMap { $0 as? NSTrackingSeparatorToolbarItem }.first)
        #expect(tracking.splitView === split.splitView)
        #expect(tracking.dividerIndex == 0)

        if #available(macOS 27.0, *) {
            // Also catches an incorrectly linked SDK (e.g. SDK 14.0), which
            // selects AppKit's legacy sidebar despite identical view code.
            func descendants(of view: NSView) -> [NSView] {
                [view] + view.subviews.flatMap { descendants(of: $0) }
            }
            let frameView = try #require(window.contentView?.superview)
            let views = descendants(of: frameView)
            #expect(views.contains { $0 is NSGlassEffectView })
            #expect(!views.contains { ($0 as? NSVisualEffectView)?.material == .sidebar })
        }

        let sidebar = try #require(split.splitViewItems.first)
        #expect(sidebar.behavior == .sidebar)
        #expect(sidebar.allowsFullHeightLayout)
        if #available(macOS 26.0, *) {
            #expect(split.splitViewItems[1].automaticallyAdjustsSafeAreaInsets)
        }
        let sidebarHost = try #require(sidebar.viewController as? NSHostingController<SettingsSidebarView>)
        sidebarHost.rootView.navigation.selection = .general
        #expect(window.title == SettingsPage.general.rawValue)
        split.toggleSidebar(nil)
        #expect(sidebar.isCollapsed)
        split.toggleSidebar(nil)
        #expect(!sidebar.isCollapsed)

        // Closing settings must not discard the view tree or its page selection.
        controller.close()

        #expect(controller.window === window)
        #expect(controller.window?.contentViewController === content)
        #expect(!window.isReleasedWhenClosed)
        #expect(!window.isVisible)
        #expect(sidebarHost.rootView.navigation.selection == .general)
    }
}

@MainActor
private struct SettingsTestLoginItemManager: LoginItemManaging {
    var status: LoginItemStatus { .notRegistered }
    func setEnabled(_ enabled: Bool) throws {}
}

private struct SettingsTestUpdater: AppUpdating {
    var currentVersion: String { "1.0.0" }
    func latestRelease() async throws -> AppRelease { throw CancellationError() }
    func install(_ release: AppRelease) async throws { throw CancellationError() }
}
