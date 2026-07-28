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

        statusItem.autosaveName = "MenuCalStatusItem"
        statusItem.isVisible = true
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
        updatePopoverSize()
    }

    private func observeChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
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
        let rawFontSizePixels = defaults.double(forKey: PreferenceKeys.clockFontSizePixels)
        let fontSizePixels = min(
            PreferenceKeys.maximumClockFontSizePixels,
            max(PreferenceKeys.minimumClockFontSizePixels, rawFontSizePixels)
        )
        let rawVerticalOffsetPixels = defaults.double(
            forKey: PreferenceKeys.clockVerticalOffsetPixels
        )
        let verticalOffsetPixels = min(
            PreferenceKeys.maximumClockVerticalOffsetPixels,
            max(PreferenceKeys.minimumClockVerticalOffsetPixels, rawVerticalOffsetPixels)
        )
        let leftPaddingPixels = horizontalPadding(
            defaults.double(forKey: PreferenceKeys.clockLeftPaddingPixels)
        )
        let rightPaddingPixels = horizontalPadding(
            defaults.double(forKey: PreferenceKeys.clockRightPaddingPixels)
        )
        let title = ClockFormatter().string(from: Date(), format: rawFormat)

        let clockTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: PreferenceKeys.points(fromPixels: fontSizePixels),
                    weight: .regular
                ),
                .baselineOffset: PreferenceKeys.points(fromPixels: verticalOffsetPixels),
                .foregroundColor: NSColor.labelColor
            ]
        )

        button.attributedTitle = clockTitle
        statusItem.length = NSStatusItem.variableLength
        let defaultLength = button.frame.width

        let attributedTitle = NSMutableAttributedString()
        attributedTitle.append(
            spacer(widthInPixels: max(leftPaddingPixels - rightPaddingPixels, 0))
        )
        attributedTitle.append(clockTitle)
        attributedTitle.append(
            spacer(widthInPixels: max(rightPaddingPixels - leftPaddingPixels, 0))
        )
        button.attributedTitle = attributedTitle
        statusItem.length = max(
            button.fittingSize.width,
            defaultLength + PreferenceKeys.points(
                fromPixels: leftPaddingPixels + rightPaddingPixels
            )
        )
    }

    @objc
    private func preferencesDidChange() {
        updateClock()
        updatePopoverSize()
    }

    private func updatePopoverSize() {
        let horizontalSpacingPixels = UserDefaults.standard.double(
            forKey: PreferenceKeys.calendarDayHorizontalSpacingPixels
        )
        let verticalSpacingPixels = UserDefaults.standard.double(
            forKey: PreferenceKeys.calendarDayVerticalSpacingPixels
        )
        let showsEvents = UserDefaults.standard.bool(
            forKey: PreferenceKeys.calendarShowsEvents
        )
        let contentSize = NSSize(
            width: CalendarLayoutMetrics.popoverWidth(
                horizontalSpacingPixels: horizontalSpacingPixels
            ),
            height: CalendarLayoutMetrics.popoverHeight(
                verticalSpacingPixels: verticalSpacingPixels,
                showsEvents: showsEvents
            )
        )
        guard popover.contentSize != contentSize else {
            return
        }
        popover.contentSize = contentSize
    }

    private func horizontalPadding(_ pixels: Double) -> Double {
        min(
            PreferenceKeys.maximumClockHorizontalPaddingPixels,
            max(PreferenceKeys.minimumClockHorizontalPaddingPixels, pixels)
        )
    }

    private func spacer(widthInPixels: Double) -> NSAttributedString {
        let width = PreferenceKeys.points(fromPixels: widthInPixels)
        guard width > 0 else {
            return NSAttributedString()
        }

        let attachment = NSTextAttachment()
        attachment.image = NSImage(size: NSSize(width: width, height: 1))
        attachment.bounds = NSRect(x: 0, y: 0, width: width, height: 0)
        return NSAttributedString(attachment: attachment)
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
