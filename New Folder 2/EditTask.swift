//
//  EditTask.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  UNUSED — older navigation-based task editor. Tasks only (no event support, no type picker,
//  no recurrence). Has title, description, deadline toggle+DatePicker, hours/minutes steppers.
//  Superseded by ShowTask which handles both tasks and events with recurrence.
//  Candidate for deletion.
//

import SwiftUI
import SwiftData

struct EditTask: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem

    let onCancel: (() -> Void)?
    let onSave: (() -> Void)?

    @State private var title: String
    @State private var details: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var hours: Int
    @State private var minutes: Int

    init(
        task: TaskItem,
        onCancel: (() -> Void)? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self.task = task
        self.onCancel = onCancel
        self.onSave = onSave

        _title = State(initialValue: task.title)
        _details = State(initialValue: task.taskDescription ?? "")

        let initialDeadline = task.deadline
        _hasDeadline = State(initialValue: initialDeadline != nil)
        _deadline = State(initialValue: initialDeadline ?? Date())

        let seconds = Int(task.timeEstimate ?? 0)
        _hours = State(initialValue: seconds / 3600)
        _minutes = State(initialValue: (seconds % 3600) / 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Description", text: $details)

                Toggle("Has deadline", isOn: $hasDeadline)

                if hasDeadline {
                    DatePicker(
                        "Deadline",
                        selection: $deadline,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                HStack {
                    Stepper("Hours: \(hours)", value: $hours, in: 0...24)
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...59)
                }


                Text("Created \(task.creationDate.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)

            }
            .navigationTitle(task.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Delete", role: .destructive) {
                        modelContext.delete(task)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let onCancel { onCancel() }
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        commitEdits()
                        if let onSave { onSave() }
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func commitEdits() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.title = trimmedTitle

        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        task.taskDescription = trimmedDetails.isEmpty ? nil : trimmedDetails

        task.deadline = hasDeadline ? deadline : nil

        let totalSeconds = hours * 3600 + minutes * 60
        let total = TimeInterval(totalSeconds)
        task.timeEstimate = totalSeconds > 0 ? total : nil
    }
}

#Preview {
    EditTask(
        task: TaskItem(title: "Preview"),
        onCancel: {},
        onSave: {}
    )
    .modelContainer(for: TaskItem.self, inMemory: true)
}
