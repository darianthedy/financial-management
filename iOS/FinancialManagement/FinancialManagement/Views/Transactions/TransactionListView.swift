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

    /// True only for the top-level Transactions tab, which owns its navigation
    /// stack and therefore needs no back button — so we can hide the system bar
    /// entirely and let our custom header reach the top. Pushed presentations
    /// (e.g. the budget drilldown) leave it false to keep the bar's back button.
    private let isRoot: Bool

    init(
        scopedAccountId: UUID? = nil,
        initialFilters: TransactionFilters? = nil,
        isRoot: Bool = false
    ) {
        _viewModel = State(initialValue: TransactionListViewModel(
            scopedAccountId: scopedAccountId, initialFilters: initialFilters
        ))
        _searchText = State(initialValue: initialFilters?.search ?? "")
        self.isRoot = isRoot
    }

    private var isScoped: Bool { viewModel.scopedAccountId != nil }

    /// The scoped account-detail embedding keeps the system large title + toolbar
    /// actions; every other context renders its own heading so the title and the
    /// Summary/Add buttons share one row (see `headerBar`).
    private var usesCustomHeader: Bool { !isScoped }

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

            if usesCustomHeader { headerBar }

            if !isScoped {
                searchBar
                if !viewModel.filters.isEmpty { chipsBar }
            }

            transactionList
        }
        // The custom header draws its own title, so collapse the system title to
        // an empty inline bar (this keeps the back button on pushed
        // presentations). The root tab has no back button, so hide the bar
        // outright and let the header sit at the top.
        .navigationTitle(usesCustomHeader ? "" : "Transactions")
        .navigationBarTitleDisplayMode(usesCustomHeader ? .inline : .automatic)
        .toolbar(isRoot ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            // Scoped account detail keeps web's header actions in the system bar:
            // an outline "Summary" button and a filled primary "Add" button.
            if isScoped {
                ToolbarItemGroup(placement: .primaryAction) {
                    summaryButton(showLabel: true)
                    addButton(showLabel: true)
                }
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

    // MARK: - Header

    /// The screen heading with its actions on the same row, mirroring web's page
    /// header (web/src/pages/transactions.tsx) where "Summary" and "Add" sit
    /// inline with the title.
    ///
    /// iOS large navigation titles always render on their own line *below* the
    /// bar's trailing actions, so the system can't keep a big title and inline
    /// buttons together — hence the hand-rolled header. When the row is too
    /// narrow for the labeled pills (most iPhones, where the wide "Transactions"
    /// title dominates), `ViewThatFits` falls back to icon-only buttons.
    private var headerBar: some View {
        HStack(spacing: 8) {
            Text("Transactions")
                .font(.largeTitle.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)

            Spacer(minLength: 8)

            ViewThatFits(in: .horizontal) {
                actionButtons(showLabels: true)
                actionButtons(showLabels: false)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func actionButtons(showLabels: Bool) -> some View {
        HStack(spacing: 8) {
            summaryButton(showLabel: showLabels)
            addButton(showLabel: showLabels)
        }
    }

    private func summaryButton(showLabel: Bool) -> some View {
        Button { showingSummary = true } label: {
            if showLabel {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.xaxis")
                    Text("Summary")
                }
            } else {
                Image(systemName: "chart.bar.xaxis")
            }
        }
        .buttonStyle(.bordered)
        .tint(Color.appForeground)
        .accessibilityLabel("Summary")
    }

    private func addButton(showLabel: Bool) -> some View {
        Button { showingForm = true } label: {
            if showLabel {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add")
                }
            } else {
                Image(systemName: "plus")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.appPrimary)
        .accessibilityLabel("Add")
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
            ForEach(viewModel.dateGroups) { group in
                Section {
                    ForEach(group.transactions) { txn in
                        row(for: txn)
                    }
                } header: {
                    dateGroupHeader(group)
                        // Reset the plain-list header insets so our own background
                        // spans edge-to-edge, then restore the row's horizontal
                        // inset internally to keep the heading aligned with the
                        // rows below it.
                        .listRowInsets(EdgeInsets())
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

    /// A single row with its tap/swipe actions and the infinite-scroll trigger.
    /// The date lives in the section header now, so the row hides its own.
    private func row(for txn: Transaction) -> some View {
        TransactionRow(
            transaction: txn,
            account: viewModel.account(for: txn),
            category: viewModel.category(for: txn),
            transferAccountName: viewModel.transferAccount(for: txn)?.name,
            tags: viewModel.tags(for: txn),
            budgetName: viewModel.budgetName(for: txn),
            fixedExpenseName: viewModel.fixedExpenseName(for: txn),
            isSpread: viewModel.isSpread(txn),
            showDate: false,
            widestNumber: widestAmountBody,
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

    // MARK: - Date group header (web: DateGroupHeader)

    /// Sticky per-day heading: the absolute date on the left, the item count and
    /// the day's net (green/red, muted when it nets to zero) on the right.
    private func dateGroupHeader(_ group: TransactionDateGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(group.dateLabel)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Color.appMutedForeground)
            Spacer()
            Text("\(group.count) \(group.count == 1 ? "item" : "items")")
                .font(.caption)
                .foregroundStyle(Color.appMutedForeground)
            // Same component + shared width as the rows, so symbol and digits
            // align into one column through the header. The net carries an
            // explicit +/− sign; a day that nets to zero shows neither. The
            // trailing spacer mirrors the row's ⋮ actions button (28pt) and its
            // 12pt gap, so the net lines up with the amount column above the menu.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                AmountColumnView(
                    minorUnits: group.net,
                    sign: netSign(group.net),
                    currencyCode: appState.defaultCurrency,
                    widestNumber: widestAmountBody
                )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(netColor(group.net))
                Color.clear.frame(width: 28, height: 0)
            }
        }
        .textCase(nil)
        // Match the rows' horizontal inset (we zero the header's list insets in
        // the Section so the background can reach the edges) plus a little
        // vertical breathing room.
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Opaque backdrop so the pinned header doesn't let the rows scrolling
        // underneath it show through.
        .background(Color.appBackground)
    }

    /// The widest number body across the loaded rows and the per-day nets, so the
    /// whole list (rows and headers) shares one digit column (see `AmountColumnView`).
    private var widestAmountBody: String {
        var maxAbs: Int64 = 0
        for txn in viewModel.transactions { maxAbs = max(maxAbs, abs(txn.amount)) }
        for group in viewModel.dateGroups { maxAbs = max(maxAbs, abs(group.net)) }
        return CurrencyUtils.numberBody(maxAbs, currency: appState.defaultCurrency)
    }

    private func netSign(_ net: Int64) -> String {
        if net > 0 { return "+" }
        if net < 0 { return "-" }
        return ""
    }

    private func netColor(_ net: Int64) -> Color {
        if net > 0 { return .appSuccess }
        if net < 0 { return .appDanger }
        return .appMutedForeground
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
