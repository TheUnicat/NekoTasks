//
//  CalendarView.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Events tab. Queries only events (typeRaw==1). Shows events for a selected date with recurrence evaluation.
//  CalendarState (@Observable) holds shared UI state: selectedDate, filter, viewType, sheet toggles.
//  CalendarView is the root — owns @Query, date filtering logic, and sheet presentation.
//  Delegates to DayView or WeekView based on calendarPeriod toggle.
//  DateNavigator handles day/week picker + date nav (chevrons, today/this week, filter).
//  WeekView renders a time-grid with 7 DayColumns and a TimeGutter.
//  EventWeekBlock is a compact event representation for the week grid.
//

import SwiftUI
import SwiftData

// MARK: - Calendar State

enum CalendarPeriod: String, CaseIterable, Hashable {
    case day = "Day"
    case week = "Week"
}

@Observable
class CalendarState {
    var selectedDate: Date = Date()
    var filter: EventFilter = .all
    var showingFilterSheet = false
    var showingDatePicker = false
    var editingEvent: TaskItem?
    var isCreatingNew = false
    var viewType: CalendarPeriod = .day
}

// MARK: - Event Filter

struct EventFilter: Equatable {
    var showRecurring: Bool = true
    var showOneTime: Bool = true
    var labelIDs: Set<PersistentIdentifier> = []

    var isDefault: Bool {
        showRecurring && showOneTime && labelIDs.isEmpty
    }

    static let all = EventFilter()
}

// MARK: - Calendar View (Root)

struct CalendarView: View {
    @Environment(CalendarState.self) var state
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<TaskItem> { $0.typeRaw == 1 })
    private var allEvents: [TaskItem]

    private let calendar = Calendar.current

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 0) {
            DateNavigator()
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            switch state.viewType {
            case .day:
                DayEventList(events: eventsForSelectedDate)
            case .week:
                WeekView(allEvents: allEvents)
            }
        }
        .sheet(isPresented: $state.showingDatePicker) {
            DatePickerSheet()
        }
        .sheet(isPresented: $state.showingFilterSheet) {
            FilterSheet()
        }
        .sheet(item: $state.editingEvent) { event in
            ShowTask(
                task: event,
                onCancel: {
                    state.editingEvent = nil
                    state.isCreatingNew = false
                },
                onSave: {
                    if state.isCreatingNew {
                        let trimmed = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            state.editingEvent = nil
                            state.isCreatingNew = false
                            return
                        }
                        event.title = trimmed
                        modelContext.insert(event)
                    }
                    state.editingEvent = nil
                    state.isCreatingNew = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewItem)) { notification in
            if let tab = notification.object as? AppTab, tab == .calendar {
                addEvent()
            }
        }
    }

    private var eventsForSelectedDate: [TaskItem] {
        allEvents.eventsOn(date: state.selectedDate, filter: state.filter)
    }

    private func addEvent() {
        state.isCreatingNew = true
        let newEvent = TaskItem(title: "", type: .event)
        newEvent.startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: state.selectedDate)
        newEvent.endTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: state.selectedDate)
        state.editingEvent = newEvent
    }

    private func parseRule(from jsonString: String) -> AnyRule? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AnyRule.self, from: data)
    }
}

// MARK: - Date Navigator

struct DateNavigator: View {
    @Environment(CalendarState.self) var state

