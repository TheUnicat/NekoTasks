//
//  AIService.swift
//  NekoTasks
//
//  Created by TheUnicat on 2/8/26.
//
//  CLAUDE NOTES:
//  AI backend using Apple Foundation Models (macOS 26+). Three separate tools (CreateTaskTool,
//  CreateEventTool, CreateLabelTool) as @MainActor final classes conforming to Tool protocol.
//  Tools insert directly into SwiftData via a global ToolExecutionContext (set by AssistantView
//  before each AI call). AIService manages a persistent LanguageModelSession with all three tools.
//  ChatMessage struct for conversation display. resetSession() creates a fresh session.
//
//  KNOWN ISSUES / LESSONS:
//  - The on-device 3B model is unreliable with tool calling. System instructions must be very directive.
//  - Tool arguments must be as simple as possible. Use String? for optional fields.
//  - Events MUST have startTime set or they won't appear in CalendarView.
//  - Always explicit modelContext.save() after tool insertions from async contexts.
//

import Foundation
import SwiftData
import FoundationModels

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user
        case assistant
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tool Execution Context

/// Passed to tools via a global so they can access the model context for database operations.
/// Set by AssistantView before each AI call, cleared after.
class ToolExecutionContext {
    let modelContext: ModelContext?
    var createdItems: [String] = []

    init(modelContext: ModelContext?) {
        self.modelContext = modelContext
    }
}

@MainActor
var currentToolContext: ToolExecutionContext?

// MARK: - AI Service

@available(iOS 26, macOS 26, *)
@MainActor
@Observable
class AIService {
    private var session: LanguageModelSession?

    init() {
        resetSession()
    }

    func resetSession() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        let currentDateTime = dateFormatter.string(from: Date())

        let tools: [any Tool] = [
            CreateTaskTool(),
            CreateEventTool(),
            CreateLabelTool()
        ]

        session = LanguageModelSession(tools: tools) {
            """
            You are a helpful assistant for NekoTasks, a task and calendar management app.

            Current date and time: \(currentDateTime)

            You MUST use the appropriate tool whenever the user wants to create, add, make, or schedule \
            any task, event, or label. Always call the tool — never just describe creating an item \
            without actually calling it. Use create_task for to-do items, create_event for calendar \
            events, and create_label for tags/categories.

            For priorities: 1 = low, 2 = medium, 3 = high
            For dates: use ISO8601 format (e.g., 2026-02-15T14:00:00Z)
            For time estimates: use HH:MM format (e.g., 1:30 for 1 hour 30 minutes, 0:45 for 45 minutes)
            For labels: pass comma-separated names to categorize items
            For subtasks: pass a JSON array string of subtask objects, ordered by sequence. Each object \
            can have: title (required), description, deadline (ISO8601), timeEstimate (HH:MM), priority (1-3). \
            Example: [{"title":"Research","timeEstimate":"0:30"},{"title":"Write draft","deadline":"2026-02-20T00:00:00Z","priority":"2"}]. \
            Only use subtasks for tasks, not events.

            Be concise. After creating items, confirm what you created.
            """
        }
    }

    func send(message: String) async throws -> String {
        guard let session else {
            resetSession()
            return try await send(message: message)
        }
        let result = try await session.respond(to: message)
        return result.content
    }
}

// MARK: - Create Task Tool
/* INEXTRICABLY LINKED TO TASKITEM CLASS, MAKE SURE THAT THEY'RE COMPATIBLE*/

@available(iOS 26, macOS 26, *)
@MainActor
final class CreateTaskTool: Tool {
    let name = "create_task"
    let description = "Create a new task. Use this when the user wants to add a task, todo item, or reminder."

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

        @Guide(description: "Comma-separated label names to categorize the task, or nil if none")
        var labels: String?

        @Guide(description: "JSON array of subtask objects, ordered by sequence. Each object: {\"title\":\"...\", \"description\":\"...\", \"deadline\":\"ISO8601\", \"timeEstimate\":\"HH:MM\", \"priority\":\"1-3\"}. Only title is required. Or nil if none.")
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

// MARK: - Create Event Tool

@available(iOS 26, macOS 26, *)
@MainActor
final class CreateEventTool: Tool {
    let name = "create_event"
    let description = "Create a calendar event. Use this when the user wants to schedule something at a specific time."

    @Generable
    struct Arguments {
        @Guide(description: "The title of the event")
        var title: String

        @Guide(description: "Start time in ISO8601 format (e.g., 2026-02-15T14:00:00Z)")
        var startTime: String?

        @Guide(description: "End time in ISO8601 format")
        var endTime: String?

        @Guide(description: "Optional location name")
        var location: String?

        @Guide(description: "Optional notes or description")
        var eventDescription: String?

        @Guide(description: "Comma-separated label names to categorize the event, or nil if none")
        var labels: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let context = currentToolContext ?? ToolExecutionContext(modelContext: nil)

        let event = TaskItem(title: arguments.title, type: .event)

        // Parse start time, default to 9 AM today if missing/invalid
        let cal = Calendar.current
        if let startStr = arguments.startTime,
           let parsed = ISO8601DateFormatter().date(from: startStr) {
            event.startTime = parsed
        } else {
            event.startTime = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
        }

        // Parse end time, default to start + 1 hour
        if let endStr = arguments.endTime,
           let parsed = ISO8601DateFormatter().date(from: endStr) {
            event.endTime = parsed
        } else if let start = event.startTime {
            event.endTime = start.addingTimeInterval(3600)
        }

        if let desc = arguments.eventDescription {
            event.taskDescription = desc
        }

        if let location = arguments.location {
            event.locationName = location
        }

        if let modelContext = context.modelContext {
            attachLabels(arguments.labels, to: event, in: modelContext)
            modelContext.insert(event)
            context.createdItems.append("event: \(arguments.title)")
            return "Created event '\(arguments.title)'"
        }
        return "Created event '\(arguments.title)' (not persisted)"
    }
}

// MARK: - Create Label Tool

@available(iOS 26, macOS 26, *)
@MainActor
final class CreateLabelTool: Tool {
    let name = "create_label"
    let description = "Create a label/tag for organizing tasks and events."

    @Generable
    struct Arguments {
        @Guide(description: "The name of the label")
        var name: String

        @Guide(description: "Color name", .anyOf(["red", "orange", "yellow", "green", "teal", "blue", "indigo", "purple", "pink", "gray"]))
        var color: String?
    }

    private let colorMap: [String: String] = [
        "red": "E53935", "orange": "FB8C00", "yellow": "FDD835",
        "green": "43A047", "teal": "00897B", "blue": "1E88E5",
        "indigo": "3949AB", "purple": "8E24AA", "pink": "D81B60",
        "gray": "757575"
    ]

    func call(arguments: Arguments) async throws -> String {
        let context = currentToolContext ?? ToolExecutionContext(modelContext: nil)

        let colorHex = arguments.color.flatMap { colorMap[$0.lowercased()] }
        let label = TaskLabel(name: arguments.name, colorHex: colorHex)

        if let modelContext = context.modelContext {
            modelContext.insert(label)
            context.createdItems.append("label: \(arguments.name)")
            return "Created label '\(arguments.name)'"
        }
        return "Created label '\(arguments.name)' (not persisted)"
    }
}

// MARK: - Label Helper

/// Finds existing labels by name (case-insensitive) or creates new ones, and attaches them to a task/event.
@MainActor
private func attachLabels(_ labelString: String?, to item: TaskItem, in modelContext: ModelContext) {
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
