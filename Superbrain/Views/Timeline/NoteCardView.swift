// Superbrain/Views/Timeline/NoteCardView.swift
import SwiftUI

struct NoteCardView: View {
    let note: Note
    let imageStorageService: ImageStorageService

    @State private var loadedImages: [UIImage] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Markdown 渲染（最多5行截断）
            let attributed = (try? AttributedString(
                markdown: note.content,
                options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace)
            )) ?? AttributedString(note.content)
            Text(attributed)
                .lineLimit(5)

            // 图片网格
            if !loadedImages.isEmpty {
                ImageGridView(images: loadedImages, maxHeight: 160)
            }

            // 标签行
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(note.tags.sorted(by: { $0.name < $1.name }), id: \.name) { tag in
                            Text("#\(tag.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // 时间戳
            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .onAppear { loadImages() }
    }

    private func loadImages() {
        loadedImages = note.images
            .sorted(by: { $0.order < $1.order })
            .compactMap { imageStorageService.load(imageID: $0.id, noteID: note.id) }
    }
}
