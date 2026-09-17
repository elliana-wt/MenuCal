import SwiftUI

@MainActor
struct AppearanceSettingsView: View {
    @AppStorage(PreferenceKeys.clockFormat) private var clockFormat = PreferenceKeys.defaultClockFormat
    @AppStorage(PreferenceKeys.clockFontSizePixels)
    private var clockFontSizePixels = PreferenceKeys.defaultClockFontSizePixels
    @AppStorage(PreferenceKeys.clockVerticalOffsetPixels)
    private var clockVerticalOffsetPixels = PreferenceKeys.defaultClockVerticalOffsetPixels
    @AppStorage(PreferenceKeys.clockLeftPaddingPixels)
    private var clockLeftPaddingPixels = PreferenceKeys.defaultClockHorizontalPaddingPixels
    @AppStorage(PreferenceKeys.clockRightPaddingPixels)
    private var clockRightPaddingPixels = PreferenceKeys.defaultClockHorizontalPaddingPixels
    @AppStorage(PreferenceKeys.calendarDayFontSizePixels)
    private var calendarDayFontSizePixels = PreferenceKeys.defaultCalendarDayFontSizePixels
    @AppStorage(PreferenceKeys.calendarDayVerticalSpacingPixels)
    private var calendarDayVerticalSpacingPixels =
        PreferenceKeys.defaultCalendarDayVerticalSpacingPixels
    @AppStorage(PreferenceKeys.calendarDayHorizontalSpacingPixels)
    private var calendarDayHorizontalSpacingPixels =
        PreferenceKeys.defaultCalendarDayHorizontalSpacingPixels
    @AppStorage(PreferenceKeys.calendarHighlightColor)
    private var calendarHighlightColor = PreferenceKeys.defaultCalendarHighlightColor
    @AppStorage(PreferenceKeys.calendarShowsEvents)
    private var calendarShowsEvents = PreferenceKeys.defaultCalendarShowsEvents
    private let controlLabelWidth: CGFloat = 76
    private let controlValueWidth: CGFloat = 54

