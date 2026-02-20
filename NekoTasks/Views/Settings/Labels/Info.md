# Views/Settings/Labels/

This subfolder contains the label list and label row components used in the Settings tab.

These components are display-only — they do NOT own sheet state or perform SwiftData mutations directly. All CRUD operations are delegated upward to `SettingsView` via callbacks.

---

## Files

### `LabelSettingsSection.swift` — Expandable label list

A `DisclosureGroup` ("Labels") containing a `ForEach` of `LabelRow`s for all `TaskLabel` records.

**Callbacks (all actions bubble up to `SettingsView`):**
- `onAdd: () -> Void` — called when "Add Label" button is tapped; parent shows the create sheet
- `onEdit: (TaskLabel) -> Void` — called when a label row is tapped; parent shows the edit sheet
- `.onDelete` — deletes the label from `modelContext` directly (this is the one mutation done here, since SwiftData `onDelete` provides the indices to delete)

**Warning:** Deleting a `TaskLabel` here does NOT cascade-remove the label from `TaskItem.labels` automatically in all cases. SwiftData's many-to-many handling should keep items consistent, but verify if you change the relationship configuration in `TaskItem` or `TaskLabel`.

---

### `LabelRow.swift` — Single label display row

A simple `HStack` with:
- Color dot (circle, 14 pt, filled with the label's color via `Color(hex:)` from `TaskRow.swift`)
- Label name text

Entire row is tappable; calls `onEdit(label)` callback.

No state, no mutations — purely a display component.

---

## Relationships

```
SettingsView
  └── LabelSettingsSection
        ├── ForEach: TaskLabel records
        └── LabelRow (per label)
              └── onEdit callback → SettingsView shows LabelEditorPopup
```

**Note:** `Color(hex:)` used for the color dot is defined in `Views/Tasks/TaskRow.swift`. It is a global extension on `Color` — accessible everywhere, but defined there.
