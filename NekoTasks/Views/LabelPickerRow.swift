//
//  LabelPickerRow.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Inline label picker used inside ShowTask (task/event editor). Displays assigned
//  labels as removable chips in a flow layout, plus a "+ Label" button that opens
//  a popover for toggling existing labels or quick-creating new ones.
//
//  ── COMPONENTS ──
//  • `FlowLayout` — Custom SwiftUI Layout that wraps children into rows (like CSS flexbox wrap).
//  • `LabelFlowPicker` — Main entry point. Binds to a `Set<PersistentIdentifier>` of selected
//    label IDs. Queries all TaskLabels, shows assigned ones as `AssignedLabelChip`s, and
//    presents `LabelPickerPopover` for adding/removing labels.
//  • `AssignedLabelChip` — Removable chip showing a label's color dot, name, and × button.
//  • `LabelPickerPopover` — Popover with a quick-create row (color + name + "Create" button)
//    and a scrollable list of all labels as toggleable `LabelToggleRow`s.
//  • `LabelToggleRow` — Single row in the popover list: color dot, name, checkmark if selected.
//
//  ── STATE ──
//  • `showingPicker` — Controls popover visibility.
//  • `newLabelName` / `newLabelColor` — Draft state for inline label creation.
//    Reset after successful creation.
//

import SwiftUI
import SwiftData

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
            totalHeight = y + rowHeight
        }

        return ArrangeResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            positions: positions
        )
    }
}

// MARK: - Label Flow Picker

struct LabelFlowPicker: View {
    @Binding var selectedLabelIDs: Set<PersistentIdentifier>
    @Query private var allLabels: [TaskLabel]
    @Environment(\.modelContext) private var modelContext

    @State private var showingPicker = false
    @State private var newLabelName = ""
    @State private var newLabelColor: Color = .blue

    private var assignedLabels: [TaskLabel] {
        allLabels.filter { selectedLabelIDs.contains($0.persistentModelID) }
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(assignedLabels) { label in
                AssignedLabelChip(label: label) {
                    selectedLabelIDs.remove(label.persistentModelID)
                }
            }

            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption2)
                    Text("Label")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary)
                )
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPicker) {
                LabelPickerPopover(
                    selectedLabelIDs: $selectedLabelIDs,
                    allLabels: allLabels,
                    newLabelName: $newLabelName,
                    newLabelColor: $newLabelColor,
                    onCreate: createLabel
                )
            }
        }
    }

    private func createLabel() {
        let trimmed = newLabelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let label = TaskLabel(name: trimmed, colorHex: newLabelColor.toHex())
        modelContext.insert(label)
        selectedLabelIDs.insert(label.persistentModelID)
        newLabelName = ""
        newLabelColor = .blue
    }
}

// MARK: - Assigned Label Chip

private struct AssignedLabelChip: View {
    let label: TaskLabel
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Circle()
                    .fill(labelColor)
                    .frame(width: 8, height: 8)
                Text(label.name)
                    .font(.caption2)
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(labelColor.opacity(0.12))
            )
            .foregroundStyle(labelColor)
        }
        .buttonStyle(.plain)
    }

    private var labelColor: Color {
        if let hex = label.colorHex, let color = Color(hex: hex) {
            return color
        }
        return .blue
    }
}

// MARK: - Label Picker Popover

private struct LabelPickerPopover: View {
    @Binding var selectedLabelIDs: Set<PersistentIdentifier>
    let allLabels: [TaskLabel]
    @Binding var newLabelName: String
    @Binding var newLabelColor: Color
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Quick create
            HStack(spacing: 8) {
                ColorPicker("", selection: $newLabelColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 28, height: 28)

                TextField("New label…", text: $newLabelName)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)

                Button("Create") {
                    onCreate()
                }
                .font(.subheadline.weight(.medium))
                .disabled(newLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)

            Divider()

            // Existing labels
            if allLabels.isEmpty {
                Text("No labels yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(20)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(allLabels) { label in
                            LabelToggleRow(
                                label: label,
                                isSelected: selectedLabelIDs.contains(label.persistentModelID)
                            ) {
                                if selectedLabelIDs.contains(label.persistentModelID) {
                                    selectedLabelIDs.remove(label.persistentModelID)
                                } else {
                                    selectedLabelIDs.insert(label.persistentModelID)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
        }
        .frame(width: 280)
    }
}

// MARK: - Label Toggle Row

private struct LabelToggleRow: View {
    let label: TaskLabel
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Circle()
                    .fill(labelColor)
                    .frame(width: 12, height: 12)
                Text(label.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var labelColor: Color {
        if let hex = label.colorHex, let color = Color(hex: hex) {
            return color
        }
        return .blue
    }
}
