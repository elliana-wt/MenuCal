import Foundation

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var authorization: CalendarAuthorization
    @Published private(set) var events: [CalendarEventSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let provider: any EventProviding
    private var selectedDate = Date()
    private var calendar = Calendar.autoupdatingCurrent

    init(provider: any EventProviding) {
        self.provider = provider
        authorization = provider.authorizationStatus
        provider.onEventsChanged = { [weak self] in
            self?.refreshCurrentDate()
        }
    }

    func refresh(for date: Date, calendar: Calendar = .autoupdatingCurrent) {
        selectedDate = date
        self.calendar = calendar
        refreshCurrentDate()
    }

    func requestAccess(for date: Date, calendar: Calendar = .autoupdatingCurrent) async {
        selectedDate = date
        self.calendar = calendar
        isLoading = true
        let granted = await provider.requestAccess()
        isLoading = false
        authorization = provider.authorizationStatus

        if granted {
            refreshCurrentDate()
        } else {
            events = []
            if authorization == .notDetermined {
                errorMessage = "日历权限请求没有完成，请稍后重试。"
            }
        }
    }

    private func refreshCurrentDate() {
        authorization = provider.authorizationStatus
        guard authorization == .fullAccess else {
            events = []
            return
        }

        isLoading = true
        events = provider.events(on: selectedDate, calendar: calendar)
        isLoading = false
    }
}
