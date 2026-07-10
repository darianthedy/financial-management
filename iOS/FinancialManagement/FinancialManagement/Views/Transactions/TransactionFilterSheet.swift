import SwiftUI
import Supabase

/// Quick date-range presets (§8.3.1). Clearing back to "all dates" is a dedicated
/// menu action, not a preset.
private enum DatePreset: String, CaseIterable, Identifiable {
    case thisMonth, lastMonth, last3Months, thisYear
    var id: String { rawValue }

    var label: String {
        switch self {
        case .thisMonth:   return "This month"
        case .lastMonth:   return "Last month"
        case .last3Months: return "Last 3 months"
        case .thisYear:    return "This year"
        }
    }

    /// Inclusive (from, to) bounds; `nil` means unbounded on that side.
    func range() -> (from: Date?, to: Date?) {
        let current = DateUtils.currentYearMonth()
        switch self {
        case .thisMonth:
            let r = DateUtils.monthDateRange(current)
            return (r?.start, r?.end)
        case .lastMonth:
            let r = DateUtils.monthDateRange(DateUtils.navigate(current, by: -1))
            return (r?.start, r?.end)
        case .last3Months:
            let start = DateUtils.monthDateRange(DateUtils.navigate(current, by: -2))?.start
            let end = DateUtils.monthDateRange(current)?.end
            return (start, end)
        case .thisYear:
            let cal = Calendar.current
            let year = cal.component(.year, from: Date())
            let from = cal.date(from: DateComponents(year: year, month: 1, day: 1))
            let to = cal.date(from: DateComponents(year: year, month: 12, day: 31))
            return (from, to)
        }
    }
}

