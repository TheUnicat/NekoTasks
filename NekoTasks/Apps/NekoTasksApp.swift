//
//  NekoTasksApp.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  App entry point. Sets up SwiftData ModelContainer (TaskItem + TaskLabel, persistent).
//  Requests notification permissions on launch. Uses NotificationManager as the single delegate
//  for both foreground presentation and action handling (Complete/Snooze).
//  Body just renders ContentView inside a WindowGroup with the shared container.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct NekoTasksApp: App {
    @State private var calendarState = CalendarState()
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            TaskLabel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        NotificationHelper.requestAuthorization()
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(calendarState)
        .modelContainer(sharedModelContainer)
    }
}

