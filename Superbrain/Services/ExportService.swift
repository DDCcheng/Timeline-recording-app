// Superbrain/Services/ExportService.swift
import Foundation
import ZIPFoundation

enum ExportService {
    struct NoteDTO: Codable {
        let id: String
        let content: String
        let createdAt: String
        let updatedAt: String
        let tags: [String]
        let images: [String]    // 图片文件名
    }

    static func toDTO(note: Note) -> NoteDTO {
        let fmt = ISO8601DateFormatter()
        return NoteDTO(
            id: note.id.uuidString,
            content: note.content,
            createdAt: fmt.string(from: note.createdAt),
            updatedAt: fmt.string(from: note.updatedAt),
            tags: note.tags.map(\.name).sorted(),
            images: note.images.sorted(by: { $0.order < $1.order }).map(\.fileName)
        )
    }

    static func exportJSON(notes: [Note]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(notes.map { toDTO(note: $0) })
    }

    static func exportMarkdownZip(notes: [Note], imageService: ImageStorageService) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("superbrain-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]

        for note in notes.sorted(by: { $0.createdAt < $1.createdAt }) {
            let dateStr = fmt.string(from: note.createdAt)
            let idPrefix = String(note.id.uuidString.prefix(8))
            var md = note.content + "\n\n"
            if !note.tags.isEmpty {
                md += "**Tags:** " + note.tags.map { "#\($0.name)" }.joined(separator: " ") + "\n"
            }
            md += "**Created:** \(note.createdAt.formatted())\n"

            // 复制图片
            let sortedImages = note.images.sorted(by: { $0.order < $1.order })
            for img in sortedImages {
                let noteImgDir = tmp.appendingPathComponent("images")
                    .appendingPathComponent(note.id.uuidString)
                try? FileManager.default.createDirectory(at: noteImgDir, withIntermediateDirectories: true)
                if let ui = imageService.load(imageID: img.id, noteID: note.id),
                   let data = ui.jpegData(compressionQuality: 0.8) {
                    try? data.write(to: noteImgDir.appendingPathComponent(img.fileName))
                    md += "![\(img.fileName)](images/\(note.id.uuidString)/\(img.fileName))\n"
                }
            }

            let mdURL = tmp.appendingPathComponent("\(dateStr)-\(idPrefix).md")
            try md.write(to: mdURL, atomically: true, encoding: .utf8)
        }

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("superbrain-\(UUID().uuidString).zip")
        try FileManager.default.zipItem(at: tmp, to: zipURL)
        try? FileManager.default.removeItem(at: tmp)
        return zipURL
    }
}
