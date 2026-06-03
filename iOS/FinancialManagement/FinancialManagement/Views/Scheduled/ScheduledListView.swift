import SwiftUI

struct ScheduledListView: View {
    @State private var viewModel = ScheduledTransactionViewModel()

    var body: some View {
        List {
            if !viewModel.pendingTransactions.isEmpty {
                Section("Pending") {
                    ForEach(viewModel.pendingTransactions) { pending in
                        PendingTransactionRow(
                            pending: pending,
                            onConfirm: {
                                await viewModel.confirmPending(pending)
                            },
                            onDismiss: {
                                await viewModel.dismissPending(pending)
                            }
                        )
                    }
                }
            }

            Section("Scheduled") {
                ForEach(viewModel.scheduledTransactions) { scheduled in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(scheduled.description ?? scheduled.type.rawValue.capitalized)
                                .font(.body)
                            Spacer()
                            Text(scheduled.amount.asCurrency(code: scheduled.currency))
                                .font(.body.monospacedDigit().bold())
                        }

                        HStack {
                            Label(scheduled.recurrence.rawValue.capitalized, systemImage: "repeat")
                            Spacer()
                            Text("Next: \(scheduled.nextDueDate, style: .date)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Scheduled")
        .overlay {
            if viewModel.scheduledTransactions.isEmpty && viewModel.pendingTransactions.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No Scheduled Transactions",
                    message: "Set up recurring transactions to automate your workflow.",
                    systemImage: "clock.arrow.2.circlepath"
                )
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
