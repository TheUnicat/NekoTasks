# Services/AI/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — Apple FoundationModels integration (macOS/iOS 26+ only). The tool classes are tightly coupled to `TaskItem` and `TaskLabel` fields. If you rename or remove model fields, check all tool `Arguments` structs and `call()` implementations. The on-device 3B model is unreliable with tool calling — keep system prompt instructions maximally directive.

---

## Architecture

```
AIPipeline  (@Observable, public API)
  ├── AIPromptBuilder  (builds system prompt string)
  ├── AIProvider  (protocol)
  └── AppleFoundationProvider  (implements AIProvider)
        └── LanguageModelSession
              ├── CreateTaskTool
              ├── CreateEventTool
              └── CreateLabelTool
                    └── LabelAttacher (shared helper)

ToolExecutionContext + currentToolContext (global)
  ← only written by AIPipeline, read by tool call(arguments:) implementations
```

**Data flow from AI call to SwiftData:**

1. `AssistantView` calls `pipeline.send(message:modelContext:)`
2. `AIPipeline` creates `ToolExecutionContext(modelContext:)`, sets `currentToolContext`, registers a `defer` to clear it
3. `AppleFoundationProvider.send()` calls `session.respond(to:)` — the model may invoke one or more tools
4. Each tool's `call(arguments:)` reads `currentToolContext` to get the `ModelContext`, creates items, calls `modelContext.insert()`
5. When `session.respond` returns, `AIPipeline` checks `context.createdItems` and calls `modelContext.save()` if non-empty
6. The `defer` clears `currentToolContext = nil`

**Why the global is unavoidable:** Apple's `Tool` protocol gives `call(arguments:)` no way to receive injected dependencies. The global is quarantined here — only `AIPipeline` writes it.

---

## Files

### `AIPipeline.swift` — public orchestrator
- `@Observable`, `@MainActor`, `@available(iOS 26, macOS 26, *)`
- Holds `provider: any AIProvider`
- `resetSession()` — delegates to provider with a freshly built system prompt (current date/time)
- `send(message:modelContext:) async throws -> String` — manages `currentToolContext` lifecycle, delegates send to provider, saves SwiftData if tools created items

### `AIPromptBuilder.swift` — prompt construction
- `enum AIPromptBuilder` with `static func buildSystemPrompt(currentDate: Date = Date()) -> String`
- The full directive prompt lives here. Edit this to tune model behaviour.
- **⚠️** The 3B on-device model needs blunt, imperative instructions. Don't soften the language.

### `ChatMessage.swift` — chat display model
- `struct ChatMessage: Identifiable, Equatable`
- Fields: `id: UUID`, `role: .user | .assistant`, `content: String`
- Not persisted to SwiftData. Used only by `AssistantView`.

### `ToolExecutionContext.swift` — mutable tool context + global
- `class ToolExecutionContext` — holds `modelContext: ModelContext?` and `createdItems: [String]`
- `@MainActor var currentToolContext: ToolExecutionContext?` — the global. Only `AIPipeline` writes it.

---

## Subdirectories

- **`Providers/`** — see `Providers/Info.md`
- **`Tools/`** — see `Tools/Info.md`

---

## Known Issues / Constraints

- The on-device 3B model is **unreliable with tool calling** — it sometimes describes creating items in text instead of calling the tool. Known model limitation.
- Tool `Arguments` structs must use `String?` for optional fields (not `Date?`, `Int?`) — simple types are most reliable.
- Events **must have `startTime` set** or they won't appear in `CalendarView` (the `occursOn()` check relies on `startTime`).
- `CreateTaskTool` is **inextricably linked to `TaskItem`'s fields**. If you add/rename `TaskItem` fields, update `CreateTaskTool.Arguments` and `call()` accordingly.
