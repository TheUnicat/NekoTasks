//
//  ContentView.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Root view. TabView with 3 tabs driven by AppTab enum: Tasks, Events (CalendarView), Assistant.
//  TasksView (defined here) queries only tasks (typeRaw==0), displays TaskCards in a LazyVStack,
//  opens ShowTask in a sheet for editing. "+" button creates a new TaskItem outside the model context
//  and only inserts on save (same pattern as CalendarView). Completed tasks are hidden on launch and
//  fade out 5 seconds after being marked complete.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: AppTab = .tasks

    var body: some View {
        TabView(selection: $selectedTab) {
            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(AppTab.tasks)

            CalendarView()
                .tabItem { Label("Events", systemImage: "calendar") }
                .tag(AppTab.calendar)

            AssistantView()
                .tabItem { Label("Assistant", systemImage: "sparkles") }
                .tag(AppTab.assistant)
        }
    }
}

// MARK: - Tasks View

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
                    Button(action: addItem) {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
        }
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

    private func addItem() {
        isCreatingNew = true
        let newTask = TaskItem(title: "")
        editingTask = newTask
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

#Preview {
    ContentView()
        .modelContainer(for: [TaskItem.self, TaskLabel.self], inMemory: true)
}
