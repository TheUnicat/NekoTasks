//
//  SettingsView.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  App settings screen. Currently contains label management (CRUD for TaskLabels).
//
//  ── ARCHITECTURE ──
//  Sheet state (`editingLabel`, `isCreatingNew`) lives here in SettingsView, NOT in
//  the Section subview. The `.sheet(item:)` is on the NavigationStack — a stable parent
//  that doesn't re-render when @Query updates the label list. This prevents the dismiss
//  flicker that occurs when a sheet is attached to a view that re-renders mid-animation.
//  Same pattern as TasksView / TaskEditorModifier.
//
//  ── COMPONENTS ──
//  • `SettingsView` — Root NavigationStack. Owns sheet state + `.sheet(item:)`.
//  A lot of other stuff is in Settings/Labels
//  ── STATE ──
//  • `editingLabel` — The TaskLabel currently open in the editor sheet, or nil.
//    For new labels, a TaskLabel is created but NOT inserted until save.
//  • `isCreatingNew` — True when editingLabel hasn't been inserted yet.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var editingLabel: TaskLabel?
    @State private var isCreatingNew = false

    var body: some View {
        NavigationStack {
            List {
                LabelSettingsSection(
                    onAdd: {
                        isCreatingNew = true
                        editingLabel = TaskLabel(name: "", colorHex: nil)
                    },
                    onEdit: { label in
                        isCreatingNew = false
                        editingLabel = label
                    }
                )
            }
            .navigationTitle("Settings")
        }
        .sheet(item: $editingLabel, onDismiss: {
            isCreatingNew = false
        }) { label in
            LabelEditorPopup(
                label: label,
                onCancel: {
                    editingLabel = nil
                    isCreatingNew = false
                },
                onSave: {
                    if isCreatingNew {
                        let trimmed = label.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            editingLabel = nil
                            isCreatingNew = false
                            return
                        }
                        label.name = trimmed
                        modelContext.insert(label)
                    }
                    editingLabel = nil
                    isCreatingNew = false
                }
            )
        }
    }
}


#Preview {
    SettingsView()
        .modelContainer(for: [TaskItem.self, TaskLabel.self], inMemory: true)
}
