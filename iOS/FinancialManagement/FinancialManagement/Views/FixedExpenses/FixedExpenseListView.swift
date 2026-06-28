import SwiftUI

/// Month-scoped fixed expenses (§8.5): an unpaid/paid split with subtotals,
/// `MonthNavigator`, and add / copy-from-previous / edit / delete.
/// Paid is derived — to mark one paid the user links a transaction to it.
struct FixedExpenseListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = FixedExpenseListViewModel()
    @State private var showingForm = false
    @State private var editingExpense: FixedExpense?
    /// The expense awaiting delete confirmation (swipe-only here).
    @State private var pendingDelete: FixedExpense?

    private var currencyCode: String { appState.defaultCurrency }

    var body: some View {
        VStack(spacing: 0) {
            MonthNavigator(
                yearMonth: viewModel.yearMonth,
                onPrevious: { viewModel.navigateMonth(by: -1) },
                onNext: { viewModel.navigateMonth(by: 1) }
            )
            .padding()

            content
                .monthPageTransition(
                    yearMonth: viewModel.yearMonth,
                    direction: viewModel.navigationDirection
                )
        }
        .navigationTitle("Fixed Expenses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingForm = true
                    } label: {
                        Label("New Fixed Expense", systemImage: "plus")
                    }
                    Button {
                        Task { await viewModel.copyFromPreviousMonth() }
                    } label: {
                        Label("Copy from Previous Month", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            FixedExpenseFormSheet(yearMonth: viewModel.yearMonth) {
                await viewModel.load()
            }
        }
        .sheet(item: $editingExpense) { expense in
            FixedExpenseEditSheet(expense: expense, decimalPlaces: appState.decimalPlaces) {
                await viewModel.load()
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        // Confirm the swipe delete (HIG: confirm permanent deletes), matching the
        // other destructive swipes across the app.
        .alert(
            "Delete fixed expense?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { expense in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteExpense(expense) }
            }
        } message: { expense in
            Text("Delete \"\(expense.name)\" for this month? Other months are unaffected.")
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            header

            if !viewModel.unpaidExpenses.isEmpty {
                section(
                    title: "Unpaid",
                    subtotal: viewModel.unpaidSubtotal,
                    expenses: viewModel.unpaidExpenses
                )
            }

            if !viewModel.paidExpenses.isEmpty {
                section(
                    title: "Paid",
                    subtotal: viewModel.paidSubtotal,
                    expenses: viewModel.paidExpenses
                )
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.fixedExpenses.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No Fixed Expenses",
                    message: "Add recurring bills or copy from the previous month.",
                    systemImage: "calendar.badge.clock"
                )
            }
        }
    }

    private var header: some View {
        HStack {
            Label("\(viewModel.paidCount)/\(viewModel.fixedExpenses.count) Paid", systemImage: "checkmark.circle")
                .font(.subheadline)
                .foregroundStyle(Color.appMutedForeground)
            Spacer()
            Text("Total: \(viewModel.totalAmount.asCurrency(code: currencyCode))")
                .font(.subheadline.bold())
                .foregroundStyle(Color.appForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .listRowSeparator(.hidden)
    }

    private func section(title: String, subtotal: Int64, expenses: [FixedExpense]) -> some View {
        Section {
            ForEach(expenses) { expense in
                FixedExpenseRow(
                    expense: expense,
                    isPaid: viewModel.isPaid(expense),
                    currencyCode: currencyCode
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDelete = expense
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editingExpense = expense
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(Color.appPrimary)
                }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Text(subtotal.asCurrency(code: currencyCode))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
