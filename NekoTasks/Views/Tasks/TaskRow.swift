//
//  TaskRow.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Task display card and all its subcomponents. Used in TasksView's list.
//  Main: TaskRow — rounded rect card (max 640pt) with label color border, checkbox, title, due badge, metadata.
//  Subcomponents: TopRow (title + DueBadge), MetadataRow (LabelChips + TimeEstimateChip),
//  TaskCheckbox (animated toggle with onToggle callback), PriorityBorder (colored left edge: first label color or none),
//  DueBadge (urgency-based: Overdue/Today/Tomorrow/weekday/date), LabelChips (shows up to 2 + overflow),
//  LabelChip (individual label capsule), TimeEstimateChip (timer icon + formatted duration).
//  Also defines Color(hex:) extension for parsing hex color strings from TaskLabel.colorHex.
//

import SwiftUI
import SwiftData

// MARK: - Main Task Card

struct TaskRow: View {
    @Bindable var task: TaskItem
    var onToggleComplete: (() -> Void)? = nil
    var onEdit: () -> Void = {}

    private enum CardUrgency {
        case overdue, today, none
    }

    private var cardUrgency: CardUrgency {
        guard let deadline = task.deadline, !task.isCompleted else { return .none }
        let calendar = Calendar.current
        let now = Date()
        if deadline < calendar.startOfDay(for: now) {
            return .overdue
        } else if calendar.isDateInToday(deadline) {
            return .today
        }
        return .none
    }

    private var cardFill: Color {
        switch cardUrgency {
        case .overdue: return Color.red.opacity(0.04)
        case .today: return Color.orange.opacity(0.03)
        case .none: return .white
        }
    }

