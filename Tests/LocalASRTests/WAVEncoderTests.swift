import XCTest
@testable import LocalASR

final class WAVEncoderTests: XCTestCase {
    func testPCM16WAVHeader() throws {
        let data = WAVEncoder.pcm16(samples: Array(repeating: 0, count: 16_000))

        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: data.subdata(in: 8..<12), encoding: .ascii), "WAVE")
        XCTAssertEqual(data.count, 44 + 16_000 * 2)
        XCTAssertEqual(readUInt16(data, offset: 22), 1)
        XCTAssertEqual(readUInt32(data, offset: 24), 16_000)
        XCTAssertEqual(readUInt16(data, offset: 34), 16)
    }

    private func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        data.withUnsafeBytes { pointer in
            pointer.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }

    private func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        data.withUnsafeBytes { pointer in
            pointer.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }
}
