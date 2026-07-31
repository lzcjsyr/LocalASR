import XCTest
@testable import LocalASR

final class ModelCatalogTests: XCTestCase {
    func testRecommendedModelIsPinnedToHTTPSAndChecksum() {
        let model = try! XCTUnwrap(WhisperModel.catalog.first(where: { $0.recommended }))
        XCTAssertEqual(model.id, "large-v3-turbo-q5_0")
        XCTAssertEqual(model.downloadURL.scheme, "https")
        XCTAssertEqual(model.expectedSHA1.count, 40)
        XCTAssertTrue(model.fileName.hasSuffix(".bin"))
    }

    func testModelNamesAreSafeFileNames() {
        for model in WhisperModel.catalog {
            XCTAssertFalse(model.fileName.contains("/"))
            XCTAssertFalse(model.fileName.contains("\\"))
        }
    }
}
