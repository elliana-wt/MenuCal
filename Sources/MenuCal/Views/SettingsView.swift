import SwiftUI

@MainActor
struct SettingsView: View {
    @AppStorage(PreferenceKeys.clockFormat) private var clockFormat = PreferenceKeys.defaultClockFormat
    @AppStorage(PreferenceKeys.clockFontSize) private var clockFontSize = PreferenceKeys.defaultClockFontSize
    @StateObject private var loginItemViewModel: LoginItemViewModel

    init(loginItemManager: any LoginItemManaging) {
        _loginItemViewModel = StateObject(
            wrappedValue: LoginItemViewModel(manager: loginItemManager)
        )
    }

    var body: some View {
        Form {
            Section("菜单栏时钟") {
                TextField("格式模板", text: $clockFormat)
                    .textFieldStyle(.roundedBorder)

                Text("使用 DateFormatter 格式，例如 HH:mm:ss、M月d日 E HH:mm。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("字号")
                    Slider(
                        value: $clockFontSize,
                        in: PreferenceKeys.minimumClockFontSize...PreferenceKeys.maximumClockFontSize,
                        step: 1
                    )
                    Text("\(Int(clockFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack {
                        Text("预览")
                        Spacer()
                        Text(ClockFormatter().string(from: context.date, format: clockFormat))
                            .font(.system(size: clockFontSize, weight: .regular, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                }
            }

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

            HStack {
                Spacer()
                Button("恢复默认设置") {
                    clockFormat = PreferenceKeys.defaultClockFormat
                    clockFontSize = PreferenceKeys.defaultClockFontSize
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 330)
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
}
