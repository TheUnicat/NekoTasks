//
//  RecurrenceRuleUI.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Full recurrence rule builder UI. Integrated into ShowTask's event mode.
//  Main: RecurrenceRulePicker — toggle repeats, pick weekly/monthly, configure pattern, optional date range,
//  live rule preview text. Constructs AnyRule via constructedRule computed property, syncs to binding via onChange.
//  On appear, loadFromRule() decomposes an existing AnyRule back into internal @State (selectedWeekdays,
//  repeatType, etc.) via recursive decompose(). Handles .and() composites by processing both sides.
//  Without this, editing an existing event would show blank picker defaults instead of the current rule.
//  Subcomponents: WeekdayPicker (M-Su circle buttons + quick selects), DayOfMonthPicker (1-31 grid),
//  WeekOfMonthPicker (1st-5th week + weekday + last week toggle), DayButton, QuickSelectButton.
//  RecurrenceRulePickerForm is an alternative wrapper that binds directly to a TaskItem (not currently used).
//
//  KNOWN ISSUES / LESSONS:
//  - onChange(of: constructedRule) does NOT fire on initial render (no previous value to compare).
//    The onAppear + loadFromRule ensures the picker's internal state matches the existing rule.
//  - For .and() composites, decompose() is recursive — it handles nested patterns like
//    .and(.and(.weekdays, .everyOtherWeek), .dateRange) correctly.
//  - The picker's internal state → constructedRule → onChange → parent binding flow is one-directional.
//    The parent binding is only READ on appear (via loadFromRule), then WRITTEN via onChange thereafter.
//

import SwiftUI

// MARK: - Main Recurrence Picker

struct RecurrenceRulePicker: View {
    @Binding var rule: AnyRule?
    @Binding var isRecurring: Bool

