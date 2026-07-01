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
    /// The transaction awaiting delete confirmation. Set by both the row's ⋮ menu
    /// and the trailing swipe so they share one confirmation alert.
    @State private var pendingDelete: Transaction?

    init(
        scopedAccountId: UUID? = nil,
        initialFilters: TransactionFilters? = nil
    ) {
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
        content
            // The main list uses the native large title; the (dormant) scoped
            // account-detail embedding keeps the inline title it had before.
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(isScoped ? .automatic : .large)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if isScoped {
                        // Scoped account detail keeps web's labeled header actions:
                        // an outline "Summary" button and a filled primary "Add".
                        summaryButton(showLabel: true)
                        addButton(showLabel: true)
                    } else {
                        // Main list: native nav-bar actions — Summary and Filter as
                        // secondary icons, Add as the primary create affordance.
                        // Search and the active-filter tokens live in the
                        // `.searchable` field (see `content`).
                        summaryToolbarButton
                        filterToolbarButton
                        addToolbarButton
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
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            // Shared delete confirmation for both the row ⋮ menu and the swipe
            // action (HIG: confirm permanent deletes).
            .alert(
                "Delete transaction?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { txn in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteTransaction(txn) }
                }
            } message: { _ in
                Text("This permanently removes the transaction and updates the affected account balances. This can't be undone.")
            }
    }

    // MARK: - Content

    /// The list (and, when scoped, the month navigator), with the native search
    /// field + active-filter tokens layered on for the main list. The scoped
    /// embedding omits search to preserve its month-by-month browsing.
    @ViewBuilder private var content: some View {
        if isScoped {
            listStack
        } else {
            listStack
                .searchable(
                    text: $searchText,
                    tokens: filterTokensBinding,
                    prompt: "Search description"
                ) { token in
                    Text(token.label)
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                // Debounce: re-query only after typing pauses ~300ms.
                .task(id: searchText) {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    viewModel.updateSearch(searchText)
                }
        }
    }

    /// The main list keeps the `List` as the direct child of the navigation
    /// container so the nav bar can track its scrolling — collapsing the large
    /// title and pulling its material background in as content scrolls under it.
    /// Wrapping the list in a `VStack` (or applying the month-page transition
    /// directly to it) detaches that tracking and leaves the bar transparent, so
    /// only the scoped embedding — which needs the month navigator above the
    /// list — uses the stack, and the page transition rides an inner view there.
    @ViewBuilder private var listStack: some View {
        if showsMonthNavigator {
            VStack(spacing: 0) {
                MonthNavigator(
                    yearMonth: viewModel.yearMonth,
                    onPrevious: { viewModel.navigateMonth(by: -1) },
                    onNext: { viewModel.navigateMonth(by: 1) }
                )
                .padding([.horizontal, .top])

                transactionList
                    .monthPageTransition(
                        yearMonth: viewModel.yearMonth,
                        direction: viewModel.navigationDirection
                    )
            }
        } else {
            transactionList
        }
    }

    // MARK: - Toolbar actions (main list)

    private var summaryToolbarButton: some View {
        Button { showingSummary = true } label: {
            Image(systemName: "chart.bar.xaxis")
        }
        .tint(Color.appForeground)
        .accessibilityLabel("Summary")
    }

    /// Opens the faceted filter sheet. The icon fills and tints when any panel
    /// filter is active, so the state stays visible even when the search bar
    /// (which carries the per-filter tokens) is scrolled away.
    private var filterToolbarButton: some View {
        Button { showingFilters = true } label: {
            Image(systemName: panelFilterCount > 0
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .tint(panelFilterCount > 0 ? Color.appPrimary : Color.appForeground)
        .accessibilityLabel(panelFilterCount > 0 ? "Filters (\(panelFilterCount) active)" : "Filters")
    }

    private var addToolbarButton: some View {
        Button { showingForm = true } label: {
            Image(systemName: "plus")
        }
        .tint(Color.appPrimary)
        .accessibilityLabel("Add")
    }

    // MARK: - Scoped header actions (account-detail embedding)

    /// The scoped account-detail embedding keeps web's labeled header actions in
    /// the system bar: an outline "Summary" button and a filled primary "Add".
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

    // MARK: - Filter tokens

    /// One active panel filter surfaced as a removable token inside the search
    /// field. Identified by its facet key so the field can delete exactly that
    /// facet.
    private struct FilterToken: Identifiable {
        let key: FilterFacetKey
        let label: String
        var id: String { key.rawValue }
    }

    /// Active panel filters — everything except the free-text search, which is the
    /// search field itself — as tokens. This is the native iOS expression of web's
    /// active-filter chips (web/src/components/transactions/transaction-filters.tsx).
    private var filterTokens: [FilterToken] {
        FilterFacetKey.allCases
            .filter { $0 != .search }
            .compactMap { key in chipLabel(for: key).map { FilterToken(key: key, label: $0) } }
    }

    /// Reading yields the current tokens; deleting one (the search field's built-in
    /// token removal) clears exactly that facet and reloads. New filters are added
    /// via the filter sheet, so there is no token-suggestion path here.
    private var filterTokensBinding: Binding<[FilterToken]> {
        Binding(
            get: { filterTokens },
            set: { newTokens in
                let remaining = Set(newTokens.map(\.key))
                for token in filterTokens where !remaining.contains(token.key) {
                    viewModel.clearFacet(token.key)
                }
            }
        )
    }

    /// Active filters configured in the panel, i.e. everything except the
    /// always-visible search — mirrors web's `countPanelFilters`. Drives the
    /// filter toolbar button's active (filled) state.
    private var panelFilterCount: Int {
        var n = viewModel.filters.activeCount
        if let s = viewModel.filters.search,
           !s.trimmingCharacters(in: .whitespaces).isEmpty {
            n -= 1
        }
        return n
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
        // The month-page transition is applied by `listStack` for the scoped
        // embedding only — applying it here (to the List itself) would detach the
        // main list from the navigation bar's scroll tracking.
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
            onDelete: { pendingDelete = txn }
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
            // allowsFullSwipe:false so the destructive action can't auto-fire on a
            // long swipe — it reveals the button, which then routes through the
            // shared confirmation alert (consistent with FixedExpenses).
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    pendingDelete = txn
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
            // trailing spacer mirrors the row's ⋮ actions button (44pt hit area)
            // and its 12pt gap, so the net lines up with the amount column above
            // the menu.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                AmountColumnView(
                    minorUnits: group.net,
                    sign: netSign(group.net),
                    currencyCode: appState.defaultCurrency,
                    widestNumber: widestAmountBody
                )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(netColor(group.net))
                Color.clear.frame(width: 44, height: 0)
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
        // System-style hairline under the pinned header, matching the separator
        // UIKit draws beneath plain-list section headers.
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.appBorder)
                .frame(height: 0.5)
        }
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

    // MARK: - Filter labels

    /// The human-readable label for an active facet, reused as the token text.
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
        let signPart: String? = f.amountSign.map { $0 == .negative ? "Expense" : "Income" }
        let code = appState.defaultCurrency
        let rangePart: String? = {
            switch (f.amountMin, f.amountMax) {
            case let (min?, max?): return "\(min.asCurrency(code: code)) – \(max.asCurrency(code: code))"
            case let (min?, nil): return "≥ \(min.asCurrency(code: code))"
            case let (nil, max?): return "≤ \(max.asCurrency(code: code))"
            case (nil, nil): return nil
            }
        }()
        switch (signPart, rangePart) {
        case let (sign?, range?): return "\(sign): \(range)"
        case let (sign?, nil): return sign
        case (nil, let range?): return range
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
