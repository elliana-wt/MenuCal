import Foundation
import Testing
@testable import MenuCal

@MainActor
struct CalendarSubscriptionStoreTests {
    @Test func addPersistDisableDeleteAndDuplicate() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("MenuCalTests-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let stub = FeedStub()
        let store = CalendarSubscriptionStore(storageURL: file, fetch: { try await stub.fetch($0) })
        try await store.add(title: "", address: "webcal://example.com/test.ics")
        let subscription = try #require(store.subscriptions.last)
        #expect(subscription.title == "测试订阅")
        #expect(store.lastUpdated(subscription.id) != nil)
        do {
            try await store.add(title: "重复", address: "https://example.com/test.ics")
            Issue.record("Duplicate subscription accepted")
        } catch { #expect(error is SubscriptionError) }
        let reloaded = CalendarSubscriptionStore(storageURL: file, fetch: { try await stub.fetch($0) })
        #expect(reloaded.subscriptions == store.subscriptions)
        let range = DateInterval(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 2_000_000_000))
        #expect(await reloaded.events(in: range).count == 1)
        reloaded.setEnabled(false, id: subscription.id)
        #expect(await reloaded.events(in: range).isEmpty)
        reloaded.remove(id: subscription.id)
        let removed = CalendarSubscriptionStore(storageURL: file)
        #expect(removed.subscriptions.count == 1)
        #expect(removed.lastUpdated(subscription.id) == nil)
    }

    @Test func failedRefreshPreservesCacheAndReportsFailure() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("MenuCalTests-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let stub = FeedStub()
        let store = CalendarSubscriptionStore(storageURL: file, fetch: { try await stub.fetch($0) })
        try await store.add(title: "测试", address: "https://example.com/test.ics")
        let id = try #require(store.subscriptions.last?.id)
        let previousUpdate = store.lastUpdated(id)
        await store.refresh(id: id)
        #expect(await stub.calls == 1)
        await stub.setFailed()
        await store.refresh(id: id, force: true)
        #expect(store.errors[id] != nil)
        #expect(store.lastUpdated(id) == previousUpdate)
        #expect(store.refreshing.isEmpty)
        let range = DateInterval(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 2_000_000_000))
        #expect(await store.events(in: range).count == 1)
    }

    @Test func holidayAnnotationSpaceIsIndependentOfEventList() {
        let base = CalendarLayoutMetrics.popoverHeight(verticalSpacingPixels: 0, showsEvents: false)
        let annotated = CalendarLayoutMetrics.popoverHeight(verticalSpacingPixels: 0, showsEvents: false, showsDayAnnotations: true)
        #expect(annotated - base == 96)
    }
}

private actor FeedStub {
    var calls = 0
    var failed = false
    func setFailed() { failed = true }
    func fetch(_ url: URL) throws -> String {
        calls += 1
        if failed { throw SubscriptionError.downloadFailed }
        return """
        BEGIN:VCALENDAR
        X-WR-CALNAME:测试订阅
        BEGIN:VEVENT
        UID:test
        SUMMARY:会议
        DTSTART:20260916T010000Z
        DTEND:20260916T020000Z
        END:VEVENT
        END:VCALENDAR
        """
    }
}
