import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskItem> { $0.typeRaw == 0 })
    private var tasks: [TaskItem]
    @State private var editingTask: TaskItem?
    @State private var isCreatingNew = false
    @State private var recentlyCompleted: Set<PersistentIdentifier> = []
    @State private var completionTokens: [PersistentIdentifier: UUID] = [:]

    private var visibleTasks: [TaskItem] {
        tasks.filter { task in
            guard task.parent == nil else { return false }
            if task.isCompleted {
                return recentlyCompleted.contains(task.persistentModelID)
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(visibleTasks) { task in
                        TaskCard(task: task, onToggleComplete: {
                            if task.isCompleted {
                                scheduleHide(task)
                            } else {
                                // User uncompleted — cancel the pending hide
                                completionTokens.removeValue(forKey: task.persistentModelID)
                                recentlyCompleted.remove(task.persistentModelID)
                            }
                        }) {
                            isCreatingNew = false
                            editingTask = task
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: visibleTasks.map(\.persistentModelID))
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreatingNew = true
                        editingTask = TaskItem(title: "")
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
        }
        .taskEditor(editingTask: $editingTask, isCreatingNew: $isCreatingNew)
    }

    private func scheduleHide(_ task: TaskItem) {
        let id = task.persistentModelID
        let token = UUID()
        recentlyCompleted.insert(id)
        completionTokens[id] = token

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            guard completionTokens[id] == token else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                recentlyCompleted.remove(id)
            }
            completionTokens.removeValue(forKey: id)
        }
    }
}
