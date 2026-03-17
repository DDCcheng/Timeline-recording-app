// Superbrain/Views/Timeline/TagFilterBar.swift
import SwiftUI
import SwiftData

struct TagFilterBar: View {
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Binding var selectedTag: String?

    var body: some View {
        if !allTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(label: "全部", tagName: nil)
                    ForEach(allTags, id: \.name) { tag in
                        chip(label: "#\(tag.name)", tagName: tag.name)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private func chip(label: String, tagName: String?) -> some View {
        let isSelected = selectedTag == tagName
        Button(action: { selectedTag = isSelected ? nil : tagName }) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.primary : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
