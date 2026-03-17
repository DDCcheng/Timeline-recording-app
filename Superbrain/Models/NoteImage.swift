// Superbrain/Models/NoteImage.swift
import Foundation
import SwiftData

@Model
final class NoteImage {
    var id: UUID = UUID()
    var order: Int = 0
    var createdAt: Date = Date()
    var note: Note?

    /// 文件名由 id 派生，完整路径：Documents/images/<noteID>/<fileName>
    var fileName: String { "\(id.uuidString).jpg" }

    init(order: Int) {
        self.id = UUID()
        self.order = order
        self.createdAt = Date()
    }
}
