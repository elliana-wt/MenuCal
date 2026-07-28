import CryptoKit
import Foundation

enum AppUpdateError: LocalizedError {
    case invalidCurrentVersion
    case releaseUnavailable
    case invalidRelease
    case downloadFailed
    case invalidChecksum
    case checksumMismatch
    case invalidApplication(String)
    case installationLocationNotWritable
    case installationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCurrentVersion:
            return "无法读取当前应用版本。"
        case .releaseUnavailable:
            return "暂时无法获取 GitHub 上的最新版本，请稍后再试。"
        case .invalidRelease:
            return "GitHub 上的最新发布缺少可识别的版本或更新文件。"
        case .downloadFailed:
            return "更新文件下载失败，请检查网络后重试。"
        case .invalidChecksum:
            return "发布中的 SHA-256 校验文件无效。"
        case .checksumMismatch:
            return "更新文件校验失败，已取消安装。"
        case let .invalidApplication(reason):
            return "下载的应用未通过安全检查：\(reason)"
        case .installationLocationNotWritable:
            return "MenuCal 当前所在位置不可写。请先将它移到“应用程序”文件夹后再更新。"
        case let .installationFailed(reason):
            return "无法安装更新：\(reason)"
        }
    }
}

struct AppUpdateService: AppUpdating {
    static let repositoryURL = URL(string: "https://github.com/elliana-wt/MenuCal")!
    static let archiveName = "MenuCal-arm64.zip"
    static let checksumName = "\(archiveName).sha256"
    static let expectedBundleIdentifier = "com.elliana.MenuCal"

    let currentVersion: String

    private let session: URLSession
    private let currentBundleURL: URL

    init(
        bundle: Bundle = .main,
        session: URLSession = .shared
    ) {
        currentVersion =
            bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.0.0"
        currentBundleURL = bundle.bundleURL
        self.session = session
    }

    func latestRelease() async throws -> AppRelease {
        let latestReleaseURL = Self.repositoryURL
            .appending(path: "releases")
            .appending(path: "latest")
        var request = URLRequest(url: latestReleaseURL)
        request.timeoutInterval = 20
        request.setValue("MenuCal/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let resolvedURL = httpResponse.url else {
            throw AppUpdateError.releaseUnavailable
        }

        return try Self.release(from: resolvedURL)
    }

    func install(_ release: AppRelease) async throws {
        guard let installedVersion = AppVersion(currentVersion),
              release.version > installedVersion else {
            throw AppUpdateError.invalidCurrentVersion
        }

        let parentDirectory = currentBundleURL.deletingLastPathComponent()
        guard currentBundleURL.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: parentDirectory.path) else {
            throw AppUpdateError.installationLocationNotWritable
        }

        let stagingDirectory = FileManager.default.temporaryDirectory
            .appending(path: "MenuCalUpdate-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        var helperWasLaunched = false
        defer {
            if !helperWasLaunched {
                try? FileManager.default.removeItem(at: stagingDirectory)
            }
        }

        let checksumData = try await downloadData(from: release.checksumURL)
        let expectedChecksum = try Self.checksum(from: checksumData)
        let archiveURL = stagingDirectory.appending(path: Self.archiveName)
        try await downloadFile(from: release.archiveURL, to: archiveURL)

        let actualChecksum = try Self.sha256(of: archiveURL)
        guard actualChecksum.caseInsensitiveCompare(expectedChecksum) == .orderedSame else {
            throw AppUpdateError.checksumMismatch
        }

        let extractionDirectory = stagingDirectory
            .appending(path: "Extracted", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: extractionDirectory,
            withIntermediateDirectories: false
        )
        try run(
            executable: URL(filePath: "/usr/bin/ditto"),
            arguments: ["-x", "-k", archiveURL.path, extractionDirectory.path]
        )

        let updatedBundleURL = extractionDirectory.appending(
            path: "MenuCal.app",
            directoryHint: .isDirectory
        )
        try validateApplication(at: updatedBundleURL, expectedVersion: release.version)
        try launchInstallerHelper(
            updatedBundleURL: updatedBundleURL,
            stagingDirectory: stagingDirectory
        )
        helperWasLaunched = true
    }

    static func release(from resolvedURL: URL) throws -> AppRelease {
        let components = resolvedURL.pathComponents
        guard resolvedURL.host == "github.com",
              let tagIndex = components.firstIndex(of: "tag"),
              components.indices.contains(tagIndex + 1) else {
            throw AppUpdateError.invalidRelease
        }

        let tagName = components[tagIndex + 1]
        guard let version = AppVersion(tagName) else {
            throw AppUpdateError.invalidRelease
        }

        let downloadBaseURL = repositoryURL
            .appending(path: "releases")
            .appending(path: "download")
            .appending(path: tagName)

        return AppRelease(
            tagName: tagName,
            version: version,
            archiveURL: downloadBaseURL.appending(path: archiveName),
            checksumURL: downloadBaseURL.appending(path: checksumName)
        )
    }