    var body: some View {
        Form {
            Section("菜单栏时钟") {
                HStack(alignment: .center) {
                    Text("格式模板")
                        .frame(width: controlLabelWidth, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 10) {
                        TextField("格式模板", text: $clockFormat)
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .frame(width: 233)
                            .multilineTextAlignment(.trailing)

                        Text("使用 DateFormatter 格式，如 HH:mm:ss、M月d日 E HH:mm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.top, 5)
                }

                HStack {
                    Text("字号")
                        .frame(width: controlLabelWidth, alignment: .leading)
                    pixelSlider(
                        value: $clockFontSizePixels,
                        in: PreferenceKeys.minimumClockFontSizePixels...PreferenceKeys.maximumClockFontSizePixels
                    )
                    .accessibilityLabel("时钟字号")
                    Text("\(Int(clockFontSizePixels)) px")
                        .monospacedDigit()
                        .frame(width: controlValueWidth, alignment: .trailing)
                }

                HStack {
                    Text("上下位置")
                        .frame(width: controlLabelWidth, alignment: .leading)
                    pixelSlider(
                        value: $clockVerticalOffsetPixels,
                        in: PreferenceKeys.minimumClockVerticalOffsetPixels...PreferenceKeys.maximumClockVerticalOffsetPixels
                    )
                    .accessibilityLabel("时钟上下位置")
                    Text(verticalOffsetDescription)
                        .monospacedDigit()
                        .frame(width: controlValueWidth, alignment: .trailing)
                }

                pixelSpacingControl(
                    title: "左间距",
                    value: $clockLeftPaddingPixels,
                    in: clockHorizontalPaddingBounds
                )

                pixelSpacingControl(
                    title: "右间距",
                    value: $clockRightPaddingPixels,
                    in: clockHorizontalPaddingBounds
                )
            }

            Section("弹窗日历") {
                Toggle("显示日程", isOn: $calendarShowsEvents)

                pixelSpacingControl(
                    title: "日期字号",
                    value: $calendarDayFontSizePixels,
                    in: calendarDayFontSizeBounds
                )

                pixelSpacingControl(
                    title: "上下间距",
                    value: $calendarDayVerticalSpacingPixels,
                    in: calendarDayVerticalSpacingBounds
                )

                pixelSpacingControl(
                    title: "左右间距",
                    value: $calendarDayHorizontalSpacingPixels,
                    in: calendarDayHorizontalSpacingBounds
                )

                HStack {
                    Text("高亮色")
                        .frame(width: controlLabelWidth, alignment: .leading)
                    Spacer()
                    ColorPicker(
                        "高亮色",
                        selection: calendarHighlightColorBinding,
                        supportsOpacity: false
                    )
                    .labelsHidden()

                    Button("跟随系统") {
                        calendarHighlightColor = PreferenceKeys.defaultCalendarHighlightColor
                    }
                    .disabled(
                        calendarHighlightColor == PreferenceKeys.defaultCalendarHighlightColor
                    )
                }
            }
            Section {
                HStack {
                    Spacer()
                    Button("恢复外观默认值", action: restoreDefaults)
                }
            } footer: {
                Text("更改会即时应用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func restoreDefaults() {
        clockFormat = PreferenceKeys.defaultClockFormat
        clockFontSizePixels = PreferenceKeys.defaultClockFontSizePixels
        clockVerticalOffsetPixels = PreferenceKeys.defaultClockVerticalOffsetPixels
        clockLeftPaddingPixels = PreferenceKeys.defaultClockHorizontalPaddingPixels
        clockRightPaddingPixels = PreferenceKeys.defaultClockHorizontalPaddingPixels
        calendarDayFontSizePixels = PreferenceKeys.defaultCalendarDayFontSizePixels
        calendarDayVerticalSpacingPixels =
            PreferenceKeys.defaultCalendarDayVerticalSpacingPixels
        calendarDayHorizontalSpacingPixels =
            PreferenceKeys.defaultCalendarDayHorizontalSpacingPixels
        calendarHighlightColor = PreferenceKeys.defaultCalendarHighlightColor
        calendarShowsEvents = PreferenceKeys.defaultCalendarShowsEvents
    }

    private var verticalOffsetDescription: String {
        let pixels = Int(clockVerticalOffsetPixels)
        if pixels > 0 {
            return "+ \(pixels) px"
        }
        if pixels < 0 {
            return "- \(-pixels) px"
        }
        return "0 px"
    }

    private var clockHorizontalPaddingBounds: ClosedRange<Double> {
        PreferenceKeys.minimumClockHorizontalPaddingPixels ... PreferenceKeys.maximumClockHorizontalPaddingPixels
    }

    private var calendarDayFontSizeBounds: ClosedRange<Double> {
        PreferenceKeys.minimumCalendarDayFontSizePixels ... PreferenceKeys.maximumCalendarDayFontSizePixels
    }

    private var calendarDayVerticalSpacingBounds: ClosedRange<Double> {
        PreferenceKeys.minimumCalendarDayVerticalSpacingPixels ... PreferenceKeys.maximumCalendarDayVerticalSpacingPixels
    }

    private var calendarDayHorizontalSpacingBounds: ClosedRange<Double> {
        PreferenceKeys.minimumCalendarDayHorizontalSpacingPixels ... PreferenceKeys.maximumCalendarDayHorizontalSpacingPixels
    }

    private var calendarHighlightColorBinding: Binding<Color> {
        Binding(
            get: { CalendarHighlightColor.color(from: calendarHighlightColor) },
            set: { calendarHighlightColor = CalendarHighlightColor.storageValue(from: $0) }
        )
    }

    @ViewBuilder
    private func pixelSlider(value: Binding<Double>, in bounds: ClosedRange<Double>) -> some View {
        Slider(
            value: integerPixelBinding(value),
            in: bounds
        )
    }

    private func integerPixelBinding(_ value: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { value.wrappedValue = $0.rounded() }
        )
    }

    private func pixelSpacingControl(
        title: String,
        value: Binding<Double>,
        in bounds: ClosedRange<Double>
    ) -> some View {
        HStack {
            Text(title)
                .frame(width: controlLabelWidth, alignment: .leading)
            pixelSlider(
                value: value,
                in: bounds
            )
            .accessibilityLabel(title)
            Text("\(Int(value.wrappedValue)) px")
                .monospacedDigit()
                .frame(width: controlValueWidth, alignment: .trailing)
        }
    }
}
