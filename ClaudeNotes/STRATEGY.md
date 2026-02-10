# NekoTasks — Claude Strategy Notes

## Architecture Overview

**SwiftUI + SwiftData** macOS app (deployment target macOS 14.0, built with SDK 26.2).
Three-tab layout: Tasks, Events (Calendar), Assistant (AI).

### Data Layer
- **SwiftData** with persistent ModelContainer (TaskItem, TaskLabel).
- **TaskItem** is the universal model — `typeRaw` distinguishes tasks (0) from events (1).
- Recurrence rules are stored as JSON strings in `recurrenceRuleString`, deserialized into an `AnyRule` composite enum at runtime.
- Subtasks use a self-referential `@Relationship` with cascade delete.

### Navigation
- **ContentView** is a TabView driven by `AppTab` enum (.tasks, .calendar, .assistant).
- **TasksView** queries only tasks (typeRaw == 0). Uses `ShowTask` for editing.
- **CalendarView** queries only events (typeRaw == 1). Uses `ShowTask` for editing. Has its own date navigator, filter system, and date picker sheet.
- **AssistantView** wraps an `@available` check, delegating to `AssistantContent` on macOS 26+.

### Editor
- **ShowTask** is the primary editor for both tasks and events. It's a Form with a segmented Task/Event picker. Event mode shows start/end times + RecurrenceRulePicker. Task mode shows deadline + time estimate.
- **EditTask / EditTaskSheet** are older, simpler editors (tasks only, no event support). Currently unused by any active view but still in the project. May be candidates for removal.

### AI Layer
- **AIService** manages a `LanguageModelSession` (Apple FoundationModels, macOS 26+).
- Uses tool calling via `AddItemTool` so the on-device LLM can create tasks/events.
- `PendingItemStore` bridges the Tool's call context back to the main thread. Items are drained after each `session.respond()` and inserted into SwiftData by AssistantView.
- `CallAI()` dispatches to `callApple()` based on the `MODEL` global. Designed so additional providers can be added later.
- No conversation persistence — clear button resets the session.

### Notifications
- **NotificationHelper** — simple one-shot permission + send.
- **NotificationManager** — richer: categories with Complete/Snooze actions, stable identifiers per task, calendar-based triggers. Currently configured in NekoTasksApp init via NotificationDelegate.

## Key Patterns
- `@Bindable var task: TaskItem` for two-way binding in editors.
- Local `@State` copies of fields in editors, committed on Save (not live-editing the model).
- `#if os(macOS)` for platform-specific text fields (LeftTextField NSViewRepresentable).
- `@available(iOS 26, macOS 26, *)` gating for FoundationModels code.
- Recurrence rules use composite pattern with operator overloads (&&, ||, !).

## File Inventory

| File | Purpose | Status |
|------|---------|--------|
| NekoTasksApp.swift | Entry point, ModelContainer, notification setup | Stable |
| ContentView.swift | TabView (Tasks/Events/Assistant) + TasksView | Active |
| Models/TaskItem.swift | Core data model (task + event) | Stable |
| Models/TaskLabel.swift | Label/tag model | Stable |
| Models/RecurrenceRule.swift | Recurrence rule engine | Stable |
| Models/AppTab.swift | Tab enum + notification names | Stable |
| Views/ShowTask.swift | Full task/event editor (Form) | Active, primary editor |
| Views/TaskRow.swift | TaskCard display + subcomponents | Active |
| Views/CalendarView.swift | Event calendar + filtering | Active |
| Views/EventCard.swift | Event display card | Active |
| Views/RecurrenceRuleUI.swift | Recurrence rule picker UI | Active |
| Views/AssistantView.swift | AI chat interface | Active |
| Views/EditTask.swift | Old task editor (nav-based) | **Unused** |
| Views/EditTaskSheet.swift | Old task editor (sheet-based) | **Unused** |
| Services/AIService.swift | AI service + tool calling | Active |
| Services/NotificationHelper.swift | Simple notification utility | Active |
| Services/NotificationManager.swift | Rich notification manager | Active |

## Things to Watch
- EditTask.swift and EditTaskSheet.swift are orphaned — nothing references them anymore. Safe to delete when ready.
- ShowTask currently uses text-based date input (MM/DD format) rather than DatePicker. Works but is unconventional.
- The CalendarView creates new events outside the modelContext and only inserts on save — good pattern for cancel-without-saving.
- AI tool calling depends on the on-device model's ability to understand tool schemas. The 3B model is limited — keep tool descriptions very clear and simple.
