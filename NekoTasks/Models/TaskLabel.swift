//
//  TaskLabel.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Simple SwiftData model for tags/categories. Has name (String) and optional colorHex (String?).
//  Used by TaskItem.labels array. Color parsing happens in TaskRow.swift via Color(hex:) extension.
//  No management UI exists yet — labels must be created programmatically or via AI assistant.
//

import SwiftData
import SwiftUI

@Model
final class TaskLabel: Identifiable {
    var name: String
    var colorHex: String?

    init(name: String, colorHex: String? = nil) {
        self.name = name
        self.colorHex = colorHex
    }
}
