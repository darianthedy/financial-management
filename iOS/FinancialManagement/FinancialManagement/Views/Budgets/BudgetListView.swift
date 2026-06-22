import SwiftUI

struct BudgetListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = BudgetListViewModel()
    @State private var formMode: BudgetFormSheet.Mode?
    @State private var drilldown: BudgetDrilldown?
    @State private var installmentSource: Transaction?

    var body: some View {
        VStack(spacing: 0) {
            MonthNavigator(
                yearMonth: viewModel.yearMonth,
                onPrevious: { viewModel.navigateMonth(by: -1) },
                onNext: { viewModel.navigateMonth(by: 1) }
            )
            .padding()

            List {
                ForEach(viewModel.progress) { progress in
                    BudgetCard(progress: progress, currencyCode: appState.defaultCurrency)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            drilldown = BudgetDrilldown(
                                name: progress.budgetName, yearMonth: progress.yearMonth
                            )
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.removeBudget(id: progress.budgetId) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            Button {
                                formMode = .edit(progress)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.appPrimary)
                        }
                }

                ActiveInstallmentsSection(
                    installments: viewModel.activeInstallments,
                    currencyCode: appState.defaultCurrency,
                    onSelect: { installmentSource = $0 },
                    onCancel: { item in Task { await viewModel.cancelInstallment(item) } }
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .overlay {
                if viewModel.progress.isEmpty && !viewModel.isLoading {
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
                }
            }
            .monthPageTransition(
                yearMonth: viewModel.yearMonth,
                direction: viewModel.navigationDirection
            )
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
        .swipeToNavigateMonth(
            onPrevious: { viewModel.navigateMonth(by: -1) },
            onNext: { viewModel.navigateMonth(by: 1) }
        )
        .task {
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
        .onDisappear { Task { await viewModel.unsubscribe() } }
        .refreshable { await viewModel.load() }
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
