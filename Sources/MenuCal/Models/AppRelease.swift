import Foundation

struct AppVersion: Comparable, Equatable, Sendable {
    let displayValue: String
    private let components: [Int]

    init?(_ rawValue: String) {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionValue = trimmedValue.first.map { $0 == "v" || $0 == "V" } == true
            ? String(trimmedValue.dropFirst())
            : trimmedValue
        let rawComponents = versionValue.split(separator: ".", omittingEmptySubsequences: false)

        guard !rawComponents.isEmpty,
              rawComponents.count <= 4,
              rawComponents.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              rawComponents.allSatisfy({ Int($0) != nil }) else {
            return nil
        }

        displayValue = versionValue
        components = rawComponents.compactMap { Int($0) }
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let componentCount = max(lhs.components.count, rhs.components.count)

        for index in 0 ..< componentCount {
            let lhsComponent = index < lhs.components.count ? lhs.components[index] : 0
            let rhsComponent = index < rhs.components.count ? rhs.components[index] : 0

            if lhsComponent != rhsComponent {
                return lhsComponent < rhsComponent
            }
        }

        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

struct AppRelease: Equatable, Sendable {
    let tagName: String
    let version: AppVersion
    let archiveURL: URL
    let checksumURL: URL
}
