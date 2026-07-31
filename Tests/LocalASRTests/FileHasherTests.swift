import Foundation
import XCTest
@testable import LocalASR

final class FileHasherTests: XCTestCase {
    func testSHA1MatchesKnownValue() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("localasr-hash-test")
        try Data("abc".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(
            try FileHasher.sha1(of: url),
            "a9993e364706816aba3e25717850c26c9cd0d89d"
        )
    }
}
