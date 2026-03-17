// SuperbrainTests/ImageStorageServiceTests.swift
import XCTest
@testable import Superbrain

final class ImageStorageServiceTests: XCTestCase {
    var sut: ImageStorageService!
    var testNoteID: UUID!

    override func setUp() {
        super.setUp()
        sut = ImageStorageService(baseURL: FileManager.default.temporaryDirectory)
        testNoteID = UUID()
    }

    override func tearDown() {
        sut.deleteImages(for: testNoteID)
        super.tearDown()
    }

    func test_saveAndLoad_roundtrip() {
        let image = UIImage(systemName: "star.fill")!
        let imageID = UUID()

        let result = sut.save(image: image, imageID: imageID, noteID: testNoteID)
        XCTAssertNoThrow(try result.get())

        let loaded = sut.load(imageID: imageID, noteID: testNoteID)
        XCTAssertNotNil(loaded)
    }

    func test_delete_removesDirectory() {
        let image = UIImage(systemName: "star.fill")!
        let imageID = UUID()
        _ = sut.save(image: image, imageID: imageID, noteID: testNoteID)

        sut.deleteImages(for: testNoteID)

        let loaded = sut.load(imageID: imageID, noteID: testNoteID)
        XCTAssertNil(loaded)
    }

    func test_loadMissingFile_returnsNil() {
        let result = sut.load(imageID: UUID(), noteID: testNoteID)
        XCTAssertNil(result)
    }
}
