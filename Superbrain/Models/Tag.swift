// Superbrain/Models/Tag.swift
import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var name: String = ""
    var createdAt: Date = Date()

    @Relationship(inverse: \Note.tags)
    var notes: [Note] = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
