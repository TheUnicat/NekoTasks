# Models/Migrations/

Versioned schema snapshots and the migration plan SwiftData runs when the store schema changes.

---

## Files

### `SchemaV1.swift` — Frozen V1 model snapshot

A byte-for-byte copy of `TaskItem` and `TaskLabel` as they existed before the V1→V2 change. SwiftData computes a hash of each `VersionedSchema`'s model definitions and compares it against the hash stored in the existing database to determine which version the store is at. **Do not modify these definitions** — any change breaks the hash match and causes migration to be skipped or to fail.

### `AppMigrationPlan.swift` — Schema version list + migration stages

Contains two things:

**`SchemaV2`** — the current schema version. Its `models` array is what `NekoTasksApp` passes to `ModelContainer`. When you bump to V3, rename this to `SchemaV3` and update the reference in `NekoTasksApp.swift`.

**`AppMigrationPlan`** — the `SchemaMigrationPlan` implementation. Lists all versions (oldest → newest) in `schemas`, and all migration stages in `stages`.

---

## Current Versions

| Version | What changed |
|---|---|
| V1 | Initial schema. `TaskLabel` has no back-reference to `TaskItem`. SwiftData stored the relationship as a one-to-many FK column (`Z1LABELS` on `ZTASKLABEL`), meaning each label could only belong to one task. |
| V2 | `TaskLabel` gains `tasks: [TaskItem]`. SwiftData now creates a proper many-to-many join table, allowing a label to be shared across any number of tasks and events. |

---

## When to Add a New Version

**Use `.lightweight` (no data risk, no new version needed):**
- Adding an optional field → existing records get `nil`
- Adding a field with a default value → existing records get the default
- Adding a new `@Model` entity entirely
- Removing a field (data is silently dropped)

**Create a new `SchemaV(N)` snapshot and use `.custom`:**
- Any relationship storage change (one-to-many ↔ many-to-many, FK column ↔ join table)
- Attribute type changes (`String` → `Int`, etc.)
- Renaming an entity or attribute without `@Attribute(.renamingIdentifier)`
- Adding a non-optional field with no default value

**Renaming with `@Attribute(.renamingIdentifier)`** is a special case — add the annotation to the current model file *before* renaming, then rename. SwiftData handles this as a lightweight migration automatically; no new schema version needed.

---

## How to Add a New Version (checklist)

1. Rename `SchemaV2` → `SchemaV3` in `AppMigrationPlan.swift` (bump `versionIdentifier` too).
2. Create `SchemaV2.swift` with a frozen copy of the models as they were *before* the new change. Follow the same rules as `SchemaV1.swift` — no app logic, no imports beyond SwiftData/Foundation, `init() {}` only.
3. Add the new `MigrationStage` to `AppMigrationPlan.stages`.
4. Update the `ModelContainer` call in `NekoTasksApp.swift` if you added new `@Model` types (add them to `SchemaV3.models`).
5. Update this file's version table.