    static func checksum(from data: Data) throws -> String {
        guard let contents = String(data: data, encoding: .utf8),
              let checksum = contents
                .split(whereSeparator: \.isWhitespace)
                .first
                .map(String.init),
              checksum.count == 64,
              checksum.allSatisfy(\.isHexDigit) else {
            throw AppUpdateError.invalidChecksum
        }

        return checksum
    }

    private func downloadData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("MenuCal/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppUpdateError.downloadFailed
        }

        return data
    }

    private func downloadFile(from url: URL, to destinationURL: URL) async throws {
        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        request.setValue("MenuCal/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await session.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppUpdateError.downloadFailed
        }

        do {
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            throw AppUpdateError.downloadFailed
        }
    }

    private static func sha256(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func validateApplication(
        at bundleURL: URL,
        expectedVersion: AppVersion
    ) throws {
        let infoPlistURL = bundleURL.appending(path: "Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: infoPlistURL.path),
              let infoData = try? Data(contentsOf: infoPlistURL),
              let info = try? PropertyListSerialization.propertyList(from: infoData, format: nil),
              let dictionary = info as? [String: Any],
              dictionary["CFBundleIdentifier"] as? String == Self.expectedBundleIdentifier,
              let bundleVersion = dictionary["CFBundleShortVersionString"] as? String,
              AppVersion(bundleVersion) == expectedVersion,
              let executableName = dictionary["CFBundleExecutable"] as? String else {
            throw AppUpdateError.invalidApplication("应用标识或版本不匹配。")
        }

        let executableURL = bundleURL
            .appending(path: "Contents/MacOS")
            .appending(path: executableName)
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw AppUpdateError.invalidApplication("找不到可执行文件。")
        }

        do {
            try run(
                executable: URL(filePath: "/usr/bin/codesign"),
                arguments: ["--verify", "--deep", "--strict", bundleURL.path]
            )
            try run(
                executable: URL(filePath: "/usr/bin/lipo"),
                arguments: [executableURL.path, "-verify_arch", "arm64"]
            )
        } catch {
            throw AppUpdateError.invalidApplication("代码签名或 arm64 架构无效。")
        }
    }

    private func launchInstallerHelper(
        updatedBundleURL: URL,
        stagingDirectory: URL
    ) throws {
        let backupURL = currentBundleURL.deletingLastPathComponent().appending(
            path: ".MenuCal-update-backup-\(UUID().uuidString).app",
            directoryHint: .isDirectory
        )
        let script = """
        set -eu
        old_pid="$1"
        new_app="$2"
        target_app="$3"
        backup_app="$4"
        staging_root="$5"

        [ -n "$new_app" ] && [ -n "$target_app" ] && [ "$target_app" != "/" ]
        [ -d "$new_app" ] && [ -d "$target_app" ] && [ ! -e "$backup_app" ]

        attempts=0
        while /bin/kill -0 "$old_pid" >/dev/null 2>&1; do
          attempts=$((attempts + 1))
          [ "$attempts" -lt 200 ] || exit 1
          /bin/sleep 0.1
        done

        rollback() {
          if [ -e "$backup_app" ]; then
            [ ! -e "$target_app" ] || /bin/rm -rf "$target_app"
            /bin/mv "$backup_app" "$target_app" || true
          fi
          [ ! -d "$target_app" ] || /usr/bin/open -n "$target_app" || true
          /bin/rm -rf "$staging_root"
        }
        trap rollback EXIT HUP INT TERM

        /bin/mv "$target_app" "$backup_app"
        /bin/mv "$new_app" "$target_app"
        /usr/bin/open -n "$target_app"

        attempts=0
        until /usr/bin/pgrep -x MenuCal >/dev/null 2>&1; do
          attempts=$((attempts + 1))
          [ "$attempts" -lt 50 ] || exit 1
          /bin/sleep 0.1
        done

        trap - EXIT HUP INT TERM
        /bin/rm -rf "$backup_app" "$staging_root"
        """

        let helper = Process()
        helper.executableURL = URL(filePath: "/bin/sh")
        helper.arguments = [
            "-c",
            script,
            "MenuCalUpdater",
            String(ProcessInfo.processInfo.processIdentifier),
            updatedBundleURL.path,
            currentBundleURL.path,
            backupURL.path,
            stagingDirectory.path
        ]
        helper.standardInput = FileHandle.nullDevice
        helper.standardOutput = FileHandle.nullDevice
        helper.standardError = FileHandle.nullDevice

        do {
            try helper.run()
        } catch {
            throw AppUpdateError.installationFailed(error.localizedDescription)
        }
    }

    private func run(executable: URL, arguments: [String]) throws {
        let process = Process()
        let standardError = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = standardError

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw AppUpdateError.installationFailed(error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AppUpdateError.installationFailed(
                message?.isEmpty == false ? message! : "系统命令执行失败。"
            )
        }
    }
}
