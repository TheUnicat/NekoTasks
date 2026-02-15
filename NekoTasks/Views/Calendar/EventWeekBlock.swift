//
//  EventWeekBlock.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Compact event tile rendered inside DayColumn in the week grid. Shows just the
//  event title (up to 2 lines) on a colored background. Sized and positioned
//  by DayColumn based on the event's time and duration.
//
//  ── STYLING ──
//  Background color is derived from the event's first label color. Falls back to
//  .blue if no label is attached or if the hex parsing fails. Text is always white.
//  Corner radius is 3pt for a tight, compact appearance that works at small sizes.
//
//  ── AI CONTEXT ──
//  This is distinct from EventCard (used in DayEventList) — EventCard is a full-width
//  card with more detail; EventWeekBlock is a minimal block for the dense week grid.
//  If adding more info to week blocks (e.g., time label), keep it minimal — these
//  can be as small as 20pt tall.
//

import SwiftUI

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
        if let firstLabel = event.labels.first,
           let hex = firstLabel.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .blue
    }
}
