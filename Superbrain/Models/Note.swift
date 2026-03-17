// Superbrain/Models/Note.swift
import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \NoteImage.note)
    var images: [NoteImage] = []

    @Relationship
    var tags: [Tag] = []

    @Relationship(deleteRule: .cascade, inverse: \EditRecord.note)
    var editHistory: [EditRecord] = []

    init(content: String = "") {
        self.id = UUID()
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
