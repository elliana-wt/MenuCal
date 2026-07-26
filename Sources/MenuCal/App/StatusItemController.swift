import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let eventService: EventKitService
    private let calendarOpener: CalendarAutomationService
    private var clockTimer: Timer?

    init(
        eventService: EventKitService = EventKitService(),
        calendarOpener: CalendarAutomationService = CalendarAutomationService()
    ) {
        self.eventService = eventService
        self.calendarOpener = calendarOpener
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        configurePopover()
        observeChanges()
        startClock()
        updateClock()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])
        button.toolTip = "MenuCal"
        button.setAccessibilityLabel("MenuCal 时钟与日历")
    }

    private func configurePopover() {
        popover.behavior = CommandLine.arguments.contains("--show-popover")
            ? .applicationDefined
            : .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 560)
    }

    private func observeChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateClock),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateClock),
            name: .NSSystemTimeZoneDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateClock),
            name: .NSCalendarDayChanged,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(updateClock),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func startClock() {
        let now = Date()
        let fraction = now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
        let firstFireDate = now.addingTimeInterval(max(0.05, 1 - fraction))
        let timer = Timer(
            fireAt: firstFireDate,
            interval: 1,
            target: self,
            selector: #selector(updateClock),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    @objc
    private func updateClock() {
        guard let button = statusItem.button else { return }

        let defaults = UserDefaults.standard
        let rawFormat = defaults.string(forKey: PreferenceKeys.clockFormat)
            ?? PreferenceKeys.defaultClockFormat
        let rawFontSize = defaults.double(forKey: PreferenceKeys.clockFontSize)
        let fontSize = min(
            PreferenceKeys.maximumClockFontSize,
            max(PreferenceKeys.minimumClockFontSize, rawFontSize)
        )
        let title = ClockFormatter().string(from: Date(), format: rawFormat)

        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    @objc
    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        showPopover()
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        let rootView = CalendarPopoverView(
            provider: eventService,
            calendarOpener: calendarOpener
        )
        popover.contentViewController = NSHostingController(rootView: rootView)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
