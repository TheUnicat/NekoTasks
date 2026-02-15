//
//  DayEventList.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Renders events for the currently selected day as a vertical scrolling list
//  of EventCard views. Shown when CalendarState.viewType == .day.
//
//  ── BEHAVIOR ──
//  • Receives a pre-filtered `[TaskItem]` — filtering is done in CalendarView.
//  • Shows EmptyDayView when the list is empty.
//  • Tapping an EventCard sets `state.editingEvent` to open the detail sheet.
//
//  ── AI CONTEXT ──
//  This is a pure presentation view. It doesn't query data or apply filters.
//  If you need to change how day-view events look, modify EventCard (separate file).
//  If you need to change which events appear, modify the filtering in CalendarView
//  or the `eventsOn(date:filter:)` extension on [TaskItem].
//

import SwiftUI

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
