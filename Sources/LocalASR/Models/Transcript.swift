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
}
