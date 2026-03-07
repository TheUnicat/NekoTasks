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
//  1. Create SchemaV(N).swift with a frozen copy of the current models.
//  2. Add a new SchemaV(N+1) enum here pointing to the live models.
//  3. Add a new MigrationStage to `stages`.
//  4. Update NekoTasksApp.swift to reference the new current schema enum.
//
//  ── V1 → V2 ──
//  TaskLabel gained `tasks: [TaskItem]`, but without @Relationship(inverse:)
//  SwiftData created two independent one-to-many FK columns instead of a
//  many-to-many join table. Migration snapshots associations via UserDefaults.
//
//  ── V2 → V3 ──
//  TaskItem.labels gained @Relationship(inverse: \TaskLabel.tasks), telling
//  SwiftData to pair the relationships and create a proper many-to-many join
//  table. Migration snapshots FK-based associations and restores them to the
//  new join table.
//

import SwiftData
import Foundation

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }
    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    // MARK: V1 → V2

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

            let tasks = try context.fetch(FetchDescriptor<SchemaV2.TaskItem>())
            let labels = try context.fetch(FetchDescriptor<SchemaV2.TaskLabel>())

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

    // MARK: V2 → V3

    static let migrateV2toV3 = MigrationStage.custom(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self,
        willMigrate: { context in
            let tasks = try context.fetch(FetchDescriptor<SchemaV2.TaskItem>())
            let formatter = ISO8601DateFormatter()
            var mapping: [String: [String]] = [:]
            for task in tasks where !task.labels.isEmpty {
                let key = formatter.string(from: task.creationDate)
                mapping[key, default: []].append(contentsOf: task.labels.map(\.name))
            }
            UserDefaults.standard.set(mapping, forKey: "nekotasks_v2v3_labels")
        },
        didMigrate: { context in
            guard let mapping = UserDefaults.standard.dictionary(
                forKey: "nekotasks_v2v3_labels"
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
            UserDefaults.standard.removeObject(forKey: "nekotasks_v2v3_labels")
        }
    )
}