    @State private var repeatType: RepeatType = .weekly
    @State private var selectedWeekdays: Set<Weekday> = []
    @State private var monthlyMode: MonthlyMode = .dayOfMonth
    @State private var selectedDayOfMonth: Int = 1
    @State private var selectedWeekOfMonth: Int = 1
    @State private var selectedWeekday: Weekday = .monday
    @State private var includeLastWeek: Bool = false
    @State private var useDateRange: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date())!
    @State private var biweekly: Bool = false
    @State private var biweeklyStartWeek: Int = 1

    enum RepeatType: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
    }

    enum MonthlyMode: String, CaseIterable {
        case dayOfMonth = "Day of month"
        case weekOfMonth = "Week of month"
    }

    var body: some View {
        Group {
            Section {
                Toggle("Repeats", isOn: $isRecurring)
            }

            if isRecurring {
                Section("Repeat Pattern") {
                    Picker("Type", selection: $repeatType) {
                        ForEach(RepeatType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch repeatType {
                    case .weekly:
                        WeekdayPicker(selected: $selectedWeekdays)

                        Toggle("Every other week", isOn: $biweekly)
                        if biweekly {
                            Stepper("Starting week: \(biweeklyStartWeek)", value: $biweeklyStartWeek, in: 1...53)
                        }

                    case .monthly:
                        Picker("Based on", selection: $monthlyMode) {
                            ForEach(MonthlyMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }

                        switch monthlyMode {
                        case .dayOfMonth:
                            DayOfMonthPicker(selectedDay: $selectedDayOfMonth)

                        case .weekOfMonth:
                            WeekOfMonthPicker(
                                selectedWeek: $selectedWeekOfMonth,
                                selectedWeekday: $selectedWeekday,
                                includeLastWeek: $includeLastWeek
                            )
                        }
                    }
                }

                Section("Date Range (Optional)") {
                    Toggle("Limit to date range", isOn: $useDateRange)

                    if useDateRange {
                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                    }
                }

                // Preview
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rule Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ruleDescription)
                            .font(.subheadline)
                    }
                }
            }
        }
        .onChange(of: constructedRule) { _, newRule in
            rule = newRule
        }
        .onAppear {
            loadFromRule(rule)
        }
    }

    // MARK: - Load Existing Rule

    /// Decomposes an existing AnyRule into internal picker state.
    /// Handles common patterns: weekdays, daysOfMonth, weekOfMonth,
    /// everyOtherWeek, dateRange, and nested .and() composites.
    private func loadFromRule(_ rule: AnyRule?) {
        guard let rule else { return }
        decompose(rule)
    }

    private func decompose(_ rule: AnyRule) {
        switch rule {
        case .weekdays(let days):
            repeatType = .weekly
            selectedWeekdays = days
            // For weekOfMonth patterns, the single weekday is stored here
            if days.count == 1, let day = days.first {
                selectedWeekday = day
            }
        case .daysOfMonth(let days):
            repeatType = .monthly
            monthlyMode = .dayOfMonth
            if let first = days.first { selectedDayOfMonth = first }
        case .weekOfMonth(let wRule):
            repeatType = .monthly
            monthlyMode = .weekOfMonth
            if let first = wRule.weeks.first { selectedWeekOfMonth = first }
            includeLastWeek = wRule.includesLast
        case .everyOtherWeek(let startWeek):
            biweekly = true
            biweeklyStartWeek = startWeek
        case .dateRange(let start, let end):
            useDateRange = true
            startDate = start
            endDate = end
        case .and(let left, let right):
            decompose(left)
            decompose(right)
        case .or, .not:
            break
        }
    }

    // MARK: - Rule Construction

    private var constructedRule: AnyRule? {
        guard isRecurring else { return nil }

        var baseRule: AnyRule?

        switch repeatType {
        case .weekly:
            guard !selectedWeekdays.isEmpty else { return nil }
            baseRule = .on(selectedWeekdays)

            if biweekly {
                baseRule = baseRule! && .everyOtherWeek(startingWeek: biweeklyStartWeek)
            }

        case .monthly:
            switch monthlyMode {
            case .dayOfMonth:
                baseRule = .onDays(selectedDayOfMonth)

            case .weekOfMonth:
                let weekRule: AnyRule = includeLastWeek
                    ? .weekOfMonth(WeekOfMonthRule(weeks: [selectedWeekOfMonth], includesLast: true))
                    : .inWeeks(selectedWeekOfMonth)
                baseRule = .on(selectedWeekday) && weekRule
            }
        }

        guard var finalRule = baseRule else { return nil }

        if useDateRange {
            finalRule = finalRule && .between(start: startDate, end: endDate)
        }

        return finalRule
    }

    private var ruleDescription: String {
        guard isRecurring else { return "Does not repeat" }

        var parts: [String] = []

        switch repeatType {
        case .weekly:
            if selectedWeekdays.isEmpty {
                return "Select at least one day"
            }
            let dayNames = selectedWeekdays
                .sorted { $0.rawValue < $1.rawValue }
                .map { $0.description }
                .joined(separator: ", ")

            if biweekly {
                parts.append("Every other \(dayNames)")
            } else {
                parts.append("Every \(dayNames)")
            }

        case .monthly:
            switch monthlyMode {
            case .dayOfMonth:
                let suffix = daySuffix(selectedDayOfMonth)
                parts.append("Monthly on the \(selectedDayOfMonth)\(suffix)")

            case .weekOfMonth:
                let weekName = weekOrdinal(selectedWeekOfMonth)
                let extra = includeLastWeek ? " (or last)" : ""
                parts.append("\(weekName) \(selectedWeekday.fullName) of each month\(extra)")
            }
        }

        if useDateRange {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("from \(formatter.string(from: startDate)) to \(formatter.string(from: endDate))")
        }

        return parts.joined(separator: ", ")
    }

    private func daySuffix(_ day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }

    private func weekOrdinal(_ week: Int) -> String {
        switch week {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        case 5: return "5th"
        default: return "\(week)th"
        }
    }
}

