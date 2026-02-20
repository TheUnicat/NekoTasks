import SwiftUI
import SwiftData

//  • `LabelRow` — Single label display: color dot + name.
// logic in settings/settingsview
// MARK: - Label Row

struct LabelRow: View {
    let label: TaskLabel
    var onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                Circle()
                    .fill(labelColor)
                    .frame(width: 12, height: 12)

                Text(label.name)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var labelColor: Color {
        if let hex = label.colorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }
}

