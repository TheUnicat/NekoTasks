//
//  WeekView.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Full-week calendar view with a vertical time grid. Shown when
//  CalendarState.viewType == .week. Renders 7 DayColumns side by side
//  with a TimeGutter on the left showing hour labels.
//
//  ── LAYOUT ──
//  ┌─────────────────────────────────────────┐
//  │  [WeekHeaderRow: SUN MON TUE ... SAT]   │
//  │─────────────────────────────────────────│
//  │ Time │ Sun │ Mon │ Tue │ ... │ Sat │    │
//  │ 12AM │     │     │     │     │     │    │
//  │  1AM │     │     │     │     │     │    │
//  │  ... │     │     │     │     │     │    │
//  └─────────────────────────────────────────┘
//
//  ── CONSTANTS ──
//  • hourHeight: 60pt per hour — controls density of the time grid.
//  • gutterWidth: 50pt — width of the left time labels column.
//  • startHour/endHour: 0–24 — full day range (midnight to midnight).
//  These are currently hardcoded. A future enhancement could make hourHeight
//  user-configurable for zoom.
//
//  ── SCROLL BEHAVIOR ──
//  On appear, auto-scrolls to 8 AM using ScrollViewReader. The scroll target
//  is the "hour-8" id set on TimeGutter's hour labels.
//
//  ── AI CONTEXT ──
//  This view receives ALL events and passes them to each DayColumn, which
//  handles per-day filtering internally. If week-level features are needed
//  (e.g., multi-day event spanning), this is the right place to add them.
//  The 7-column layout assumes a standard week — if locale-aware week start
//  is needed, adjust `weekDates` computation.
//

import SwiftUI

struct WeekView: View {
    let allEvents: [TaskItem]
    @Environment(CalendarState.self) var state

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    private let gutterWidth: CGFloat = 50
    private let startHour = 0
    private let endHour = 24

    /// Computes the 7 dates of the week containing `state.selectedDate`.
    private var weekDates: [Date] {
        var start = state.selectedDate
        var interval: TimeInterval = 0
        _ = calendar.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: state.selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(spacing: 0) {
            WeekHeaderRow(dates: weekDates)
                .padding(.leading, gutterWidth)

            Divider()

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
                        proxy.scrollTo("hour-8", anchor: .top)
                    }
                }
            }
        }
    }
}
