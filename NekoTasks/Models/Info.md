# Models/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — This is the data layer. `TaskItem` is used everywhere in the app: all views query it, the editor modifies it, the AI tools create it, notifications reference it. Any change to `TaskItem`'s fields or relationships can break CalendarView, TasksView, ShowTask, AIService, NotificationManager, and the recurrence engine simultaneously.

This folder contains the three core data types. There is no repository layer — views query SwiftData directly.

---

## Files

### `TaskItem.swift` — Core SwiftData model (dual-purpose: task + event)

`TaskItem` is an `@Model` that represents **both tasks and calendar events** via the `typeRaw` field:
- `typeRaw = 0` → task (shown in Tasks tab, queried with `typeRaw == 0`)
- `typeRaw = 1` → event (shown in Calendar tab, queried with `typeRaw == 1`)

**Fields:**

| Field | Type | Purpose |
|---|---|---|
| `title` | `String` | Required, shown everywhere |
| `taskDescription` | `String?` | Notes/body text |
| `creationDate` | `Date` | Set on init, shown in editor |
| `deadline` | `Date?` | Task due date; also used by `occursOn()` for non-recurring events |
| `timeEstimate` | `TimeInterval?` | Duration in seconds; displayed as H:MM |
| `importance` | `Int?` | Priority 1–5; drives PriorityBorder color |
| `isCompleted` | `Bool` | Task checkbox state |
| `labels` | `[TaskLabel]` | Many-to-many with TaskLabel |
| `locationName` | `String?` | Event location string |
| `sortOrder` | `Int` | Used to order subtasks |
| `notificationID` | `String` | Stable UUID string for notification identifiers — do NOT regenerate after creation |
| `startTime` | `Date?` | Event start; used for calendar positioning |
| `endTime` | `Date?` | Event end |
| `typeRaw` | `Int` | Raw value of `ItemType` enum (0=task, 1=event) |
| `recurrence` | `Bool` | Whether this event repeats |
| `recurrenceRuleString` | `String?` | JSON-encoded `AnyRule`; see `RecurrenceRule.swift` |
| `subTasks` | `[TaskItem]` | Self-referential, cascade-deleted on parent delete |
| `parent` | `TaskItem?` | Set on subtasks; used to filter subtasks out of the top-level task list |

**Computed properties:**
- `type: ItemType` — get/set wrapper around `typeRaw`
- `recurrenceRule: AnyRule?` — decodes `recurrenceRuleString` from JSON on read; encodes via `toJSON()` on write

**Extensions:**
- `Array<TaskItem>.eventsOn(date:filter:)` — filters + sorts events for a given date. Used by `DayEventList` and `DayColumn`. Evaluates `occursOn()` per event, respects `EventFilter` (recurring/one-time toggles + label allowlist).
- `TaskItem.occursOn(date:calendar:)` — for recurring events, decodes and evaluates the `AnyRule`; for non-recurring, checks if `startTime` (or `deadline`) falls on the given date.

**Warning — `notificationID` stability:** `NotificationManager` uses `notificationID` as the stable UNNotification identifier. If you ever regenerate this field on existing records, pending notifications will become orphaned and uncancel-able.

**Warning — type switching in editor:** `ShowTask` allows switching an item between task and event. When this happens, `commitEdits()` clears the other type's fields (e.g. clearing `startTime`/`endTime` when saving as a task). Be careful if adding fields that are type-specific.

---

### `TaskLabel.swift` — Tag model

Simple `@Model` for labels/tags that can be attached to tasks and events.

| Field | Type | Purpose |
|---|---|---|
| `name` | `String` | Display name |
| `colorHex` | `String?` | Optional hex string like `"E53935"`; parsed via `Color(hex:)` extension (defined in `TaskRow.swift`). Falls back to `.blue` if nil or unparseable. |

TaskLabel has a many-to-many relationship with TaskItem (SwiftData handles the join table automatically). Labels are managed in Settings and can be created inline in the task/event editor.

**Warning:** The `Color(hex:)` extension that parses `colorHex` is defined in `TaskRow.swift` (not here). If you move or rename that extension, all label color rendering will break.

---

### `RecurrenceRule.swift` — Recurrence rule engine

A self-contained rule evaluation engine. Nothing here touches SwiftData or SwiftUI directly.

**`Weekday` enum** — Sun=1 through Sat=7. Raw values intentionally match `Calendar.component(.weekday, from:)` output. Do NOT change raw values.

**`RecurrenceContext`** — wraps a `Date` and computes:
- `weekday: Weekday?` — which day of the week
- `dayOfMonth: Int` — 1–31
- `weekOfMonth: Int` — which week in the month (1-based)
- `weekOfYear: Int` — used by `everyOtherWeek`
- `isLastWeekOfMonth: Bool` — true if adding 7 days would move to the next month

**`AnyRule`** — `indirect enum`, `Codable`, `Equatable`. The composite pattern:

| Case | Matches when... |
|---|---|
| `.weekdays(Set<Weekday>)` | current weekday is in the set |
| `.daysOfMonth([Int])` | current day-of-month is in the list |
| `.weekOfMonth(WeekOfMonthRule)` | current week-of-month matches; or `includesLast && isLastWeekOfMonth` |
| `.everyOtherWeek(startingWeek: Int)` | `(weekOfYear - startingWeek) % 2 == 0` |
| `.dateRange(start:end:)` | current date falls within the range (inclusive, day-level) |
| `.and(AnyRule, AnyRule)` | both sub-rules match |
| `.or(AnyRule, AnyRule)` | either sub-rule matches |
| `.not(AnyRule)` | sub-rule does NOT match |

Operator overloads: `&&`, `||`, `!` build `.and`, `.or`, `.not` composites.

`AnyRule.toJSON()` serializes to a JSON string stored in `TaskItem.recurrenceRuleString`. `RecurrenceRulePicker` in `Views/Calendar/RecurrenceRuleUI.swift` builds and decomposes `AnyRule` values for the UI. When modifying rule cases, you must update the UI decomposer (`loadFromRule()` / `decompose()` in RecurrenceRuleUI) to match.

**`WeekOfMonthRule`** — helper struct for `.weekOfMonth` case: a list of week numbers + an `includesLast` flag.

---

## Relationships Between Models

```
TaskItem (typeRaw=0: task)
  ├── labels: [TaskLabel]   ← many-to-many
  ├── subTasks: [TaskItem]  ← self-referential (cascade delete)
  └── parent: TaskItem?     ← back-reference for subtasks

TaskItem (typeRaw=1: event)
  ├── labels: [TaskLabel]   ← same relationship
  ├── recurrenceRuleString  ← JSON-encoded AnyRule (see RecurrenceRule.swift)
  └── (no subtasks in practice, though the relationship exists)

TaskLabel
  └── (no back-reference to TaskItem stored here; SwiftData manages the join)
```

---

## How Recurrence Works End-to-End

1. User builds a rule in `RecurrenceRulePicker` (Views/Calendar/RecurrenceRuleUI.swift)
2. `constructedRule` assembles an `AnyRule` from picker state
3. On Save, `ShowTask.commitEdits()` sets `task.recurrenceRule = rule` (triggers JSON encoding into `recurrenceRuleString`)
4. `TaskItem.occursOn(date:)` decodes the JSON back to `AnyRule` and calls `rule.matches(context:)`
5. `[TaskItem].eventsOn(date:filter:)` calls `occursOn()` for every event to populate CalendarView
