import Foundation

enum PreferenceKeys {
    static let clockFormat = "clockFormat"
    static let clockFontSize = "clockFontSize"

    static let defaultClockFormat = "M月d日 E HH:mm"
    static let defaultClockFontSize = 13.0
    static let minimumClockFontSize = 9.0
    static let maximumClockFontSize = 18.0

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            clockFormat: defaultClockFormat,
            clockFontSize: defaultClockFontSize
        ])
    }
}
