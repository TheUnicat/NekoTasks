//
//  AIPipeline.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Public-facing @Observable orchestrator. Owns the provider and manages ToolExecutionContext
//  lifecycle (set before send, cleared after via defer). Saves SwiftData when tools create items.
//
//  Session lifecycle:
//  - Session is built LAZILY on the first send() call so that buildSystemPrompt() has a real
//    ModelContext and can inject live labels/tasks into the prompt.
//  - resetSession() sets sessionNeedsRebuild = true; the next send() rebuilds with fresh data.
//  - This means "clear chat" + first new message always picks up the latest labels/tasks.
//
//  KNOWN ISSUES / LESSONS:
//  - The on-device 3B model is unreliable with tool calling. System instructions must be very directive.
//  - Tool arguments must be as simple as possible. Use String? for optional fields.
//  - Events MUST have startTime set or they won't appear in CalendarView.
//  - Always explicit modelContext.save() after tool insertions from async contexts.
//

import Foundation
import SwiftData
import FoundationModels

@available(iOS 26, macOS 26, *)
@MainActor
@Observable
class AIPipeline {
    private var provider: any AIProvider
    private var sessionNeedsRebuild = true

    init() {
        provider = AppleFoundationProvider()
        // Session is intentionally NOT built here — we need ModelContext for a rich prompt.
        // It will be built on the first send() call.
    }

    /// Call after clearing the chat. The next send() will rebuild the session with fresh context.
    func resetSession() {
        sessionNeedsRebuild = true
    }

    func send(message: String, modelContext: ModelContext) async throws -> String {
        if sessionNeedsRebuild {
            provider.resetSession(systemPrompt: AIPromptBuilder.buildSystemPrompt(modelContext: modelContext))
            sessionNeedsRebuild = false
        }

        let context = ToolExecutionContext(modelContext: modelContext)
        currentToolContext = context
        defer { currentToolContext = nil }

        let response = try await provider.send(message: message)

        if !context.createdItems.isEmpty {
            do {
                try modelContext.save()
            } catch {
                print("NekoTasks: Failed to save AI-created items: \(error)")
            }
        }
        return response
    }
}
