# Views/Tasks/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — This folder contains the task list page and all its row/card display components. `TasksView` (the @Query-driven list with the "+" button and editor sheet) is defined in `TaskView.swift` here.

---

## Files

### `TaskView.swift` — TasksView (the Tasks tab page)

Defines `TasksView`, the top-level Tasks tab. Responsibilities:
- `@Query` fetches only tasks (`typeRaw == 0`), sorted by `creationDate`.
- `visibleTasks` computed property: hides completed tasks unless they were recently completed (tracked by `recentlyCompleted` — a `@State Set<PersistentIdentifier>`). Also filters out subtasks (items with a non-nil `parent`) so only top-level tasks appear.
- `"+"` toolbar button creates a new `TaskItem(title: "")` **outside** the model context, then opens it in the editor sheet. Only inserted on Save.
- Uses the `.taskEditor(editingTask:isCreatingNew:)` modifier to present `ShowTask` as a sheet.
- `scheduleHide()`: When a task is marked complete, a 5-second `DispatchQueue.main.asyncAfter` hides it from the list. Uses a token-based cancellation system (`completionTokens`) so marking incomplete within 5 seconds cancels the hide.

---

### `TaskRow.swift` — All task card UI components

Contains every struct used to render a task card. All components are in this one file.

**`TaskRow`** — the top-level task row component. Takes a `@Bindable var task: TaskItem`, an `onToggleComplete` closure (fires after the checkbox is toggled), and an `onEdit` trailing closure (opens the editor). Layout:
- `HStack` of `PriorityBorder` (left edge color) + content `VStack`
- Content: `TopRow` (title + due badge), `MetadataRow` (labels + time estimate), `SubtaskSection` (if subtasks exist)
- Background: white/secondary with border; fills with a tinted color when overdue (red) or due today (orange)
- Tapping the card body calls `onTap(task)`; the checkbox is separate

**`TopRow`** — `HStack` with `TaskCheckbox` + title text + `DueBadge`

**`TaskCheckbox`** — animated circle button. Empty circle when incomplete; green filled circle with checkmark when complete. Toggling fires a haptic and updates `task.isCompleted`.

**`DueBadge`** — shows deadline urgency:
- No deadline → hidden
- Overdue → red, "Overdue", exclamation icon
- Today → orange, "Today", clock icon
- Tomorrow → yellow, "Tomorrow", clock icon
- This week → secondary color, weekday name
- Further → secondary color, "MMM d" formatted date

**`PriorityBorder`** — a 5 pt wide colored rectangle on the left edge of the card:
- `importance == nil` or 0 → no border (clear)
- 1 → yellow
- 2 → orange
- 3+ → red

**`MetadataRow`** — `HStack` with `LabelChips` and `TimeEstimateChip` separated by a "·" dot. Hidden if both are empty.

**`LabelChips`** — shows up to 2 label chips, then `"+N more"` overflow text if more exist. Uses `LabelChip` for each.

**`LabelChip`** — label name text in a colored capsule background. Color via `Color(hex:)` extension (defined in this file — see below).

**`TimeEstimateChip`** — timer SF symbol + formatted duration. Format: `"Xh Ym"` (omits minutes if zero, omits hours if zero).

**`SubtaskSection`** — collapsible (toggle via `isExpanded` @State). Shows subtask title + checkbox for each subtask in `task.subTasks`, sorted by `sortOrder`. Tapping a subtask's checkbox toggles `subtask.isCompleted`.

**`Color(hex:)` extension** — parses a hex string like `"E53935"` (no `#`) into a `Color`. Falls back to `.blue` if nil, empty, or unparseable. **This extension is used throughout the app** (label colors in Calendar, Settings, and here). Do not remove or move it without updating all callers.

---

## Relationships

```
Views/Tasks/TaskView.swift — TasksView
  └── LazyVStack of TaskRow(s)  ← TaskRow.swift
        ├── PriorityBorder
        ├── TopRow
        │     ├── TaskCheckbox (toggles task.isCompleted)
        │     └── DueBadge
        ├── MetadataRow
        │     ├── LabelChips → LabelChip (reads TaskLabel.colorHex)
        │     └── TimeEstimateChip
        └── SubtaskSection
              └── per subtask: title + checkbox

Color(hex:) extension  ← defined here, used by:
  - LabelChip (Tasks tab)
  - EventCard (Calendar tab)
  - LabelRow (Settings tab)
  - LabelPickerRow (editor popup)
```

---

## Things to watch

- **`Color(hex:)` is global** — defined here but used everywhere. Keep it in sync if the hex format ever changes.
- **Subtask ordering** — `SubtaskSection` sorts by `sortOrder`. `ShowTask.commitSubtasks()` sets `sortOrder` by array index when saving. Keep consistent.
- **Card urgency coloring** — the card's background fill changes based on deadline urgency (computed in `TaskRow`). This styling is separate from `DueBadge`'s color but uses the same urgency logic. If you change urgency thresholds, update both.
