// Superbrain/Views/Detail/EditHistoryView.swift
import SwiftUI

struct EditHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note

    @State private var selectedRecord: EditRecord?

    private var sortedHistory: [EditRecord] {
        note.editHistory.sorted(by: { $0.editedAt > $1.editedAt })
    }

    var body: some View {
        NavigationStack {
            List(sortedHistory, id: \.id) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.editedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(record.content)
                        .lineLimit(2)
                }
                .onTapGesture { selectedRecord = record }
            }
            .navigationTitle("历史版本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(item: $selectedRecord) { record in
                NavigationStack {
                    ScrollView {
                        let attributed = (try? AttributedString(
                            markdown: record.content,
                            options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace)
                        )) ?? AttributedString(record.content)
                        Text(attributed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .navigationTitle(record.editedAt.formatted(date: .abbreviated, time: .shortened))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { selectedRecord = nil }
                        }
                    }
                }
            }
        }
    }
}

extension EditRecord: Identifiable {}
