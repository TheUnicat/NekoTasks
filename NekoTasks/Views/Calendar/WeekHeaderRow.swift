//
//  WeekHeaderRow.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Horizontal header row showing abbreviated day names and day numbers for the
//  current week. Sits above the WeekView time grid. Highlights today's date
//  with a filled blue circle.
//
//  ── AI CONTEXT ──
//  Pure display component — no state mutation. Uses CalendarFormatting for the
//  short weekday string. The layout distributes columns evenly with `maxWidth: .infinity`.
//

import SwiftUI

struct WeekHeaderRow: View {
    let dates: [Date]
    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
                VStack(spacing: 2) {
                    Text(CalendarFormatting.shortWeekdayString(from: date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(calendar.component(.day, from: date))")
                        .font(.subheadline.weight(calendar.isDateInToday(date) ? .bold : .regular))
                        .foregroundStyle(calendar.isDateInToday(date) ? .white : .primary)
                        .frame(width: 28, height: 28)
                        .background {
                            if calendar.isDateInToday(date) {
                                Circle().fill(Color.blue)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
    }
}
