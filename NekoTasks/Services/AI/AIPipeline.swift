//
//  AIPipeline.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Public-facing @Observable orchestrator. Owns the provider, manages ToolExecutionContext
//  lifecycle (set before send, cleared after via defer), and saves SwiftData when tools
//  create items. AssistantView passes modelContext into send() instead of setting the
//  global externally — the defer guarantees cleanup even on error.
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

    init() {
        let p = AppleFoundationProvider()
        provider = p
        p.resetSession(systemPrompt: AIPromptBuilder.buildSystemPrompt())
    }

    func resetSession() {
        provider.resetSession(systemPrompt: AIPromptBuilder.buildSystemPrompt())
    }

    func send(message: String, modelContext: ModelContext) async throws -> String {
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
