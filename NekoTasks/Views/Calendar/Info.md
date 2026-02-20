# Views/Calendar/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — This folder is the most complex in the app. It has 15 files, a shared @Observable state object (`CalendarState`) injected via the environment, a custom time-grid layout, a full recurrence rule builder UI, and a filtering system. Changes to `CalendarState`, `EventFilter`, or the `eventsOn()` extension (in `Models/TaskItem.swift`) will ripple through multiple views here.

---

## The Big Picture

The Calendar tab shows events (`typeRaw == 1` TaskItems). It supports two view modes:
- **Day view** (`DayEventList`): Vertical list of events for the selected day
- **Week view** (`WeekView`): 7-column time grid with event blocks positioned by time

Both views share the same `CalendarState` for navigation, filtering, and editing state.

---

## Files

### `CalendarState.swift` — Shared state (read this first)

`@Observable` class injected into the environment by `NekoTasksApp`. Every Calendar subview reads from it via `@Environment(CalendarState.self)`.

**Properties:**
- `selectedDate: Date` — the navigation anchor. In day mode = displayed day; in week mode = any day within the displayed week.
- `filter: EventFilter` — active filter (recurring/one-time toggles + label allowlist). Default is `.all` (no filtering).
- `editingEvent: TaskItem?` — the event currently open in the ShowTask sheet. Set to nil to close.
- `isCreatingNew: Bool` — true when `editingEvent` is a new unsaved event (not yet in modelContext). The sheet's onSave handler uses this to decide whether to call `modelContext.insert()`.
- `viewType: CalendarPeriod` — `.day` or `.week`
- `showingFilterSheet`, `showingDatePicker` — sheet presentation flags

**`EventFilter` struct** (defined in this file):
- `showRecurring: Bool`, `showOneTime: Bool` — toggle which categories of events are visible
- `labelIDs: Set<PersistentIdentifier>` — if non-empty, only events with at least one matching label are shown
- `isDefault: Bool` — true when no filtering is active (used to show/hide the filter indicator)
- `.all` static constant — the default "no filter" state

**Warning:** `EventFilter` is consumed by `[TaskItem].eventsOn(date:filter:)` in `Models/TaskItem.swift`. If you add fields to `EventFilter`, you must also update that extension.

---

### `CalendarView.swift` — Root for Events tab

- `@Query` fetches all events (`typeRaw == 1`)
- `@Environment(CalendarState.self) var state` for navigation and editing
- Switches between `DayEventList` and `WeekView` based on `state.viewType`
- Presents three sheets: `DatePickerSheet`, `FilterSheet`, `ShowTask` (via `.taskEditor()` modifier)
- `"+"` button creates a new `TaskItem(type: .event)` with default times (9 AM start, 10 AM end today), sets `state.editingEvent` and `state.isCreatingNew = true`
- Listens for `Notification.Name.addNewItem` to trigger the same "create new event" flow

---

### `CalendarFormatting.swift` — Date formatting utilities

Centralized static date formatters (expensive to allocate — cached as `static let`):
- `weekdayMonthDay` → "Friday, Jan 24"
- `monthDay` → "Jan 24"
- `dayOnly` → "24"
- `yearOnly` → "2026"
- `shortWeekday` → "FRI"
- `hourPeriod` → "9 AM"

Public methods: `weekdayMonthDayString()`, `monthDayString()`, `dayString()`, `yearString()`, `shortWeekdayString()`, `hourString()`.
- `weekRangeTitle(for:)` → "Jan 20 – 26" (collapses repeated month name if same month)
- `relativeLabel(for:)` → "Today", "Yesterday", "Tomorrow", or year string

Used by `DateNavigator`, `WeekHeaderRow`, `DayColumn`, and anywhere else dates need display strings.

---

### `DateNavigator.swift` — Navigation bar at top of Calendar tab

Controls: segmented Day/Week picker, prev/next chevrons, tappable date title, "Today"/"This Week" jump button, filter icon (filled when filter is active).

- Reads/writes `state.selectedDate`, `state.viewType`, `state.showingDatePicker`, `state.showingFilterSheet`
- Moving prev/next: day mode shifts by ±1 day; week mode shifts by ±7 days
- "Today"/"This Week" button appears only when not viewing the current period

---

### `WeekView.swift` — 7-column time grid

Constants (important — used by `DayColumn` for event positioning):
- `hourHeight = 60` pt per hour
- `startHour = 0`, `endHour = 24` (full 24-hour day)
- Total height = `hourHeight * (endHour - startHour)` = 1440 pt

Structure: `ScrollView` containing `WeekHeaderRow` above, then `HStack` of `TimeGutter` (50 pt wide) + 7 `DayColumn`s.

Auto-scrolls to `"hour-8"` (8 AM) on appear via `ScrollViewReader`.

---

### `DayColumn.swift` — Single day in WeekView

For each event in the day, computes:
- **Y offset** = `minutesSinceStartHour / totalMinutes × totalHeight`
- **Height** = `durationMinutes / totalMinutes × totalHeight` (min 20 pt)

