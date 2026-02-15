//
//  DatePickerSheet.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Modal sheet with a graphical date picker. Presented when the user taps the
//  date title in DateNavigator. Binds directly to CalendarState.selectedDate
//  so the selection takes effect immediately.
//
//  ── AI CONTEXT ──
//  Minimal view — just a DatePicker and a Done button. Presented at .medium detent.
//

import SwiftUI

struct DatePickerSheet: View {
    @Environment(CalendarState.self) var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var state = state

        NavigationStack {
            DatePicker(
                "Select Date",
                selection: $state.selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Go to Date")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
