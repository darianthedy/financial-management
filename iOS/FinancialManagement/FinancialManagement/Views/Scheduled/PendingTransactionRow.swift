import SwiftUI

struct PendingTransactionRow: View {
    let pending: Transaction
    var onConfirm: () async -> Void
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

                Text(pending.amount.asCurrency(code: pending.currency))
                    .font(.body.monospacedDigit().bold())
            }

            HStack(spacing: 12) {
                Button {
                    isProcessing = true
                    Task {
                        await onConfirm()
                        isProcessing = false
                    }
                } label: {
                    Label("Confirm", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
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
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .disabled(isProcessing)
        }
        .padding(.vertical, 4)
    }
}
