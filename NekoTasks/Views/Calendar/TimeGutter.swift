//
//  TimeGutter.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Vertical column of hour labels (12 AM, 1 AM, ... 11 PM) displayed on the
//  left edge of the WeekView time grid. Each label is offset upward by 6pt so
//  the text baseline aligns with the corresponding grid line in DayColumn.
//
//  ── SCROLL TARGETS ──
//  Each hour label carries an `.id("hour-N")` which WeekView uses as a scroll
//  anchor. On appear, WeekView scrolls to "hour-8" to show the workday.
//
//  ── AI CONTEXT ──
//  Pure display. Receives startHour, endHour, and hourHeight from WeekView.
//  Uses CalendarFormatting.hourLabel(for:) for consistent formatting.
//

import SwiftUI

struct TimeGutter: View {
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                Text(CalendarFormatting.hourLabel(for: hour))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(height: hourHeight, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 4)
                    .offset(y: -6)
                    .id("hour-\(hour)")
            }
        }
    }
}
