//
//  SchemaV2.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Frozen snapshot of the schema as it existed before the V2→V3 migration.
//  Must stay byte-for-byte identical to the V2 models. Do not modify.
//
//  What changed in V2 (from V1):
//  — TaskLabel gained `tasks: [TaskItem]`, intended as the inverse side.
//    However, without an explicit @Relationship(inverse:) annotation,
//    SwiftData treated them as two independent one-to-many relationships
//    (FK columns Z1LABELS and Z2TASKS) instead of a many-to-many join table.
//
//  What changed in V3:
//  — TaskItem.labels gained @Relationship(inverse: \TaskLabel.tasks),
//    telling SwiftData to pair the relationships and create a proper
//    many-to-many join table.
//

import SwiftData
import Foundation

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV2.TaskItem.self, SchemaV2.TaskLabel.self]
    }

    @Model final class TaskItem {
        var creationDate: Date = Date.now
        var deadline: Date?
        var title: String = ""
        var labels: [SchemaV2.TaskLabel] = []
        var importance: Int?
        var taskDescription: String?
        var isCompleted: Bool = false
        var timeEstimate: TimeInterval?
        var locationName: String?
        var sortOrder: Int = 0
        var notificationID: String = ""
        var startTime: Date?
        var endTime: Date?
        var typeRaw: Int = 0
        var recurrence: Bool = false
        var recurrenceRuleString: String?

        @Relationship(deleteRule: .cascade)
        var subTasks: [SchemaV2.TaskItem] = []
        var parent: SchemaV2.TaskItem?

        init() {}
    }

    @Model final class TaskLabel {
        var name: String = ""
        var colorHex: String?
        var tasks: [SchemaV2.TaskItem] = []
        init() {}
    }
}
