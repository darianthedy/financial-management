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

    /// The MonthNavigator is only used by the scoped account-detail embedding.
    /// The main Transactions list mirrors web (web/src/pages/transactions.tsx):
    /// no month navigator — filters drive the period and the list defaults to all
    /// transactions.
    private var showsMonthNavigator: Bool {
        isScoped
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
                if !viewModel.filters.isEmpty { chipsBar }
            }

            transactionList
        }
        .navigationTitle("Transactions")
        .toolbar {
            // Web header actions (web/src/pages/transactions.tsx): an outline
            // "Summary" button and a filled primary "Add" button.
            ToolbarItemGroup(placement: .primaryAction) {
                // Explicit icon+text content: a bare `Label` renders icon-only in
                // the toolbar, so spell out the row to keep web's labeled pills.
                Button { showingSummary = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                        Text("Summary")
                    }
                }
                .buttonStyle(.bordered)
                .tint(Color.appForeground)

                Button { showingForm = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appPrimary)
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

    /// Web's filter bar (web/src/components/transactions/transaction-filters.tsx):
    /// the search field with a compact filter trigger on its right. The trigger
    /// shows the active panel-filter count (green) or a sliders icon.
    private var searchBar: some View {
        HStack(spacing: 8) {
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

            filterButton
        }
        .padding(.horizontal)
        .padding(.top, 8)
        // Debounce: re-fires only after typing pauses ~300ms.
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            viewModel.updateSearch(searchText)
        }
    }

    /// Active filters configured in the panel, i.e. everything except the
    /// always-visible search — mirrors web's `countPanelFilters`, which the
    /// filter button badges.
    private var panelFilterCount: Int {
        var n = viewModel.filters.activeCount
        if let s = viewModel.filters.search,
           !s.trimmingCharacters(in: .whitespaces).isEmpty {
            n -= 1
        }
        return n
    }

    private var filterButton: some View {
        Button { showingFilters = true } label: {
            Group {
                if panelFilterCount > 0 {
                    Text("\(panelFilterCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appSuccess)
                } else {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Color.appForeground)
                }
            }
            .frame(width: 38, height: 38)
            .background(Color.appMuted, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(panelFilterCount > 0 ? "Filters (\(panelFilterCount) active)" : "Filters")
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
                    onCreateInstallment: { installmentSource = txn },
                    onEdit: { editingTransaction = txn },
                    onDelete: { Task { await viewModel.deleteTransaction(txn) } }
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
