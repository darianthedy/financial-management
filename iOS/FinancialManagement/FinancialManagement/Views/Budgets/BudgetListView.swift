import SwiftUI

struct BudgetListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = BudgetListViewModel()
    @State private var formMode: BudgetFormSheet.Mode?
    @State private var drilldown: BudgetDrilldown?
    @State private var installmentSource: Transaction?
    /// The budget awaiting remove confirmation — shared by the card ⋮ menu and the
    /// trailing swipe so both go through one alert.
    @State private var pendingRemove: BudgetProgress?
    /// The installment awaiting cancel confirmation (swipe-only here).
    @State private var pendingCancel: ActiveInstallment?

    var body: some View {
        Group {
            if viewModel.progress.isEmpty && !viewModel.isLoading {
                VStack(spacing: 0) {
                    MonthNavigator(
                        yearMonth: viewModel.yearMonth,
                        onPrevious: { viewModel.navigateMonth(by: -1) },
                        onNext: { viewModel.navigateMonth(by: 1) }
                    )
                    .padding(.vertical, 8)
                    .background(Color.appBackground)

                    GeometryReader { geo in
                        ScrollView {
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                EmptyStateView(
                                    title: "No budgets this month",
                                    message: "Add a budget to track spending against a monthly target, or copy this month's set from the previous month.",
                                    systemImage: "target"
                                ) {
                                    Button("Copy previous month") {
                                        Task { await viewModel.copyFromPreviousMonth() }
                                    }
                                    Button("Add budget") {
                                        formMode = .add(yearMonth: viewModel.yearMonth)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: geo.size.height)
                        }
                        .background(Color.appBackground)
                    }
                    .monthPageTransition(
                        yearMonth: viewModel.yearMonth,
                        direction: viewModel.navigationDirection
                    )
                }
            } else {
                List {
                    Section {
                        ForEach(viewModel.progress) { progress in
                            BudgetCard(
                                progress: progress,
                                currencyCode: appState.defaultCurrency,
                                onEdit: { formMode = .edit(progress) },
                                onRemove: { pendingRemove = progress }
                            )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    drilldown = BudgetDrilldown(
                                        name: progress.budgetName, yearMonth: progress.yearMonth
                                    )
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .budgetRowInsets()
                                // The card's trailing three-dot menu (web parity) carries
                                // Edit/Remove; the swipe actions remain as a native iOS
                                // shortcut to the same actions — including the same remove
                                // confirmation. allowsFullSwipe:false so a long swipe can't
                                // auto-fire the destructive action.
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        formMode = .edit(progress)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.appPrimary)
                                    Button(role: .destructive) {
                                        pendingRemove = progress
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        MonthNavigator(
                            yearMonth: viewModel.yearMonth,
                            onPrevious: { viewModel.navigateMonth(by: -1) },
                            onNext: { viewModel.navigateMonth(by: 1) }
                        )
                        .padding(.vertical, 8)
                        .background(Color.appBackground)
                        .listRowInsets(EdgeInsets())
                    }

                    ActiveInstallmentsSection(
                        installments: viewModel.activeInstallments,
                        currencyCode: appState.defaultCurrency,
                        onSelect: { installmentSource = $0 },
                        onCancel: { pendingCancel = $0 }
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .monthPageTransition(
                    yearMonth: viewModel.yearMonth,
                    direction: viewModel.navigationDirection
                )
            }
        }
        .navigationTitle("Budgets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        formMode = .add(yearMonth: viewModel.yearMonth)
                    } label: {
                        Label("New Budget", systemImage: "plus")
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
        .sheet(item: $formMode) { mode in
            BudgetFormSheet(mode: mode, viewModel: viewModel)
        }
        .sheet(item: $installmentSource) { source in
            NavigationStack {
                TransactionFormView(
                    editing: source,
                    currency: appState.defaultCurrency,
                    decimalPlaces: appState.decimalPlaces
                ) {
                    await viewModel.load()
                }
            }
        }
        .navigationDestination(item: $drilldown) { link in
            TransactionListView(initialFilters: link.filters)
        }
        .task {
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
        .onDisappear { Task { await viewModel.unsubscribe() } }
        .refreshable { await viewModel.load() }
        // Shared remove confirmation for both the card ⋮ menu and the swipe action
        // (HIG: confirm permanent deletes).
        .alert(
            "Remove budget?",
            isPresented: Binding(
                get: { pendingRemove != nil },
                set: { if !$0 { pendingRemove = nil } }
            ),
            presenting: pendingRemove
        ) { progress in
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeBudget(id: progress.budgetId) }
            }
        } message: { progress in
            Text("Remove \"\(progress.budgetName)\" for \(DateUtils.formatYearMonth(progress.yearMonth))? This month's row is deleted; other months are unaffected.")
        }
        // Cancelling an installment deletes its header and cascades to its
        // allocations, so confirm it like the other destructive swipes.
        .alert(
            "Cancel installment?",
            isPresented: Binding(
                get: { pendingCancel != nil },
                set: { if !$0 { pendingCancel = nil } }
            ),
            presenting: pendingCancel
        ) { item in
            Button("Keep Installment", role: .cancel) {}
            Button("Cancel Installment", role: .destructive) {
                Task { await viewModel.cancelInstallment(item) }
            }
        } message: { item in
            Text("Cancel \"\(item.title)\"? Its future reservations are deleted and the affected budgets recover their allowance. This can't be undone.")
        }
    }
}

/// A tap target that opens the Transactions list filtered to one budget's
/// **name**, scoped to that budget's own month (date range pinned to the month).
struct BudgetDrilldown: Identifiable, Hashable {
    let name: String
    let yearMonth: String

    var id: String { "\(name)|\(yearMonth)" }

    var filters: TransactionFilters {
        var f = TransactionFilters()
        f.budgets = Facet(values: [name])
        if let range = DateUtils.monthDateRange(yearMonth) {
            f.dateFrom = range.start
            f.dateTo = range.end
        }
        return f
    }
}

extension BudgetFormSheet.Mode: Identifiable {
    var id: String {
        switch self {
        case .add(let yearMonth): return "add-\(yearMonth)"
        case .edit(let progress): return "edit-\(progress.budgetId.uuidString)"
        }
    }
}
