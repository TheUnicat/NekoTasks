# Services/AI/Tools/

FoundationModels `Tool` implementations. Each tool reads `currentToolContext` (global in `ToolExecutionContext.swift`) to access the SwiftData `ModelContext`.

> ⚠️ Tool `Arguments` structs use `String?` for all optional fields — the on-device 3B model handles simple types most reliably. Do not change to `Date?`, `Int?`, etc.

---

## Files

### `CreateTaskTool.swift`
- Tool name: `create_task`
- Creates `TaskItem(type: .task)`
- Supports: title, description, deadline (natural language via `parseNaturalDate`), timeEstimate (HH:MM), priority (1–3), labels (comma-separated), subtasks (JSON array string)
- **⚠️ Inextricably linked to `TaskItem` fields** — if `TaskItem` gains/loses fields, update `Arguments` and `call()` here

### `CreateEventTool.swift`
- Tool name: `create_event`
- Creates `TaskItem(type: .event)`
- Supports: title, startTime (natural language, defaults to 9 AM today), endTime (defaults to start+1h), location, description, labels
- **⚠️ Events must have `startTime` set** or they won't appear in `CalendarView`

### `CreateLabelTool.swift`
- Tool name: `create_label`
- Creates `TaskLabel` with name and optional color (name → hex via internal `colorMap`)
- Supported colors: red, orange, yellow, green, teal, blue, indigo, purple, pink, gray

### `LabelAttacher.swift`
- `@MainActor func attachLabels(_ labelString: String?, to item: TaskItem, in modelContext: ModelContext)`
- Shared by `CreateTaskTool` and `CreateEventTool`
- Parses comma-separated label names, finds existing `TaskLabel` records (case-insensitive), creates new ones for unknown names, appends all to `item.labels`

### `ParseDateTime.swift`
- `func parseNaturalDate(_ text: String) -> Date?`
- Shared NLP date parser used by `CreateTaskTool`, `CreateEventTool`, and `ShowTask`
- Uses `NSDataDetector` to parse natural language dates (e.g. "tomorrow", "next Monday", "March 15 2pm")
- Falls back to `ISO8601DateFormatter` for backwards compatibility

---

## Relationships

```
CreateTaskTool, CreateEventTool
  ├── attachLabels()      ← LabelAttacher.swift
  │     └── fetches/inserts TaskLabel via ModelContext
  └── parseNaturalDate()  ← ParseDateTime.swift
        └── also used by ShowTask (Views/PopupToEditTasksAndEvents/)

All tools
  └── read currentToolContext  ← ToolExecutionContext.swift
        └── written by AIPipeline before each send()
```
