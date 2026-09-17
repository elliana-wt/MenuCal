import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    private static let sidebarSeparator = NSToolbarItem.Identifier("MenuCalSettingsSidebarSeparator")
    private let loginItemViewModel: LoginItemViewModel
    private let navigation = SettingsNavigation()
    private var selectionObservation: AnyCancellable?

    init(
        loginItemManager: any LoginItemManaging = SMLoginItemManager(),
        appUpdater: any AppUpdating = AppUpdateService(),
        frameAutosaveName: NSWindow.FrameAutosaveName? = "MenuCalSettingsWindow"
    ) {
        let loginItemViewModel = LoginItemViewModel(manager: loginItemManager)
        self.loginItemViewModel = loginItemViewModel
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = navigation.selection.rawValue
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.collectionBehavior = [.fullScreenNone]
        window.contentMinSize = NSSize(width: 780, height: 580)
        let splitController = NSSplitViewController()
        let sidebarController = NSHostingController(rootView: SettingsSidebarView(navigation: navigation))
        let detailController = NSHostingController(rootView: SettingsView(
            navigation: navigation,
            loginItemViewModel: loginItemViewModel,
            appUpdateViewModel: AppUpdateViewModel(updater: appUpdater)
        ))
        // AppKit owns pane sizes and safe areas; the hosted forms remain flexible.
        sidebarController.sizingOptions = []
        detailController.sizingOptions = []

        let sidebar = NSSplitViewItem(sidebarWithViewController: sidebarController)
        // Use the previous maximum width and prevent divider resizing.
        sidebar.minimumThickness = 240
        sidebar.maximumThickness = 240
        sidebar.allowsFullHeightLayout = true
        sidebar.canCollapseFromWindowResize = false
        sidebar.collapseBehavior = .preferResizingSiblingsWithFixedSplitView

        let detail = NSSplitViewItem(viewController: detailController)
        detail.minimumThickness = 520
        if #available(macOS 26.0, *) {
            // Enables the system floating sidebar while keeping form controls
            // inside the unobscured content safe area.
            detail.automaticallyAdjustsSafeAreaInsets = true
        }
        splitController.addSplitViewItem(sidebar)
        splitController.addSplitViewItem(detail)
        window.contentViewController = splitController

        super.init(window: window)
        window.delegate = self

        let toolbar = NSToolbar(identifier: "MenuCalSettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        if #available(macOS 15.0, *) {
            toolbar.allowsDisplayModeCustomization = false
        }
        window.toolbar = toolbar
        // Populate the real toolbar immediately, including before first presentation.
        if #available(macOS 15.0, *) {
            toolbar.itemIdentifiers = toolbarDefaultItemIdentifiers(toolbar)
        } else {
            for (index, identifier) in toolbarDefaultItemIdentifiers(toolbar).enumerated() {
                toolbar.insertItem(withItemIdentifier: identifier, at: index)
            }
        }
        toolbar.isVisible = true

        selectionObservation = navigation.$selection.sink { [weak window] page in
            window?.title = page.rawValue
        }
        if let frameAutosaveName {
            if !window.setFrameUsingName(frameAutosaveName) {
                window.center()
            }
            window.setFrameAutosaveName(frameAutosaveName)
        } else {
            window.center()
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        // Keep the toggle at the trailing edge of the sidebar's toolbar region.
        [.flexibleSpace, .toggleSidebar, Self.sidebarSeparator, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard itemIdentifier == Self.sidebarSeparator,
              let splitController = window?.contentViewController as? NSSplitViewController else {
            return nil
        }
        // Bind the native tracking item directly to our split view, so its
        // titlebar section follows both divider resizing and sidebar collapse.
        return NSTrackingSeparatorToolbarItem(
            identifier: itemIdentifier,
            splitView: splitController.splitView,
            dividerIndex: 0
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func windowDidBecomeKey(_ notification: Notification) {
        loginItemViewModel.refresh()
    }

    override func showWindow(_ sender: Any?) {
        loginItemViewModel.refresh()
        super.showWindow(sender)
        if window?.isMiniaturized == true { window?.deminiaturize(sender) }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(sender)
    }
}
