# Services/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — This folder contains the AI integration and notification management. The AI stack lives in `AI/` and requires macOS/iOS 26+; its tools insert directly into SwiftData. `NotificationManager` is a singleton with a global delegate — changes here affect background notification handling (Complete/Snooze actions) that runs even when the app is in the background.

---

## Structure

```
Services/
├── AI/                          ← Apple FoundationModels AI stack (macOS/iOS 26+)
│   ├── AIPipeline.swift         ← public @Observable orchestrator; owns provider lifecycle
│   ├── AIPromptBuilder.swift    ← builds the system prompt string
│   ├── ChatMessage.swift        ← display model for chat UI (not persisted)
│   ├── ToolExecutionContext.swift ← mutable context + currentToolContext global
│   ├── Providers/
│   │   ├── AIProvider.swift     ← protocol abstracting the model backend
│   │   └── AppleFoundationProvider.swift ← wraps LanguageModelSession
│   └── Tools/
│       ├── CreateTaskTool.swift
│       ├── CreateEventTool.swift
│       ├── CreateLabelTool.swift
│       └── LabelAttacher.swift  ← shared attachLabels() helper
├── NotificationManager.swift    ← rich notifications with Complete/Snooze action buttons
└── NotificationHelper.swift     ← lightweight fire-and-forget notifications
```

See `AI/Info.md` for full AI stack documentation.

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
  └── AIPipeline.send(message:modelContext:)
        ├── sets/clears currentToolContext (global)
        ├── AppleFoundationProvider → LanguageModelSession → tools
        │     ├── CreateTaskTool → inserts TaskItem
        │     ├── CreateEventTool → inserts TaskItem
        │     └── CreateLabelTool → inserts TaskLabel
        └── saves modelContext if tools created items

NotificationManager
  ├── reads: TaskItem.notificationID
  ├── reads: TaskItem.deadline
  └── posts: Notification.Name.taskNotificationAction (defined in AppTab.swift)
```