    private let calendar = Calendar.current

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 8) {
            // Day/Week segmented picker
            Picker("", selection: $state.viewType) {
                ForEach(CalendarPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            // Date navigation row
            ZStack {
                // Centered: chevrons + date
                HStack(spacing: 20) {
                    Button {
                        moveDate(by: state.viewType == .day ? -1 : -7)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.showingDatePicker = true
                    } label: {
                        VStack(spacing: 2) {
                            Text(dateTitle)
                                .font(.headline)
                            Text(dateSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 180)
                    }
                    .buttonStyle(.plain)

                    Button {
                        moveDate(by: state.viewType == .day ? 1 : 7)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3.weight(.semibold))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                }

                // Right-aligned: today/this week + filter
                HStack {
                    Spacer()

                    if !isCurrentPeriod {
                        Button(state.viewType == .day ? "Today" : "This Week") {
                            withAnimation {
                                state.selectedDate = Date()
                            }
                        }
                        .font(.subheadline)
                        .buttonStyle(.bordered)
                    }

                    Button {
                        state.showingFilterSheet = true
                    } label: {
                        Image(systemName: state.filter.isDefault
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                            .font(.title3)
                            .foregroundStyle(state.filter.isDefault ? .secondary : Color.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Date Display

    private var dateTitle: String {
        let formatter = DateFormatter()
        switch state.viewType {
        case .day:
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: state.selectedDate)
        case .week:
            let (start, end) = weekBounds
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: start)
            // If week spans two months, show both; otherwise just show end day
            if calendar.component(.month, from: start) == calendar.component(.month, from: end) {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "d"
                return "\(startStr) – \(dayFormatter.string(from: end))"
            } else {
                return "\(startStr) – \(formatter.string(from: end))"
            }
        }
    }

    private var dateSubtitle: String {
        switch state.viewType {
        case .day:
            if calendar.isDateInToday(state.selectedDate) {
                return "Today"
            } else if calendar.isDateInYesterday(state.selectedDate) {
                return "Yesterday"
            } else if calendar.isDateInTomorrow(state.selectedDate) {
                return "Tomorrow"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy"
                return formatter.string(from: state.selectedDate)
            }
        case .week:
            let (start, _) = weekBounds
            if calendar.isDate(start, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy"
                return formatter.string(from: state.selectedDate)
            }
        }
    }

    private var isCurrentPeriod: Bool {
        switch state.viewType {
        case .day:
            return calendar.isDateInToday(state.selectedDate)
        case .week:
            let (start, _) = weekBounds
            return calendar.isDate(start, equalTo: Date(), toGranularity: .weekOfYear)
        }
    }

    private var weekBounds: (start: Date, end: Date) {
        var start = state.selectedDate
        var interval: TimeInterval = 0
        _ = calendar.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: state.selectedDate)
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        return (start, end)
    }

    private func moveDate(by days: Int) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if let newDate = calendar.date(byAdding: .day, value: days, to: state.selectedDate) {
                state.selectedDate = newDate
            }
        }
    }
}

// MARK: - Day Event List

struct DayEventList: View {
    let events: [TaskItem]
    @Environment(CalendarState.self) var state

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if events.isEmpty {
                    EmptyDayView()
                } else {
                    ForEach(events) { event in
                        EventCard(event: event) {
                            state.isCreatingNew = false
                            state.editingEvent = event
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

// MARK: - Week View

struct WeekView: View {
    let allEvents: [TaskItem]
    @Environment(CalendarState.self) var state

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    private let gutterWidth: CGFloat = 50
    private let startHour = 0
    private let endHour = 24

    private var weekDates: [Date] {
        var start = state.selectedDate
        var interval: TimeInterval = 0
        _ = calendar.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: state.selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Week header row
            WeekHeaderRow(dates: weekDates)
                .padding(.leading, gutterWidth)

            Divider()

            // Time grid
            ScrollView(.vertical) {
                ScrollViewReader { proxy in
                    HStack(alignment: .top, spacing: 0) {
                        TimeGutter(startHour: startHour, endHour: endHour, hourHeight: hourHeight)
                            .frame(width: gutterWidth)

                        ForEach(weekDates, id: \.self) { date in
                            DayColumn(
                                date: date,
                                allEvents: allEvents,
                                hourHeight: hourHeight,
                                startHour: startHour,
                                endHour: endHour
                            )
                        }
                    }
                    .onAppear {
                        // Scroll to ~8 AM on appear
                        proxy.scrollTo("hour-8", anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - Week Header Row

struct WeekHeaderRow: View {
    let dates: [Date]
    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
                VStack(spacing: 2) {
                    Text(dayOfWeekShort(date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(calendar.component(.day, from: date))")
                        .font(.subheadline.weight(calendar.isDateInToday(date) ? .bold : .regular))
                        .foregroundStyle(calendar.isDateInToday(date) ? .white : .primary)
                        .frame(width: 28, height: 28)
                        .background {
                            if calendar.isDateInToday(date) {
                                Circle().fill(Color.blue)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
    }

    private func dayOfWeekShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Time Gutter

struct TimeGutter: View {
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                Text(hourLabel(hour))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(height: hourHeight, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 4)
                    .offset(y: -6) // Align text with grid line
                    .id("hour-\(hour)")
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
}

// MARK: - Day Column (Week Grid)

struct DayColumn: View {
    let date: Date
    let allEvents: [TaskItem]
    let hourHeight: CGFloat
    let startHour: Int
    let endHour: Int

    @Environment(CalendarState.self) var state

    private let calendar = Calendar.current

    private var totalHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hour grid lines
            VStack(spacing: 0) {
                ForEach(startHour..<endHour, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: hourHeight)
                        .overlay(alignment: .top) {
                            Divider()
                        }
                }
            }

            // Current time indicator
            if calendar.isDateInToday(date) {
                CurrentTimeIndicator(hourHeight: hourHeight, startHour: startHour)
            }

            // Events
            ForEach(allEvents.eventsOn(date: date, filter: state.filter)) { event in
                EventWeekBlock(event: event)
                    .frame(height: eventHeight(event))
                    .offset(y: eventYOffset(event))
                    .padding(.horizontal, 1)
                    .onTapGesture {
                        state.isCreatingNew = false
                        state.editingEvent = event
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
    }

    private func eventYOffset(_ event: TaskItem) -> CGFloat {
        guard let startTime = event.startTime else { return 0 }
        let components = calendar.dateComponents([.hour, .minute], from: startTime)
        let minutesSinceStart = CGFloat((components.hour ?? 0) - startHour) * 60 + CGFloat(components.minute ?? 0)
        let totalMinutes = CGFloat(endHour - startHour) * 60
        return (minutesSinceStart / totalMinutes) * totalHeight
    }

    private func eventHeight(_ event: TaskItem) -> CGFloat {
        guard let startTime = event.startTime, let endTime = event.endTime else {
            return hourHeight / 2 // Default: 30 min block
        }
        let duration = endTime.timeIntervalSince(startTime) / 60 // minutes
        let totalMinutes = CGFloat(endHour - startHour) * 60
        return max(CGFloat(duration) / totalMinutes * totalHeight, 20) // Min height 20
    }
}

// MARK: - Current Time Indicator

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    let startHour: Int

    private var yOffset: CGFloat {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        let minutesSinceStart = CGFloat((components.hour ?? 0) - startHour) * 60 + CGFloat(components.minute ?? 0)
        let totalMinutes = CGFloat(24 - startHour) * 60
        let totalHeight = CGFloat(24 - startHour) * hourHeight
        return (minutesSinceStart / totalMinutes) * totalHeight
    }

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
        .offset(y: yOffset - 4) // Center the circle on the line
    }
}

// MARK: - Event Week Block (Compact)

struct EventWeekBlock: View {
    let event: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(event.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .foregroundStyle(.white)
        }
        .padding(2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(eventColor.cornerRadius(3))
    }

    private var eventColor: Color {
        // Use first label color if available, otherwise default
        if let firstLabel = event.labels.first,
           let hex = firstLabel.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .blue
    }
}

// MARK: - Date Picker Sheet

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

// MARK: - Filter Sheet

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
        .environment(CalendarState())
        .modelContainer(for: [TaskItem.self, TaskLabel.self], inMemory: true)
}
