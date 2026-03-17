// Superbrain/Views/Compose/ComposeView.swift
import SwiftUI
import SwiftData
import PhotosUI

struct ComposeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil = 新建模式，non-nil = 编辑模式
    var note: Note? = nil

    private let imageStorageService = ImageStorageService()

    @State private var content = ""
    @State private var selectedTags: [Tag] = []
    @State private var isPreview = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []
    @State private var removedImageIDs: Set<UUID> = []
    @State private var existingImages: [UIImage] = []
    @State private var showImageError = false

    private var remainingSlots: Int {
        let existing = (note?.images.count ?? 0) - removedImageIDs.count
        return max(0, 4 - existing - newImages.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isPreview { previewContent } else { editContent }
            }
            .navigationTitle(note == nil ? "新建笔记" : "编辑笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(isPreview ? "编辑" : "预览") { isPreview.toggle() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") { save() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.bold)
                }
            }
            .alert("图片保存失败", isPresented: $showImageError) {
                Button("好") { dismiss() }
            } message: {
                Text("请检查存储空间后重试")
            }
        }
        .onAppear { loadExistingNote() }
    }

    // MARK: - Edit Mode

    @ViewBuilder
    private var editContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $content)
                    .frame(minHeight: 150)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

                imageSection
                Divider()
                TagInputField(selectedTags: $selectedTags)
                    .padding(.horizontal, 4)
            }
            .padding()
        }
    }

    // MARK: - Preview Mode

    @ViewBuilder
    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                let attributed = (try? AttributedString(markdown: content)) ?? AttributedString(content)
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let allImages = existingImages + newImages
                if !allImages.isEmpty { ImageGridView(images: allImages) }
            }
            .padding()
        }
    }

    // MARK: - Image Section

    @ViewBuilder
    private var imageSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 已有图片（编辑模式）
                ForEach((note?.images ?? []).sorted(by: { $0.order < $1.order }), id: \.id) { img in
                    if !removedImageIDs.contains(img.id) {
                        existingThumbnail(img)
                    }
                }

                // 新选图片
                ForEach(newImages.indices, id: \.self) { i in
                    newThumbnail(at: i)
                }

                // 添加按钮
                if remainingSlots > 0 {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: remainingSlots,
                        matching: .images
                    ) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay(Image(systemName: "plus").foregroundStyle(.secondary))
                    }
                    .onChange(of: pickerItems) { loadPickerItems() }
                }
            }
        }
    }

    private func existingThumbnail(_ img: NoteImage) -> some View {
        let uiImage = note.flatMap { imageStorageService.load(imageID: img.id, noteID: $0.id) }
        return ZStack(alignment: .topTrailing) {
            Group {
                if let ui = uiImage {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Color.secondary.opacity(0.3)
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                }
            }
            .frame(width: 80, height: 80).clipped().cornerRadius(8)

            Button { removedImageIDs.insert(img.id) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(4)
        }
    }

    private func newThumbnail(at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: newImages[index])
                .resizable().scaledToFill()
                .frame(width: 80, height: 80).clipped().cornerRadius(8)

            Button { newImages.remove(at: index) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(4)
        }
    }

    // MARK: - Logic

    private func loadExistingNote() {
        guard let note else { return }
        content = note.content
        selectedTags = note.tags
        existingImages = note.images
            .sorted(by: { $0.order < $1.order })
            .compactMap { imageStorageService.load(imageID: $0.id, noteID: note.id) }
    }

    private func loadPickerItems() {
        Task {
            var loaded: [UIImage] = []
            for item in pickerItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    loaded.append(img)
                }
            }
            await MainActor.run {
                newImages.append(contentsOf: loaded)
                pickerItems = []
            }
        }
    }

    private func save() {
        let targetNote: Note

        if let existing = note {
            // 编辑模式：保存历史快照
            if existing.content != content {
                let record = EditRecord(content: existing.content, note: existing)
                modelContext.insert(record)
                // 超出 20 条时删除最旧的
                let sorted = existing.editHistory.sorted(by: { $0.editedAt < $1.editedAt })
                if sorted.count >= 20, let oldest = sorted.first {
                    modelContext.delete(oldest)
                }
            }
            existing.content = content
            existing.updatedAt = Date()
            existing.tags = selectedTags
            // 删除被移除的图片记录
            for imgID in removedImageIDs {
                if let img = existing.images.first(where: { $0.id == imgID }) {
                    let imgDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("images")
                        .appendingPathComponent(existing.id.uuidString)
                        .appendingPathComponent(img.fileName)
                    try? FileManager.default.removeItem(at: imgDir)
                    modelContext.delete(img)
                }
            }
            targetNote = existing
        } else {
            // 新建模式
            let newNote = Note(content: content)
            newNote.tags = selectedTags
            modelContext.insert(newNote)
            targetNote = newNote
        }

        // 保存新图片
        let startOrder = (targetNote.images.map(\.order).max() ?? -1) + 1
        for (i, img) in newImages.enumerated() {
            let noteImage = NoteImage(order: startOrder + i)
            modelContext.insert(noteImage)
            let result = imageStorageService.save(image: img, imageID: noteImage.id, noteID: targetNote.id)
            if case .failure = result {
                showImageError = true
                modelContext.delete(noteImage)
                continue
            }
            targetNote.images.append(noteImage)
        }

        try? modelContext.save()
        if !showImageError {
            dismiss()
        }
    }
}
