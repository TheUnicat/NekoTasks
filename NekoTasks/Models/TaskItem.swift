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
    var notificationID: String = UUID().uuidString

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

// MARK: - various extensions, like for filtering tasks or events on a certain day

extension Array where Element == TaskItem {
    func eventsOn(date: Date, filter: EventFilter) -> [TaskItem] {
        let calendar = Calendar.current

        return self
            .filter { event in
                if event.recurrence && !filter.showRecurring { return false }
                if !event.recurrence && !filter.showOneTime { return false }

                if !filter.labelIDs.isEmpty {
                    let ids = Set(event.labels.map { $0.persistentModelID })
                    if ids.isDisjoint(with: filter.labelIDs) { return false }
                }

                return event.occursOn(date: date, calendar: calendar)
            }
            .sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
    }
}

extension TaskItem {
    func occursOn(date: Date, calendar: Calendar = .current) -> Bool {
        if recurrence {
            guard let ruleString = recurrenceRuleString,
                  let data = ruleString.data(using: .utf8),
                  let rule = try? JSONDecoder().decode(AnyRule.self, from: data) else { return false }
            return rule.matches(context: RecurrenceContext(date: date))
        } else {
            if let s = startTime { return calendar.isDate(s, inSameDayAs: date) }
            if let d = deadline { return calendar.isDate(d, inSameDayAs: date) }
            return false
        }
    }
}

// MARK: - Item Type

enum ItemType: Int, Codable {
    case task = 0
    case event = 1
}
