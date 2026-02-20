//
//  ToolExecutionContext.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Mutable context passed to AI tools via a global so they can access SwiftData.
//  Only AIPipeline writes currentToolContext (set before send, cleared after via defer).
//  Tools read it in call(arguments:). The global is unavoidable because Apple's Tool
//  protocol provides no way to inject dependencies into call(arguments:).
//

import SwiftData

/// Passed to tools via a global so they can access the model context for database operations.
/// Set by AIPipeline before each AI call, cleared after (via defer).
class ToolExecutionContext {
    let modelContext: ModelContext?
    var createdItems: [String] = []

    init(modelContext: ModelContext?) {
        self.modelContext = modelContext
    }
}

@MainActor
var currentToolContext: ToolExecutionContext?
