import AppKit
import Testing
@testable import MenuCal

@MainActor
struct StatusItemControllerTests {
    @Test
    func dayChangeNotificationCanArriveOffMainActor() async {
        let controller = StatusItemController()

        await Task.detached {
            NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
        }.value
        await Task.yield()

        withExtendedLifetime(controller) {}
    }
}
