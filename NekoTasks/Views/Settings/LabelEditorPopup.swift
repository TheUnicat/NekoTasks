//
//  LabelEditorPopup.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Modal form for creating or editing a single TaskLabel. Presented as a sheet
//  from SettingsView's LabelSettingsSection.
//
//  ── BEHAVIOR ──
//  • Always receives a TaskLabel to edit (which may or may not be in the model
//    context yet). Writes name/color back to the label on save.
//  • Follows the same dismiss pattern as ShowTask: the `onCancel`/`onSave`
//    callbacks nil the parent's item binding, then `dismiss()` is called.
//  • The parent decides whether to insert the label into the model context
//    (for new labels) — this popup only writes properties.
//
//  ── PROPERTIES ──
//  • `label` — The TaskLabel to edit. May be new (not yet inserted) or existing.
//  • `onCancel` / `onSave` — Callbacks for the parent to nil its sheet binding.
//  • `name` / `selectedColor` — Local draft state initialized from the label.
//

import SwiftUI
import SwiftData

struct LabelEditorPopup: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var label: TaskLabel

    let onCancel: (() -> Void)?
    let onSave: (() -> Void)?

    @State private var name: String
    @State private var selectedColor: Color

    init(
        label: TaskLabel,
        onCancel: (() -> Void)? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self.label = label
        self.onCancel = onCancel
        self.onSave = onSave

        _name = State(initialValue: label.name)

        if let hex = label.colorHex, let color = Color(hex: hex) {
            _selectedColor = State(initialValue: color)
        } else {
            _selectedColor = State(initialValue: .blue)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(label.modelContext == nil ? "New Label" : "Edit Label")
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
                    commitEdits()
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

    private func commitEdits() {
        label.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        label.colorHex = selectedColor.toHex()
    }
}

#Preview {
    LabelEditorPopup(
        label: TaskLabel(name: "", colorHex: nil),
        onCancel: {},
        onSave: {}
    )
    .modelContainer(for: [TaskItem.self, TaskLabel.self], inMemory: true)
}
