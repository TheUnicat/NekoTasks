//
//  CreateTaskTool.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  INEXTRICABLY LINKED TO TASKITEM CLASS — if you add/rename TaskItem fields,
//  check if Arguments and call() need updating.
//  Reads currentToolContext (global) to get ModelContext. Supports subtasks as a
//  JSON array string. Uses attachLabels() from LabelAttacher.swift.
//

import Foundation
import SwiftData
import FoundationModels

@available(iOS 26, macOS 26, *)
@MainActor
final class CreateTaskTool: Tool {
    let name = "create_task"
    let description = "Create a new task. Use this when the user wants to add a task or item todo."

    @Generable
    struct Arguments {
        @Guide(description: "The title of the task")
        var title: String

        @Guide(description: "Optional notes or description of the task")
        var taskDescription: String?

        @Guide(description: "Optional deadline in ISO8601 format (e.g., 2026-02-15T14:00:00Z)")
        var deadline: String?

        @Guide(description: "Estimate of time needed to complete the task in HH:MM format")
        var timeEstimate: String?

        @Guide(description: "Priority level: 1 = low, 2 = medium, 3 = high", .anyOf(["1", "2", "3"]))
        var priority: String?

        @Guide(description: "Comma-separated label names to categorize the task. Try to add at least one label to each task/event. You can infer labels. Do not create new labels without the user explicitly asking. Try to minimize number of labels.")
        var labels: String?

        @Guide(description: "JSON array of subtask objects, ordered sequentially. Each object: {\"title\":\"...\", \"description\":\"...\", \"deadline\":\"ISO8601\", \"timeEstimate\":\"HH:MM\", \"priority\":\"1-3\"}. Only title is required.")
        var subtasks: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let context = currentToolContext ?? ToolExecutionContext(modelContext: nil)

        let task = TaskItem(title: arguments.title, type: .task)

        if let desc = arguments.taskDescription {
            task.taskDescription = desc
        }

        if let deadlineStr = arguments.deadline,
           let deadline = ISO8601DateFormatter().date(from: deadlineStr) {
            task.deadline = deadline
        }

        if let timeEstimateStr = arguments.timeEstimate {
            let parts = timeEstimateStr.split(separator: ":").map { String($0) }
            if let hours = Int(parts[0]) {
                var minutes = 0
                if parts.count > 1, let m = Int(parts[1]) {
                    minutes = min(59, max(0, m))
                }
                let total = hours * 3600 + minutes * 60
                if total > 0 {
                    task.timeEstimate = TimeInterval(total)
                }
            }
        }

        if let priorityStr = arguments.priority, let priority = Int(priorityStr) {
            task.importance = priority
        }

        if let modelContext = context.modelContext {
            attachLabels(arguments.labels, to: task, in: modelContext)
            modelContext.insert(task)

            if let subtasksStr = arguments.subtasks,
               let data = subtasksStr.data(using: .utf8),
               let subtaskList = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let isoFormatter = ISO8601DateFormatter()
                for (index, dict) in subtaskList.enumerated() {
                    guard let title = dict["title"] as? String, !title.isEmpty else { continue }
                    let subtask = TaskItem(title: title, type: .task)

                    if let desc = dict["description"] as? String, !desc.isEmpty {
                        subtask.taskDescription = desc
                    }
                    if let deadlineStr = dict["deadline"] as? String,
                       let deadline = isoFormatter.date(from: deadlineStr) {
                        subtask.deadline = deadline
                    }
                    if let estStr = dict["timeEstimate"] as? String {
                        let parts = estStr.split(separator: ":").map { String($0) }
                        if let hours = Int(parts[0]) {
                            var minutes = 0
                            if parts.count > 1, let m = Int(parts[1]) {
                                minutes = min(59, max(0, m))
                            }
                            let total = hours * 3600 + minutes * 60
                            if total > 0 {
                                subtask.timeEstimate = TimeInterval(total)
                            }
                        }
                    }
                    if let priStr = dict["priority"] as? String, let pri = Int(priStr) {
                        subtask.importance = pri
                    }

                    subtask.parent = task
                    subtask.sortOrder = index
                    modelContext.insert(subtask)
                }
            }

            context.createdItems.append("task: \(arguments.title)")
            return "Created task '\(arguments.title)'"
        }
        return "Created task '\(arguments.title)' (not persisted)"
    }
}
