//
//  TaskLabel.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  ── PURPOSE ──
//  SwiftData model for tags/categories that can be attached to tasks and events.
//
//  ── PROPERTIES ──
//  • `name` (String) — Display name shown in chips, pickers, and settings.
//  • `colorHex` (String?) — Optional hex color string (e.g. "FF5733"). Parsed via
//    `Color(hex:)` extension in TaskRow.swift. Falls back to `.blue` when nil.
//
//  ── USAGE ──
//  • Stored in `TaskItem.labels` (many-to-many relationship managed by SwiftData).
//  • Displayed as chips via `LabelChips` / `LabelChip` (TaskRow.swift).
//  • The first label's colorHex drives the PriorityBorder left-edge color on TaskRow.
//  • Managed in Settings → Labels section (SettingsView.swift → LabelEditorPopup.swift).
//  • Assigned to tasks/events via `LabelFlowPicker` (LabelPickerRow.swift) inside ShowTask.
//  • Used for filtering events in CalendarView via `EventFilter.labelIDs`.
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
