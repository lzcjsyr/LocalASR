import Foundation

struct TranscriptSegment: Codable, Identifiable, Hashable {
    let id: UUID
    let start: Double
    let end: Double
    let text: String

    init(id: UUID = UUID(), start: Double, end: Double, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }
}

struct TranscriptionResponse: Codable {
    let text: String
    let segments: [ServerSegment]?
}

struct ServerSegment: Codable {
    let start: Double?
    let end: Double?
    let text: String?
    let noSpeechProbability: Double?

    enum CodingKeys: String, CodingKey {
        case start
        case end
        case text
        case noSpeechProbability = "no_speech_prob"
    }
}

enum TranscriptCleaner {
    static func removeConsecutiveDuplicates(from segments: [ServerSegment]) -> [ServerSegment] {
        var cleaned = [ServerSegment]()
        var previousKey: String?

        for segment in segments {
            guard let text = segment.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                continue
            }

            let key = normalized(text)
            if key.count >= 4, key == previousKey {
                continue
            }

            cleaned.append(segment)
            previousKey = key
        }

        return cleaned
    }

    static func normalized(_ text: String) -> String {
        text
            .lowercased()
            .filter { !$0.isWhitespace && !$0.isPunctuation && !$0.isSymbol }
    }
}
