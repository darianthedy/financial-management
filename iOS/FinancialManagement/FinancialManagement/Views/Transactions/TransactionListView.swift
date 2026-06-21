import SwiftUI

struct TransactionListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: TransactionListViewModel
    @State private var showingForm = false
    @State private var editingTransaction: Transaction?
    @State private var installmentSource: Transaction?
    @State private var showingFilters = false
    @State private var showingSummary = false
    @State private var searchText = ""

    init(scopedAccountId: UUID? = nil, initialFilters: TransactionFilters? = nil) {
        _viewModel = State(initialValue: TransactionListViewModel(
            scopedAccountId: scopedAccountId, initialFilters: initialFilters
        ))
        _searchText = State(initialValue: initialFilters?.search ?? "")
    }

    private var isScoped: Bool { viewModel.scopedAccountId != nil }

    /// The MonthNavigator shows for the scoped account-detail list, and on the
    /// main list until an explicit Date-range filter takes over the period.
    private var showsMonthNavigator: Bool {
        isScoped || !viewModel.hasExplicitDateRange
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsMonthNavigator {
                MonthNavigator(
                    yearMonth: viewModel.yearMonth,
                    onPrevious: { viewModel.navigateMonth(by: -1) },
                    onNext: { viewModel.navigateMonth(by: 1) }
                )
                .padding([.horizontal, .top])
            }

            if !isScoped {
                searchBar
                controlBar
                if !viewModel.filters.isEmpty { chipsBar }
            }

            transactionList
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingForm) {
            NavigationStack {
                TransactionFormView(
                    defaultAccountId: appState.defaultAccountId,
                    currency: appState.defaultCurrency,
                    decimalPlaces: appState.decimalPlaces
                ) {
                    await viewModel.load()
                }
            }
        }
        .sheet(item: $editingTransaction) { txn in
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
        .sheet(item: $installmentSource) { source in
            CreateInstallmentSheet(source: source) {
                await viewModel.load()
            }
        }
        .sheet(isPresented: $showingFilters) {
            TransactionFilterSheet(initial: viewModel.filters) { newFilters in
                viewModel.applyFilters(newFilters)
                searchText = newFilters.search ?? ""
            }
        }
        .sheet(isPresented: $showingSummary) {
            TransactionSummarySheet(
                filters: viewModel.effectiveFilters,
                currencyCode: appState.defaultCurrency,
                accountsById: viewModel.accountsById,
                categoriesById: viewModel.categoriesById,
                tagsById: viewModel.tagsById
            )
        }
        .swipeToNavigateMonth(
            onPrevious: { if showsMonthNavigator { viewModel.navigateMonth(by: -1) } },
            onNext: { if showsMonthNavigator { viewModel.navigateMonth(by: 1) } }
        )
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Bars

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.appMutedForeground)
            TextField("Search description", text: $searchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.appMutedForeground)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.appMuted)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .padding(.horizontal)
        .padding(.top, 8)
        // Debounce: re-fires only after typing pauses ~300ms.
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            viewModel.updateSearch(searchText)
        }
    }

    private var controlBar: some View {
        HStack {
            Button { showingFilters = true } label: {
                Label(
                    viewModel.filters.activeCount > 0 ? "Filters (\(viewModel.filters.activeCount))" : "Filters",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }

            Spacer()

            Text("\(viewModel.totalCount) match\(viewModel.totalCount == 1 ? "" : "es")")
                .font(.caption)
                .foregroundStyle(Color.appMutedForeground)

            Spacer()

            Menu {
                Picker("Page size", selection: Binding(
                    get: { viewModel.pageSize },
                    set: { viewModel.setPageSize($0) }
                )) {
                    ForEach(transactionPageSizes, id: \.self) { size in
                        Text("\(size) / page").tag(size)
                    }
                }
            } label: {
                Image(systemName: "square.stack.3d.up")
            }

            Button { showingSummary = true } label: {
                Image(systemName: "chart.pie")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var chipsBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(activeChips, id: \.key) { chip in
                        removableChip(label: chip.label) { clear(chip.key) }
                    }
                }
                .padding(.horizontal)
            }
            Button("Clear all") {
                viewModel.clearAllFilters()
                searchText = ""
            }
            .font(.caption)
            .tint(Color.appPrimary)
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private func removableChip(label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption.weight(.medium))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.appPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.appPrimary.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.appPrimary.opacity(0.3), lineWidth: 1))
    }

    private var transactionList: some View {
        List {
            ForEach(viewModel.transactions) { txn in
                TransactionRow(
                    transaction: txn,
                    account: viewModel.account(for: txn),
                    category: viewModel.category(for: txn),
                    transferAccountName: viewModel.transferAccount(for: txn)?.name,
                    tags: viewModel.tags(for: txn),
                    budgetName: viewModel.budgetName(for: txn),
                    fixedExpenseName: viewModel.fixedExpenseName(for: txn),
                    isSpread: viewModel.isSpread(txn),
                    onCreateInstallment: { installmentSource = txn }
                )
                    .listRowBackground(txn.status == .pending ? Color.appMuted : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { editingTransaction = txn }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if txn.status == .pending {
                            Button {
                                Task { await viewModel.setStatus(txn, to: .confirmed) }
                            } label: {
                                Label("Confirm", systemImage: "checkmark")
                            }
                            .tint(Color.appSuccess)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteTransaction(txn) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        if txn.status == .pending {
                            Button {
                                Task { await viewModel.setStatus(txn, to: .dismissed) }
                            } label: {
                                Label("Dismiss", systemImage: "xmark")
                            }
                            .tint(Color.appWarning)
                        }
                    }
                    .onAppear {
                        if txn.id == viewModel.transactions.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.transactions.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No Transactions",
                    message: viewModel.filters.isEmpty
                        ? "Add your first transaction for this month."
                        : "No transactions match these filters.",
                    systemImage: "list.bullet"
                )
            }
        }
        .monthPageTransition(
            yearMonth: showsMonthNavigator ? viewModel.yearMonth : "filtered",
            direction: viewModel.navigationDirection
        )
    }

    // MARK: - Chips

    private struct Chip { let key: FilterFacetKey; let label: String }

    private var activeChips: [Chip] {
        FilterFacetKey.allCases.compactMap { key in
            chipLabel(for: key).map { Chip(key: key, label: $0) }
        }
    }

    private func clear(_ key: FilterFacetKey) {
        viewModel.clearFacet(key)
        if key == .search { searchText = "" }
    }

    private func chipLabel(for key: FilterFacetKey) -> String? {
        let f = viewModel.filters
        switch key {
        case .search:
            guard let s = f.search, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return "“\(s)”"
        case .types:
            return f.types.map { "Type: " + facetText($0, names: { $0.rawValue.capitalized }) }
        case .accounts:
            return f.accounts.map { "Account: " + facetText($0, names: { viewModel.accountsById[$0]?.name ?? "—" }) }
        case .statuses:
            return f.statuses.map { "Status: " + facetText($0, names: { $0.rawValue.capitalized }) }
        case .date:
            return dateChipLabel(f)
        case .amount:
            return amountChipLabel(f)
        case .categories:
            return f.categories.map { "Category: " + facetText($0, names: { viewModel.categoriesById[$0]?.name ?? "—" }) }
        case .tags:
            return f.tags.map { "Tags: " + facetText($0, names: { viewModel.tagsById[$0]?.name ?? "—" }) }
        case .budgets:
            return f.budgets.map { "Budget: " + facetText($0, names: { $0 }) }
        case .fixedExpenses:
            return f.fixedExpenses.map { "Fixed: " + facetText($0, names: { $0 }) }
        }
    }

    private func facetText<V: Hashable & Codable>(_ facet: Facet<V>, names: (V) -> String) -> String {
        if facet.matchesNothing { return "none" }
        var parts = facet.values.map(names).sorted()
        if facet.includeBlanks { parts.append("(Blanks)") }
        return parts.joined(separator: ", ")
    }

    private func dateChipLabel(_ f: TransactionFilters) -> String? {
        let fmt = Self.dateFormatter
        switch (f.dateFrom, f.dateTo) {
        case let (from?, to?): return "\(fmt.string(from: from)) – \(fmt.string(from: to))"
        case let (from?, nil): return "≥ \(fmt.string(from: from))"
        case let (nil, to?): return "≤ \(fmt.string(from: to))"
        case (nil, nil): return nil
        }
    }

    private func amountChipLabel(_ f: TransactionFilters) -> String? {
        let code = appState.defaultCurrency
        switch (f.amountMin, f.amountMax) {
        case let (min?, max?): return "\(min.asCurrency(code: code)) – \(max.asCurrency(code: code))"
        case let (min?, nil): return "≥ \(min.asCurrency(code: code))"
        case let (nil, max?): return "≤ \(max.asCurrency(code: code))"
        case (nil, nil): return nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
