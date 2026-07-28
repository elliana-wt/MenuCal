import Foundation
import Testing
@testable import MenuCal

struct AppUpdateServiceTests {
    @Test
    func comparesSemanticVersionsNumerically() {
        #expect(AppVersion("v1.10.0")! > AppVersion("1.9.9")!)
        #expect(AppVersion("1.0")! == AppVersion("1.0.0")!)
        #expect(AppVersion("not-a-version") == nil)
    }

    @Test
    func createsReleaseAssetURLsFromLatestRedirect() throws {
        let redirectURL = URL(
            string: "https://github.com/elliana-wt/MenuCal/releases/tag/v1.2.3"
        )!

        let release = try AppUpdateService.release(from: redirectURL)

        #expect(release.tagName == "v1.2.3")
        #expect(release.version == AppVersion("1.2.3"))
        #expect(
            release.archiveURL.absoluteString
                == "https://github.com/elliana-wt/MenuCal/releases/download/v1.2.3/MenuCal-arm64.zip"
        )
        #expect(
            release.checksumURL.absoluteString
                == "https://github.com/elliana-wt/MenuCal/releases/download/v1.2.3/MenuCal-arm64.zip.sha256"
        )
    }

    @Test
    func parsesReleaseChecksum() throws {
        let checksum = String(repeating: "a", count: 64)
        let data = Data("\(checksum)  MenuCal-arm64.zip\n".utf8)

        #expect(try AppUpdateService.checksum(from: data) == checksum)
    }
}
