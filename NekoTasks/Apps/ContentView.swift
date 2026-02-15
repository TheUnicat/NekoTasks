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

#Preview {
    ContentView()
        .modelContainer(for: [TaskItem.self, TaskLabel.self], inMemory: true)
}
