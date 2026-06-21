import SwiftUI

struct PendingTransactionRow: View {
    @Environment(AppState.self) private var appState
    let pending: Transaction
    var onConfirm: () async -> Void
    var onEdit: () -> Void
    var onDismiss: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pending.description ?? pending.type.rawValue.capitalized)
                        .font(.subheadline.bold())
                    Text("Due: \(pending.transactionDate, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(pending.amount.asCurrency(code: appState.defaultCurrency))
                    .font(.body.monospacedDigit().bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 8) {
                Button {
                    isProcessing = true
                    Task {
                        await onConfirm()
                        isProcessing = false
                    }
                } label: {
                    Label("Confirm", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    isProcessing = true
                    Task {
                        await onDismiss()
                        isProcessing = false
                    }
                } label: {
                    Label("Dismiss", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            }
            .disabled(isProcessing)
        }
        .padding(.vertical, 4)
    }
}
