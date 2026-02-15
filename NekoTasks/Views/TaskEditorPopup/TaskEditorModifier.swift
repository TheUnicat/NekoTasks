import SwiftUI
import SwiftData

struct TaskEditorModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Binding var editingTask: TaskItem?
    @Binding var isCreatingNew: Bool

    func body(content: Content) -> some View {
        content
            .sheet(item: $editingTask, onDismiss: {
                isCreatingNew = false
            }) { task in
                ShowTask(
                    task: task,
                    onCancel: {
                        editingTask = nil
                        isCreatingNew = false
                    },
                    onSave: {
                        if isCreatingNew {
                            let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else {
                                editingTask = nil
                                isCreatingNew = false
                                return
                            }
                            task.title = trimmed
                            modelContext.insert(task)
                        }
                        editingTask = nil
                        isCreatingNew = false
                    }
                )
            }
    }
}

extension View {
    func taskEditor(editingTask: Binding<TaskItem?>, isCreatingNew: Binding<Bool>) -> some View {
        modifier(TaskEditorModifier(editingTask: editingTask, isCreatingNew: isCreatingNew))
    }
}
