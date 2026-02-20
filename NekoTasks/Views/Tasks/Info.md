# Views/Tasks/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — This folder contains the task row/card display components. Note that `TasksView` (the actual task list page with @Query, the "+" button, and the sheet) is defined inline in `Apps/ContentView.swift`, NOT here. This folder only has the visual building blocks.

---

## Files

### `TaskView.swift` — Thin wrapper (mostly unused)

Currently contains little to nothing of substance. The actual task list logic (`TasksView`) lives in `Apps/ContentView.swift`. This file is a candidate for future use if `TasksView` is ever extracted out of `ContentView.swift`.

---

### `TaskRow.swift` — All task card UI components

Contains every struct used to render a task card. All components are in this one file.

**`TaskCard`** — the top-level task row component. Takes a `@Bindable var task: TaskItem` and an `onTap` closure (opens the editor). Layout:
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
- This week → yellow, weekday name
- Further → secondary color, "MMM d" formatted date

**`PriorityBorder`** — a 4 pt wide colored rectangle on the left edge of the card:
- `importance == nil` or 0 → no border (clear)
- 1 → yellow
- 2 → orange
- 3+ → red

**`MetadataRow`** — `HStack` with `LabelChips` and `TimeEstimateChip` separated by a "·" dot. Hidden if both are empty.

**`LabelChips`** — shows up to 2 label chips, then `"+N more"` overflow text if more exist. Uses `LabelChip` for each.

**`LabelChip`** — a capsule with a colored circle dot and label name. Color via `Color(hex:)` extension (defined in this file — see below).

**`TimeEstimateChip`** — timer SF symbol + formatted duration. Format: `"Xh Ym"` (omits minutes if zero, omits hours if zero).

**`SubtaskSection`** — collapsible (toggle via `isExpanded` @State). Shows subtask title + checkbox for each subtask in `task.subTasks`, sorted by `sortOrder`. Tapping a subtask's checkbox toggles `subtask.isCompleted`.

**`Color(hex:)` extension** — parses a hex string like `"E53935"` (no `#`) into a `Color`. Falls back to `.blue` if nil, empty, or unparseable. **This extension is used throughout the app** (label colors in Calendar, Settings, and here). Do not remove or move it without updating all callers.

---

## Relationships

```
Apps/ContentView.swift — TasksView
  └── LazyVStack of TaskCard(s)  ← TaskRow.swift
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
- **Card urgency coloring** — the card's background fill changes based on deadline urgency (computed in `TaskCard`). This styling is separate from `DueBadge`'s color but uses the same urgency logic. If you change urgency thresholds, update both.
