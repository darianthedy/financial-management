import SwiftUI

struct PendingTransactionRow: View {
    @Environment(AppState.self) private var appState
    let pending: Transaction
    /// Resolved budget name — top of the title precedence (budget → fixed expense → category → description → type).
    var budgetName: String?
    /// Resolved fixed expense name — second in the title precedence.
    var fixedExpenseName: String?
    /// Resolved category name — third in the title precedence.
    var categoryName: String?
    var onConfirm: () async -> Void
    var onEdit: () -> Void
    var onDismiss: () async -> Void

    @State private var isProcessing = false

    /// Title precedence: budget (non-transfer) → fixed expense → category → description → type word.
    private var title: String {
        if let budgetName, pending.type != .transfer { return budgetName }
        if let fixedExpenseName { return fixedExpenseName }
        if let categoryName { return categoryName }
        if let description = pending.description, !description.isEmpty { return description }
        return pending.type.rawValue.capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(Color.appWarning)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.appForeground)
                    Text("Due: \(pending.transactionDate, style: .date)")
                        .font(.caption)
                        .foregroundStyle(Color.appMutedForeground)
                }

                Spacer()

                Text(pending.amount.asCurrency(code: appState.defaultCurrency))
                    .font(.body.monospacedDigit().bold())
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // Three inline actions. At default sizes they sit side by side, but at
            // larger Dynamic Type / narrow widths three labelled buttons crowd and
            // truncate ("Conf…", "Dis…"), so ViewThatFits falls back to a full-width
            // vertical stack. Each button keeps a 44pt-tall hit area (HIG minimum).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    actionButtons(fillWidth: false)
                }
                VStack(spacing: 8) {
                    actionButtons(fillWidth: true)
                }
            }
            .disabled(isProcessing)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionButtons(fillWidth: Bool) -> some View {
        Button {
            isProcessing = true
            Task {
                await onConfirm()
                isProcessing = false
            }
        } label: {
            Label("Confirm", systemImage: "checkmark")
                .frame(maxWidth: fillWidth ? .infinity : nil, minHeight: 44)
                .lineLimit(1)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.appSuccess)
        .controlSize(.small)

        Button {
            onEdit()
        } label: {
            Label("Edit", systemImage: "pencil")
                .frame(maxWidth: fillWidth ? .infinity : nil, minHeight: 44)
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
                .frame(maxWidth: fillWidth ? .infinity : nil, minHeight: 44)
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .tint(Color.appDanger)
        .controlSize(.small)
    }
}
