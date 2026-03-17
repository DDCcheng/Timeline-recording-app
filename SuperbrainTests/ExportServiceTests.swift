// SuperbrainTests/ExportServiceTests.swift
import XCTest
@testable import Superbrain

final class ExportServiceTests: XCTestCase {
    func test_toDTO_mapsContent() {
        let note = Note(content: "**Hello** world")
        let dto = ExportService.toDTO(note: note)
        XCTAssertEqual(dto.content, "**Hello** world")
        XCTAssertTrue(dto.tags.isEmpty)
        XCTAssertTrue(dto.images.isEmpty)
    }

    func test_exportJSON_producesValidJSON() throws {
        let note = Note(content: "Test note")
        let data = try ExportService.exportJSON(notes: [note])
        let decoded = try JSONDecoder().decode([ExportService.NoteDTO].self, from: data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].content, "Test note")
    }

    func test_exportJSON_multipleNotes() throws {
        let notes = [Note(content: "A"), Note(content: "B")]
        let data = try ExportService.exportJSON(notes: notes)
        let decoded = try JSONDecoder().decode([ExportService.NoteDTO].self, from: data)
        XCTAssertEqual(decoded.count, 2)
    }
}
