// Superbrain/Views/Timeline/SearchOverlayView.swift
import SwiftUI

struct SearchOverlayView: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var selectedTags: Set<String>
    let allTagNames: [String]
    let onClear: () -> Void

    @State private var tempStart = Date()
    @State private var tempEnd = Date()
    @State private var useStartDate = false
    @State private var useEndDate = false

    var body: some View {
        List {
            Section("日期范围") {
                Toggle("开始日期", isOn: $useStartDate)
                if useStartDate {
                    DatePicker("", selection: $tempStart, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .onChange(of: tempStart) { startDate = tempStart }
                }
                Toggle("结束日期", isOn: $useEndDate)
                if useEndDate {
                    DatePicker("", selection: $tempEnd, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .onChange(of: tempEnd) { endDate = tempEnd }
                }
            }

            Section("标签") {
                ForEach(allTagNames, id: \.self) { name in
                    let isSelected = selectedTags.contains(name)
                    Button {
                        if isSelected { selectedTags.remove(name) }
                        else { selectedTags.insert(name) }
                    } label: {
                        HStack {
                            Text("#\(name)")
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section {
                Button("清除全部筛选", role: .destructive) {
                    useStartDate = false
                    useEndDate = false
                    selectedTags = []
                    onClear()
                }
            }
        }
        .onChange(of: useStartDate) { if !useStartDate { startDate = nil } }
        .onChange(of: useEndDate) { if !useEndDate { endDate = nil } }
    }
}
