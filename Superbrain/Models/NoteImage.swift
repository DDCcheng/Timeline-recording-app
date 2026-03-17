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
    /// @Transient 防止 SwiftData 将计算属性纳入 schema 持久化
    @Transient
    var fileName: String { "\(id.uuidString).jpg" }

    init(order: Int) {
        self.id = UUID()
        self.order = order
        self.createdAt = Date()
    }
}
