//
//  NekoTasksApp.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  App entry point. Sets up SwiftData ModelContainer (TaskItem + TaskLabel, persistent).
//  Requests notification permissions on launch. Sets NotificationDelegate for foreground banners.
//  Body just renders ContentView inside a WindowGroup with the shared container.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct NekoTasksApp: App {
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
        // Ask for notification permission when the app starts
        NotificationHelper.requestAuthorization()

        // Optional: Show notifications while app is in the foreground
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    private override init() {}

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
