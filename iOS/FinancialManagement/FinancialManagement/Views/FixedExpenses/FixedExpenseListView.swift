import SwiftUI

/// Month-scoped fixed expenses (§8.5): an unpaid/paid split with subtotals,
/// `MonthNavigator`, and add / copy-from-previous / edit / delete.
/// Paid is derived — to mark one paid the user links a transaction to it.
///
/// On regular width (implementation plan D2.4) tapping a row shows its linked
/// transactions in the detail column; the month navigator stays in the list
/// column, and changing month clears the selection. Compact rows have no tap
/// action, as before.
struct FixedExpenseListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.foldKeptModels) private var keptModels
    @State private var localModel = FixedExpenseListViewModel()
    @State private var showingForm = false
    @State private var editingExpense: FixedExpense?
    /// The expense we're adding a linked (paid) transaction for.
    @State private var addingTransactionFor: FixedExpense?
    /// The expense awaiting delete confirmation (swipe-only here).
    @State private var pendingDelete: FixedExpense?
    /// The tiled split's selection (regular width only), by expense ID.
    @State private var selectedExpenseId: UUID?

    init(selectedExpenseId: UUID? = nil) {
        _selectedExpenseId = State(initialValue: selectedExpenseId)
    }

    private var currencyCode: String { appState.defaultCurrency }

    private var viewModel: FixedExpenseListViewModel { keptModels?.fixedExpenses ?? localModel }

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
        .refreshable { await viewModel.load() }
        .splitDetail(
            selection: $selectedExpenseId,
            in: viewModel.fixedExpenses.map(\.id),
            id: \.uuidString,
            storageKey: "fixedExpenses",
            placeholder: SplitPlaceholder(
                title: "Select a Fixed Expense",
                systemImage: "receipt",
                description: "The transactions that paid it appear here."
            )
        ) { expenseId in
            if let expense = viewModel.fixedExpenses.first(where: { $0.id == expenseId }) {
                DrilldownTransactionList(
                    screen: "fixedExpenses", item: expense.id.uuidString,
                    filters: Self.linkedTransactionFilters(for: expense)
                )
            }
        }
        .foldSafeSheet(isPresented: $showingForm) {
            FixedExpenseFormSheet(yearMonth: viewModel.yearMonth) {
                await viewModel.load()
            }
        }
        .foldSafeSheet(item: $editingExpense) { expense in
            FixedExpenseEditSheet(expense: expense, decimalPlaces: appState.decimalPlaces) {
                await viewModel.load()
            }
        }
        // "Add transaction" opens the transaction form pre-linked to this expense
        // (an expense, which marks it paid) with the amount and month prefilled —
        // mirrors web's `addTransaction`.
        .foldSafeSheet(item: $addingTransactionFor) { expense in
            NavigationStack {
                TransactionFormView(
                    defaultAccountId: appState.defaultAccountId,
                    currency: appState.defaultCurrency,
                    decimalPlaces: appState.decimalPlaces,
                    prefillFixedExpenseId: expense.id,
                    prefillAmount: prefillAmount(for: expense),
                    prefillDate: prefillDate(for: expense)
                ) {
                    await viewModel.load()
                }
            }
        }
        // A month with no fixed expenses lists nothing, which `.splitDetail`
        // treats as still loading, so drop the selection explicitly.
        .onChange(of: viewModel.yearMonth) { selectedExpenseId = nil }
        .task { await viewModel.load() }
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
                .splitSelectOnTap { selectedExpenseId = expense.id }
                .splitRowSelected(selectedExpenseId == expense.id)
                .layoutProbe("fixed.row.\(expense.name)", interactive: true)
                // Web parity: each row carries Add transaction / Edit / Delete.
                // The context menu holds all three (like web's ⋮ dropdown); the
                // swipe actions remain as the native iOS shortcut.
                .contextMenu {
                    Button {
                        addingTransactionFor = expense
                    } label: {
                        Label("Add Transaction", systemImage: "arrow.left.arrow.right")
                    }
                    Button {
                        editingExpense = expense
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        pendingDelete = expense
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        addingTransactionFor = expense
                    } label: {
                        Label("Add Transaction", systemImage: "arrow.left.arrow.right")
                    }
                    .tint(Color.appSuccess)
                }
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

    /// The transactions linked to `expense`: the fixed-expense facet (by name)
    /// pinned to the expense's own month, like a budget drill-down.
    static func linkedTransactionFilters(for expense: FixedExpense) -> TransactionFilters {
        var filters = TransactionFilters()
        filters.fixedExpenses = Facet(values: [expense.name])
        if let range = DateUtils.monthDateRange(expense.yearMonth) {
            filters.dateFrom = range.start
            filters.dateTo = range.end
        }
        return filters
    }

    /// Prefilled amount (display units) for a linked transaction — the expense's
    /// known cost, so the user doesn't retype it. Mirrors web's `toDisplayAmount`.
    private func prefillAmount(for expense: FixedExpense) -> String {
        String(CurrencyUtils.toDisplayAmount(expense.amount, decimalPlaces: appState.decimalPlaces))
    }

    /// Prefilled date for a linked transaction: today when it falls in the
    /// expense's month (so the fixed-expense picker lists and pre-selects it),
    /// otherwise the month's first day. Mirrors web's `addTransaction`.
    private func prefillDate(for expense: FixedExpense) -> Date {
        if DateUtils.yearMonth(from: Date()) == expense.yearMonth {
            return Date()
        }
        return DateUtils.monthDateRange(expense.yearMonth)?.start ?? Date()
    }
}
