//
//  NotificationManager.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Rich notification manager (singleton). Registers TASK_REMINDER category with "Mark Complete" and
//  "Snooze 15 min" actions. Uses TaskItem.notificationID (stable UUID) for notification identifiers.
//  scheduleReminder() — calendar-based trigger from task deadline.
//  scheduleSnooze() — time-interval trigger (default 15 min).
//  cancelReminder() — removes pending + delivered notifications for a task.
//  UNUserNotificationCenterDelegate: handles foreground presentation + Complete/Snooze actions.
//  configure() must be called once at app launch (from NekoTasksApp.init).
//

import Foundation
import UserNotifications

final class NotificationManager: NSObject {
    static let shared = NotificationManager()
    private override init() {}

    // Call this once at app launch
    func configure() {
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            completion(granted)
        }
    }

    private func registerCategories() {
        let complete = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Complete",
            options: [.authenticationRequired]
        )

        let snooze = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze 15 min",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [complete, snooze],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func identifier(for task: TaskItem) -> String {
        "task-\(task.notificationID)"
    }

    func scheduleReminder(for task: TaskItem) {
        guard !task.isCompleted, let deadline = task.deadline else { return }

        let content = UNMutableNotificationContent()
        content.title = task.title
        if let desc = task.taskDescription {
            content.body = desc
        }
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = [
            "taskIdentifier": identifier(for: task)
        ]

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: deadline)
        // Optional: normalize seconds to zero
        dateComponents.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier(for: task), content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelReminder(for task: TaskItem) {
        let id = identifier(for: task)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }

    func scheduleSnooze(for task: TaskItem, minutes: TimeInterval = 15) {
        let content = UNMutableNotificationContent()
        content.title = task.title
        if let desc = task.taskDescription {
            content.body = desc
        }
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = ["taskIdentifier": identifier(for: task)]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: minutes * 60, repeats: false)
        let request = UNNotificationRequest(identifier: identifier(for: task), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Foreground presentation (optional)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    // Handle actions like Complete / Snooze
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let taskID = userInfo["taskIdentifier"] as? String else { return }

        switch response.actionIdentifier {
        case "COMPLETE_ACTION":
            NotificationCenter.default.post(name: .taskNotificationAction,
                                            object: nil,
                                            userInfo: ["taskIdentifier": taskID, "action": "complete"])
        case "SNOOZE_ACTION":
            NotificationCenter.default.post(name: .taskNotificationAction,
                                            object: nil,
                                            userInfo: ["taskIdentifier": taskID, "action": "snooze"])
        default:
            break
        }
    }
}
