//
//  ShowTask.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Primary editor for both tasks and events. Presented as a sheet from TasksView and CalendarView.
//  Layout: title field at top, segmented Task/Event picker, grouped Form with context-dependent sections,
//  Cancel/Delete/Save buttons at bottom. Uses local @State copies of all fields — only commits on Save.
//  Includes LeftTextField (macOS NSViewRepresentable) for left-aligned text input without SwiftUI quirks.
//  Event mode integrates RecurrenceRulePicker. Date/time input is text-based (MM/DD HH:MM format)
//  with custom parseDateTime/parseTimeEstimate. onCancel/onSave callbacks for CalendarView's
//  create-then-insert pattern. Min size 350x450.
//

import SwiftUI
import SwiftData

private struct SubtaskDraft: Identifiable {
    let id = UUID()
    var title: String
    var deadlineText: String
    var timeEstimateText: String
    var isCompleted: Bool

    init(title: String = "", deadlineText: String = "", timeEstimateText: String = "", isCompleted: Bool = false) {
        self.title = title
        self.deadlineText = deadlineText
        self.timeEstimateText = timeEstimateText
        self.isCompleted = isCompleted
    }
}

#if os(macOS)
struct LeftTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.stringValue = text
        field.font = font
        field.baseWritingDirection = .leftToRight
        field.focusRingType = .none
        field.alignment = .left
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.isBordered = false
        field.backgroundColor = .clear
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.font = font
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                text = field.stringValue
            }
        }
    }
}
#endif



