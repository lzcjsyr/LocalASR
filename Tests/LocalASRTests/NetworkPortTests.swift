import XCTest
@testable import LocalASR

final class NetworkPortTests: XCTestCase {
    func testEphemeralLoopbackPortAllocation() throws {
        let port = try LocalPortAllocator.allocateLoopbackPort()
        XCTAssertGreaterThan(port, 0)
    }
}
