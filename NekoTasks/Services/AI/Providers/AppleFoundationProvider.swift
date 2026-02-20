//
//  AppleFoundationProvider.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Wraps LanguageModelSession. Registers the three tools internally.
//  resetSession() creates a fresh LanguageModelSession with the given prompt string.
//  lastSystemPrompt allows self-recovery if session is somehow nil at send time.
//

import Foundation
import FoundationModels

@available(iOS 26, macOS 26, *)
@MainActor
final class AppleFoundationProvider: AIProvider {
    private var session: LanguageModelSession?
    private var lastSystemPrompt: String = ""

    func send(message: String) async throws -> String {
        guard let session else {
            resetSession(systemPrompt: lastSystemPrompt)
            return try await send(message: message)
        }
        let result = try await session.respond(to: message)
        return result.content
    }

    func resetSession(systemPrompt: String) {
        lastSystemPrompt = systemPrompt
        let tools: [any Tool] = [
            CreateTaskTool(),
            CreateEventTool(),
            CreateLabelTool()
        ]
        session = LanguageModelSession(tools: tools) {
            systemPrompt
        }
    }
}
