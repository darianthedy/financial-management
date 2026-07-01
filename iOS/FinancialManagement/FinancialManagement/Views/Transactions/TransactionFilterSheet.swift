import SwiftUI
import Supabase

/// Quick date-range presets (§8.3.1). `allTime` clears the bounds.
private enum DatePreset: String, CaseIterable, Identifiable {
    case thisMonth, lastMonth, last3Months, thisYear, allTime
    var id: String { rawValue }

    var label: String {
        switch self {
        case .thisMonth:   return "This month"
        case .lastMonth:   return "Last month"
        case .last3Months: return "Last 3 months"
        case .thisYear:    return "This year"
        case .allTime:     return "All time"
        }
    }

    /// Inclusive (from, to) bounds; `nil` means unbounded on that side.
    func range() -> (from: Date?, to: Date?) {
        let current = DateUtils.currentYearMonth()
        switch self {
        case .allTime:
            return (nil, nil)
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
    @State private var amountSign: AmountSign? = nil
    @State private var showDiscardConfirm = false

    @State private var accounts: [Account] = []
    @State private var categories: [Category] = []
    @State private var tags: [Tag] = []
    @State private var budgetNames: [String] = []
    @State private var fixedNames: [String] = []

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
            || amountSign != initial.amountSign
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }
                }
            }
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
        }
        .onAppear {
            minAmount = Self.amountText(initial.amountMin, decimalPlaces: appState.decimalPlaces)
            maxAmount = Self.amountText(initial.amountMax, decimalPlaces: appState.decimalPlaces)
            amountSign = initial.amountSign
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

    /// Web's Date field: a row of quick-range preset chips plus From/To pickers.
    /// "All time" appears (as on web) only while a range is set, to clear it back
    /// to all dates.
    private var dateSection: some View {
        Section("Date") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visiblePresets) { preset in
                        Button { applyPreset(preset) } label: {
                            Text(preset.label)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    activePreset == preset ? Color.appPrimary : Color.appMuted,
                                    in: Capsule()
                                )
                                .foregroundStyle(
                                    activePreset == preset ? Color.appPrimaryForeground : Color.appForeground
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            if working.dateFrom != nil || working.dateTo != nil {
                DatePicker("From", selection: Binding(
                    get: { working.dateFrom ?? Date() },
                    set: { working.dateFrom = $0 }
                ), displayedComponents: .date)
                DatePicker("To", selection: Binding(
                    get: { working.dateTo ?? Date() },
                    set: { working.dateTo = $0 }
                ), displayedComponents: .date)
            } else {
                Button("Custom range") {
                    let r = DateUtils.monthDateRange(DateUtils.currentYearMonth())
                    working.dateFrom = r?.start
                    working.dateTo = r?.end
                }
            }
        }
    }

    /// The 4 quick presets, plus "All time" only while a range is active.
    private var visiblePresets: [DatePreset] {
        let base: [DatePreset] = [.thisMonth, .lastMonth, .last3Months, .thisYear]
        return (working.dateFrom != nil || working.dateTo != nil) ? base + [.allTime] : base
    }

    /// The preset whose range matches the working bounds (day-precision), so it
    /// can be highlighted like web.
    private var activePreset: DatePreset? {
        DatePreset.allCases.first { preset in
            guard preset != .allTime else { return false }
            let r = preset.range()
            return sameDay(r.from, working.dateFrom) && sameDay(r.to, working.dateTo)
        }
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

            Picker("Sign", selection: $amountSign) {
                Text("All").tag(AmountSign?.none)
                Text("Expense").tag(AmountSign?.negative)
                Text("Income").tag(AmountSign?.positive)
            }
            .pickerStyle(.segmented)
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
        amountSign = nil
    }

    private func apply() {
        var f = working
        f.amountMin = Self.parseAmount(minAmount, decimalPlaces: appState.decimalPlaces)
        f.amountMax = Self.parseAmount(maxAmount, decimalPlaces: appState.decimalPlaces)
        f.amountSign = amountSign
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
