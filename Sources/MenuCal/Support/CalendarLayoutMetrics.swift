import CoreGraphics

enum CalendarLayoutMetrics {
    static let maximumPopoverWidth: CGFloat = 360
    static let eventListHeight: CGFloat = 260
    static let defaultPopoverHeight: CGFloat = defaultCalendarAndChromeHeight + eventListHeight

    private static let defaultCalendarAndChromeHeight: CGFloat = 346
    private static let calendarRowGapCount: CGFloat = 5

    static func popoverWidth(horizontalSpacingPixels: Double) -> CGFloat {
        let spacingPixels = horizontalSpacingPixels.isFinite
            ? horizontalSpacingPixels
            : PreferenceKeys.defaultCalendarDayHorizontalSpacingPixels
        let clampedSpacingPixels = min(
            PreferenceKeys.maximumCalendarDayHorizontalSpacingPixels,
            max(PreferenceKeys.minimumCalendarDayHorizontalSpacingPixels, spacingPixels)
        )
        let maximumSpacing = PreferenceKeys.points(
            fromPixels: PreferenceKeys.maximumCalendarDayHorizontalSpacingPixels
        )
        let currentSpacing = PreferenceKeys.points(fromPixels: clampedSpacingPixels)
        let horizontalGapCount: CGFloat = 6

        return maximumPopoverWidth - horizontalGapCount * (maximumSpacing - currentSpacing)
    }

    static func popoverHeight(
        verticalSpacingPixels: Double,
        showsEvents: Bool
    ) -> CGFloat {
        let spacingPixels = verticalSpacingPixels.isFinite
            ? verticalSpacingPixels
            : PreferenceKeys.defaultCalendarDayVerticalSpacingPixels
        let clampedSpacingPixels = min(
            PreferenceKeys.maximumCalendarDayVerticalSpacingPixels,
            max(PreferenceKeys.minimumCalendarDayVerticalSpacingPixels, spacingPixels)
        )
        let defaultSpacing = PreferenceKeys.points(
            fromPixels: PreferenceKeys.defaultCalendarDayVerticalSpacingPixels
        )
        let currentSpacing = PreferenceKeys.points(fromPixels: clampedSpacingPixels)
        let eventHeight = showsEvents ? eventListHeight : 0

        return defaultCalendarAndChromeHeight
            + eventHeight
            + calendarRowGapCount * (currentSpacing - defaultSpacing)
    }
}
