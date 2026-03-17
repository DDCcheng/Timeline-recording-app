// Superbrain/Views/Export/ExportView.swift
import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss

    let filteredNotes: [Note]   // 当前时间线筛选结果
    let allNotes: [Note]        // 全部笔记（从 TimelineView 传入）

    private let imageService = ImageStorageService()

    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case markdown = "Markdown + 图片 (.zip)"
    }

    enum ExportScope: String, CaseIterable {
        case filtered = "当前筛选结果"
        case all = "全部笔记"
    }

    @State private var format: ExportFormat = .json
    @State private var scope: ExportScope = .all
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var shareURL: URL?
    @State private var showShare = false

    private var notesToExport: [Note] {
        scope == .all ? allNotes : filteredNotes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("导出范围") {
                    Picker("范围", selection: $scope) {
                        ForEach(ExportScope.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("导出格式") {
                    Picker("格式", selection: $format) {
                        ForEach(ExportFormat.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Text("将导出 \(notesToExport.count) 条笔记")
                        .foregroundStyle(.secondary)
                }

                if let error = exportError {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: doExport) {
                        if isExporting {
                            HStack {
                                ProgressView().padding(.trailing, 8)
                                Text("导出中...")
                            }
                        } else {
                            Text("开始导出")
                        }
                    }
                    .disabled(isExporting || notesToExport.isEmpty)
                }
            }
            .navigationTitle("导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func doExport() {
        isExporting = true
        exportError = nil
        Task {
            do {
                let url: URL
                switch format {
                case .json:
                    let data = try ExportService.exportJSON(notes: notesToExport)
                    let tmpURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("superbrain-\(Int(Date().timeIntervalSince1970)).json")
                    try data.write(to: tmpURL)
                    url = tmpURL
                case .markdown:
                    url = try ExportService.exportMarkdownZip(notes: notesToExport, imageService: imageService)
                }
                await MainActor.run {
                    shareURL = url
                    showShare = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
