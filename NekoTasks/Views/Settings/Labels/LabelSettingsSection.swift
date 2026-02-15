import SwiftUI
import SwiftData

//  • `LabelSettingsSection` — Expandable section listing all TaskLabels. Calls back
//    to SettingsView to set editingLabel.
// logic in settings/settingsview

// MARK: - Label Settings Section

struct LabelSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var labels: [TaskLabel]
    @State private var isExpanded = true

    var onAdd: () -> Void
    var onEdit: (TaskLabel) -> Void

    var body: some View {
        Section {
            DisclosureGroup("Labels", isExpanded: $isExpanded) {
                ForEach(labels) { label in
                    LabelRow(label: label) {
                        onEdit(label)
                    }
                }
                .onDelete(perform: deleteLabels)

                Button(action: onAdd) {
                    Label("Add Label", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }
        }
    }

    private func deleteLabels(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(labels[index])
        }
    }
}
