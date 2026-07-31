import Foundation

enum WAVEncoder {
    static func pcm16(samples: [Float], sampleRate: Int = 16_000, channels: Int = 1) -> Data {
        let clamped = samples.map { max(-1, min(1, $0)) }
        var pcm = Data(capacity: clamped.count * 2)
        for sample in clamped {
            let value = Int16(sample * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: value) { pcm.append(contentsOf: $0) }
        }

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        appendUInt32(&data, UInt32(36 + pcm.count))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendUInt32(&data, 16)
        appendUInt16(&data, 1)
        appendUInt16(&data, UInt16(channels))
        appendUInt32(&data, UInt32(sampleRate))
        appendUInt32(&data, UInt32(sampleRate * channels * 2))
        appendUInt16(&data, UInt16(channels * 2))
        appendUInt16(&data, 16)
        data.append(contentsOf: Array("data".utf8))
        appendUInt32(&data, UInt32(pcm.count))
        data.append(pcm)
        return data
    }

    private static func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private static func appendUInt32(_ data: inout Data, _ value: UInt32) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
