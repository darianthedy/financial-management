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

    var body: some View {
        NavigationStack {
            Form {
                searchSection
                typeSection
                statusSection
                dateSection
                amountSection
                accountSection
                categorySection
                tagSection
                budgetSection
                fixedSection

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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }
                }
            }
            .task { await loadOptions() }
            .onChange(of: working.dateFrom) { Task { await loadNameOptions() } }
            .onChange(of: working.dateTo) { Task { await loadNameOptions() } }
        }
        .onAppear {
            minAmount = Self.amountText(initial.amountMin, decimalPlaces: appState.decimalPlaces)
            maxAmount = Self.amountText(initial.amountMax, decimalPlaces: appState.decimalPlaces)
        }
    }

    // MARK: - Sections

    private var searchSection: some View {
        Section("Search") {
            TextField("Description contains…", text: Binding(
                get: { working.search ?? "" },
                set: { working.search = $0.isEmpty ? nil : $0 }
            ))
            .autocorrectionDisabled()
        }
    }

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

    private var dateSection: some View {
        Section("Date Range") {
            Menu {
                ForEach(DatePreset.allCases) { preset in
                    Button(preset.label) { applyPreset(preset) }
                }
            } label: {
                Label("Presets", systemImage: "calendar")
            }

            Toggle("Custom range", isOn: Binding(
                get: { working.dateFrom != nil || working.dateTo != nil },
                set: { on in
                    if on {
                        let r = DateUtils.monthDateRange(DateUtils.currentYearMonth())
                        working.dateFrom = working.dateFrom ?? r?.start
                        working.dateTo = working.dateTo ?? r?.end
                    } else {
                        working.dateFrom = nil
                        working.dateTo = nil
                    }
                }
            ))

            if working.dateFrom != nil || working.dateTo != nil {
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

    private var amountSection: some View {
        Section("Amount Range") {
            CurrencyField(label: "Min", value: $minAmount)
            CurrencyField(label: "Max", value: $maxAmount)
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
        var f = working
        f.amountMin = Self.parseAmount(minAmount, decimalPlaces: appState.decimalPlaces)
        f.amountMax = Self.parseAmount(maxAmount, decimalPlaces: appState.decimalPlaces)
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
