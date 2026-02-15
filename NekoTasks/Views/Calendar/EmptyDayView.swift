//
//  EmptyDayView.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Placeholder view shown in DayEventList when no events match the current date
//  and filter. Displays a calendar icon with "No events" messaging.
//
//  ── AI CONTEXT ──
//  Pure cosmetic. If you want to add a "Create event" CTA button here, wire it
//  through CalendarState (set isCreatingNew + editingEvent).
//

import SwiftUI

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
