import XCTest
@testable import LocalASR

final class AudioPreprocessorTests: XCTestCase {
    func testSilenceProducesNoAudio() {
        XCTAssertNil(AudioPreprocessor.trimSilence(Array(repeating: Float.zero, count: 16_000)))
    }

    func testTrimsSilenceAroundSpeech() {
        var samples = Array(repeating: Float.zero, count: 32_000)
        for index in 12_800..<19_200 {
            samples[index] = Float(sin(Double(index) * 0.18)) * 0.2
        }

        let trimmed = try! XCTUnwrap(AudioPreprocessor.trimSilence(samples))
        XCTAssertLessThan(trimmed.count, samples.count)
        XCTAssertGreaterThan(trimmed.count, 6_400)
        XCTAssertLessThan(trimmed.count, 20_000)
    }

    func testRemovesConsecutiveDuplicateSegments() {
        let first = ServerSegment(start: 0, end: 1, text: "这些东西是什么都不错的", noSpeechProbability: 0.1)
        let duplicate = ServerSegment(start: 1, end: 2, text: "这些东西是什么都不错的", noSpeechProbability: 0.1)
        let next = ServerSegment(start: 2, end: 3, text: "今天继续推进", noSpeechProbability: 0.1)

        let cleaned = TranscriptCleaner.removeConsecutiveDuplicates(from: [first, duplicate, next])

        XCTAssertEqual(cleaned.map(\.text), ["这些东西是什么都不错的", "今天继续推进"])
    }
}
