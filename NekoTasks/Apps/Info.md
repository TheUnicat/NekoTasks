# Apps/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — This folder is the app entry point and root navigation. Changes here affect the entire app's startup, data persistence layer, tab structure, and global state injection.

This folder contains the app entry point, root view, tab definition, and app-wide notification names.

---

## Files

### `NekoTasksApp.swift` — @main entry point

The top-level `App` struct. Responsibilities:
- Creates the **SwiftData `ModelContainer`** for `TaskItem` and `TaskLabel` (persistent, not in-memory). This is the single database for the entire app. If you need to add a new `@Model` type, it must be registered here.
- Creates `CalendarState()` in `@State` and injects it via `.environment(calendarState)` on the `WindowGroup`. This means every view in the app can read/write `CalendarState` via `@Environment(CalendarState.self)`.
- Calls `NotificationHelper.requestAuthorization()` on init (simple one-shot permission request).
- Calls `NotificationManager.shared.configure()` on init (registers rich notification categories with Complete/Snooze actions and sets the `UNUserNotificationCenter` delegate).
- Renders `ContentView` inside a `WindowGroup`.

**Warning:** The `ModelContainer` creation will `fatalError` if it fails — this is intentional (SwiftData schema mismatch usually means you need to delete the app and reinstall during development).

---

### `ContentView.swift` — Root TabView + TasksView

Root view with a `TabView` (4 tabs driven by `AppTab` enum):
- **Tasks** → `TasksView` (defined in `Views/Tasks/TaskView.swift`)
- **Events** → `CalendarView`
- **Assistant** → `AssistantView`
- **Settings** → `SettingsView`

`TasksView` is defined in `Views/Tasks/`. It is the primary tasks list view:
- `@Query` fetches only tasks (`typeRaw == 0`), sorted by `creationDate`.
- `visibleTasks` computed property: hides completed tasks unless they were recently completed (tracked by `recentlyCompleted` — a `@State Set<PersistentIdentifier>`). Also filters out subtasks (items with a non-nil `parent`) so only top-level tasks appear.
- `"+"` toolbar button creates a new `TaskItem(title: "")` **outside** the model context (not inserted yet), then opens it in the editor sheet. Only inserted into the context on Save. This is the "create-then-insert" pattern used throughout the app.
- Uses the `.taskEditor(editingTask:isCreatingNew:)` modifier (from `TaskEditorModifier.swift`) to present `ShowTask` as a sheet.
- `scheduleHide()`: When a task is marked complete, a 5-second `DispatchQueue.main.asyncAfter` hides it from the list. Uses a token-based cancellation system (`completionTokens`) so marking a task incomplete within 5 seconds cancels the hide.

---

### `AppTab.swift` — Tab enum + Notification names

- **`AppTab` enum**: `.tasks`, `.calendar`, `.assistant`, `.settings` — used as `TabView` selection tags in `ContentView`.
- **`Notification.Name` extensions**:
  - `.addNewItem` — broadcast when the "+" button in CalendarView is tapped; listened for nowhere currently (reserved for future use).
  - `.taskNotificationAction` — posted by `NotificationManager` when the user taps "Mark Complete" or "Snooze" on a local notification. `ContentView` or the task list could listen for this to update the UI.

---

## Relationships

```
NekoTasksApp
  ├── Creates: ModelContainer (TaskItem + TaskLabel)
  ├── Creates: CalendarState → injected globally via .environment()
  ├── Inits: NotificationHelper + NotificationManager
  └── Renders: ContentView
        ├── Tab: TasksView  ← Views/Tasks/TaskView.swift
        ├── Tab: CalendarView  ← Views/Calendar/
        ├── Tab: AssistantView ← Views/Assistant/
        └── Tab: SettingsView  ← Views/Settings/
```

---

## Key Patterns

- **Create-then-insert**: New tasks and events are created as plain Swift objects first, only inserted into `modelContext` on Save. Cancel = discard without touching the database.
- **Global environment**: `ModelContainer` (via `.modelContainer()`) and `CalendarState` (via `.environment()`) are both injected at the root here so all child views can access them.
- **`@State` on App struct**: `calendarState` is `@State` on `NekoTasksApp` so it survives re-renders of the scene.
