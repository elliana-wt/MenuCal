import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var loginItemViewModel: LoginItemViewModel
    @ObservedObject var appUpdateViewModel: AppUpdateViewModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MenuCal").font(.title.weight(.semibold))
                        Text("抬眼看时间，点开看日程。")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            Section("启动") {
                Toggle("登录后自动启动 MenuCal", isOn: Binding(
                    get: { loginItemViewModel.isEnabled },
                    set: { loginItemViewModel.setEnabled($0) }
                ))
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
            Section("软件更新") {
                HStack(spacing: 12) {
                    Text("当前版本")
                    Spacer()
                    Text("v\(appUpdateViewModel.currentVersion)")
                        .foregroundStyle(.secondary)
                    Button {
                        appUpdateViewModel.checkAndInstallUpdate()
                    } label: {
                        HStack(spacing: 6) {
                            if appUpdateViewModel.isBusy {
                                ProgressView().controlSize(.small)
                            }
                            Text(appUpdateViewModel.buttonTitle)
                        }
                    }
                    .disabled(appUpdateViewModel.isBusy)
                }
            }
            Text("© 2026 未达之境 · Enfinity @Elliana. All rights reserved.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 16)
                .frame(maxWidth: .infinity)
        }
        .formStyle(.grouped)
        .onAppear { loginItemViewModel.refresh() }
    }
}
