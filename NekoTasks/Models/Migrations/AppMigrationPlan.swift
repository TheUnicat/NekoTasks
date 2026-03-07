//
//  AppMigrationPlan.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Defines all schema versions and the migration stages between them.
//  NekoTasksApp.swift passes AppMigrationPlan to ModelContainer so SwiftData
//  runs the appropriate stage(s) on first launch after a schema change.
//
//  ── ADDING A NEW VERSION ──
//  1. Bump SchemaV2 → SchemaV3 (rename the enum, update versionIdentifier,
//     update models[] if new @Model types were added).
//  2. Create SchemaV(N-1).swift with a frozen copy of the previous models
//     (same rule as SchemaV1: must match the old schema hash exactly).
//  3. Add a new MigrationStage to `stages` — use .lightweight if the change
//     is additive (new optional field, new field with default, new entity);
//     use .custom if the storage structure changes (relationship restructure,
//     type change, rename without @Attribute(.renamingIdentifier)).
//  4. Update NekoTasksApp.swift to reference the new current schema enum.
//
//  ── V1 → V2 ──
//  TaskLabel gained `tasks: [TaskItem]`, converting the TaskItem.labels
//  storage from a one-to-many FK (Z1LABELS on ZTASKLABEL) to a many-to-many
//  join table. Core Data does not automatically carry FK values into the new
//  join table, so we snapshot associations in willMigrate (V1 context, FK
//  still readable via TaskItem.labels traversal) and restore them in
//  didMigrate (V2 context, join table now writable). Snapshot is held in
//  UserDefaults under "nekotasks_v1v2_labels" and removed after restoration.
//

import SwiftData
import Foundation

// MARK: - Current Schema

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [TaskItem.self, TaskLabel.self]
    }
}

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            let tasks = try context.fetch(FetchDescriptor<SchemaV1.TaskItem>())
            let formatter = ISO8601DateFormatter()
            var mapping: [String: [String]] = [:]
            for task in tasks where !task.labels.isEmpty {
                let key = formatter.string(from: task.creationDate)
                mapping[key, default: []].append(contentsOf: task.labels.map(\.name))
            }
            UserDefaults.standard.set(mapping, forKey: "nekotasks_v1v2_labels")
        },
        didMigrate: { context in
            guard let mapping = UserDefaults.standard.dictionary(
                forKey: "nekotasks_v1v2_labels"
            ) as? [String: [String]] else { return }

            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
            let labels = try context.fetch(FetchDescriptor<TaskLabel>())

            let formatter = ISO8601DateFormatter()
            let tasksByDate = Dictionary(grouping: tasks) {
                formatter.string(from: $0.creationDate)
            }
            let labelsByName = Dictionary(
                labels.map { ($0.name, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            for (dateKey, labelNames) in mapping {
                guard let matchedTasks = tasksByDate[dateKey] else { continue }
                for task in matchedTasks {
                    for name in labelNames {
                        guard let label = labelsByName[name] else { continue }
                        guard !task.labels.contains(where: {
                            $0.persistentModelID == label.persistentModelID
                        }) else { continue }
                        task.labels.append(label)
                    }
                }
            }
            try context.save()
            UserDefaults.standard.removeObject(forKey: "nekotasks_v1v2_labels")
        }
    )
}