/// The full filter sheet (§8.3.1). Edits a working copy of `TransactionFilters`
/// and hands it back on **Apply**; **Reset** clears every facet.
struct TransactionFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let initial: TransactionFilters
    var onApply: (TransactionFilters) -> Void

    @State private var working: TransactionFilters
    @State private var minAmount = ""
    @State private var maxAmount = ""
    @State private var showDiscardConfirm = false

    @State private var accounts: [Account] = []
    @State private var categories: [Category] = []
    @State private var tags: [Tag] = []
    @State private var budgetNames: [String] = []
    @State private var fixedNames: [String] = []

    /// Live preview of how many transactions the current (unapplied) filters match,
    /// shown on the Apply button. `nil` until the first count resolves.
    @State private var matchCount: Int?
    @State private var isCounting = false
    /// The in-flight debounced count, cancelled whenever the filters change again.
    @State private var countTask: Task<Void, Never>?

    private let repository = TransactionRepository()

    init(initial: TransactionFilters, onApply: @escaping (TransactionFilters) -> Void) {
        self.initial = initial
        self.onApply = onApply
        _working = State(initialValue: initial)
    }

    /// True once the user changes a facet or an amount field away from the values
    /// the sheet opened with — drives the discard-changes guard. (The amount text
    /// fields stage into `working` only on Apply, so they're compared separately.)
    private var hasChanges: Bool {
        working != initial
            || minAmount != Self.amountText(initial.amountMin, decimalPlaces: appState.decimalPlaces)
            || maxAmount != Self.amountText(initial.amountMax, decimalPlaces: appState.decimalPlaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section order mirrors web's filter panel
                // (web/src/components/transactions/transaction-filters.tsx): date →
                // status → type → account → amount → budget → category → fixed →
                // tags. Search lives in the always-visible list search bar, so the
                // panel itself carries none.
                dateSection
                statusSection
                typeSection
                accountSection
                amountSection
                budgetSection
                categorySection
                fixedSection
                tagSection

                Section {
                    Button("Reset All Filters", role: .destructive) { reset() }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .disabled(working.isEmpty && minAmount.isEmpty && maxAmount.isEmpty)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { showDiscardConfirm = true } else { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { applyButton }
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog(
                "Discard filter changes?",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
            .task { await loadOptions() }
            .onChange(of: working.dateFrom) { Task { await loadNameOptions() } }
            .onChange(of: working.dateTo) { Task { await loadNameOptions() } }
            .onChange(of: working) { scheduleCount() }
            .onChange(of: minAmount) { scheduleCount() }
            .onChange(of: maxAmount) { scheduleCount() }
            .onDisappear { countTask?.cancel() }
        }
        .onAppear {
            minAmount = Self.amountText(initial.amountMin, decimalPlaces: appState.decimalPlaces)
            maxAmount = Self.amountText(initial.amountMax, decimalPlaces: appState.decimalPlaces)
            scheduleCount()
        }
    }

    /// Full-width primary action pinned to the bottom of the sheet. Its label is a
    /// live preview of the result set — "Show N Results" — so the user never
    /// commits a filter blind; a zero match reads "No Matching Transactions".
    private var applyButton: some View {
        Button(action: apply) {
            Group {
                if isCounting && matchCount == nil {
                    ProgressView()
                } else {
                    Text(applyLabel)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 26)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var applyLabel: String {
        guard let matchCount else { return "Apply" }
        switch matchCount {
        case 0:  return "No Matching Transactions"
        case 1:  return "Show 1 Result"
        default: return "Show \(matchCount.formatted()) Results"
        }
    }

    /// The working facets with the staged amount text folded in, so the preview
    /// count (and Apply) reflect exactly the filters that will be applied.
    private var stagedFilters: TransactionFilters {
        var f = working
        f.amountMin = Self.parseAmount(minAmount, decimalPlaces: appState.decimalPlaces)
        f.amountMax = Self.parseAmount(maxAmount, decimalPlaces: appState.decimalPlaces)
        return f
    }

    /// Debounced live count: cancels any in-flight request, waits out rapid edits,
    /// then refreshes `matchCount` for the Apply button.
    private func scheduleCount() {
        countTask?.cancel()
        let filters = stagedFilters
        isCounting = true
        countTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let n = try? await repository.count(filters: filters)
            guard !Task.isCancelled else { return }
            matchCount = n
            isCounting = false
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        MultiSelectFacet(
            title: "Type",
            options: TransactionType.allCases.map {
                FacetOption(value: $0, label: $0.rawValue.capitalized)
            },
            facet: $working.types
        )
    }

    private var statusSection: some View {
        MultiSelectFacet(
            title: "Status",
            options: TransactionStatus.allCases.map {
                FacetOption(value: $0, label: $0.rawValue.capitalized)
            },
            facet: $working.statuses
        )
    }

    /// Date field: a native preset menu plus (once a range is active) From/To
    /// pickers. The presets pick a range in one tap; "All dates" clears back to
    /// unbounded; "Custom range…" opens the pickers so arbitrary bounds are
    /// reachable without first landing on a preset. Editing either picker drops
    /// the menu into "Custom" automatically.
    private var dateSection: some View {
        Section("Date") {
            Menu {
                ForEach(DatePreset.allCases) { preset in
                    Button { applyPreset(preset) } label: {
                        if activePreset == preset {
                            Label(preset.label, systemImage: "checkmark")
                        } else {
                            Text(preset.label)
                        }
                    }
                }
                Divider()
                Button("Custom range…") { enterCustomRange() }
                if hasDateRange {
                    Button("All dates", role: .destructive) { clearDateRange() }
                }
            } label: {
                HStack {
                    Text("Range").foregroundStyle(Color.appForeground)
                    Spacer()
                    Text(rangeLabel).foregroundStyle(Color.appMutedForeground)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Color.appMutedForeground)
                }
                .contentShape(Rectangle())
            }

            if hasDateRange {
                DatePicker("From", selection: Binding(
                    get: { working.dateFrom ?? Date() },
                    set: { working.dateFrom = $0 }
                ), displayedComponents: .date)
                DatePicker("To", selection: Binding(
                    get: { working.dateTo ?? Date() },
                    set: { working.dateTo = $0 }
                ), displayedComponents: .date)
            }
        }
    }

    private var hasDateRange: Bool { working.dateFrom != nil || working.dateTo != nil }

    /// The collapsed menu value: the matching preset, else "Custom" when arbitrary
    /// bounds are set, else "All dates".
    private var rangeLabel: String {
        if let activePreset { return activePreset.label }
        return hasDateRange ? "Custom" : "All dates"
    }

    /// The preset whose range matches the working bounds (day-precision), so the
    /// menu can check it.
    private var activePreset: DatePreset? {
        DatePreset.allCases.first { preset in
            let r = preset.range()
            return sameDay(r.from, working.dateFrom) && sameDay(r.to, working.dateTo)
        }
    }

    /// Reveal the From/To pickers for arbitrary bounds. Seeds the current month
    /// only when no range exists yet; if a preset/custom range is already active
    /// the pickers are shown, so we leave the user's bounds untouched.
    private func enterCustomRange() {
        guard !hasDateRange else { return }
        let r = DateUtils.monthDateRange(DateUtils.currentYearMonth())
        working.dateFrom = r?.start
        working.dateTo = r?.end
    }

    private func clearDateRange() {
        working.dateFrom = nil
        working.dateTo = nil
    }

    private func sameDay(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return DateUtils.yearMonthDay(from: x) == DateUtils.yearMonthDay(from: y)
        default: return false
        }
    }

    private var amountSection: some View {
        Section("Amount (\(appState.defaultCurrency))") {
            CurrencyField(label: "Min", value: $minAmount, decimals: appState.decimalPlaces)
            CurrencyField(label: "Max", value: $maxAmount, decimals: appState.decimalPlaces)
        }
    }

    private var accountSection: some View {
        MultiSelectFacet(
            title: "Account",
            options: accounts.map { FacetOption(value: $0.id, label: $0.name) },
            facet: $working.accounts
        )
    }

    private var categorySection: some View {
        MultiSelectFacet(
            title: "Category",
            options: categories.map { FacetOption(value: $0.id, label: $0.name, leading: $0.icon) },
            allowsBlanks: true,
            facet: $working.categories
        )
    }

    private var tagSection: some View {
        MultiSelectFacet(
            title: "Tags",
            options: tags.map { FacetOption(value: $0.id, label: $0.name) },
            allowsBlanks: true,
            facet: $working.tags
        )
    }

    private var budgetSection: some View {
        MultiSelectFacet(
            title: "Budget",
            options: budgetNames.map { FacetOption(value: $0, label: $0) },
            allowsBlanks: true,
            facet: $working.budgets
        )
    }

    private var fixedSection: some View {
        MultiSelectFacet(
            title: "Fixed Expense",
            options: fixedNames.map { FacetOption(value: $0, label: $0) },
            allowsBlanks: true,
            facet: $working.fixedExpenses
        )
    }

    // MARK: - Actions

    private func applyPreset(_ preset: DatePreset) {
        let r = preset.range()
        working.dateFrom = r.from
        working.dateTo = r.to
    }

    private func reset() {
        working = TransactionFilters()
        minAmount = ""
        maxAmount = ""
    }

    private func apply() {
        var f = stagedFilters
        if let s = f.search, s.trimmingCharacters(in: .whitespaces).isEmpty { f.search = nil }
        onApply(f)
        dismiss()
    }

    private static func parseAmount(_ text: String, decimalPlaces: Int) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Double(trimmed) else { return nil }
        return CurrencyUtils.toMinorUnits(value, decimalPlaces: decimalPlaces)
    }

    private static func amountText(_ minor: Int64?, decimalPlaces: Int) -> String {
        guard let minor else { return "" }
        let value = CurrencyUtils.toDisplayAmount(minor, decimalPlaces: decimalPlaces)
        return value == value.rounded() ? String(Int64(value)) : String(value)
    }

    // MARK: - Option loading

    private func loadOptions() async {
        let client = SupabaseService.shared.client
        do {
            async let acc: [Account] = client.from("accounts")
                .select().eq("is_archived", value: false).order("name").execute().value
            async let cat: [Category] = client.from("categories").select().order("name").execute().value
            async let tag: [Tag] = client.from("tags").select().order("name").execute().value
            accounts = try await acc
            categories = try await cat
            tags = try await tag
        } catch {
            // Leave whatever loaded; missing options just can't be selected.
        }
        await loadNameOptions()
    }

    /// Budget / fixed-expense **names**, scoped to the working date range's months
    /// so the choices reflect the active period (System Design §4.9).
    private func loadNameOptions() async {
        let client = SupabaseService.shared.client
        let fromYM = working.dateFrom.map { DateUtils.yearMonth(from: $0) }
        let toYM = working.dateTo.map { DateUtils.yearMonth(from: $0) }

        struct BudgetRow: Decodable { let budget_name: String }
        struct FixedRow: Decodable { let name: String }

        do {
            var bq = client.from("v_budget_progress").select("budget_name")
            if let fromYM { bq = bq.gte("year_month", value: fromYM) }
            if let toYM { bq = bq.lte("year_month", value: toYM) }
            let budgets: [BudgetRow] = try await bq.execute().value
            budgetNames = Set(budgets.map(\.budget_name)).sorted()

            var fq = client.from("fixed_expenses").select("name")
            if let fromYM { fq = fq.gte("year_month", value: fromYM) }
            if let toYM { fq = fq.lte("year_month", value: toYM) }
            let fixed: [FixedRow] = try await fq.execute().value
            fixedNames = Set(fixed.map(\.name)).sorted()
        } catch {
            // Non-fatal.
        }
    }
}
