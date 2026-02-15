//
//  LabelEditorPopup.swift
//  NekoTasks
//

import SwiftUI
import SwiftData

struct LabelEditorPopup: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingLabel: TaskLabel?
    var onCancel: (() -> Void)?
    var onSave: (() -> Void)?

    @State private var name: String
    @State private var selectedColor: Color

    init(
        existingLabel: TaskLabel? = nil,
        onCancel: (() -> Void)? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self.existingLabel = existingLabel
        self.onCancel = onCancel
        self.onSave = onSave

        _name = State(initialValue: existingLabel?.name ?? "")

        if let hex = existingLabel?.colorHex, let color = Color(hex: hex) {
            _selectedColor = State(initialValue: color)
        } else {
            _selectedColor = State(initialValue: .blue)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(existingLabel == nil ? "New Label" : "Edit Label")
                .font(.title2.bold())
                .padding()

            Form {
                Section {
                    #if os(macOS)
                    HStack {
                        Text("Name")
                            .font(.body)
                            .foregroundStyle(.primary)
                        LeftTextField(placeholder: "Label name", text: $name, font: .systemFont(ofSize: NSFont.systemFontSize))
                            .frame(maxWidth: 600)
                    }
                    #else
                    TextField("Name", text: $name)
                    #endif
                }

                Section {
                    ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                }

                Section {
                    HStack {
                        Text("Preview")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(name.isEmpty ? "Label" : name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(selectedColor.opacity(0.15))
                            )
                            .foregroundStyle(selectedColor)
                    }
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

                Button("Save") {
                    commitLabel()
                    onSave?()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 350, idealWidth: 400, minHeight: 300)
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, Locale(identifier: "en_US"))
    }

    private func commitLabel() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = selectedColor.toHex()

        if let existingLabel {
            existingLabel.name = trimmedName
            existingLabel.colorHex = hex
        } else {
            let label = TaskLabel(name: trimmedName, colorHex: hex)
            modelContext.insert(label)
        }
    }
}

#Preview {
    LabelEditorPopup()
        .modelContainer(for: [TaskItem.self, TaskLabel.self], inMemory: true)
}
