import AppKit
import Foundation

@MainActor
final class AppUpdateViewModel: ObservableObject {
    struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    enum Activity {
        case idle
        case checking
        case installing
    }

    @Published private(set) var activity: Activity = .idle
    @Published var notice: Notice?

    let currentVersion: String

    private let updater: any AppUpdating
    private var updateTask: Task<Void, Never>?

    init(updater: any AppUpdating) {
        self.updater = updater
        currentVersion = updater.currentVersion
    }

    var isBusy: Bool {
        activity != .idle
    }

    var buttonTitle: String {
        switch activity {
        case .idle:
            return "检查更新"
        case .checking:
            return "正在检查…"
        case .installing:
            return "正在更新…"
        }
    }

    func checkAndInstallUpdate() {
        guard !isBusy else {
            return
        }

        activity = .checking
        updateTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                guard let installedVersion = AppVersion(currentVersion) else {
                    throw AppUpdateError.invalidCurrentVersion
                }

                let release = try await updater.latestRelease()
                guard release.version > installedVersion else {
                    activity = .idle
                    notice = Notice(
                        title: "已是最新版本",
                        message: "当前版本为 v\(currentVersion)。"
                    )
                    return
                }

                activity = .installing
                try await updater.install(release)
                NSApplication.shared.terminate(nil)
            } catch is CancellationError {
                activity = .idle
            } catch {
                activity = .idle
                notice = Notice(
                    title: "更新失败",
                    message: error.localizedDescription
                )
            }
        }
    }
}