    private var cardStroke: Color {
        switch cardUrgency {
        case .overdue: return Color.red.opacity(0.4)
        case .today: return Color.orange.opacity(0.35)
        case .none: return Color.gray.opacity(0.3)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            TaskRowLeftBorder(color: task.labels.first.flatMap { Color(hex: $0.colorHex ?? "") })

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    TaskCheckbox(isCompleted: $task.isCompleted, onToggle: onToggleComplete)

                    VStack(alignment: .leading, spacing: 6) {
                        TopRow(task: task)

                        if let desc = task.taskDescription, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        MetadataRow(task: task)
                    }

                    Spacer()
                }
                .padding(18)
                .contentShape(Rectangle())
                .onTapGesture(perform: onEdit)

                if !task.subTasks.isEmpty {
                    Divider()
                        .padding(.horizontal, 18)
                    SubtaskSection(task: task)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                        .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: 640)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardFill)
                .stroke(cardStroke, lineWidth: cardUrgency == .none ? 1 : 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Top Row (Title + Due Date)

private struct TopRow: View {
    let task: TaskItem

    var body: some View {
        HStack(alignment: .center) {
            Text(task.title)
                .font(.title3.weight(.semibold))
                .strikethrough(task.isCompleted, color: .secondary)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .lineLimit(2)

            Spacer()

            if let deadline = task.deadline {
                DueBadge(deadline: deadline, isCompleted: task.isCompleted)
            }
        }
    }
}

// MARK: - Metadata Row (Labels + Time Estimate)

private struct MetadataRow: View {
    let task: TaskItem

    var body: some View {
        let hasLabels = !task.labels.isEmpty
        let hasTimeEstimate = task.timeEstimate != nil

        if hasLabels || hasTimeEstimate {
            HStack(spacing: 8) {
                if hasLabels {
                    LabelChips(labels: task.labels)
                }

                if hasLabels && hasTimeEstimate {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }

                if let estimate = task.timeEstimate {
                    TimeEstimateChip(estimate: estimate)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Subtask Section

private struct SubtaskSection: View {
    let task: TaskItem
    @State private var isExpanded = false

    private var sortedSubtasks: [TaskItem] {
        task.subTasks.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(task.subTasks.count) subtask\(task.subTasks.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sortedSubtasks) { subtask in
                        SubtaskChecklistRow(subtask: subtask)
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - Subtask Checklist Row

private struct SubtaskChecklistRow: View {
    @Bindable var subtask: TaskItem

    var body: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    subtask.isCompleted.toggle()
                }
            } label: {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(subtask.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(subtask.title)
                .font(.subheadline)
                .strikethrough(subtask.isCompleted, color: .secondary)
                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            if let deadline = subtask.deadline {
                Text(compactDeadline(deadline))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let estimate = subtask.timeEstimate {
                HStack(spacing: 2) {
                    Image(systemName: "timer")
                        .font(.system(size: 9))
                    Text(compactEstimate(estimate))
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private func compactDeadline(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tmrw" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func compactEstimate(_ estimate: TimeInterval) -> String {
        let minutes = Int(estimate / 60)
        let hours = minutes / 60
        let rem = minutes % 60
        if hours > 0 && rem > 0 { return "\(hours)h\(rem)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
}

// MARK: - Checkbox Component

struct TaskCheckbox: View {
    @Binding var isCompleted: Bool
    var onToggle: (() -> Void)? = nil

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCompleted.toggle()
            }
            onToggle?()
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title)
                .foregroundStyle(isCompleted ? .green : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Priority Border

struct TaskRowLeftBorder: View {
    let color: Color?

    var body: some View {
        Rectangle()
            .fill(color ?? .clear)
            .frame(width: color != nil ? 5 : 0)
    }
}

// MARK: - Due Badge

struct DueBadge: View {
    let deadline: Date
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 4) {
            if urgency == .overdue && !isCompleted {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
            } else if urgency == .today || urgency == .tomorrow {
                Image(systemName: "clock.fill")
                    .font(.caption)
            }

            Text(formattedDeadline)
                .font(.subheadline)
                .fontWeight(urgency == .overdue ? .bold : .medium)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.12))
        )
    }

    private enum Urgency {
        case overdue, today, tomorrow, thisWeek, later
    }

    private var urgency: Urgency {
        let calendar = Calendar.current
        let now = Date()

        if deadline < calendar.startOfDay(for: now) {
            return .overdue
        } else if calendar.isDateInToday(deadline) {
            return .today
        } else if calendar.isDateInTomorrow(deadline) {
            return .tomorrow
        } else if let weekAway = calendar.date(byAdding: .day, value: 7, to: now),
                  deadline < weekAway {
            return .thisWeek
        } else {
            return .later
        }
    }

    private var formattedDeadline: String {
        switch urgency {
        case .overdue:
            return "Overdue"
        case .today:
            return "Today"
        case .tomorrow:
            return "Tomorrow"
        case .thisWeek:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE" // Mon, Tue, etc.
            return formatter.string(from: deadline)
        case .later:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d" // Jan 15
            return formatter.string(from: deadline)
        }
    }

    private var badgeColor: Color {
        if isCompleted { return .secondary }
        switch urgency {
        case .overdue: return .red
        case .today: return .orange
        case .tomorrow: return .yellow.opacity(0.8)
        case .thisWeek, .later: return .secondary
        }
    }
}

// MARK: - Time Estimate Chip

struct TimeEstimateChip: View {
    let estimate: TimeInterval

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "timer")
                .font(.caption2)
            Text(formattedEstimate)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private var formattedEstimate: String {
        let minutes = Int(estimate / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 && remainingMinutes > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Label Chips

struct LabelChips: View {
    let labels: [TaskLabel]
    var maxVisible: Int = 2

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(labels.prefix(maxVisible))) { label in
                LabelChip(label: label)
            }

            if labels.count > maxVisible {
                Text("+\(labels.count - maxVisible)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LabelChip: View {
    let label: TaskLabel

    var body: some View {
        Text(label.name)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(labelColor.opacity(0.15))
            )
            .foregroundStyle(labelColor)
    }

    private var labelColor: Color {
        if let hex = label.colorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Preview

#Preview("Default Task") {
    TaskRow(task: TaskItem(title: "Sample Task"))
        .padding()
        .modelContainer(for: TaskItem.self, inMemory: true)
}

#Preview("Task with Deadline Today") {
    let task = TaskItem(title: "Review pull request", deadline: Date())
    task.importance = 2
    task.timeEstimate = 30 * 60 // 30 minutes

    return TaskRow(task: task)
        .padding()
        .modelContainer(for: TaskItem.self, inMemory: true)
}

#Preview("Overdue Task") {
    let task = TaskItem(
        title: "Submit expense report",
        deadline: Calendar.current.date(byAdding: .day, value: -2, to: Date())
    )
    task.importance = 3

    return TaskRow(task: task)
        .padding()
        .modelContainer(for: TaskItem.self, inMemory: true)
}

#Preview("Completed Task") {
    let task = TaskItem(title: "Completed task", deadline: Date())
    task.isCompleted = true

    return TaskRow(task: task)
        .padding()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
