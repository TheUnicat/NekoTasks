# Views/Assistant/

> ⚠️ **READ THIS BEFORE MAKING CHANGES** — This folder wraps Apple's FoundationModels API (macOS/iOS 26+ only). The entire UI is gated behind an availability check. The AI creates SwiftData records by writing through a global `currentToolContext` — this is an unusual pattern that requires `AssistantView` to set up the context before each AI call and save the model context after.

---

## Files

### `AssistantView.swift` — AI chat interface

**Availability gating:**
```swift
if #available(iOS 26, macOS 26, *) {
    AssistantContent()
} else {
    // "AI assistant not available on this OS version" message
}
```

Everything real lives in `AssistantContent` (nested struct, same file).

---

**`AssistantContent`** layout:
1. `ScrollViewReader` wrapping a `LazyVStack` of `MessageBubble`s + optional `TypingBubble`
2. Auto-scrolls to `"bottom"` anchor on new messages
3. Text input field + send button at bottom
4. "Clear" toolbar button (top right)

**Empty state:** Sparkles icon + "Ask me to create tasks or events" prompt shown when `messages` is empty.

---

**`sendMessage()` — the AI call flow:**
1. Appends `ChatMessage(role: .user, content: text)` to `messages`
2. Sets `currentToolContext = ToolExecutionContext(modelContext: modelContext)` (global in `Services/AIService.swift`)
3. Sets `isTyping = true`, clears input
4. Calls `AIService.send(message:)` (async, may call one or more tools internally)
5. If `context.createdItems` is non-empty, calls `try? modelContext.save()` to persist AI-created items
6. Appends `ChatMessage(role: .assistant, content: response)` to `messages`
7. On error: appends an error message in the assistant bubble

**Why `currentToolContext` is needed:** FoundationModels `Tool` objects are instantiated independently and can't receive `@Environment` values. The global context is the only practical bridge from the tool's async execution back to the SwiftData model context.

**`clearChat()`:** Clears `messages`, calls `AIService.resetSession()` to start a fresh `LanguageModelSession` (resets conversation history and re-injects the system prompt with the current date/time).

---

**`MessageBubble`** — displays a single chat message:
- User messages: blue background, right-aligned
- Assistant messages: gray background, left-aligned

**`TypingBubble`** — animated 3 bouncing dots shown while `isTyping == true`. Uses staggered `.animation()` on each dot.

---

## Relationships

```
AssistantView
  └── AssistantContent
        ├── @Environment(\.modelContext)  ← from ModelContainer (set up in NekoTasksApp)
        ├── AIService  ← Services/AIService.swift
        │     └── LanguageModelSession (FoundationModels, macOS 26+)
        │           ├── CreateTaskTool → inserts TaskItem
        │           ├── CreateEventTool → inserts TaskItem
        │           └── CreateLabelTool → inserts TaskLabel
        └── currentToolContext (global)  ← bridges ModelContext into tools
```

---

## Known Issues

- The on-device 3B model is unreliable with tool calling. It sometimes describes creating items in text instead of calling the tool. This is a model limitation, not a code bug.
- If `AIService` is unavailable (device doesn't support FoundationModels), the view shows a static message — no functionality is lost for the rest of the app.
- `currentToolContext` is a global mutable variable. This is safe in practice because AI calls are sequential (one at a time from the UI), but it's an architectural smell to be aware of.
