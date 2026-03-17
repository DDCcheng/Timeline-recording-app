// Superbrain/App/SuperbrainApp.swift
import SwiftUI
import SwiftData

@main
struct SuperbrainApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([Note.self, NoteImage.self, Tag.self, EditRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            Text("Models loaded")
                .modelContainer(modelContainer)
        }
    }
}
