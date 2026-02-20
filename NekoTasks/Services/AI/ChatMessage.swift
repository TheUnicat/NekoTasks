//
//  ChatMessage.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Pure data model for chat UI display. Not persisted to SwiftData.
//  Used only by AssistantView.
//

import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user
        case assistant
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}
