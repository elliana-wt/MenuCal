import CoreGraphics

enum CalendarLayoutMetrics {
    static let maximumPopoverWidth: CGFloat = 360
    static let popoverHeight: CGFloat = 560

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
}
