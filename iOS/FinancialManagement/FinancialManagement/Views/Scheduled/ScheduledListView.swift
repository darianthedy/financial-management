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
                    ScheduledRow(scheduled: scheduled, currencyCode: appState.defaultCurrency)
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

/// A recurring scheduled-transaction row, aligned to web's `ScheduledCard`
/// (`web/src/components/scheduled/scheduled-card.tsx`): a title, an amount tinted
/// by type (income → success, expense → danger), a muted next-due footer with a
/// calendar-clock glyph reading "Next" / "Paused · next", and a dimmed
/// appearance while paused. iOS does not yet load the joined account / category
/// / tag metadata the web card renders as an avatar and chips, so the row omits
/// those.
private struct ScheduledRow: View {
    let scheduled: ScheduledTransaction
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(scheduled.description ?? scheduled.type.rawValue.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(1)

                Label {
                    Text("\(scheduled.isActive ? "Next" : "Paused · next") \(Self.dateFormatter.string(from: scheduled.nextDueDate))")
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                }
                .font(.caption)
                .foregroundStyle(Color.appMutedForeground)
            }

            Spacer(minLength: 8)

            Text(scheduled.amount.asCurrency(code: currencyCode))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 4)
        .opacity(scheduled.isActive ? 1 : 0.6)
    }

    /// Matches web `amountColor`: income → success, expense → danger,
    /// transfer → foreground.
    private var amountColor: Color {
        switch scheduled.type {
        case .income: return .appSuccess
        case .expense: return .appDanger
        case .transfer: return .appForeground
        }
    }

    /// Web date format: "MMM d, yyyy" (e.g. "Jun 3, 2026").
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
}
