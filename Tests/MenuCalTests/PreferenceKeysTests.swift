import Foundation
import Testing
@testable import MenuCal

struct PreferenceKeysTests {
    @Test
    func convertsPixelsToPointsForFinerFontAdjustment() {
        #expect(PreferenceKeys.points(fromPixels: 16) == 12)
    }

    @Test
    func clockHorizontalPaddingCanReduceEachEdgeByEightPixels() {
        #expect(PreferenceKeys.minimumClockHorizontalPaddingPixels == -8)
        #expect(
            PreferenceKeys.points(
                fromPixels: PreferenceKeys.minimumClockHorizontalPaddingPixels
            ) == -6
        )
    }

    @Test
    func migratesLegacyPointFontSizeToPixels() {
        let suiteName = "PreferenceKeysTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(13.0, forKey: "clockFontSize")

        PreferenceKeys.registerDefaults(in: defaults)

        #expect(defaults.double(forKey: PreferenceKeys.clockFontSizePixels) == 17)
        #expect(defaults.double(forKey: PreferenceKeys.clockVerticalOffsetPixels) == 0)
        #expect(defaults.double(forKey: PreferenceKeys.clockLeftPaddingPixels) == 0)
        #expect(defaults.double(forKey: PreferenceKeys.clockRightPaddingPixels) == 0)
        #expect(defaults.double(forKey: PreferenceKeys.calendarDayFontSizePixels) == 19)
        #expect(defaults.double(forKey: PreferenceKeys.calendarDayVerticalSpacingPixels) == 5)
        #expect(defaults.double(forKey: PreferenceKeys.calendarDayHorizontalSpacingPixels) == 20)
        #expect(
            defaults.string(forKey: PreferenceKeys.calendarHighlightColor)
                == PreferenceKeys.defaultCalendarHighlightColor
        )
        #expect(defaults.bool(forKey: PreferenceKeys.calendarShowsEvents))
    }

    @Test
    func calendarPopoverWidthTracksHorizontalSpacingAndCapsAtCurrentWidth() {
        #expect(
            CalendarLayoutMetrics.popoverWidth(
                horizontalSpacingPixels: PreferenceKeys.maximumCalendarDayHorizontalSpacingPixels
            ) == 360
        )
        #expect(CalendarLayoutMetrics.popoverWidth(horizontalSpacingPixels: 0) == 261)
        #expect(CalendarLayoutMetrics.popoverWidth(horizontalSpacingPixels: 100) == 360)
    }

    @Test
    func calendarPopoverHeightTracksVerticalSpacingAndPreservesEventListHeight() {
        #expect(CalendarLayoutMetrics.eventListHeight == 260)
        #expect(CalendarLayoutMetrics.defaultPopoverHeight == 606)
        #expect(
            CalendarLayoutMetrics.popoverHeight(
                verticalSpacingPixels: PreferenceKeys.defaultCalendarDayVerticalSpacingPixels,
                showsEvents: true
            ) == CalendarLayoutMetrics.defaultPopoverHeight
        )
        #expect(
            CalendarLayoutMetrics.popoverHeight(
                verticalSpacingPixels: PreferenceKeys.defaultCalendarDayVerticalSpacingPixels,
                showsEvents: false
            ) == 346
        )
        #expect(
            CalendarLayoutMetrics.popoverHeight(
                verticalSpacingPixels: 0,
                showsEvents: true
            ) == 587.25
        )
        #expect(
            CalendarLayoutMetrics.popoverHeight(
                verticalSpacingPixels: 20,
                showsEvents: true
            ) == 662.25
        )
        #expect(
            CalendarLayoutMetrics.popoverHeight(
                verticalSpacingPixels: 100,
                showsEvents: true
            ) == 662.25
        )
    }

    @Test
    func parsesStoredCalendarHighlightColor() {
        let components = CalendarHighlightColor.rgbComponents(from: "#33AAFF")

        #expect(components?.red == Double(0x33) / 255)
        #expect(components?.green == Double(0xAA) / 255)
        #expect(components?.blue == 1)
        #expect(CalendarHighlightColor.rgbComponents(from: "systemAccent") == nil)
    }
}
