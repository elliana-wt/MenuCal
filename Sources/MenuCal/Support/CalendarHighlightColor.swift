import AppKit
import SwiftUI

enum CalendarHighlightColor {
    static func color(from storageValue: String) -> Color {
        guard let components = rgbComponents(from: storageValue) else {
            return .accentColor
        }

        return Color(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: 1
        )
    }

    static func storageValue(from color: Color) -> String {
        guard let color = NSColor(color).usingColorSpace(.sRGB) else {
            return PreferenceKeys.defaultCalendarHighlightColor
        }

        return String(
            format: "#%02X%02X%02X",
            byte(from: color.redComponent),
            byte(from: color.greenComponent),
            byte(from: color.blueComponent)
        )
    }

    static func foregroundColor(from storageValue: String) -> Color {
        guard let components = rgbComponents(from: storageValue) else {
            return Color(nsColor: .alternateSelectedControlTextColor)
        }

        let luminance =
            0.2126 * components.red
            + 0.7152 * components.green
            + 0.0722 * components.blue
        return luminance > 0.58 ? .black.opacity(0.82) : .white
    }

    static func rgbComponents(
        from storageValue: String
    ) -> (red: Double, green: Double, blue: Double)? {
        let hex = storageValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count == 7,
              hex.first == "#",
              let value = UInt64(hex.dropFirst(), radix: 16) else {
            return nil
        }

        return (
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    private static func byte(from component: CGFloat) -> Int {
        Int((min(1, max(0, component)) * 255).rounded())
    }
}
