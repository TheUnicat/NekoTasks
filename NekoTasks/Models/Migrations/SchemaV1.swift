//
//  SchemaV1.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Frozen snapshot of the schema as it existed before the V1→V2 migration.
//  These model definitions must stay byte-for-byte identical to the original
//  TaskItem / TaskLabel — SwiftData matches the stored schema hash against
//  this definition to determine that existing store data is V1. Changing
//  anything here (adding a property, changing a type, altering a relationship
//  config) will break that hash match and cause the migration to be skipped
//  or to fail.
//
//  DO NOT use these types anywhere in app code. They exist solely for the
//  migration stage in AppMigrationPlan.swift.
//
//  What changed in V2:
//  — TaskLabel gained `tasks: [TaskItem]`, adding the inverse side of the
//    TaskItem.labels relationship. This converts the underlying storage from
//    a one-to-many FK column (Z1LABELS on ZTASKLABEL) to a many-to-many
//    join table, enabling a label to be assigned to multiple tasks/events.
//

import SwiftData
import Foundation

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV1.TaskItem.self, SchemaV1.TaskLabel.self]
    }

    @Model final class TaskItem {
        var creationDate: Date = Date.now
        var deadline: Date?
        var title: String = ""
        var labels: [SchemaV1.TaskLabel] = []
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
        var subTasks: [SchemaV1.TaskItem] = []
        var parent: SchemaV1.TaskItem?

        init() {}
    }

    @Model final class TaskLabel {
        var name: String = ""
        var colorHex: String?
        init() {}
    }
}
