import SwiftUI
import Supabase

/// Spreads an **already-recorded expense** across future budgets (P1 virtual
/// installments, §8.8). Opens over the expense's own amount; the user picks a
/// start month, a set of budget lineages, a month span, then distributes the
/// amount across the budgets × months grid. The grid is pre-filled with an even
/// split and **Save is disabled until it sums exactly to the expense amount**.
/// On submit it calls the `spread_existing_transaction` RPC (which nulls the
/// source `budget_id` but keeps amount/category/fixed-link/tags untouched).
struct CreateInstallmentSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// The expense being spread. Its `amount` is the total to allocate.
    let source: Transaction
    /// Called after a successful spread so the caller can refresh its lists.
    var onSaved: () async -> Void

    @State private var startOffset = 0          // 0 = this month, 1 = next month
    @State private var months = 3
    @State private var selectedNames: Set<String> = []
    @State private var grid: [Cell: String] = [:]
    @State private var availableNames: [String] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let repository = InstallmentRepository()

    /// One allocation cell: a budget lineage in a given month.
    private struct Cell: Hashable { let name: String; let month: String }

    private var total: Int64 { source.amount }
    private var decimalPlaces: Int { appState.decimalPlaces }
    private var currencyCode: String { appState.defaultCurrency }

    private var startYearMonth: String {
        DateUtils.navigate(DateUtils.currentYearMonth(), by: startOffset)
    }

    private var monthList: [String] {
        (0..<max(months, 1)).map { DateUtils.navigate(startYearMonth, by: $0) }
    }

    private var sortedNames: [String] { selectedNames.sorted() }

    /// Ordered cells (budget rows × month columns) that make up the grid.
    private var cells: [Cell] {
        sortedNames.flatMap { name in monthList.map { Cell(name: name, month: $0) } }
    }

    private var reserved: Int64 {
        cells.reduce(0) { $0 + minorUnits(grid[$1]) }
    }

    private var remaining: Int64 { total - reserved }
    private var isBalanced: Bool { remaining == 0 }
    private var canSave: Bool { !selectedNames.isEmpty && isBalanced && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                summarySection
                startMonthSection
                monthsSection
                budgetsSection
                if !selectedNames.isEmpty {
                    ForEach(sortedNames, id: \.self) { name in
                        allocationSection(for: name)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Color.appDanger) }
                }
            }
            .navigationTitle("Virtual Installment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
            .task { await loadBudgetNames() }
            .onChange(of: selectedNames) { _, _ in applyEvenSplit() }
            .onChange(of: months) { _, _ in applyEvenSplit() }
            .onChange(of: startOffset) { _, _ in applyEvenSplit() }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            LabeledContent("Expense", value: total.asCurrency(code: currencyCode))
            LabeledContent("Reserved", value: reserved.asCurrency(code: currencyCode))
            LabeledContent("Remaining to allocate") {
                Text(remaining.asCurrency(code: currencyCode))
                    .foregroundStyle(isBalanced ? Color.appMutedForeground : (remaining < 0 ? Color.appDanger : Color.appWarning))
            }
            if !selectedNames.isEmpty {
                Button("Split evenly") { applyEvenSplit() }
            }
        } footer: {
            Text("Reservations lower these budgets' future allowance only — they never affect account balances.")
        }
    }

    private var startMonthSection: some View {
        Section("Start month") {
            Picker("Start month", selection: $startOffset) {
                Text("This month").tag(0)
                Text("Next month").tag(1)
            }
            .pickerStyle(.segmented)
        }
    }

    private var monthsSection: some View {
        Section {
            Stepper("Months: \(months)", value: $months, in: 1...24)
        }
    }

    private var budgetsSection: some View {
        Section("Budgets") {
            if availableNames.isEmpty {
                Text("No budgets found. Create a budget first.")
                    .foregroundStyle(Color.appMutedForeground)
            } else {
                ForEach(availableNames, id: \.self) { name in
                    Button {
                        toggle(name)
                    } label: {
                        HStack {
                            Text(name).foregroundStyle(Color.appForeground)
                            Spacer()
                            if selectedNames.contains(name) {
                                Image(systemName: "checkmark").foregroundStyle(Color.appPrimary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func allocationSection(for name: String) -> some View {
        Section(name) {
            ForEach(monthList, id: \.self) { month in
                let cell = Cell(name: name, month: month)
                HStack {
                    Text(DateUtils.formatYearMonth(month))
                    Spacer()
                    TextField("0", text: amountBinding(cell))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
            }
        }
    }

    // MARK: - Grid math

    private func toggle(_ name: String) {
        if selectedNames.contains(name) {
            selectedNames.remove(name)
        } else {
            selectedNames.insert(name)
        }
    }

    /// Even pre-fill: `floor(total / cellCount)` in every cell, with the
    /// remainder dropped into the first cell so the grid sums **exactly** to the
    /// expense amount. Re-runs whenever the budget set, span, or start changes.
    private func applyEvenSplit() {
        let cells = cells
        guard !cells.isEmpty else { grid = [:]; return }
        let amounts = EvenSplit.distribute(total: total, count: cells.count)
        var next: [Cell: String] = [:]
        for (cell, amount) in zip(cells, amounts) {
            next[cell] = displayString(amount)
        }
        grid = next
    }

    private func amountBinding(_ cell: Cell) -> Binding<String> {
        Binding(
            get: { grid[cell] ?? "" },
            set: { grid[cell] = $0 }
        )
    }

    /// Parses a display string back to minor units (clamping blanks / invalid /
    /// negative entries to 0).
    private func minorUnits(_ text: String?) -> Int64 {
        guard let text, let value = Double(text.trimmingCharacters(in: .whitespaces)), value > 0
        else { return 0 }
        return CurrencyUtils.toMinorUnits(value, decimalPlaces: decimalPlaces)
    }

    /// Formats minor units as a plain (symbol-less) decimal string for the field.
    private func displayString(_ minor: Int64) -> String {
        guard decimalPlaces > 0 else { return String(minor) }
        return String(format: "%.\(decimalPlaces)f",
                      CurrencyUtils.toDisplayAmount(minor, decimalPlaces: decimalPlaces))
    }

    // MARK: - Data

    private func loadBudgetNames() async {
        do {
            struct NameRow: Decodable { let budget_name: String }
            let rows: [NameRow] = try await SupabaseService.shared.client
                .from("v_budget_progress")
                .select("budget_name")
                .execute()
                .value
            availableNames = Array(Set(rows.map(\.budget_name))).sorted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        // Non-zero cells only; the RPC re-validates the exact sum.
        let payload: [InstallmentRepository.GridCell] = cells.compactMap { cell in
            let amount = minorUnits(grid[cell])
            guard amount > 0 else { return nil }
            return InstallmentRepository.GridCell(
                budget_name: cell.name, year_month: cell.month, amount: amount
            )
        }

        do {
            try await repository.spread(
                transactionId: source.id,
                startYearMonth: startYearMonth,
                months: months,
                grid: payload
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
