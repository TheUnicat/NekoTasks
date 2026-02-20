//
//  AppTab.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Tab enum for ContentView's TabView: .tasks, .calendar, .assistant, .settings.
//  Also defines Notification.Name extensions: .addNewItem (used by CalendarView to receive "add event"
//  broadcasts) and .taskNotificationAction (used by NotificationManager for complete/snooze actions).
//

import Foundation

enum AppTab: Hashable {
    case tasks
    case calendar
    case assistant
    case settings
}

extension Notification.Name {
    static let addNewItem = Notification.Name("addNewItem")
    static let taskNotificationAction = Notification.Name("TaskNotificationAction")
}
