# Services/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — This folder contains the AI integration and notification management. `AIService` requires macOS/iOS 26+ and uses Apple's on-device FoundationModels. Its tools insert directly into SwiftData. `NotificationManager` is a singleton with a global delegate — changes here affect background notification handling (Complete/Snooze actions) that runs even when the app is in the background.

---

## Files

### `AIService.swift` — Apple FoundationModels AI integration

**Availability:** `@available(iOS 26, macOS 26, *)`. The `AssistantView` wraps this in an availability check and shows a fallback for older OS versions.

**Architecture — how data flows from AI to SwiftData:**

The FoundationModels `Tool` protocol requires tool classes to be independent of SwiftUI/SwiftData environment. To bridge the gap, a **global `currentToolContext: ToolExecutionContext?`** (set by `AssistantView` before each AI call) passes the `ModelContext` into the tools.

1. User sends a message in `AssistantView`
2. `AssistantView` sets `currentToolContext = ToolExecutionContext(modelContext: modelContext)`
3. `AIService.send(message:)` calls `session.respond(to:)` — the model may call one or more tools
4. Each tool's `call(arguments:)` reads `currentToolContext` to get the `ModelContext`, creates items, calls `modelContext.insert()`
5. After `send()` returns, `AssistantView` calls `try? modelContext.save()` if any items were created

**`ChatMessage`** — display model for the chat UI. Fields: `id: UUID`, `role: .user | .assistant`, `content: String`. Only used by `AssistantView`, not persisted to SwiftData.

**`AIService` class:**
- `@Observable`, `@MainActor`
- Holds a `LanguageModelSession` with all three tools registered
- `resetSession()`: Creates a fresh session with the current date/time in the system prompt. Called on init and when the user clears the chat.
- `send(message:) async throws -> String`: Calls `session.respond(to:)`, returns the model's text response.

**The three tools:**

| Tool class | Tool name | Creates |
|---|---|---|
| `CreateTaskTool` | `create_task` | `TaskItem(type: .task)` with optional deadline, time estimate, priority, labels, subtasks |
| `CreateEventTool` | `create_event` | `TaskItem(type: .event)` with startTime (defaults to 9 AM today if missing), endTime (defaults to start+1h), location, labels |
| `CreateLabelTool` | `create_label` | `TaskLabel` with name and optional color (mapped from color name to hex) |

**`attachLabels(_:to:in:)`** — private helper that parses a comma-separated label string, finds existing `TaskLabel` records by name (case-insensitive), creates new ones for names that don't exist yet, and appends them to the item.

**⚠️ Known issues / important constraints:**
- The on-device 3B model is **unreliable with tool calling** — system instructions must be maximally directive. If the model sometimes responds in text instead of calling tools, that's a known model limitation.
- Tool `Arguments` structs must use `String?` for optional fields (not `Date?`, `Int?`) — the on-device model handles simple types most reliably.
- Events **must have `startTime` set** or they won't appear in `CalendarView` (the `occursOn()` check falls back to `startTime`, then `deadline`).
- `CreateTaskTool` is **inextricably linked to `TaskItem`'s fields** (see the large comment in the source). If you add/rename TaskItem fields, check if `CreateTaskTool.Arguments` and `call()` need updating.
- Always call `modelContext.save()` after tool insertions from async contexts — SwiftData does not auto-save in async tool calls.

---

### `NotificationManager.swift` — Rich local notifications with action buttons

**Singleton:** `NotificationManager.shared`. Must call `configure()` once on app launch (done in `NekoTasksApp.init()`).

**What it does:**
- Registers a `TASK_REMINDER` `UNNotificationCategory` with two `UNNotificationAction`s:
  - `"COMPLETE_ACTION"` — "Mark Complete" (foreground)
  - `"SNOOZE_ACTION"` — "Snooze 15 min" (foreground)
- Sets itself as `UNUserNotificationCenter.current().delegate`

**Methods:**
- `requestAuthorization()` — one-time permission request (alert + sound + badge)
- `scheduleReminder(for task: TaskItem)` — schedules a calendar-based trigger from `task.deadline`. Uses `task.notificationID` as the stable identifier. If called again for the same task, it replaces the existing notification.
- `scheduleSnooze(for task: TaskItem, minutes: Int = 15)` — schedules a time-interval trigger. Uses `"\(task.notificationID)_snooze"` as the identifier.
- `cancelReminder(for task: TaskItem)` — removes both the main and snooze notifications (pending + delivered).

**Delegate callbacks:**
- `willPresent`: Allows foreground notification display (banner + sound + badge).
- `didReceive(response:)`: Handles action button taps:
  - `"COMPLETE_ACTION"` → posts `Notification.Name.taskNotificationAction` with `["action": "complete", "notificationID": ...]`
  - `"SNOOZE_ACTION"` → posts `Notification.Name.taskNotificationAction` with `["action": "snooze", ...]`, then calls `scheduleSnooze()`

**⚠️ Warning:** The notification identifier is `task.notificationID` (a stable UUID string set on `TaskItem` creation). Never regenerate `notificationID` for existing tasks — orphaned notifications can't be cancelled.

**`Notification.Name.taskNotificationAction`** is defined in `Apps/AppTab.swift`, not here. Any listener (e.g. a view that marks tasks complete in response to the notification) must observe that name.

---

### `NotificationHelper.swift` — Lightweight fire-and-forget notifications

Stateless `enum` with static methods. Much simpler than `NotificationManager` — use this for simple one-shot alerts, not for task reminders with action buttons.

- `requestAuthorization()` — requests notification permissions (same as `NotificationManager` but standalone)
- `send(title:body:in:)` — fires a notification after a delay (default 1 second). No category, no action buttons, no stable identifier.

**When to use which:**
- `NotificationManager.shared` → Task deadline reminders that need Complete/Snooze action buttons and must be cancellable
- `NotificationHelper` → Simple one-off alerts (e.g. confirming an AI action)

---

## Relationships

```
NekoTasksApp.init()
  ├── NotificationHelper.requestAuthorization()
  └── NotificationManager.shared.configure()
        └── sets UNUserNotificationCenter delegate

AssistantView
  ├── creates: currentToolContext (global)
  ├── calls: AIService.send()
  │     └── LanguageModelSession calls tools
  │           ├── CreateTaskTool → inserts TaskItem
  │           ├── CreateEventTool → inserts TaskItem
  │           └── CreateLabelTool → inserts TaskLabel
  └── saves: modelContext after tools run

NotificationManager
  ├── reads: TaskItem.notificationID
  ├── reads: TaskItem.deadline
  └── posts: Notification.Name.taskNotificationAction (defined in AppTab.swift)
```
