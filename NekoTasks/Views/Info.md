# Views/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — The Views folder contains all UI code. Read the Info.md in each subfolder before touching any subcomponent. The most interconnected part is `PopupToEditTasksAndEvents/` — it is the shared editor for both tasks AND events, presented from multiple places.

This folder is organized by feature/tab. Each subfolder corresponds to a major section of the app.

---

## Subfolder Overview

```
Views/
├── Tasks/                      ← Tasks tab content (task rows, cards)
├── Calendar/                   ← Events/Calendar tab (week view, day view, filters, recurrence UI)
├── PopupToEditTasksAndEvents/  ← Shared editor sheet for tasks AND events (ShowTask, label picker)
├── Assistant/                  ← AI chat tab
└── Settings/                   ← Settings tab
      └── Labels/               ← Label list and row components
```

**Note:** `TasksView` (the top-level Tasks tab view with the task list + "+" button) is defined **inline in `Apps/ContentView.swift`**, not in `Views/Tasks/`. The `Views/Tasks/` folder only contains the row/card components.

---

## Which Views Are Presented Where

| Sheet/View | Presenter | File |
|---|---|---|
| `ShowTask` editor sheet | `TasksView` (via `.taskEditor()` modifier) | `Apps/ContentView.swift` |
| `ShowTask` editor sheet | `CalendarView` | `Views/Calendar/CalendarView.swift` |
| `DatePickerSheet` | `CalendarView` | `Views/Calendar/CalendarView.swift` |
| `FilterSheet` | `CalendarView` | `Views/Calendar/CalendarView.swift` |
| `LabelEditorPopup` | `SettingsView` | `Views/Settings/SettingsView.swift` |

---

## Shared Infrastructure

**`.taskEditor(editingTask:isCreatingNew:)` modifier** — defined in `PopupToEditTasksAndEvents/TaskEditorModifier.swift`. Used by both `TasksView` and `CalendarView` to present `ShowTask` as a sheet with a consistent create-then-insert pattern.

**`CalendarState`** — injected globally from `NekoTasksApp`, accessed via `@Environment(CalendarState.self)` in all Calendar subviews. See `Views/Calendar/Info.md` and `Views/Calendar/CalendarState.swift`.

**`Color(hex:)` extension** — defined in `Views/Tasks/TaskRow.swift`. Used by label color rendering throughout the app (including Calendar and Settings). If you move this extension, update all callers.

---

## Read Info.md files in each subfolder before editing anything significant.
