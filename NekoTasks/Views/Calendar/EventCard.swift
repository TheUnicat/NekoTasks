//
//  EventCard.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Display card for events in CalendarView. Styled to match TaskCard (rounded rect, max 640pt, label color border).
//  Prominent time display in a highlighted block on the left, event title + location + recurring badge on the right.
//  LabelChips included for future label integration. Tap triggers onTap callback (opens ShowTask editor).
//

import SwiftUI
import SwiftData

struct EventCard: View {
    @Bindable var event: TaskItem
    var onTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            TaskRowLeftBorder(color: event.labels.first.flatMap { Color(hex: $0.colorHex ?? "") })

            HStack(spacing: 14) {
                // Prominent time block
                EventTimeBlock(startTime: event.startTime, endTime: event.endTime)

                // Event details
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        Text(event.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)

                        Spacer()

                        if event.recurrence {
                            HStack(spacing: 4) {
                                Image(systemName: "repeat")
                                    .font(.caption)
                                Text("Recurring")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.12))
                            )
                        }
                    }

                    if let location = event.locationName, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(location)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // Label chips for future integration
                    if !event.labels.isEmpty {
                        LabelChips(labels: event.labels)
                    }
                }

                Spacer()
            }
            .padding(18)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .frame(maxWidth: 640)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Event Time Block

private struct EventTimeBlock: View {
    let startTime: Date?
    let endTime: Date?

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            if let startTime {
                Text(formatTime(startTime))
                    .font(.subheadline.weight(.bold))
            }
            if let endTime {
                Text(formatTime(endTime))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 74)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let event = TaskItem(title: "Team Meeting", type: .event)
    event.startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
    event.endTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())
    event.locationName = "Conference Room A"

    return EventCard(event: event)
        .padding()
        .modelContainer(for: TaskItem.self, inMemory: true)
}

#Preview("Recurring Event") {
    let event = TaskItem(title: "Weekly Standup", type: .event)
    event.startTime = Calendar.current.date(bySettingHour: 10, minute: 30, second: 0, of: Date())
    event.endTime = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())
    event.recurrence = true
    event.importance = 2

    return EventCard(event: event)
        .padding()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
