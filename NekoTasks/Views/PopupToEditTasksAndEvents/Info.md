# Views/PopupToEditTasksAndEvents/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — This folder contains the primary editor for BOTH tasks AND events. It is presented from at least two different places (`TasksView` in `ContentView.swift` and `CalendarView`). Changes to `ShowTask` affect the entire edit experience across the app.

---

## Files

### `ShowTask.swift` — The main editor (tasks and events)

A single `View` that handles editing for both `ItemType.task` and `ItemType.event`. The user can switch between types with a segmented picker inside the sheet, and the form sections change accordingly.

**How it's invoked:**
- `ShowTask(task:)` — editing an existing task/event already in the model context
- `ShowTask(task:onCancel:onSave:)` — creating a new item (not yet in modelContext); the `onSave` callback in `TaskEditorModifier` handles `modelContext.insert()` for new items

**Key design: local @State copies**

All fields are copied into local `@State` on init:
```
@State private var title, details, importance, location, selectedType
@State private var deadlineText, timeEstimateText
@State private var startTimeText, endTimeText
@State private var isRecurring, rule: AnyRule?
@State private var subtaskDrafts: [SubtaskDraft]
@State private var selectedLabelIDs: Set<PersistentIdentifier>
```

Changes are NOT written back to the `TaskItem` until `Save` is tapped (calls `commitEdits()`). Cancel = throw away local state, TaskItem is unchanged. This is safe because new items are created outside the model context and only inserted on save.

**Task mode sections (Form):**
- Notes (description)
- Deadline (text input: "MM/DD" or "YYYY/MM/DD")
- Time estimate (text input: "H:MM")
- Subtasks (list of `SubtaskDraft`s; `"Add Subtask"` button appends drafts)
- Priority (text: "1-5"), Location, Labels, Creation date (read-only)

**Event mode sections (Form):**
- Notes
- Start/End time (text input: "MM/DD HH:MM")
- `RecurrenceRulePicker` (from `RecurrenceRuleUI.swift` in `Views/Calendar/`)
- Priority, Location, Labels, Creation date

**`commitEdits()`** — called on Save. Writes local state back to the `TaskItem`. When switching types (task→event or event→task), clears irrelevant fields:
- Saving as task: clears `startTime`, `endTime`, `recurrence`, `recurrenceRule`; sets `deadline`, `timeEstimate`; calls `commitSubtasks()`
- Saving as event: clears `deadline`, `timeEstimate`; sets `startTime`, `endTime`, `recurrence`, `recurrenceRule`; does NOT commit subtasks

**`commitSubtasks()`** — deletes all existing subtasks from modelContext (cascade would handle it, but this is explicit), then creates new `TaskItem` records from `subtaskDrafts` with `parent = task` set.

**Delete button** — only shown when `task.modelContext != nil` (i.e., item is already persisted). New unsaved items don't show Delete.

**Date/time parsing:**
- `parseDateTime(_:)` — flexible: accepts "DD", "MM/DD", "YYYY/MM/DD", optionally followed by " HH:MM". Defaults year/month to current if not specified.
- `parseTimeEstimate(_:)` — accepts "H:MM" or "H" format, returns `TimeInterval` in seconds.
- `formatDateTime(_:)` — formats `Date?` to "YYYY/M/D" or "YYYY/M/D H:MM" (omits time if midnight).

**macOS support:**
- `LeftTextField` — `NSViewRepresentable` for left-aligned text input. SwiftUI's `TextField` on macOS has writing direction quirks; `LeftTextField` fixes this. Used for title and all labeled text fields on macOS.
- Forces `.leftToRight` layout direction and `en_US` locale via `.environment()` modifiers.

**`SubtaskDraft`** — private struct (only in this file) representing an in-progress subtask edit. Fields: `title`, `deadlineText`, `timeEstimateText`, `isCompleted`. Not a SwiftData model.

---

### `TaskEditorModifier.swift` — ViewModifier for presenting ShowTask

A `ViewModifier` that presents `ShowTask` as a `.sheet`. Applied via the `.taskEditor(editingTask:isCreatingNew:)` extension on `View`.

Used by:
- `TasksView` (in `Apps/ContentView.swift`)
- `CalendarView` (in `Views/Calendar/CalendarView.swift`)

**How it works:**
- `editingTask: Binding<TaskItem?>` — the item to edit. Sheet appears when non-nil.
- `isCreatingNew: Binding<Bool>` — true when the item is new and not yet in modelContext
- `onSave` closure inside the modifier: if `isCreatingNew`, validates title and calls `modelContext.insert(task)` before clearing state
- `onCancel` closure: just clears state (new item is discarded since it was never inserted)

**Why this pattern exists:** Both `TasksView` and `CalendarView` need to present the same editor. The modifier encapsulates the create-then-insert logic so neither caller has to implement it themselves.

---

### `LabelPickerRow.swift` — Label picker UI for inside ShowTask

Two main components used in `ShowTask`'s "Labels" section:

**`LabelFlowPicker`** — the full label assignment UI:
- Shows currently assigned labels as `AssignedLabelChip`s (color dot + name + × to remove)
- A `"+ Label"` button opens `LabelPickerPopover`
- Binds to `Set<PersistentIdentifier>` (the `selectedLabelIDs` in `ShowTask`)
- Includes a quick-create row: `ColorPicker` + `TextField` + `"Create"` button to make a new label without leaving the popover

**`LabelPickerPopover`** — a popover with:
- Quick-create row at top
- Scrollable list of all existing labels as `LabelToggleRow`s (color dot, name, checkmark if selected)
- Max height 250 pt, width 280 pt

**`AssignedLabelChip`** — a capsule showing a selected label. Has a × button to remove it from `selectedLabelIDs`.

**`FlowLayout`** — custom `Layout` that wraps children into rows like CSS flexbox. Used to lay out `AssignedLabelChip`s + `"+ Label"` button in a wrapping flow.

## Relationships

```
TasksView (Apps/ContentView.swift)
  └── .taskEditor(editingTask:isCreatingNew:)  ← TaskEditorModifier
        └── ShowTask(task:onCancel:onSave:)
              ├── LabelFlowPicker  ← LabelPickerRow.swift
              └── RecurrenceRulePicker  ← Views/Calendar/RecurrenceRuleUI.swift

CalendarView (Views/Calendar/CalendarView.swift)
  └── .taskEditor(editingTask:isCreatingNew:)  ← TaskEditorModifier
        └── ShowTask(task:onCancel:onSave:)
              ├── LabelFlowPicker
              └── RecurrenceRulePicker (event mode)
```

---

## Warning: Type-switching in the editor

If a user opens a task and switches the segmented picker to "Event" (or vice versa), `commitEdits()` will clear the fields that don't apply to the new type. For example, switching task→event clears `deadline` and `timeEstimate`. Make sure any new type-specific fields are cleared in the opposite branch of `commitEdits()`.
