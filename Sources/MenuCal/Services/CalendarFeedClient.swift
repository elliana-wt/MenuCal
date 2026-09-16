import Foundation

struct CalendarFeedClient: Sendable {
    func fetch(_ url: URL) async throws -> String {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("text/calendar", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw SubscriptionError.downloadFailed
        }
        let limit = 10 * 1024 * 1024
        guard response.expectedContentLength <= limit else { throw SubscriptionError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw SubscriptionError.tooLarge }
            data.append(byte)
        }
        guard let text = String(data: data, encoding: .utf8) else { throw SubscriptionError.invalidCalendar }
        return text
    }
}
