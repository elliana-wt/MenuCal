import AppKit
import SwiftUI

@MainActor
struct GeneralSettingsView: View {
    @ObservedObject var loginItemViewModel: LoginItemViewModel
    @ObservedObject var appUpdateViewModel: AppUpdateViewModel

    var body: some View {
        VStack(spacing: 0) {
            appHeader
                .padding(.horizontal, 20)
                .padding(.top, 28)

            settingsForm
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("© 2026 未境 · Enfinity @Elliana. All rights reserved.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .onAppear { loginItemViewModel.refresh() }
    }

    private var appHeader: some View {
        VStack(spacing: 12) {
            Image(nsImage: appIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            VStack(spacing: 5) {
                Text("MenuCal").font(.title.weight(.semibold))
                Text("一款轻量精美的 Mac 菜单栏日历工具")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var settingsForm: some View {
        Form {
            Section {
                Toggle("登录后自动启动 MenuCal", isOn: Binding(
                    get: { loginItemViewModel.isEnabled },
                    set: { loginItemViewModel.setEnabled($0) }
                ))
                .font(.system(size: 13))
                if loginItemViewModel.status == .requiresApproval {
                    HStack {
                        Text("需要在系统设置中批准 MenuCal。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("打开登录项设置") {
                            SystemSettingsOpener.openLoginItems()
                        }
                        .controlSize(.regular)
                    }
                }
            } header: {
                Text("启动").bold()
            }
            Section {
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
                                .font(.system(size: 13))
                        }
                    }
                    .controlSize(.regular)
                    .disabled(appUpdateViewModel.isBusy)
                }
                .font(.system(size: 13))
            } header: {
                Text("软件更新").bold()
            }
        }
        .formStyle(.grouped)
    }

    private var appIcon: NSImage {
        // Load the compiled icon directly: accessory apps can receive the generic
        // application placeholder from NSApplication.applicationIconImage.
        if let iconFile = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            let name = (iconFile as NSString).deletingPathExtension
            if let url = Bundle.main.url(forResource: name, withExtension: "icns"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return NSApplication.shared.applicationIconImage
    }
}
