import SwiftUI

struct FixedExpensePicker: View {
    @Binding var selectedExpenseId: UUID?
    var transactionDate: Date

    @State private var fixedExpenses: [FixedExpense] = []

    private let repository = FixedExpenseRepository()

    private var yearMonth: String {
        DateUtils.yearMonth(from: transactionDate)
    }

    var body: some View {
        Picker("Fixed Expense", selection: $selectedExpenseId) {
            Text("None").tag(UUID?.none)
            ForEach(fixedExpenses) { expense in
                let amount = CurrencyUtils.format(expense.amount, currency: expense.currency)
                Text("\(expense.name) (\(amount), due \(expense.dueDay))")
                    .tag(Optional(expense.id))
            }
        }
        .task {
            await load()
        }
        .onChange(of: transactionDate) {
            Task { await load() }
        }
    }

    private func load() async {
        do {
            fixedExpenses = try await repository.getForMonth(yearMonth: yearMonth)
        } catch {
            fixedExpenses = []
        }
    }
}
