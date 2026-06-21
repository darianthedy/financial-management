import SwiftUI

struct ScheduledListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ScheduledTransactionViewModel()
    @State private var editingPending: Transaction?

    var body: some View {
        List {
            if !viewModel.pendingTransactions.isEmpty {
                Section("Pending") {
                    ForEach(viewModel.pendingTransactions) { pending in
                        PendingTransactionRow(
                            pending: pending,
                            onConfirm: { await viewModel.confirmPending(pending) },
                            onEdit: { editingPending = pending },
                            onDismiss: { await viewModel.dismissPending(pending) }
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
                            Text(scheduled.amount.asCurrency(code: appState.defaultCurrency))
                                .font(.body.monospacedDigit().bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
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
        .sheet(item: $editingPending) { txn in
            NavigationStack {
                TransactionFormView(
                    editing: txn,
                    currency: appState.defaultCurrency,
                    decimalPlaces: appState.decimalPlaces
                ) {
                    await viewModel.load()
                }
            }
        }
        .task {
            viewModel.currencyCode = appState.defaultCurrency
            _ = await NotificationService.shared.requestPermission()
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
        .onDisappear {
            Task { await viewModel.unsubscribe() }
        }
        .refreshable { await viewModel.load() }
    }
}
