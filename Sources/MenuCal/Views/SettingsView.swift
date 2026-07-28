import Foundation
import SwiftUI

@MainActor
struct SettingsView: View {
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
    @StateObject private var loginItemViewModel: LoginItemViewModel

    // MARK: - 排版常量（新增）
    /// 每行标题文字的统一宽度，保证所有滑块从同一条竖线开始
    private let controlLabelWidth: CGFloat = 76
    /// 每行数值文字的统一宽度，兼容最长的 "下 999 px" 这类文本
    private let controlValueWidth: CGFloat = 46

    init(loginItemManager: any LoginItemManaging) {
        _loginItemViewModel = StateObject(
            wrappedValue: LoginItemViewModel(manager: loginItemManager)
        )
    }

    var body: some View {

        VStack(spacing: 0) {
            Form {
                Section("通用") {
                    Toggle(
                        "登录时启动",
                        isOn: Binding(
                            get: { loginItemViewModel.isEnabled },
                            set: { loginItemViewModel.setEnabled($0) }
                        )
                    )

                    if loginItemViewModel.status == .requiresApproval {
                        HStack {
                            Text("需要在系统设置中批准 MenuCal。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("打开登录项设置") {
                                SystemSettingsOpener.openLoginItems()
                            }
                        }
                    }
                }
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

                Section {
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
                } header: {
                    Text("弹窗日历")
                } footer: {
                    HStack {
                        Spacer()
                        Button("恢复默认设置") {
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
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.horizontal, -10)
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: .infinity)
        }
        // 原来是 480x590；加了固定宽度标签后横向更紧凑，先放宽一点，
        // 具体数值建议在 Xcode 预览里边看边调
        .frame(width: 520, height: 635)
        .onAppear {
            loginItemViewModel.refresh()
        }
        .alert(
            "无法更新登录项",
            isPresented: Binding(
                get: { loginItemViewModel.errorMessage != nil },
                set: { if !$0 { loginItemViewModel.errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(loginItemViewModel.errorMessage ?? "")
        }
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
            Text("\(Int(value.wrappedValue)) px")
                .monospacedDigit()
                .frame(width: controlValueWidth, alignment: .trailing)
        }
    }
}

#if DEBUG
@MainActor
private struct PreviewLoginItemManager: LoginItemManaging {
    let status: LoginItemStatus

    func setEnabled(_ enabled: Bool) throws {}
}

private struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            loginItemManager: PreviewLoginItemManager(status: .notRegistered)
        )
        .defaultAppStorage(
            UserDefaults(suiteName: "com.elliana.MenuCal.preview.settings")!
        )
        .previewDisplayName("设置")
    }
}
#endif
