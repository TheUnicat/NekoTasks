//
//  CreateEventTool.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Reads currentToolContext (global) to get ModelContext.
//  startTime defaults to 9 AM today if missing/invalid.
//  endTime defaults to start + 1 hour if missing/invalid.
//  Events MUST have startTime set or they won't appear in CalendarView.
//  Uses attachLabels() from LabelAttacher.swift.
//

import Foundation
import SwiftData
import FoundationModels

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
