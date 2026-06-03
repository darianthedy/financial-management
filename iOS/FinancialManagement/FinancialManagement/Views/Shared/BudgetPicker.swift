import SwiftUI

struct BudgetPicker: View {
    @Binding var selectedBudgetPeriodId: UUID?
    var transactionDate: Date

    @State private var budgets: [Budget] = []
    @State private var periods: [BudgetPeriod] = []

    private let budgetRepository = BudgetRepository()

    private var yearMonth: String {
        DateUtils.yearMonth(from: transactionDate)
    }

    private var pickerOptions: [(budgetPeriodId: UUID, label: String)] {
        periods.compactMap { period in
            guard let budget = budgets.first(where: { $0.id == period.budgetId }) else { return nil }
            let amount = CurrencyUtils.format(period.effectiveAmount, currency: period.currency)
            return (period.id, "\(budget.name) (\(amount))")
        }
    }

    var body: some View {
        Picker("Budget", selection: $selectedBudgetPeriodId) {
            Text("None").tag(UUID?.none)
            ForEach(pickerOptions, id: \.budgetPeriodId) { option in
                Text(option.label).tag(Optional(option.budgetPeriodId))
            }
        }
        .task {
            await loadBudgets()
        }
        .onChange(of: transactionDate) {
            Task { await loadBudgets() }
        }
    }

    private func loadBudgets() async {
        do {
            budgets = try await budgetRepository.getAll()
            periods = try await budgetRepository.getAllPeriodsForMonth(yearMonth: yearMonth)
        } catch {
            budgets = []
            periods = []
        }
    }
}
