//
//  TaskItem.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Core SwiftData model. Serves dual purpose: tasks (typeRaw=0) and events (typeRaw=1).
//  Key fields: title, taskDescription, deadline, timeEstimate, importance, labels, locationName,
//  isCompleted, startTime/endTime (events), recurrence + recurrenceRuleString (JSON-encoded AnyRule).
//  Has self-referential subtask relationship (cascade delete). parent: TaskItem? for nesting.
//  ItemType enum: .task=0, .event=1. Computed type/recurrenceRule properties for convenience.
//

import SwiftData
import SwiftUI

@Model
final class TaskItem {
    var creationDate: Date
    var deadline: Date?
    var title: String
    var labels: [TaskLabel]
    var importance: Int?
    var taskDescription: String?
    var isCompleted: Bool
    var timeEstimate: TimeInterval?
    var locationName: String?
    var sortOrder: Int = 0

    // Event-specific properties
    var startTime: Date?
    var endTime: Date?
    var typeRaw: Int
    var recurrence: Bool
    var recurrenceRuleString: String?

    // Self-referential relationship for subtasks
    @Relationship(deleteRule: .cascade)
    var subTasks: [TaskItem] = []

    var parent: TaskItem?

    var type: ItemType {
        get { ItemType(rawValue: typeRaw) ?? .task }
        set { typeRaw = newValue.rawValue }
    }

    var recurrenceRule: AnyRule? {
        get {
            guard let string = recurrenceRuleString,
                  let data = string.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(AnyRule.self, from: data)
        }
        set {
            recurrenceRuleString = newValue?.toJSON()
        }
    }

    init(title: String, taskDescription: String? = nil, type: ItemType = .task, deadline: Date? = nil) {
        self.title = title
        self.taskDescription = taskDescription
        self.creationDate = Date()
        self.labels = []
        self.isCompleted = false
        self.typeRaw = type.rawValue
        self.recurrence = false
        self.deadline = deadline
    }
}

// MARK: - Item Type

enum ItemType: Int, Codable {
    case task = 0
    case event = 1
}
