// Superbrain/Models/EditRecord.swift
import Foundation
import SwiftData

@Model
final class EditRecord {
    var id: UUID = UUID()
    var content: String = ""
    var editedAt: Date = Date()
    var note: Note?

    init(content: String, note: Note) {
        self.id = UUID()
        self.content = content
        self.editedAt = Date()
        self.note = note
    }
}
