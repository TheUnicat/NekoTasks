//
//  LabelAttacher.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Shared helper used by CreateTaskTool and CreateEventTool.
//  Parses a comma-separated label string, finds existing TaskLabel records by name
//  (case-insensitive), creates new ones for names that don't exist yet, and appends
//  them to the item.
//

import SwiftData

/// Finds existing labels by name (case-insensitive) or creates new ones, and attaches them to a task/event.
@MainActor
func attachLabels(_ labelString: String?, to item: TaskItem, in modelContext: ModelContext) {
    guard let labelString, !labelString.trimmingCharacters(in: .whitespaces).isEmpty else { return }

    let names = labelString.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    guard !names.isEmpty else { return }

    let existing = (try? modelContext.fetch(FetchDescriptor<TaskLabel>())) ?? []
    var byName: [String: TaskLabel] = [:]
    for label in existing {
        byName[label.name.lowercased()] = label
    }

    for name in names {
        let key = name.lowercased()
        if let label = byName[key] {
            item.labels.append(label)
        } else {
            let newLabel = TaskLabel(name: name)
            modelContext.insert(newLabel)
            byName[key] = newLabel
            item.labels.append(newLabel)
        }
    }
}
