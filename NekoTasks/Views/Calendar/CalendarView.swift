//
//  CalendarView.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  ── PURPOSE ──
//  Root view for the Events tab. This is the single entry point for the calendar
//  feature — it owns the @Query for all events, handles sheet presentation, and
//  delegates rendering to DayEventList or WeekView based on the current period.
//
//  ── DATA FLOW ──
//  • @Query fetches ALL events (typeRaw == 1) from SwiftData.
//  • `eventsForSelectedDate` filters them through the shared CalendarState's filter
//    and selected date, using the `[TaskItem].eventsOn(date:filter:)` extension.
//  • Subviews receive either the filtered list (DayEventList) or the full list
//    (WeekView, which filters per-column internally).
//
//  ── SHEET MANAGEMENT ──
//  Three sheets are managed here:
//    1. DatePickerSheet — date navigation popup
//    2. FilterSheet — event type and label filtering
//    3. ShowTask (via editingEvent) — event detail/edit view
//  The ShowTask sheet handles both new and existing events. When `isCreatingNew` is
//  true, the save handler validates the title and inserts into modelContext.
//
//  ── AI CONTEXT ──
//  This file should stay thin — it's a composition root, not a place for layout
//  logic or formatting. If you're adding a new calendar feature, prefer creating
//  a new subview file and wiring it in here. The `parseRule` function handles
//  recurrence rule deserialization and is used by recurrence evaluation logic
//  (currently being connected — do not remove).
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(CalendarState.self) var state
    @Query(filter: #Predicate<TaskItem> { $0.typeRaw == 1 })
    private var allEvents: [TaskItem]

    private let calendar = Calendar.current

    var body: some View {
        @Bindable var state = state

        NavigationStack {
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
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        state.isCreatingNew = true
                        let newEvent = TaskItem(title: "", type: .event)
                        newEvent.startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: state.selectedDate)
                        newEvent.endTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: state.selectedDate)
                        state.editingEvent = newEvent
                    } label: {
                        Label("Add Event", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $state.showingDatePicker) {
            DatePickerSheet()
        }
        .sheet(isPresented: $state.showingFilterSheet) {
            FilterSheet()
        }
        .taskEditor(editingTask: $state.editingEvent, isCreatingNew: $state.isCreatingNew)
    }

    private var eventsForSelectedDate: [TaskItem] {
        allEvents.eventsOn(date: state.selectedDate, filter: state.filter)
    }
}
