//
//  DayColumn.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Renders a single day's column within the WeekView time grid. Draws hour grid
//  lines, positions event blocks at the correct Y offset based on their start time,
//  and sizes them proportionally to their duration.
//
//  ── POSITIONING MATH ──
//  Events are positioned absolutely within a ZStack of height `totalHeight`.
//  • Y offset = (minutes since midnight) / (total minutes in grid) × totalHeight
//  • Height = (event duration in minutes) / (total minutes in grid) × totalHeight
//  • Minimum block height is 20pt to keep very short events tappable.
//  If an event has no start/endTime, it defaults to a 30-minute block at the top.
//
//  ── CURRENT TIME ──
//  Shows a CurrentTimeIndicator (red line) when the column represents today.
//
//  ── AI CONTEXT ──
//  This view filters events per-day using `allEvents.eventsOn(date:filter:)`.
//  It receives ALL events from WeekView rather than a pre-filtered list, because
//  each column needs to evaluate recurrence rules independently for its own date.
//  Tapping an event block sets `state.editingEvent` to open the detail sheet.
//

import SwiftUI

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

            // Current time indicator (today only)
            if calendar.isDateInToday(date) {
                CurrentTimeIndicator(hourHeight: hourHeight, startHour: startHour)
            }

            // Event blocks
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

    // MARK: - Positioning

    private func eventYOffset(_ event: TaskItem) -> CGFloat {
        guard let startTime = event.startTime else { return 0 }
        let components = calendar.dateComponents([.hour, .minute], from: startTime)
        let minutesSinceStart = CGFloat((components.hour ?? 0) - startHour) * 60 + CGFloat(components.minute ?? 0)
        let totalMinutes = CGFloat(endHour - startHour) * 60
        return (minutesSinceStart / totalMinutes) * totalHeight
    }

    private func eventHeight(_ event: TaskItem) -> CGFloat {
        guard let startTime = event.startTime, let endTime = event.endTime else {
            return hourHeight / 2
        }
        let duration = endTime.timeIntervalSince(startTime) / 60
        let totalMinutes = CGFloat(endHour - startHour) * 60
        return max(CGFloat(duration) / totalMinutes * totalHeight, 20)
    }
}
