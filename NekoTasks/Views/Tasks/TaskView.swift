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

    // MARK: - Bucketing

    private enum DeadlineBucket: String, CaseIterable {
        case overdue   = "Overdue"
        case today     = "Today"
        case tomorrow  = "Tomorrow"
        case thisWeek  = "This Week"
        case later     = "Later"
        case none      = "No Due Date"
    }

    private func bucket(for task: TaskItem) -> DeadlineBucket {
        guard let deadline = task.deadline else { return .none }
        let cal = Calendar.current
        let now = Date()
        if deadline < cal.startOfDay(for: now) { return .overdue }
        if cal.isDateInToday(deadline)          { return .today }
        if cal.isDateInTomorrow(deadline)       { return .tomorrow }
        if let endOfWeek = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: now)),
           deadline < endOfWeek                 { return .thisWeek }
        return .later
    }

    private var taskSections: [(title: String, tasks: [TaskItem])] {
        let visible = tasks.filter { task in
            guard task.parent == nil else { return false }
            if task.isCompleted {
                return recentlyCompleted.contains(task.persistentModelID)
            }
            return true
        }

        // Group into buckets, preserving defined order
        var grouped: [DeadlineBucket: [TaskItem]] = [:]
        for task in visible {
            let b = bucket(for: task)
            grouped[b, default: []].append(task)
        }

        // Within each bucket sort by deadline (nils last), then creation date
        for key in grouped.keys {
            grouped[key]?.sort {
                switch ($0.deadline, $1.deadline) {
                case let (a?, b?): return a < b
                case (_?, nil):   return true
                default:          return $0.creationDate < $1.creationDate
                }
            }
        }

        return DeadlineBucket.allCases.compactMap { bucket in
            guard let tasks = grouped[bucket], !tasks.isEmpty else { return nil }
            return (title: bucket.rawValue, tasks: tasks)
        }
    }

    // Flat list of visible task IDs for animation tracking
    private var visibleTaskIDs: [PersistentIdentifier] {
        taskSections.flatMap { $0.tasks.map(\.persistentModelID) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(taskSections, id: \.title) { section in
                        Text(section.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.top, 6)

                        ForEach(section.tasks) { task in
                            TaskRow(task: task, onToggleComplete: {
                                if task.isCompleted {
                                    scheduleHide(task)
                                } else {
                                    completionTokens.removeValue(forKey: task.persistentModelID)
                                    recentlyCompleted.remove(task.persistentModelID)
                                }
                            }) {
                                isCreatingNew = false
                                editingTask = task
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: visibleTaskIDs)
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

    // MARK: - Helpers

    private func scheduleHide(_ task: TaskItem) {
        let id = task.persistentModelID
        let token = UUID()
        recentlyCompleted.insert(id)
        completionTokens[id] = token

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            guard completionTokens[id] == token else { return }
            recentlyCompleted.remove(id)
            completionTokens.removeValue(forKey: id)
        }
    }
}
