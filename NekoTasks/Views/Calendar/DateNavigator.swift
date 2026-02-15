//
//  DateNavigator.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Top navigation bar for the calendar. Contains the day/week segmented picker,
//  left/right date chevrons, tappable date title (opens DatePickerSheet), a
//  "Today" / "This Week" jump button, and the filter icon.
//
//  ── LAYOUT ──
//  Two rows stacked vertically:
//    Row 1: Segmented picker (Day | Week)
//    Row 2: ZStack with centered [◀ Date ▶] and right-aligned [Today] [Filter]
//
//  ── DEPENDENCIES ──
//  • CalendarState (via @Environment) — reads/writes selectedDate, viewType,
//    showingDatePicker, showingFilterSheet, filter.
//  • CalendarFormatting — all date string formatting is delegated there.
//
//  ── AI CONTEXT ──
//  This view is purely navigational — it doesn't render events or own any data.
//  If you need to add a new navigation control to the calendar header, this is
//  the right file. The `weekBounds` helper computes the start/end of the week
//  containing `selectedDate` and is used for both display and "This Week" logic.
//

import SwiftUI

struct DateNavigator: View {
    @Environment(CalendarState.self) var state

    private let calendar = Calendar.current

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 8) {
            Picker("", selection: $state.viewType) {
                ForEach(CalendarPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

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

    // MARK: - Display Helpers

    private var dateTitle: String {
        switch state.viewType {
        case .day:
            return CalendarFormatting.weekdayMonthDayString(from: state.selectedDate)
        case .week:
            let (start, end) = weekBounds
            return CalendarFormatting.weekRangeTitle(start: start, end: end)
        }
    }

    private var dateSubtitle: String {
        switch state.viewType {
        case .day:
            return CalendarFormatting.relativeLabel(for: state.selectedDate)
        case .week:
            let (start, _) = weekBounds
            if calendar.isDate(start, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            }
            return CalendarFormatting.yearString(from: state.selectedDate)
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

    /// Returns the Monday–Sunday bounds of the week containing `selectedDate`.
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
