//
//  CurrentTimeIndicator.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Red horizontal line with a dot, positioned vertically to indicate the current
//  time within a DayColumn. Only rendered when the column represents today.
//
//  ── KNOWN LIMITATION ──
//  The Y offset is computed once from Date() and does NOT update in real time.
//  To make it tick forward, wrap the parent in a TimelineView(.periodic(from: .now, by: 60))
//  or add a Timer that triggers a re-render every minute. This is a TODO.
//
//  ── POSITIONING ──
//  Same math as DayColumn.eventYOffset: minutes since startHour mapped proportionally
//  to the total grid height. The circle is offset -4pt to center it on the line.
//
//  ── AI CONTEXT ──
//  If fixing the live-update issue, the change should happen in DayColumn (wrapping
//  this view in a TimelineView) rather than inside this view, since this view has
//  no access to a refresh trigger on its own.
//

import SwiftUI

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    let startHour: Int

    private var yOffset: CGFloat {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        let minutesSinceStart = CGFloat((components.hour ?? 0) - startHour) * 60 + CGFloat(components.minute ?? 0)
        let totalMinutes = CGFloat(24 - startHour) * 60
        let totalHeight = CGFloat(24 - startHour) * hourHeight
        return (minutesSinceStart / totalMinutes) * totalHeight
    }

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
        .offset(y: yOffset - 4)
    }
}
