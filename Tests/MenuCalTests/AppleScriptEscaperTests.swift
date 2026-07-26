import Testing
@testable import MenuCal

struct AppleScriptEscaperTests {
    @Test
    func escapesQuotesBackslashesAndNewlines() {
        let value = "a\"b\\c\nd"

        #expect(AppleScriptEscaper.quotedString(value) == "\"a\\\"b\\\\c d\"")
    }
}
