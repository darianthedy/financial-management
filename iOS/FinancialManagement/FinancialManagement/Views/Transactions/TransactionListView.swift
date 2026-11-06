import SwiftUI

/// Transactions (S6). Tapping a row opens its `TransactionDetailView`, a
/// read-only Contacts-style card whose Edit turns it into the form in place: in
/// the detail column as the Transactions section root on regular width (iPhone
/// Duo plan D3.1), pushed everywhere else. Switching rows with unsaved edits
/// asks "Discard changes?" first. New still opens a sheet. Drill-down
/// embeddings (Budgets, Categories, …) never tile.
struct TransactionListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.canTileSplitRoot) private var canTileSplitRoot
    @Environment(\.transactionDrafts) private var sharedDrafts
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel: TransactionListViewModel
    @State private var showingForm = false
    /// The transaction pushed from a drill-down embedding (not the tab root).
    @State private var pushedTransactionId: UUID?
    /// The transaction to open already editing (the row menu's Edit).
    @State private var editOnOpen: UUID?
    @State private var installmentSource: Transaction?
    @State private var showingFilters = false
    @State private var searchText = ""
    /// The transaction awaiting delete confirmation. Set by both the row's long-press menu
    /// and the trailing swipe so they share one confirmation alert.
    @State private var pendingDelete: Transaction?
    /// The tiled split's selection (transaction ID), guarded against dropping
    /// edits. Tab root only.
    @State private var selection: GuardedSelection<UUID>
    /// Used when no `ContentRootView` provides shared drafts (hosted tests).
    @State private var localDrafts = TransactionEditorDrafts()
    /// The Transactions tab root, the only embedding that adopts the split.
    private let isTabRoot: Bool
    /// A drill-down's own filters (its budget, tag, month, …): what the screen
    /// is, not a search the user made, so they aren't removable search tokens.
    /// The search field's clear button would otherwise drop them with the
    /// text and turn the drill-down into every transaction.
    private let scopeFacets: Set<FilterFacetKey>

    init(
        scopedAccountId: UUID? = nil,
        initialFilters: TransactionFilters? = nil,
        model: TransactionListViewModel? = nil,
        isTabRoot: Bool = false,
        selectedTransactionId: UUID? = nil,
        showsSummary: Bool = false
    ) {
        // The tab root passes a model owned above the size-class branches, so
        // its filters and search survive a fold that re-creates this view.
        let model = model ?? TransactionListViewModel(
            scopedAccountId: scopedAccountId, initialFilters: initialFilters
        )
        _viewModel = State(initialValue: model)
        _searchText = State(initialValue: model.filters.search ?? "")
        _selection = State(initialValue: GuardedSelection(selection: isTabRoot ? selectedTransactionId : nil))
        self.isTabRoot = isTabRoot
        scopeFacets = isTabRoot ? [] : (initialFilters?.activeFacets ?? [])
        if showsSummary { model.isShowingSummary = true }
    }

    private var drafts: TransactionEditorDrafts { sharedDrafts ?? localDrafts }

    /// On the model, so an open Summary stays open through a fold.
    private var showingSummary: Bool {
        get { viewModel.isShowingSummary }
        nonmutating set { viewModel.isShowingSummary = newValue }
    }

    private var showingSummaryBinding: Binding<Bool> {
        Binding(get: { showingSummary }, set: { showingSummary = $0 })
    }

    /// Whether this list tiles list | detail (tab root on regular width).
    private var tilesDetail: Bool { isTabRoot && canTileSplitRoot }

    /// Opens the transaction's detail: the tab root's split selection (the
    /// detail column when tiled, else pushed), or a push from a drill-down.
    /// `editing` opens it straight into the form (the row menu's Edit).
    private func open(_ txn: Transaction, editing: Bool = false) {
        editOnOpen = editing ? txn.id : nil
        if isTabRoot {
            selection.request(txn.id)
        } else {
            pushedTransactionId = txn.id
        }
    }

    /// Closes the open detail (e.g. after deleting its transaction).
    private func closeDetail() {
        if isTabRoot { selection.close() } else { pushedTransactionId = nil }
    }

    private var isScoped: Bool { viewModel.scopedAccountId != nil }

    /// The MonthNavigator is only used by the scoped account-detail embedding.
    /// The main Transactions list mirrors web (web/src/pages/transactions.tsx):
    /// no month navigator — filters drive the period and the list defaults to all
    /// transactions.
    private var showsMonthNavigator: Bool {
        isScoped
    }

    @ViewBuilder
    var body: some View {
        if isTabRoot && horizontalSizeClass == .regular {
            // Summary (F3) is a sheet everywhere: a side panel inside the
            // system split covered the detail column's editor.
            splitScreen
                .sheet(isPresented: showingSummaryBinding) { summaryView }
                .tentGlance { glance }
        } else if isTabRoot {
            splitScreen.sheet(isPresented: showingSummaryBinding) { summaryView }
        } else {
            // Drill-downs (Budgets, Categories, Tags, …): the sheet, as before.
            screen.sheet(isPresented: showingSummaryBinding) { summaryView }
        }
    }

    /// Tent posture (D6.2): the size of the current result, and the latest
    /// day's net. The Summary has the full totals, but costs a fetch.
    private var glance: some View {
        var stats = [GlanceStats.Stat(label: "Transactions", value: "\(viewModel.totalCount)")]
        if let latest = viewModel.dateGroups.first {
            stats.append(.init(
                label: latest.dateLabel,
                value: CurrencyUtils.format(latest.net, currency: appState.defaultCurrency, decimalPlaces: appState.decimalPlaces)
            ))
        }
        return GlanceStats(stats: stats)
    }

    private var summaryView: some View {
        TransactionSummarySheet(
            filters: viewModel.effectiveFilters,
            currencyCode: appState.defaultCurrency,
            accountsById: viewModel.accountsById,
            categoriesById: viewModel.categoriesById,
            tagsById: viewModel.tagsById,
            onDone: { showingSummary = false }
        )
        .layoutProbe("transactions.summary")
    }

    /// The tab root's list | detail split (D3.1).
    private var splitScreen: some View {
        Group {
            screen
                .splitDetail(
                    selection: $selection.selection,
                    in: selectableIds,
                    id: \.uuidString,
                    storageKey: "transactions",
                    placeholder: SplitPlaceholder(
                        title: "Select a Transaction",
                        systemImage: "arrow.left.arrow.right",
                        description: "Its details appear here."
                    )
                ) { id in
                    detailView(for: id)
                }
                .discardChangesDialog(for: $selection)
                // Nothing selected means no editor, so nothing can be dirty.
                // The draft itself is only dropped by the editor (saved or
                // cancelled) or by editing another row: a fold tears down the
                // stacks, which writes nil here too (device test, build 144).
                .onChange(of: selection.selection) { _, selected in
                    if selected == nil { selection.isDirty = false }
                    if selected != editOnOpen { editOnOpen = nil }
                    // Another row: the previous row's editor is closed.
                    if let selected, drafts.transaction != nil, drafts.transaction(withId: selected) == nil {
                        drafts.discard()
                    }
                }
                // After a fold re-creates the list, reopen an unsaved draft.
                .task { reopenUnsavedDraft() }
        }
    }

    /// Selects the transaction whose editor was open, if nothing is selected:
    /// in the detail column when tiled, else pushed. A fold or a rotation
    /// re-creates the list, and the editor reopens with it, edits or not.
    private func reopenUnsavedDraft() {
        guard selection.selection == nil, let draft = drafts.transaction else { return }
        selection.selection = draft.id
        selection.isDirty = drafts.unsavedTransaction != nil
    }

    /// The loaded rows, plus a kept draft whose row isn't loaded (yet), so the
    /// split doesn't clear the selection under it.
    private var selectableIds: [UUID] {
        let ids = viewModel.transactions.map(\.id)
        guard let draft = drafts.transaction, !ids.isEmpty, !ids.contains(draft.id) else { return ids }
        return ids + [draft.id]
    }

    /// The selected transaction's detail. Its editor works on the shared
    /// draft, so a fold / unfold keeps the edits (and reopens it editing).
    @ViewBuilder
    private func detailView(for id: UUID) -> some View {
        if let txn = viewModel.transactions.first(where: { $0.id == id }) ?? drafts.transaction(withId: id) {
            let shown = presentation(for: txn)
            TransactionDetailView(
                presentation: shown,
                // The editor was open (a draft exists until it closes), so a
                // fold or a rotation reopens it, with or without edits.
                startsEditing: editOnOpen == id || drafts.transaction(withId: id) != nil,
                draft: {
                    drafts.model(for: txn, currency: appState.defaultCurrency, decimalPlaces: appState.decimalPlaces)
                },
                isDirty: $selection.isDirty,
                onSaved: { await viewModel.load() },
                onEditingEnded: {
                    drafts.discard()
                    if editOnOpen == id { editOnOpen = nil }
                },
                onSetStatus: { await viewModel.setStatus(txn, to: $0) },
                onDelete: {
                    await viewModel.deleteTransaction(txn)
                    // A failed delete keeps the row (and its error); stay put.
                    guard !viewModel.transactions.contains(where: { $0.id == id }) else { return }
                    if drafts.transaction(withId: id) != nil { drafts.discard() }
                    closeDetail()
                }
            )
        }
    }

    private func presentation(for txn: Transaction) -> TransactionPresentation {
        TransactionPresentation(
            transaction: txn,
            account: viewModel.account(for: txn),
            category: viewModel.category(for: txn),
            transferAccountName: viewModel.transferAccount(for: txn)?.name,
            tags: viewModel.tags(for: txn),
            budgetName: viewModel.budgetName(for: txn),
            fixedExpenseName: viewModel.fixedExpenseName(for: txn),
            isSpread: viewModel.isSpread(txn)
        )
    }

    private var screen: some View {
        content
            // The main list uses the native large title; the (dormant) scoped
            // account-detail embedding keeps the inline title it had before.
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(isScoped ? .automatic : .large)
            .toolbar {
                if isScoped {
                    ToolbarItemGroup(placement: .primaryAction) {
                        // Scoped account detail keeps web's labeled header actions:
                        // an outline "Summary" button and a filled primary "Add".
                        summaryButton(showLabel: true)
                        addButton(showLabel: true)
                    }
                } else {
                    // Main list: native nav-bar actions — Summary and Filter as
                    // secondary icons, Add as the primary create affordance.
                    // Search and the active-filter tokens live in the
                    // `.searchable` field (see `content`). On the iPhone Duo's
                    // vertical bar (D3.3) Add keeps its place and Summary is the
                    // first to overflow into "…" (`TransactionsToolbar`).
                    ToolbarItem(placement: .primaryAction) { summaryToolbarButton }
                        .duoVisibilityPriority(TransactionsToolbar.priority(of: .summary))
                    ToolbarItem(placement: .primaryAction) { filterToolbarButton }
                    ToolbarItem(placement: .primaryAction) { addToolbarButton }
                        .duoVisibilityPriority(TransactionsToolbar.priority(of: .add))
                }
            }
            .foldSafeSheet(isPresented: $showingForm) {
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
            // Drill-downs push the detail onto their own stack.
            .navigationDestination(item: $pushedTransactionId) { id in
                detailView(for: id)
            }
            .foldSafeSheet(item: $installmentSource, sizing: .page) { source in
                CreateInstallmentSheet(source: source) {
                    await viewModel.load()
                }
            }
            .foldSafeSheet(isPresented: $showingFilters, sizing: .page) {
                TransactionFilterSheet(initial: viewModel.filters) { newFilters in
                    viewModel.applyFilters(newFilters)
                    searchText = newFilters.search ?? ""
                }
            }
            .task { await viewModel.load() }
            .reloadsAfterFoldedSheet { await viewModel.load() }
            .refreshable { await viewModel.load() }
            // Shared delete confirmation for both the row's long-press menu and the swipe
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
                    // Deleting the transaction being edited drops its draft.
                    if selection.selection == txn.id { selection.close() }
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
        Button { showingSummary.toggle() } label: {
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
            .filter { $0 != .search && !scopeFacets.contains($0) }
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
        // One background behind the rows, the sticky day headers and the
        // detail: the selected row's pill is the only fill in the list.
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .layoutProbe("transactions.list")
        .overlay {
            if viewModel.failedToLoad {
                LoadFailedView(title: "Couldn't Load Transactions", message: viewModel.errorMessage) {
                    await viewModel.load()
                }
            } else if viewModel.transactions.isEmpty && !viewModel.isLoading {
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
            isSelected: isSelected(txn),
            onCreateInstallment: { installmentSource = txn },
            onEdit: { open(txn, editing: true) },
            onDelete: { pendingDelete = txn }
        )
            .layoutProbe("transactions.row.\(txn.description ?? txn.type.rawValue)", interactive: true)
            // The header's own 16 pt inset, so the rows' amount column and the
            // day's net share one trailing edge on every display (the system
            // row margin differs from it, e.g. beside the Duo's vertical bar).
            .listRowInsets(EdgeInsets(top: 10, leading: Self.rowInset, bottom: 10, trailing: Self.rowInset))
            .listRowBackground(rowBackground(for: txn))
            .listRowSeparator(isSelected(txn) ? .hidden : .automatic)
            .contentShape(Rectangle())
            .onTapGesture { open(txn) }
            .modifier(RowSwipeActions(
                isPending: txn.status == .pending,
                onConfirm: { Task { await viewModel.setStatus(txn, to: .confirmed) } },
                onDismiss: { Task { await viewModel.setStatus(txn, to: .dismissed) } },
                onDelete: { pendingDelete = txn }
            ))
            .onAppear {
                if txn.id == viewModel.transactions.last?.id {
                    Task { await viewModel.loadMore() }
                }
            }
    }

    /// The horizontal inset shared by the rows and the day headers.
    private static let rowInset: CGFloat = 16

    /// Whether `txn` is the selection of a tiled split.
    private func isSelected(_ txn: Transaction) -> Bool {
        tilesDetail && selection.selection == txn.id
    }

    /// In a tiled split the selected row is an accent-filled rounded pill, as
    /// in Contacts. Nothing else is filled: a pending row is marked by its
    /// badge alone, so the list has one background and one highlight.
    @ViewBuilder
    private func rowBackground(for txn: Transaction) -> some View {
        if isSelected(txn) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appPrimary)
                .padding(.horizontal, 8)
        } else {
            Color.clear
        }
    }

    // MARK: - Date group header (web: DateGroupHeader)

    /// Sticky per-day heading: the absolute date on the left, the item count and
    /// the day's net (green/red, muted when it nets to zero) on the right.
    private func dateGroupHeader(_ group: TransactionDateGroup) -> some View {
        // The day's net never truncates and stays in the rows' aligned amount
        // column; a narrow list drops the item count instead.
        ViewThatFits(in: .horizontal) {
            fullDateGroupHeader(group)
            fullDateGroupHeader(group, showsCount: false)
        }
        .textCase(nil)
        // Match the rows' horizontal inset (we zero the header's list insets in
        // the Section so the background can reach the edges) plus a little
        // vertical breathing room.
        .padding(.horizontal, Self.rowInset)
        .padding(.vertical, 10)
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

    private func dateLabel(_ group: TransactionDateGroup) -> some View {
        Text(group.dateLabel)
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(Color.appMutedForeground)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func fullDateGroupHeader(_ group: TransactionDateGroup, showsCount: Bool = true) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            dateLabel(group)
            Spacer()
            if showsCount {
                Text("\(group.count) \(group.count == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundStyle(Color.appMutedForeground)
                    .lineLimit(1)
                    .fixedSize()
            }
            // Same component + shared width as the rows, so symbol and digits
            // align into one column through the header. The net carries an
            // explicit +/− sign; a day that nets to zero shows neither.
            AmountColumnView(
                minorUnits: group.net,
                sign: netSign(group.net),
                currencyCode: appState.defaultCurrency,
                widestNumber: widestAmountBody,
                alwaysWhole: true
            )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(netColor(group.net))
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

/// The row's swipe actions. Each edge gets only the buttons it has: an `if`
/// that renders nothing inside `.swipeActions` still reserves an empty slot,
/// so a confirmed row's lone Delete slid the row twice as far as it needed
/// (and its leading edge revealed a blank action).
private struct RowSwipeActions: ViewModifier {
    let isPending: Bool
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    let onDelete: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPending {
            content
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button(action: onConfirm) {
                        Label("Confirm", systemImage: "checkmark")
                    }
                    .tint(Color.appSuccess)
                }
                // allowsFullSwipe:false so the destructive action can't
                // auto-fire on a long swipe — it reveals the button, which then
                // routes through the shared confirmation alert.
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    deleteButton
                    Button(action: onDismiss) {
                        Label("Dismiss", systemImage: "xmark")
                    }
                    .tint(Color.appWarning)
                }
        } else {
            content
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    deleteButton
                }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
    }
}
