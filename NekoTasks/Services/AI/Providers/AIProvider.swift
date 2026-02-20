//
//  AIProvider.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Protocol abstracting over the AI session/model backend so AIPipeline doesn't care
//  what's underneath. Tools are NOT in the protocol — each provider owns tool registration
//  internally (Apple's Tool protocol is FoundationModels-specific; a future OpenAI provider
//  would use JSON function schemas instead).
//

import Foundation

@MainActor
protocol AIProvider {
    func send(message: String) async throws -> String
    func resetSession(systemPrompt: String)
}
