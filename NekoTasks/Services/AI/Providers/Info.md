# Services/AI/Providers/

Contains the `AIProvider` protocol and concrete implementations.

---

## Files

### `AIProvider.swift` — backend protocol
```swift
@MainActor
protocol AIProvider {
    func send(message: String) async throws -> String
    func resetSession(systemPrompt: String)
}
```
Tools are **not** in the protocol — each provider owns tool registration internally. Apple's `Tool` protocol is FoundationModels-specific; a future OpenAI provider would use JSON function schemas.

### `AppleFoundationProvider.swift` — Apple on-device model
- `@available(iOS 26, macOS 26, *)`, `@MainActor`, `final class`
- Wraps `LanguageModelSession` with `CreateTaskTool`, `CreateEventTool`, `CreateLabelTool` registered
- `resetSession(systemPrompt:)` — creates a fresh `LanguageModelSession` with the given prompt; stores `lastSystemPrompt` for self-recovery
- `send(message:)` — calls `session.respond(to:)`; if `session` is nil (edge case), re-initialises and retries once

## Adding a New Provider

1. Create `<Name>Provider.swift` in this folder
2. Conform to `AIProvider`
3. Register provider-specific tool formats internally (e.g. JSON function schemas for OpenAI)
4. Update `AIPipeline.init()` to instantiate the desired provider
