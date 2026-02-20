//
//  CreateLabelTool.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Reads currentToolContext (global) to get ModelContext.
//  Maps color names to hex strings via colorMap.
//

import Foundation
import SwiftData
import FoundationModels

@available(iOS 26, macOS 26, *)
@MainActor
final class CreateLabelTool: Tool {
    let name = "create_label"
    let description = "Create a label/tag for organizing tasks and events."

    @Generable
    struct Arguments {
        @Guide(description: "The name of the label")
        var name: String

        @Guide(description: "Color name", .anyOf(["red", "orange", "yellow", "green", "teal", "blue", "indigo", "purple", "pink", "gray"]))
        var color: String?
    }

    private let colorMap: [String: String] = [
        "red": "E53935", "orange": "FB8C00", "yellow": "FDD835",
        "green": "43A047", "teal": "00897B", "blue": "1E88E5",
        "indigo": "3949AB", "purple": "8E24AA", "pink": "D81B60",
        "gray": "757575"
    ]

    func call(arguments: Arguments) async throws -> String {
        let context = currentToolContext ?? ToolExecutionContext(modelContext: nil)

        let colorHex = arguments.color.flatMap { colorMap[$0.lowercased()] }
        let label = TaskLabel(name: arguments.name, colorHex: colorHex)

        if let modelContext = context.modelContext {
            modelContext.insert(label)
            context.createdItems.append("label: \(arguments.name)")
            return "Created label '\(arguments.name)'"
        }
        return "Created label '\(arguments.name)' (not persisted)"
    }
}
