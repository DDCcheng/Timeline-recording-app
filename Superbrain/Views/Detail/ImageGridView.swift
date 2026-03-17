// Superbrain/Views/Detail/ImageGridView.swift
import SwiftUI

/// 自适应图片网格：1张全宽 / 2张各半宽 / 3-4张 2列网格
/// NoteCardView 和 NoteDetailView 共同复用
struct ImageGridView: View {
    let images: [UIImage]
    var maxHeight: CGFloat = 200

    var body: some View {
        switch images.count {
        case 1:
            singleImage(images[0])
        case 2:
            HStack(spacing: 2) {
                imageCell(images[0])
                imageCell(images[1])
            }
            .frame(height: maxHeight)
        case 3, 4:
            let rows = images.chunked(into: 2)
            VStack(spacing: 2) {
                ForEach(rows.indices, id: \.self) { i in
                    HStack(spacing: 2) {
                        ForEach(rows[i], id: \.self) { img in
                            imageCell(img)
                        }
                    }
                }
            }
            .frame(maxHeight: maxHeight * CGFloat((images.count + 1) / 2))
        default:
            EmptyView()
        }
    }

    private func singleImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: maxHeight)
            .clipped()
            .cornerRadius(8)
    }

    private func imageCell(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(6)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
