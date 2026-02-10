//
//  CalendarView.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Events tab. Queries only events (typeRaw==1). Shows events for a selected date with recurrence evaluation.
//  Main: CalendarView — date navigator + scrolling event list. Filters by recurring/one-time and labels.
//  New events created outside modelContext, inserted only on save (good cancel pattern).
//  Subviews: DateNavigator (prev/next/today/filter buttons), DatePickerSheet (graphical date picker),
//  FilterSheet (toggles for event types + label selection), LabelToggleRow, EmptyDayView.
//  EventFilter struct tracks filter state. eventOccursOn() evaluates recurrence rules via RecurrenceContext.
//  Listens for .addNewItem notification to create events from external triggers.
//

import SwiftUI
import SwiftData

// MARK: - Event Filter

struct EventFilter: Equatable {
    var showRecurring: Bool = true
    var showOneTime: Bool = true
    var labelIDs: Set<PersistentIdentifier> = []  // Empty = show all

    var isDefault: Bool {
        showRecurring && showOneTime && labelIDs.isEmpty
    }

    static let all = EventFilter()
}

// MARK: - Calendar View

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskItem> { $0.typeRaw == 1 })
    private var allEvents: [TaskItem]

    @State private var selectedDate: Date = Date()
    @State private var filter: EventFilter = .all
    @State private var showingFilterSheet = false
    @State private var showingDatePicker = false
    @State private var editingEvent: TaskItem?
    @State private var isCreatingNew = false

    private var eventsForSelectedDate: [TaskItem] {
        let context = RecurrenceContext(date: selectedDate)

        return allEvents
            .filter { event in
                // Apply visibility filters
                if event.recurrence && !filter.showRecurring { return false }
                if !event.recurrence && !filter.showOneTime { return false }

                // Apply label filter
                if !filter.labelIDs.isEmpty {
                    let eventLabelIDs = Set(event.labels.map { $0.persistentModelID })
                    if eventLabelIDs.isDisjoint(with: filter.labelIDs) { return false }
                }

                // Check if event occurs on selected date
                return eventOccursOn(event: event, context: context)
            }
            .sorted { a, b in
                // All-day events first, then by start time
                let aTime = a.startTime ?? Date.distantPast
                let bTime = b.startTime ?? Date.distantPast
                return aTime < bTime
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            DateNavigator(
                selectedDate: $selectedDate,
                showingDatePicker: $showingDatePicker,
                filter: $filter,
                showingFilterSheet: $showingFilterSheet
            )
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 12) {
                    if eventsForSelectedDate.isEmpty {
                        EmptyDayView()
                    } else {
                        ForEach(eventsForSelectedDate) { event in
                            EventCard(event: event) {
                                isCreatingNew = false
                                editingEvent = event
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(filter: $filter)
        }
        .sheet(item: $editingEvent) { event in
            ShowTask(
                task: event,
                onCancel: {
                    editingEvent = nil
                    isCreatingNew = false
                },
                onSave: {
                    if isCreatingNew {
                        let trimmed = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            editingEvent = nil
                            isCreatingNew = false
                            return
                        }
                        event.title = trimmed
                        modelContext.insert(event)
                    }
                    editingEvent = nil
                    isCreatingNew = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewItem)) { notification in
            if let tab = notification.object as? AppTab, tab == .calendar {
                addEvent()
            }
        }
    }

    private func addEvent() {
        isCreatingNew = true
        let newEvent = TaskItem(title: "", type: .event)
        // Default to selected date at 9 AM
        let calendar = Calendar.current
        newEvent.startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate)
        newEvent.endTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: selectedDate)
        editingEvent = newEvent
    }

    private func eventOccursOn(event: TaskItem, context: RecurrenceContext) -> Bool {
        let calendar = Calendar.current

        if event.recurrence {
            // Parse and evaluate recurrence rule
            if let ruleString = event.recurrenceRuleString,
               let rule = parseRule(from: ruleString) {
                return rule.matches(context: context)
            }
            // No valid rule = doesn't match
            return false
        } else {
            // One-time event: check if deadline or startTime is on selected date
            if let startTime = event.startTime {
                return calendar.isDate(startTime, inSameDayAs: context.date)
            }
            if let deadline = event.deadline {
                return calendar.isDate(deadline, inSameDayAs: context.date)
            }
            return false
        }
    }

    private func parseRule(from jsonString: String) -> AnyRule? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AnyRule.self, from: data)
    }
}

// MARK: - Date Navigator

struct DateNavigator: View {
    @Binding var selectedDate: Date
    @Binding var showingDatePicker: Bool
    @Binding var filter: EventFilter
    @Binding var showingFilterSheet: Bool

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 16) {
            // Previous day
            Button {
                moveDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.plain)

            // Date display (tappable)
            Button {
                showingDatePicker = true
            } label: {
                VStack(spacing: 2) {
                    Text(formattedDate)
                        .font(.headline)
                    Text(relativeDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Next day
            Button {
                moveDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.plain)

            Spacer()

            // Today button
            if !calendar.isDateInToday(selectedDate) {
                Button("Today") {
                    withAnimation {
                        selectedDate = Date()
                    }
                }
                .font(.subheadline)
                .buttonStyle(.bordered)
            }

            // Filter button
            Button {
                showingFilterSheet = true
            } label: {
                Image(systemName: filter.isDefault ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.title3)
                    .foregroundStyle(filter.isDefault ? .secondary : Color.blue)
            }
            .buttonStyle(.plain)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    private var relativeDate: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            return formatter.string(from: selectedDate)
        }
    }

    private func moveDate(by days: Int) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Go to Date")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Binding var filter: EventFilter
    @Query private var allLabels: [TaskLabel]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Types") {
                    Toggle("Recurring events", isOn: $filter.showRecurring)
                    Toggle("One-time events", isOn: $filter.showOneTime)
                }

                if !allLabels.isEmpty {
                    Section("Labels") {
                        ForEach(allLabels) { label in
                            LabelToggleRow(
                                label: label,
                                isSelected: filter.labelIDs.contains(label.persistentModelID)
                            ) { selected in
                                if selected {
                                    filter.labelIDs.insert(label.persistentModelID)
                                } else {
                                    filter.labelIDs.remove(label.persistentModelID)
                                }
                            }
                        }

                        if !filter.labelIDs.isEmpty {
                            Button("Clear label filter") {
                                filter.labelIDs.removeAll()
                            }
                        }
                    }
                }

                if !filter.isDefault {
                    Section {
                        Button("Reset all filters") {
                            filter = .all
                        }
                    }
                }
            }
            .navigationTitle("Filter Events")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

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

// MARK: - Empty Day View

struct EmptyDayView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No events")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Nothing scheduled for this day")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Preview

#Preview {
    CalendarView()
        .modelContainer(for: [TaskItem.self, TaskLabel.self], inMemory: true)
}
