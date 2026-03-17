// Superbrain/Views/Detail/NoteDetailView.swift
import SwiftUI

struct NoteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let note: Note
    let imageStorageService: ImageStorageService

    @State private var showEdit = false
    @State private var showHistory = false
    @State private var showDeleteAlert = false
    @State private var loadedImages: [UIImage] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Markdown 渲染
                let attributed = (try? AttributedString(
                    markdown: note.content,
                    options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace)
                )) ?? AttributedString(note.content)
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 图片
                if !loadedImages.isEmpty {
                    ImageGridView(images: loadedImages, maxHeight: 240)
                }

                // 标签
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(note.tags.sorted(by: { $0.name < $1.name }), id: \.name) { tag in
                                Text("#\(tag.name)")
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // 时间信息
                VStack(alignment: .leading, spacing: 4) {
                    Text("创建于 \(note.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                    if note.updatedAt > note.createdAt {
                        Text("编辑于 \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !note.editHistory.isEmpty {
                    Button { showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                Button { showEdit = true } label: {
                    Image(systemName: "pencil")
                }
                Button { showDeleteAlert = true } label: {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
            }
        }
        .sheet(isPresented: $showEdit) { ComposeView(note: note) }
        .sheet(isPresented: $showHistory) { EditHistoryView(note: note) }
        .alert("删除笔记", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { deleteNote() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销")
        }
        .onAppear { loadImages() }
    }

    private func loadImages() {
        loadedImages = note.images
            .sorted(by: { $0.order < $1.order })
            .compactMap { imageStorageService.load(imageID: $0.id, noteID: note.id) }
    }

    private func deleteNote() {
        imageStorageService.deleteImages(for: note.id)
        for tag in note.tags where tag.notes.count <= 1 {
            modelContext.delete(tag)
        }
        modelContext.delete(note)
        try? modelContext.save()
        dismiss()
    }
}
