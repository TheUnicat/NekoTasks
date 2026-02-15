//
//  NotificationHelper.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Simple stateless notification utility (enum with static methods).
//  requestAuthorization() — one-time permission request (called from NekoTasksApp.init).
//  send(title:body:in:) — fire-and-forget notification after a delay (default 1s).
//  For richer notification handling (categories, actions, scheduling), see NotificationManager.
//

import Foundation
import UserNotifications

enum NotificationHelper {
    // Request permission once (e.g., at app start)
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            // Handle result if needed; keeping it minimal
        }
    }

    // Send a simple notification after a short delay
    static func send(title: String, body: String, in seconds: TimeInterval = 1) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
