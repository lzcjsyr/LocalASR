import XCTest
@testable import LocalASR

final class LLMServiceTests: XCTestCase {
    func testDeepSeekBaseURLBuildsChatCompletionsEndpoint() throws {
        let url = try LLMService.endpointURL(from: "https://api.deepseek.com/")
        XCTAssertEqual(url.absoluteString, "https://api.deepseek.com/chat/completions")
    }

    func testOpenAIStyleVersionedBaseURLIsPreserved() throws {
        let url = try LLMService.endpointURL(from: "https://example.com/v1")
        XCTAssertEqual(url.absoluteString, "https://example.com/v1/chat/completions")
    }

    func testPublicHTTPIsRejectedButLoopbackHTTPIsAllowed() throws {
        XCTAssertThrowsError(try LLMService.endpointURL(from: "http://example.com"))
        let url = try LLMService.endpointURL(from: "http://127.0.0.1:11434/v1")
        XCTAssertEqual(url.absoluteString, "http://127.0.0.1:11434/v1/chat/completions")
    }
}