struct ShowTask: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem

    let onCancel: (() -> Void)?
    let onSave: (() -> Void)?

    @State private var title: String
    @State private var details: String
    @State private var importance: String
    @State private var location: String
    @State private var selectedType: ItemType
    @State private var deadlineText: String
    @State private var timeEstimateText: String
    @State private var startTimeText: String
    @State private var endTimeText: String
    @State private var isRecurring: Bool
    @State private var rule: AnyRule?
    @State private var subtaskDrafts: [SubtaskDraft] = []
    @State private var selectedLabelIDs: Set<PersistentIdentifier> = []
    @Query private var allLabels: [TaskLabel]

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
        _importance = State(initialValue: task.importance.map { String($0) } ?? "")
        _location = State(initialValue: task.locationName ?? "")
        _selectedType = State(initialValue: task.type)
        _startTimeText = State(initialValue: Self.formatDateTime(task.startTime))
        _deadlineText = State(initialValue: Self.formatDateTime(task.deadline))
        _endTimeText = State(initialValue: Self.formatDateTime(task.endTime))

        let seconds = Int(task.timeEstimate ?? 0)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        _timeEstimateText = State(initialValue: seconds > 0 ? (m > 0 ? "\(h):\(String(format: "%02d", m))" : "\(h)") : "")

        _isRecurring = State(initialValue: task.recurrence)
        _rule = State(initialValue: task.recurrenceRule)

        let drafts = task.subTasks.sorted { $0.sortOrder < $1.sortOrder }.map { sub in
            let secs = Int(sub.timeEstimate ?? 0)
            let sh = secs / 3600
            let sm = (secs % 3600) / 60
            return SubtaskDraft(
                title: sub.title,
                deadlineText: Self.formatDateTime(sub.deadline),
                timeEstimateText: secs > 0 ? "\(sh):\(String(format: "%02d", sm))" : "",
                isCompleted: sub.isCompleted
            )
        }
        _subtaskDrafts = State(initialValue: drafts)
        _selectedLabelIDs = State(initialValue: Set(task.labels.map { $0.persistentModelID }))
    }

    // Platform-appropriate text field
    @ViewBuilder
    private func inputField(
        _ label: String,
        text: Binding<String>,
        placeholder: String = ""
    ) -> some View {
        #if os(macOS)
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
            LeftTextField(placeholder: placeholder, text: text, font: .systemFont(ofSize: NSFont.systemFontSize))
                .frame(maxWidth: 600)
        }
        #else
        TextField(label, text: text)
        #endif
    }

    @ViewBuilder
    private func titleField(
        text: Binding<String>,
        placeholder: String = ""
    ) -> some View {
        #if os(macOS)
        HStack {
            LeftTextField(placeholder: placeholder, text: text, font: .systemFont(ofSize: 22, weight: .bold))
                .frame(maxWidth: 600)
        }
        #else
        TextField("Title", text: text)
            .font(.title.bold())
        #endif
    }


    var body: some View {
        VStack(spacing: 0) {
            titleField(
                text: $title,
                placeholder: "Title"
            )
            .padding().multilineTextAlignment(.trailing)

            Picker("Type", selection: $selectedType) {
                Text("Task").tag(ItemType.task)
                Text("Event").tag(ItemType.event)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.bottom)

            Form {
                Section {
                    inputField("Notes", text: $details)
                }

                if selectedType == .task {
                    Section("Task") {
                        inputField("Deadline", text: $deadlineText, placeholder: "MM/DD or YYYY/MM/DD")
                        inputField("Estimate", text: $timeEstimateText, placeholder: "H:MM")
                    }

                    Section("Subtasks") {
                        ForEach($subtaskDrafts) { $draft in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    TextField("Subtask title", text: $draft.title)
                                    Button {
                                        if let idx = subtaskDrafts.firstIndex(where: { $0.id == draft.id }) {
                                            subtaskDrafts.remove(at: idx)
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                HStack(spacing: 16) {
                                    HStack(spacing: 4) {
                                        Text("Due")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("MM/DD", text: $draft.deadlineText)
                                            .font(.caption)
                                            .frame(maxWidth: 80)
                                    }
                                    HStack(spacing: 4) {
                                        Text("Est.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("H:MM", text: $draft.timeEstimateText)
                                            .font(.caption)
                                            .frame(maxWidth: 60)
                                    }
                                }
                            }
                        }

                        Button {
                            subtaskDrafts.append(SubtaskDraft())
                        } label: {
                            Label("Add Subtask", systemImage: "plus.circle")
                                .font(.subheadline)
                        }
                    }
                } else {
                    Section("Event") {
                        inputField("Start", text: $startTimeText, placeholder: "MM/DD HH:MM")
                        inputField("End", text: $endTimeText, placeholder: "MM/DD HH:MM")
                    }

                    RecurrenceRulePicker(rule: $rule, isRecurring: $isRecurring)
                }
                Section {
                    inputField("Priority", text: $importance, placeholder: "1-5")
                    inputField("Location", text: $location)
                }

                Section("Labels") {
                    LabelFlowPicker(selectedLabelIDs: $selectedLabelIDs)
                }

                Section {
                    Text("Created \(task.creationDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    onCancel?()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if task.modelContext != nil {
                    Button("Delete", role: .destructive) {
                        modelContext.delete(task)
                        dismiss()
                    }
                }

                Button("Save") {
                    commitEdits()
                    onSave?()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 350, idealWidth: 400, minHeight: 450)
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
    }

    // MARK: - Parsing

    private func parseDateTime(_ input: String) -> Date? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: " ", maxSplits: 1)
        let datePart = String(parts[0])
        let timePart = parts.count > 1 ? String(parts[1]) : nil

        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        let dateComponents = datePart.split(separator: "/").map { String($0) }
        var year = currentYear
        var month = currentMonth
        var day = 1

        switch dateComponents.count {
        case 1:
            guard let d = Int(dateComponents[0]) else { return nil }
            day = d
        case 2:
            guard let m = Int(dateComponents[0]), let d = Int(dateComponents[1]) else { return nil }
            month = m
            day = d
        case 3:
            guard let y = Int(dateComponents[0]), let m = Int(dateComponents[1]), let d = Int(dateComponents[2]) else { return nil }
            year = y < 100 ? 2000 + y : y
            month = m
            day = d
        default:
            return nil
        }

        var hour = 0
        var minute = 0
        if let timePart {
            let timeComponents = timePart.split(separator: ":").map { String($0) }
            if let h = Int(timeComponents[0]) { hour = h }
            if timeComponents.count > 1, let m = Int(timeComponents[1]) {
                minute = min(59, max(0, m))
            }
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    private func parseTimeEstimate(_ input: String) -> TimeInterval? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":").map { String($0) }
        guard let hours = Int(parts[0]) else { return nil }

        var minutes = 0
        if parts.count > 1, let m = Int(parts[1]) {
            minutes = min(59, max(0, m))
        }

        let total = hours * 3600 + minutes * 60
        return total > 0 ? TimeInterval(total) : nil
    }

    private static func formatDateTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let calendar = Calendar.current
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        let h = calendar.component(.hour, from: date)
        let min = calendar.component(.minute, from: date)

        if h == 0 && min == 0 {
            return "\(y)/\(m)/\(d)"
        }
        return "\(y)/\(m)/\(d) \(h):\(String(format: "%02d", min))"
    }

    private func commitSubtasks() {
        guard selectedType == .task else { return }

        for subtask in task.subTasks where subtask.modelContext != nil {
            modelContext.delete(subtask)
        }
        task.subTasks = []

        for (index, draft) in subtaskDrafts.enumerated() {
            let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let subtask = TaskItem(title: title, type: .task)
            subtask.deadline = parseDateTime(draft.deadlineText)
            subtask.timeEstimate = parseTimeEstimate(draft.timeEstimateText)
            subtask.sortOrder = index
            subtask.isCompleted = draft.isCompleted
            subtask.parent = task
            task.subTasks.append(subtask)
        }
    }

    private func commitEdits() {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.taskDescription = details.isEmpty ? nil : details
        task.type = selectedType
        task.importance = Int(importance)
        task.locationName = location.isEmpty ? nil : location

        if selectedType == .task {
            task.deadline = parseDateTime(deadlineText)
            task.timeEstimate = parseTimeEstimate(timeEstimateText)
            task.startTime = nil
            task.endTime = nil
            task.recurrence = false
            commitSubtasks()
        } else if selectedType == .event {
            task.startTime = parseDateTime(startTimeText)
            task.endTime = parseDateTime(endTimeText)
            task.deadline = nil
            task.timeEstimate = nil
            task.recurrence = isRecurring
            print("Rule: \(rule?.toJSON() ?? "nil")")
            task.recurrenceRule = isRecurring ? rule : nil
        }

        task.labels = allLabels.filter { selectedLabelIDs.contains($0.persistentModelID) }
    }
}

#Preview {
    ShowTask(
        task: TaskItem(title: "Preview"),
        onCancel: {},
        onSave: {}
    )
    .modelContainer(for: TaskItem.self, inMemory: true)
}
