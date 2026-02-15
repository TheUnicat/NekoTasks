//
//  SettingsView.swift
//  NekoTasks
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                LabelSettingsSection()
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Label Settings Section

private struct LabelSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var labels: [TaskLabel]
    @State private var isExpanded = true
    @State private var showingAddLabel = false
    @State private var editingLabel: TaskLabel?

    var body: some View {
        Section {
            DisclosureGroup("Labels", isExpanded: $isExpanded) {
                ForEach(labels) { label in
                    LabelRow(label: label) {
                        editingLabel = label
                    }
                }
                .onDelete(perform: deleteLabels)

                Button {
                    showingAddLabel = true
                } label: {
                    Label("Add Label", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }
        }
        .sheet(isPresented: $showingAddLabel) {
            LabelEditorPopup(
                onCancel: { showingAddLabel = false },
                onSave: { showingAddLabel = false }
            )
        }
        .sheet(item: $editingLabel) { label in
            LabelEditorPopup(
                existingLabel: label,
                onCancel: { editingLabel = nil },
                onSave: { editingLabel = nil }
            )
        }
    }

    private func deleteLabels(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(labels[index])
        }
    }
}

// MARK: - Label Row

private struct LabelRow: View {
    let label: TaskLabel
    var onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                Circle()
                    .fill(labelColor)
                    .frame(width: 12, height: 12)

                Text(label.name)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var labelColor: Color {
        if let hex = label.colorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [TaskItem.self, TaskLabel.self], inMemory: true)
}
