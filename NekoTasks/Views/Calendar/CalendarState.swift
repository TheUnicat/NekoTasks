//
//  CalendarState.swift
//  NekoTasks
//
//  Refactored from CalendarView.swift
//
//  ── PURPOSE ──
//  Single source of truth for all calendar UI state. This is an @Observable class
//  injected into the environment so that every calendar subview (DateNavigator,
//  WeekView, FilterSheet, etc.) can read and write shared state without prop-drilling.
//
//  ── ARCHITECTURE NOTES ──
//  • Owns: selected date, active filter, sheet presentation flags, editing context.
//  • Does NOT own: data queries, model context, or business logic.
//  • Injected at the root via `.environment(CalendarState())` — typically in the
//    parent that hosts CalendarView (e.g., a TabView or NavigationStack root).
//  • `editingEvent` + `isCreatingNew` together track whether the event sheet is
//    showing an existing event for editing or a freshly created one. When `isCreatingNew`
//    is true, the save handler inserts the event into the model context; otherwise it
//    just dismisses.
//
//  ── AI CONTEXT ──
//  If modifying calendar behavior, this is the file to check first for relevant state.
//  All calendar subviews read from this via @Environment(CalendarState.self).
//  The EventFilter struct lives here too — it controls which events are visible in
//  both day and week views via the `eventsOn(date:filter:)` extension on [TaskItem].
//

import SwiftUI
import SwiftData

// MARK: - Calendar Period

/// Determines whether the calendar displays a single day or a full week.
/// Drives both the DateNavigator's display logic and which subview
/// (DayEventList vs WeekView) is rendered in CalendarView.
enum CalendarPeriod: String, CaseIterable, Hashable {
    case day = "Day"
    case week = "Week"
}

// MARK: - Calendar State

@Observable
class CalendarState {
    /// The date the user has navigated to. In day mode this is the displayed day;
    /// in week mode, the week containing this date is shown.
    var selectedDate: Date = Date()

    /// Active filter controlling which events are visible (type + labels).
    var filter: EventFilter = .all

    /// Sheet presentation flags
    var showingFilterSheet = false
    var showingDatePicker = false

    /// The event currently open in the detail/edit sheet, or nil if no sheet is shown.
    var editingEvent: TaskItem?

    /// True when `editingEvent` is a newly created event that hasn't been inserted
    /// into the model context yet. The save handler checks this to decide whether
    /// to call `modelContext.insert()`.
    var isCreatingNew = false

    /// Day vs. week toggle state.
    var viewType: CalendarPeriod = .day
}

// MARK: - Event Filter

/// Determines which events pass through to the calendar display.
/// Used by `[TaskItem].eventsOn(date:filter:)` (defined elsewhere).
///
/// - `showRecurring` / `showOneTime`: toggle event categories
/// - `labelIDs`: when non-empty, only events with at least one matching label are shown
/// - `isDefault`: convenience check for whether any filtering is active
struct EventFilter: Equatable {
    var showRecurring: Bool = true
    var showOneTime: Bool = true
    var labelIDs: Set<PersistentIdentifier> = []

    var isDefault: Bool {
        showRecurring && showOneTime && labelIDs.isEmpty
    }

    static let all = EventFilter()
}
