//
//  SchemaV3.swift
//  NekoTasks
//
//  Created by Unicat on 3/7/26.
//

import SwiftData
import Foundation

// MARK: - Current Schema

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [TaskItem.self, TaskLabel.self]
    }
}
