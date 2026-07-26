import Foundation

@MainActor
final class LoginItemViewModel: ObservableObject {
    @Published private(set) var status: LoginItemStatus
    @Published var errorMessage: String?

    private let manager: any LoginItemManaging

    init(manager: any LoginItemManaging) {
        self.manager = manager
        status = manager.status
    }

    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    func refresh() {
        status = manager.status
    }

    func setEnabled(_ enabled: Bool) {
        do {
            try manager.setEnabled(enabled)
            status = manager.status
            errorMessage = nil
        } catch {
            status = manager.status
            errorMessage = error.localizedDescription
        }
    }
}
