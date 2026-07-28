import Foundation

enum PreferenceKeys {
    static let clockFormat = "clockFormat"
    static let clockFontSizePixels = "clockFontSizePixels"
    static let clockVerticalOffsetPixels = "clockVerticalOffsetPixels"
    static let clockLeftPaddingPixels = "clockLeftPaddingPixels"
    static let clockRightPaddingPixels = "clockRightPaddingPixels"
    static let calendarDayFontSizePixels = "calendarDayFontSizePixels"
    static let calendarDayVerticalSpacingPixels = "calendarDayVerticalSpacingPixels"
    static let calendarDayHorizontalSpacingPixels = "calendarDayHorizontalSpacingPixels"
    static let calendarHighlightColor = "calendarHighlightColor"
    static let calendarShowsEvents = "calendarShowsEvents"

    static let defaultClockFormat = "M月d日 E HH:mm"
    static let defaultClockFontSizePixels = 17.0
    static let minimumClockFontSizePixels = 12.0
    static let maximumClockFontSizePixels = 24.0
    static let defaultClockVerticalOffsetPixels = 0.0
    static let minimumClockVerticalOffsetPixels = -6.0
    static let maximumClockVerticalOffsetPixels = 6.0
    static let defaultClockHorizontalPaddingPixels = 0.0
    static let minimumClockHorizontalPaddingPixels = -8.0
    static let maximumClockHorizontalPaddingPixels = 16.0
    static let defaultCalendarDayFontSizePixels = 19.0
    static let minimumCalendarDayFontSizePixels = 12.0
    static let maximumCalendarDayFontSizePixels = 28.0
    static let defaultCalendarDayVerticalSpacingPixels = 5.0
    static let minimumCalendarDayVerticalSpacingPixels = 0.0
    static let maximumCalendarDayVerticalSpacingPixels = 20.0
    static let defaultCalendarDayHorizontalSpacingPixels = 20.0
    static let minimumCalendarDayHorizontalSpacingPixels = 0.0
    static let maximumCalendarDayHorizontalSpacingPixels = 22.0
    static let defaultCalendarHighlightColor = "systemAccent"
    static let defaultCalendarShowsEvents = true

    private static let legacyClockFontSize = "clockFontSize"
    private static let pointsPerPixel = 0.75

    static func points(fromPixels pixels: Double) -> CGFloat {
        CGFloat(pixels * pointsPerPixel)
    }

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        migrateLegacyFontSize(in: defaults)
        defaults.register(defaults: [
            clockFormat: defaultClockFormat,
            clockFontSizePixels: defaultClockFontSizePixels,
            clockVerticalOffsetPixels: defaultClockVerticalOffsetPixels,
            clockLeftPaddingPixels: defaultClockHorizontalPaddingPixels,
            clockRightPaddingPixels: defaultClockHorizontalPaddingPixels,
            calendarDayFontSizePixels: defaultCalendarDayFontSizePixels,
            calendarDayVerticalSpacingPixels: defaultCalendarDayVerticalSpacingPixels,
            calendarDayHorizontalSpacingPixels: defaultCalendarDayHorizontalSpacingPixels,
            calendarHighlightColor: defaultCalendarHighlightColor,
            calendarShowsEvents: defaultCalendarShowsEvents
        ])
    }

    private static func migrateLegacyFontSize(in defaults: UserDefaults) {
        guard defaults.object(forKey: clockFontSizePixels) == nil,
              let legacyFontSize = defaults.object(forKey: legacyClockFontSize) as? NSNumber else {
            return
        }

        let fontSizePixels = min(
            maximumClockFontSizePixels,
            max(
                minimumClockFontSizePixels,
                (legacyFontSize.doubleValue / pointsPerPixel).rounded()
            )
        )
        defaults.set(fontSizePixels, forKey: clockFontSizePixels)
    }
}
