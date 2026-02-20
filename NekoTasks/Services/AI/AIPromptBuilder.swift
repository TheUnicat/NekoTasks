//
//  AIPromptBuilder.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Builds the system prompt string for the AI session. Fetches live labels and tasks
//  from SwiftData when a ModelContext is provided (which happens on first send / after clear).
//  Edit INCLUDE_EXISTING_TASKS to toggle task/event context injection.
//  The on-device 3B model needs very directive instructions — keep language blunt when editing.
//

import Foundation
import SwiftData

// ─── Feature flags ───────────────────────────────────────────────────────────

/// When true, the prompt includes the incomplete task list and the 7-day event calendar.
/// Set to false if the prompt is getting too large or you don't want context injected.
private let INCLUDE_EXISTING_TASKS = true

// ─────────────────────────────────────────────────────────────────────────────

enum AIPromptBuilder {

    static func buildSystemPrompt(currentDate: Date = Date(), modelContext: ModelContext? = nil) -> String {
        let calSection     = buildCalendarSection(from: currentDate)
        let contextSection = buildContextSection(modelContext: modelContext, currentDate: currentDate)
        let contextBlock = contextSection.isEmpty ? "" : """


        ── Current app context ──────────────────────────────────────────────
        \(contextSection)
        ─────────────────────────────────────────────────────────────────────
        """

        return """
        You are a helpful assistant for NekoTasks, a task and calendar management app.

        \(calSection)\(contextBlock)

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

        DUPLICATE DETECTION: Before creating any task or event, compare the request against the \
        existing items listed above. If it looks like a duplicate, ask the user to confirm and name \
        the item you think it matches. Exception: do NOT flag as duplicate if the deadlines differ \
        significantly — that likely means a different instance of a recurring task, not a copy.

        Be concise. After creating items, confirm what you created.
        """
    }

    // MARK: - Calendar section

    private static func buildCalendarSection(from date: Date) -> String {
        let cal = Calendar.current

        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        let todayStr = fullFormatter.string(from: date)

        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "EEE MMM d"
        var upcomingDays: [String] = []
        for i in 1...7 {
            if let day = cal.date(byAdding: .day, value: i, to: date) {
                upcomingDays.append(shortFormatter.string(from: day))
            }
        }

        return """
        Today: \(todayStr)
        Next 7 days: \(upcomingDays.joined(separator: ", "))
        """
    }

    // MARK: - Context section

    private static func buildContextSection(modelContext: ModelContext?, currentDate: Date) -> String {
        guard let modelContext else { return "" }

        var parts: [String] = []

        // Labels
        let labels = (try? modelContext.fetch(FetchDescriptor<TaskLabel>())) ?? []
        if !labels.isEmpty {
            let names = labels.map { $0.name }.sorted().joined(separator: ", ")
            parts.append("Existing labels: \(names)")
        } else {
            parts.append("Existing labels: (none yet)")
        }

        if INCLUDE_EXISTING_TASKS {
            // Fetch once, split by type
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { !$0.isCompleted }
            )
            let all = (try? modelContext.fetch(descriptor)) ?? []
            let topLevel = all.filter { $0.parent == nil }

            if let tasksBlock = buildTasksBlock(from: topLevel) {
                parts.append(tasksBlock)
            }

            let eventsBlock = buildEventsBlock(from: topLevel, currentDate: currentDate)
            parts.append(eventsBlock)
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Incomplete tasks block (sorted by deadline)

    private static func buildTasksBlock(from topLevel: [TaskItem]) -> String? {
        let tasks = topLevel
            .filter { $0.type == .task }
            .sorted {
                switch ($0.deadline, $1.deadline) {
                case let (a?, b?): return a < b
                case (_?, nil):    return true
                default:           return false
                }
            }

        guard !tasks.isEmpty else { return nil }

        var lines = ["Incomplete tasks:"]
        for task in tasks.prefix(40) {
            lines.append(formatTask(task))
        }
        if tasks.count > 40 {
            lines.append("  … and \(tasks.count - 40) more")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 7-day events block (day-by-day, handles recurring)

    private static func buildEventsBlock(from topLevel: [TaskItem], currentDate: Date) -> String {
        let cal = Calendar.current
        let events = topLevel.filter { $0.type == .event }

        let dayLabelFormatter = DateFormatter()
        dayLabelFormatter.dateFormat = "EEEE, MMM d"

        var lines = ["EVENTS – next 7 days:"]

        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: currentDate)) else { continue }

            let dayEvents = events
                .filter { $0.occursOn(date: day) }
                .sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }

            let label: String
            switch offset {
            case 0: label = "Today, \(dayLabelFormatter.string(from: day))"
            case 1: label = "Tomorrow, \(dayLabelFormatter.string(from: day))"
            default: label = dayLabelFormatter.string(from: day)
            }

            if dayEvents.isEmpty {
                lines.append("  \(label): (none)")
            } else {
                let items = dayEvents.map { formatEventInline($0) }.joined(separator: " | ")
                lines.append("  \(label): \(items)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Formatters

    private static let dowDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f
    }()

    private static let timeOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static func priorityName(_ p: Int?) -> String {
        switch p {
        case 3: return "high"
        case 2: return "medium"
        case 1: return "low"
        default: return "none"
        }
    }

    /// Multi-line format used in the task list.
    private static func formatTask(_ task: TaskItem) -> String {
        var details: [String] = []

        if let deadline = task.deadline {
            details.append("due \(dowDateFormatter.string(from: deadline))")
        } else {
            details.append("no deadline")
        }

        if let p = task.importance {
            details.append("priority: \(priorityName(p))")
        }

        if !task.labels.isEmpty {
            details.append("labels: \(task.labels.map { $0.name }.joined(separator: ", "))")
        }

        if let est = task.timeEstimate, est > 0 {
            let h = Int(est) / 3600
            let m = (Int(est) % 3600) / 60
            details.append("estimate: \(h):\(String(format: "%02d", m))")
        }

        if !task.subTasks.isEmpty {
            details.append("\(task.subTasks.count) subtask(s)")
        }

        let suffix = details.isEmpty ? "" : " — " + details.joined(separator: ", ")
        return "  • \"\(task.title)\"\(suffix)"
    }

    /// Compact inline format used inside the day-by-day events section.
    private static func formatEventInline(_ event: TaskItem) -> String {
        var parts: [String] = ["\"\(event.title)\""]

        if let start = event.startTime {
            var timeStr = timeOnlyFormatter.string(from: start)
            if let end = event.endTime {
                timeStr += "–\(timeOnlyFormatter.string(from: end))"
            }
            parts.append(timeStr)
        }

        if let loc = event.locationName, !loc.isEmpty {
            parts.append("@ \(loc)")
        }

        if !event.labels.isEmpty {
            parts.append("[\(event.labels.map { $0.name }.joined(separator: ", "))]")
        }

        return parts.joined(separator: " ")
    }
}
