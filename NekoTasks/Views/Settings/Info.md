# Views/Settings/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — Settings owns the label CRUD flow. The sheet management here uses a specific pattern (sheets attached to `NavigationStack`, not to individual rows) to avoid re-render flicker. Breaking this pattern causes the sheet to dismiss prematurely.

---

## Files

### `SettingsView.swift` — Root settings view

A `NavigationStack` containing `LabelSettingsSection` (and anything else added to settings in the future).

**Sheet management — important pattern:**

The `editingLabel: TaskLabel?` and `isCreatingNew: Bool` state for the `LabelEditorPopup` sheet are stored on `SettingsView`, not on `LabelSettingsSection` or `LabelRow`. The `.sheet()` modifier is attached to the `NavigationStack`.

This is intentional: attaching `.sheet()` to deeply nested rows causes SwiftUI to re-render the parent when the sheet appears, which can immediately dismiss the sheet. Anchoring at the `NavigationStack` level prevents this.

**`onSave` callback from `LabelEditorPopup`:**
- If `isCreatingNew == true`: validates label name is non-empty, creates a new `TaskLabel`, calls `modelContext.insert()`, then saves
- If editing existing: `LabelEditorPopup` writes directly to the `@Bindable` label, `SettingsView` just calls `try? modelContext.save()`

---

### `LabelEditorPopup.swift` — Create/edit label modal

A `NavigationStack`-wrapped form for creating or editing a `TaskLabel`.

**Fields:**
- Name (`TextField` / macOS `LeftTextField`)
- Color (`ColorPicker`) — bound to a local `selectedColor: Color`
- Preview chip showing the result before saving

**Local state pattern:** Uses local `@State` for `name` and `selectedColor`. On Save, converts `selectedColor` to a hex string via `UIColor`/`NSColor` → RGBA components → hex. Calls `onSave(name, colorHex)` callback — the parent (`SettingsView`) decides whether to insert (new) or just save (existing).

**macOS `LeftTextField`:** Same `NSViewRepresentable` as in `ShowTask.swift`. If `LeftTextField` is ever extracted to a shared file, both usages must be updated.

---

## Relationships

```
SettingsView
  ├── @State: editingLabel: TaskLabel?
  ├── @State: isCreatingNew: Bool
  ├── LabelSettingsSection (Labels/ subfolder)
  │     ├── onAdd: () -> Void  ← sets isCreatingNew=true, shows sheet
  │     └── onEdit: (TaskLabel) -> Void  ← sets editingLabel, shows sheet
  └── .sheet → LabelEditorPopup
        └── onSave: (String, String?) -> Void
              ← SettingsView handles insert vs update
```

---

## Adding New Settings

To add a new settings section:
1. Create a new view in this folder (e.g. `NotificationSettingsSection.swift`)
2. Add it inside the `List` or `Form` in `SettingsView.swift`
3. If it needs its own sheet/editor, follow the same pattern: own the sheet state in `SettingsView`, not in the child component
