// Superbrain/Views/Timeline/TimelineView.swift
import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appearance: AppearanceManager

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var selectedTags: Set<String> = []
    @State private var showCompose = false
    @State private var showSearchOverlay = false
    @State private var showExport = false

    @Query(sort: \Tag.name) private var allTags: [Tag]
    private let imageStorageService = ImageStorageService()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    TagFilterBar(selectedTag: $selectedTag)
                    noteList
                }

                // 浮动 + 按钮
                Button { showCompose = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.primary)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(20)
            }
            .navigationTitle("Superbrain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .searchable(text: $searchText, prompt: "搜索笔记")
            .sheet(isPresented: $showCompose) {
                ComposeView()
            }
            .sheet(isPresented: $showExport) {
                ExportView(
                    filteredNotes: filteredNotes,
                    allNotes: (try? modelContext.fetch(FetchDescriptor<Note>())) ?? []
                )
            }
            .sheet(isPresented: $showSearchOverlay) {
                NavigationStack {
                    SearchOverlayView(
                        startDate: $startDate,
                        endDate: $endDate,
                        selectedTags: $selectedTags,
                        allTagNames: allTags.map(\.name),
                        onClear: { startDate = nil; endDate = nil }
                    )
                    .navigationTitle("筛选")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showSearchOverlay = false }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var noteList: some View {
        let notes = filteredNotes
        if notes.isEmpty {
            ContentUnavailableView(
                "还没有笔记",
                systemImage: "note.text",
                description: Text("点击右下角 + 开始记录")
            )
        } else {
            List {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        NoteCardView(note: note, imageStorageService: imageStorageService)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .onDelete(perform: deleteNotes)
            }
            .listStyle(.plain)
            .navigationDestination(for: Note.self) { note in
                NoteDetailView(note: note, imageStorageService: imageStorageService)
            }
        }
    }

    private var filteredNotes: [Note] {
        let all = (try? modelContext.fetch(
            FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []

        let predicate = PredicateBuilder()
            .withText(searchText)
            .withDateRange(start: startDate, end: endDate)
            .withTags(selectedTags.isEmpty ? (selectedTag.map { [$0] } ?? []) : selectedTags)
            .build()

        guard let nsPredicate = predicate else { return all }
        return all.filter { nsPredicate.evaluate(with: $0) }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showSearchOverlay = true } label: {
                    Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
                }
                Button { showExport = true } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                Divider()
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button { appearance.mode = mode } label: {
                        Label(mode.label, systemImage: modeIcon(mode))
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func modeIcon(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        let notes = filteredNotes
        for index in offsets {
            let note = notes[index]
            imageStorageService.deleteImages(for: note.id)
            for tag in note.tags where tag.notes.count <= 1 {
                modelContext.delete(tag)
            }
            modelContext.delete(note)
        }
        try? modelContext.save()
    }
}
