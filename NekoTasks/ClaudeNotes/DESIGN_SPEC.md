# NekoTasks — Design Specification

> **Edit this file** to describe the design you want. Claude will read this before making changes.

---

## App Identity

- **Name**: NekoTasks
- **Platform**: macOS (potential iOS later)
- **Vibe**: (describe the overall feel — minimal? playful? professional?)

---

## Color Palette

- **Primary accent**: (e.g., blue, custom hex)
- **Background**: (e.g., white, system background)
- **Card style**: (e.g., white cards with subtle border, flat, shadowed)
- **Priority colors**: Currently yellow (1), orange (2), red (3+)

---

## Typography

- **Title style**: (e.g., system bold, custom font)
- **Body text**: (e.g., system default)
- **Card titles**: Currently `.headline`
- **Metadata**: Currently `.caption` / `.caption2`
- **Text fields**: No blue border highlight when focused

---

## Layout

### Tab Bar
- **Tabs**: Tasks, Events, Assistant
- **Icons**: checklist, calendar, sparkles
- **Tab bar style**: (e.g., default macOS, custom bottom bar)

### Tasks Tab
- **List style**: Scrolling cards (LazyVStack), max width 560
- **Card contents**: Checkbox, title, due badge, label chips, time estimate
- **Empty state**: (describe what to show when no tasks)
- **Sorting**: (e.g., by deadline, by creation date, by priority)

### Events Tab (Calendar)
- **Navigation**: Date navigator with prev/next arrows, tap-to-pick date
- **Event cards**: Time column (50pt) + title + location + recurrence badge
- **Empty state**: "No events" with calendar icon
- **Filters**: Recurring/one-time toggle, label filter

### Assistant Tab
- **Chat style**: Message bubbles (user=blue right-aligned, assistant=gray left-aligned)
- **Empty state**: Sparkles icon + "Ask me to create tasks or events"
- **Input**: Text field + send button at bottom
- **Clear button**: Trash icon in toolbar

### Task/Event Editor (ShowTask)
- **Layout**: Title at top, type picker (segmented), grouped Form, action buttons at bottom
- **Task fields**: Notes, deadline (text), time estimate (text), priority, location
- **Event fields**: Notes, start/end times (text), recurrence picker, priority, location
- **Buttons**: Cancel, Delete, Save

---

## Interactions

- **Tap task card**: Opens editor sheet
- **Checkbox**: Toggle completion with animation
- **Add button (+)**: Creates new item and opens editor immediately
- **Swipe actions**: (describe any swipe-to-delete, swipe-to-complete, etc.)

---

## AI Assistant Behavior

- **Personality**: (e.g., concise and helpful, casual, formal)
- **Capabilities**: Create tasks, create events via tool calling
- **Limitations**: On-device Apple Intelligence (3B model), no internet, 4096 token limit
- **Error handling**: Shows error in chat bubble

---

## Future Plans

- (list features you want to add next)
- (e.g., drag-and-drop reordering, label management UI, subtask support in editor)
- (e.g., iOS version, widgets, shortcuts integration)

---

## Notes

(Any other design decisions, constraints, or preferences go here.)
