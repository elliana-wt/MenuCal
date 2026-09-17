import Foundation

@MainActor
final class CalendarSubscriptionStore: ObservableObject {
    static let shared = CalendarSubscriptionStore()

    @Published private(set) var subscriptions: [CalendarSubscription]
    @Published private(set) var refreshing = Set<UUID>()
    @Published private(set) var errors: [UUID: String] = [:]
    @Published private(set) var revision = 0
    @Published var persistenceError: String?

    private struct CachedFeed: Codable {
        let text: String
        let updatedAt: Date
    }
    private struct SavedState: Codable {
        var subscriptions: [CalendarSubscription]
        var feeds: [UUID: CachedFeed]
    }
    private var feeds: [UUID: CachedFeed]
    private var documents: [UUID: ICalendarDocument] = [:]
    private var lastAttempts: [UUID: Date] = [:]
    private var documentTimeZone = TimeZone.current
    private let storageURL: URL
    private let fetch: @Sendable (URL) async throws -> String

    init(storageURL: URL? = nil, fetch: @escaping @Sendable (URL) async throws -> String = { try await CalendarFeedClient().fetch($0) }) {
        self.storageURL = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MenuCal/CalendarSubscriptions.json")
        self.fetch = fetch
        if let data = try? Data(contentsOf: self.storageURL), let saved = try? JSONDecoder().decode(SavedState.self, from: data) {
            // A saved list may intentionally omit the default holiday subscription.
            subscriptions = saved.subscriptions
            feeds = saved.feeds
        } else {
            subscriptions = [.chinaHolidays]
            feeds = [:]
        }
        for (id, feed) in feeds { documents[id] = try? ICalendarDocument(text: feed.text) }
    }

    var showsHolidays: Bool { subscriptions.first(where: \.isBuiltIn)?.isEnabled == true }
    func lastUpdated(_ id: UUID) -> Date? { feeds[id]?.updatedAt }

    func setEnabled(_ enabled: Bool, id: UUID) {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[index].isEnabled = enabled
        revision += 1
        save()
        if enabled { Task { await refresh(id: id) } }
    }

    func remove(id: UUID) {
        guard subscriptions.contains(where: { $0.id == id }) else { return }
        subscriptions.removeAll { $0.id == id }
        feeds[id] = nil
        documents[id] = nil
        errors[id] = nil
        lastAttempts[id] = nil
        revision += 1
        save()
    }

    func add(title: String, address: String) async throws {
        let url = try CalendarSubscription.normalizedURL(address)
        guard !subscriptions.contains(where: { $0.url == url }) else { throw SubscriptionError.duplicate }
        let text = try await download(url)
        let document = try await Task.detached { try ICalendarDocument(text: text) }.value
        try Task.checkCancellation()
        // Recheck after the network suspension, in case another window added the same URL.
        guard !subscriptions.contains(where: { $0.url == url }) else { throw SubscriptionError.duplicate }
        let enteredTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let subscription = CalendarSubscription(id: UUID(), title: enteredTitle.isEmpty ? document.title ?? url.host ?? "订阅日历" : enteredTitle,
                                                url: url, isEnabled: true, isBuiltIn: false)
        subscriptions.append(subscription)
        feeds[subscription.id] = CachedFeed(text: text, updatedAt: Date())
        documents[subscription.id] = document
        revision += 1
        save()
    }

    func refreshAll(force: Bool = false) async {
        let ids = subscriptions.filter(\.isEnabled).map(\.id)
        await withTaskGroup(of: Void.self) { group in
            for id in ids { group.addTask { await self.refresh(id: id, force: force) } }
        }
    }

    func refresh(id: UUID, force: Bool = false) async {
        guard let subscription = subscriptions.first(where: { $0.id == id }), !refreshing.contains(id) else { return }
        if !force {
            if let updatedAt = feeds[id]?.updatedAt, Date().timeIntervalSince(updatedAt) < 6 * 3600 { return }
            if let attempted = lastAttempts[id], Date().timeIntervalSince(attempted) < 60 { return }
        }
        refreshing.insert(id)
        lastAttempts[id] = Date()
        defer { refreshing.remove(id) }
        do {
            let text = try await download(subscription.url)
            let document = try await Task.detached { try ICalendarDocument(text: text) }.value
            guard subscriptions.contains(where: { $0.id == id }) else { return }
            documents[id] = document
            feeds[id] = CachedFeed(text: text, updatedAt: Date())
            errors[id] = nil
            revision += 1
            save()
        } catch is CancellationError {
            return
        } catch {
            guard subscriptions.contains(where: { $0.id == id }) else { return }
            errors[id] = (error as? SubscriptionError)?.localizedDescription ?? SubscriptionError.downloadFailed.localizedDescription
        }
    }

    func events(in range: DateInterval) async -> [SubscribedCalendarEvent] {
        if documentTimeZone != TimeZone.current {
            documentTimeZone = .current
            for (id, feed) in feeds { documents[id] = try? ICalendarDocument(text: feed.text) }
        }
        let sources = subscriptions.filter(\.isEnabled).compactMap { subscription -> (CalendarSubscription, ICalendarDocument)? in
            guard let document = documents[subscription.id] else { return nil }
            return (subscription, document)
        }
        return await Task.detached(priority: .userInitiated) {
            sources.flatMap { subscription, document in
                document.occurrences(in: range, subscription: subscription)
                    .filter { !$0.isBuiltIn || $0.holidayLabel != nil }
            }
        }.value
    }

    private func download(_ url: URL) async throws -> String {
        do { return try await fetch(url) }
        catch let error as SubscriptionError { throw error }
        catch is CancellationError { throw CancellationError() }
        catch { throw SubscriptionError.downloadFailed }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(SavedState(subscriptions: subscriptions, feeds: feeds))
            try data.write(to: storageURL, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storageURL.path)
            persistenceError = nil
        } catch {
            persistenceError = "无法保存订阅；本次更改在退出后可能丢失，请检查磁盘空间和访问权限。"
        }
    }
}
