// Superbrain/Views/Compose/TagInputField.swift
import SwiftUI
import SwiftData

struct TagInputField: View {
    @Binding var selectedTags: [Tag]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Environment(\.modelContext) private var modelContext

    @State private var inputText = ""
    @State private var showSuggestions = false

    private var suggestions: [Tag] {
        guard !inputText.isEmpty else { return [] }
        return allTags.filter {
            $0.name.localizedCaseInsensitiveContains(inputText) && !selectedTags.contains($0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 已选标签
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(selectedTags, id: \.name) { tag in
                            HStack(spacing: 3) {
                                Text("#\(tag.name)").font(.subheadline)
                                Button {
                                    selectedTags.removeAll { $0.name == tag.name }
                                } label: {
                                    Image(systemName: "xmark.circle.fill").font(.caption)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // 输入框
            HStack {
                Image(systemName: "tag").foregroundStyle(.secondary)
                TextField("添加标签...", text: $inputText)
                    .autocorrectionDisabled()
                    .onSubmit { confirmTag() }
                    .onChange(of: inputText) { showSuggestions = !inputText.isEmpty }
            }

            // 候选列表
            if showSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.name) { tag in
                        Button { addTag(tag) } label: {
                            Text("#\(tag.name)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .foregroundStyle(.primary)
                        Divider()
                    }
                }
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }

    private func confirmTag() {
        let name = inputText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if let existing = allTags.first(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            addTag(existing)
        } else {
            let newTag = Tag(name: name)
            modelContext.insert(newTag)
            addTag(newTag)
        }
    }

    private func addTag(_ tag: Tag) {
        guard !selectedTags.contains(tag) else { return }
        selectedTags.append(tag)
        inputText = ""
        showSuggestions = false
    }
}