Renders a `ZStack` with hour grid lines, `CurrentTimeIndicator` (today only), and event `EventWeekBlock`s.

Tapping an `EventWeekBlock` sets `state.editingEvent` to open the editor.

---

### `EventWeekBlock.swift` — Compact event tile in WeekView

Minimal display: just the event title (up to 2 lines) on a colored background. Color comes from the first label's `colorHex`, falling back to `.blue`. Used only inside `DayColumn`.

---

### `DayEventList.swift` — Event list for day view

`ScrollView` + `LazyVStack` of `EventCard`s for events on `state.selectedDate`. Shows `EmptyDayView` when there are no events. Tapping an `EventCard` sets `state.editingEvent`.

---

### `EventCard.swift` — Event display card in day list

Shows: `EventTimeBlock` (start/end time in a blue box), title, location (with mappin icon), "Recurring" badge (if applicable), `LabelChips`. Uses `PriorityBorder` from `TaskRow.swift` for the left-edge color accent (first label color, or no border if unlabelled).

Max width 640 pt, rounded rect with border.

---

### `TimeGutter.swift` — Hour labels on left side of WeekView

Renders labels "12 AM", "1 AM", ..., "11 PM". Each label has an ID `"hour-N"` for `ScrollViewReader`. Labels are offset -6 pt vertically to baseline-align with grid lines.

---

### `WeekHeaderRow.swift` — Weekday header in WeekView

Displays abbreviated weekday names (SUN, MON, ...) and day numbers. Today's date gets a blue circle background.

---

### `CurrentTimeIndicator.swift` — Red "now" line in DayColumn

A red horizontal line + circle dot at the current time's Y position. **Known issue: does not update in real-time** — position is computed once on `.onAppear`. Wrapping in `TimelineView` would fix this (TODO).

---

### `FilterSheet.swift` — Event filter modal

Toggles for "Recurring events" and "One-time events" plus a label filter list. "Clear label filter" removes label filtering. "Reset all filters" restores `EventFilter.all`. Writes directly to `state.filter`.

---

### `DatePickerSheet.swift` — Date picker modal

Simple `NavigationStack` with a graphical `DatePicker` bound to `state.selectedDate`. Presented at `.medium` detent.

---

### `EmptyDayView.swift` — Empty state for day view

Calendar icon + "No events" message. Shown by `DayEventList` when no events pass the filter for the selected day.

---

### `RecurrenceRuleUI.swift` — Recurrence rule builder

> ⚠️ **High complexity** — This file builds and decomposes `AnyRule` values (from `Models/RecurrenceRule.swift`). It is tightly coupled to every case of the `AnyRule` indirect enum. If you add a new rule case to `AnyRule`, you MUST update `loadFromRule()`, `decompose()`, `constructedRule`, and `ruleDescription` here.

Used inside `ShowTask` (in `PopupToEditTasksAndEvents/`) when an item is in event mode with "Repeats" toggled on.

**`RecurrenceRulePicker`** — top-level component, takes `Binding<AnyRule?>` and `Binding<Bool>` (isRecurring):
- Toggle "Repeats" on/off
- Picker: Weekly | Monthly
- Weekly: `WeekdayPicker` + optional "Every other week" toggle
- Monthly: toggle between `DayOfMonthPicker` and `WeekOfMonthPicker`
- Optional date range picker
- Live `ruleDescription` preview
- `loadFromRule()`: Decomposes an existing `AnyRule` back into the picker's internal state (called on `.onAppear`). Uses recursive `decompose()` to handle `.and()` composites.
- `constructedRule`: Assembles an `AnyRule` from the current picker state

**`WeekdayPicker`** — 7 day buttons + quick-select presets (Weekdays, MWF, TTh, Clear)

**`DayOfMonthPicker`** — grid of 1–31 + "Last day" option

**`WeekOfMonthPicker`** — 1st–5th week buttons + weekday sub-picker + "include last week" toggle

**Warning:** The `loadFromRule()` / `decompose()` functions handle `.and()` nesting from `constructedRule`. If `constructedRule` changes its composition structure, `loadFromRule()` must be updated to match or it will fail to round-trip existing rules.

---

## How It All Connects

```
CalendarView (root)
  ├── @Query: all events (typeRaw==1)
  ├── @Environment: CalendarState (selectedDate, filter, editing state)
  ├── DateNavigator (navigation + filter icon)
  ├── if .day: DayEventList → EventCard(s) → taps → state.editingEvent
  ├── if .week: WeekView → DayColumn(s) → EventWeekBlock → taps → state.editingEvent
  ├── Sheet: DatePickerSheet (state.showingDatePicker)
  ├── Sheet: FilterSheet (state.showingFilterSheet) → writes state.filter
  └── Sheet: ShowTask via .taskEditor() (state.editingEvent)
        └── includes RecurrenceRulePicker (event mode only)

Event visibility pipeline:
  CalendarView gets all events via @Query
  → .eventsOn(date:filter:)  [Models/TaskItem.swift]
        → filter by state.filter
        → per event: occursOn(date:) → AnyRule.matches(context:)
  → sorted by startTime
  → passed to DayEventList or DayColumn
```
