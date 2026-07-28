protocol AppUpdating: Sendable {
    var currentVersion: String { get }

    func latestRelease() async throws -> AppRelease
    func install(_ release: AppRelease) async throws
}