// MARK: - Sync Extension

extension RecurrenceRulePicker {
    /// Call this when the form is saved
    func syncToBinding() {
        rule = constructedRule
    }
}

// MARK: - Weekday Picker (Tap Buttons)

struct WeekdayPicker: View {
    @Binding var selected: Set<Weekday>

    // Start week on Monday
    private let orderedDays: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(orderedDays) { day in
                    DayButton(
                        day: day,
                        isSelected: selected.contains(day)
                    ) {
                        if selected.contains(day) {
                            selected.remove(day)
                        } else {
                            selected.insert(day)
                        }
                    }
                }
            }

            // Quick select buttons
            HStack(spacing: 12) {
                QuickSelectButton(label: "Weekdays") {
                    selected = Weekday.weekdays
                }
                QuickSelectButton(label: "MWF") {
                    selected = [.monday, .wednesday, .friday]
                }
                QuickSelectButton(label: "TTh") {
                    selected = [.tuesday, .thursday]
                }
                QuickSelectButton(label: "Clear") {
                    selected = []
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

private struct DayButton: View {
    let day: Weekday
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(String(day.description.prefix(1)))
                .font(.subheadline.weight(.medium))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.15))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct QuickSelectButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(label, action: action)
            .foregroundStyle(.blue)
    }
}

// MARK: - Day of Month Picker

struct DayOfMonthPicker: View {
    @Binding var selectedDay: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(1...31, id: \.self) { day in
                    Button {
                        selectedDay = day
                    } label: {
                        Text("\(day)")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedDay == day ? Color.blue : Color.gray.opacity(0.15))
                            )
                            .foregroundStyle(selectedDay == day ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Last day option
            Button {
                selectedDay = -1
            } label: {
                HStack {
                    Image(systemName: selectedDay == -1 ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedDay == -1 ? .blue : .secondary)
                    Text("Last day of month")
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Week of Month Picker

struct WeekOfMonthPicker: View {
    @Binding var selectedWeek: Int
    @Binding var selectedWeekday: Weekday
    @Binding var includeLastWeek: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Week selector
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { week in
                    Button {
                        selectedWeek = week
                    } label: {
                        Text(weekLabel(week))
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedWeek == week ? Color.blue : Color.gray.opacity(0.15))
                            )
                            .foregroundStyle(selectedWeek == week ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Weekday selector
            Picker("Day", selection: $selectedWeekday) {
                ForEach(Weekday.allCases) { day in
                    Text(day.fullName).tag(day)
                }
            }

            // Include last week toggle
            Toggle("Also include last week of month", isOn: $includeLastWeek)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }

    private func weekLabel(_ week: Int) -> String {
        switch week {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        case 5: return "5th"
        default: return "\(week)"
        }
    }
}

// MARK: - Wrapper for Form Usage

struct RecurrenceRulePickerForm: View {
    @Binding var task: TaskItem
    @State private var rule: AnyRule?
    @State private var isRecurring: Bool

    init(task: Binding<TaskItem>) {
        self._task = task
        self._isRecurring = State(initialValue: task.wrappedValue.recurrence)
        self._rule = State(initialValue: task.wrappedValue.recurrenceRule)
    }

    var body: some View {
        RecurrenceRulePicker(rule: $rule, isRecurring: $isRecurring)
            .onChange(of: rule) { _, newRule in
                task.recurrenceRule = newRule
            }
            .onChange(of: isRecurring) { _, newValue in
                task.recurrence = newValue
                if !newValue {
                    task.recurrenceRule = nil
                }
            }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var rule: AnyRule? = nil
        @State private var isRecurring = true

        var body: some View {
            Form {
                RecurrenceRulePicker(rule: $rule, isRecurring: $isRecurring)
            }
            .onChange(of: rule) { _, newRule in
                if let json = newRule?.toJSON() {
                    print("Rule JSON: \(json)")
                }
            }
        }
    }

    return PreviewWrapper()
}
