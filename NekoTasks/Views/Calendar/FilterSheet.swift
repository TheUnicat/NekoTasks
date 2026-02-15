//
//  FilterSheet.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Modal sheet for filtering calendar events by type (recurring vs one-time) and
//  by label. Modifications are applied directly to CalendarState.filter, which
//  immediately affects the visible events in both day and week views.
//
//  ── FILTER LOGIC ──
//  • showRecurring / showOneTime: simple booleans toggled independently.
//  • labelIDs: when non-empty, acts as an allowlist — only events with at least
//    one matching label are shown. When empty, label filtering is disabled.
//  • "Reset all filters" restores EventFilter.all (everything visible).
//
//  ── AI CONTEXT ──
//  The actual filtering is performed by `[TaskItem].eventsOn(date:filter:)` defined
//  elsewhere. This sheet only modifies the filter state; it doesn't evaluate it.
//  LabelToggleRow is a private subview kept here since it's only used in this sheet.
//

import SwiftUI
import SwiftData

struct FilterSheet: View {
    @Environment(CalendarState.self) var state
    @Query private var allLabels: [TaskLabel]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var state = state

        NavigationStack {
            Form {
                Section("Event Types") {
                    Toggle("Recurring events", isOn: $state.filter.showRecurring)
                    Toggle("One-time events", isOn: $state.filter.showOneTime)
                }

                if !allLabels.isEmpty {
                    Section("Labels") {
                        ForEach(allLabels) { label in
                            LabelToggleRow(
                                label: label,
                                isSelected: state.filter.labelIDs.contains(label.persistentModelID)
                            ) { selected in
                                if selected {
                                    state.filter.labelIDs.insert(label.persistentModelID)
                                } else {
                                    state.filter.labelIDs.remove(label.persistentModelID)
                                }
                            }
                        }

                        if !state.filter.labelIDs.isEmpty {
                            Button("Clear label filter") {
                                state.filter.labelIDs.removeAll()
                            }
                        }
                    }
                }

                if !state.filter.isDefault {
                    Section {
                        Button("Reset all filters") {
                            state.filter = .all
                        }
                    }
                }
            }
            .navigationTitle("Filter Events")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Label Toggle Row

/// Single row in the label filter list. Displays a color dot, label name, and
/// checkmark when selected. Kept private to this file since it's only used here.
private struct LabelToggleRow: View {
    let label: TaskLabel
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isSelected)
        } label: {
            HStack {
                Circle()
                    .fill(labelColor)
                    .frame(width: 12, height: 12)
                Text(label.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var labelColor: Color {
        if let hex = label.colorHex, let color = Color(hex: hex) {
            return color
        }
        return .blue
    }
}
