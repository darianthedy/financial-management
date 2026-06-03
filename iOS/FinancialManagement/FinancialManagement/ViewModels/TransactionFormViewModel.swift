import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class TransactionFormViewModel {
    var type: TransactionType = .expense
    var amount: String = ""
    var currency: String = "USD"
    var accountId: UUID?
    var toAccountId: UUID?
    var categoryId: UUID?
    var budgetPeriodId: UUID?
    var fixedExpenseId: UUID?
    var description: String = ""
    var transactionDate = Date()
    var selectedTags: Set<UUID> = []

    var isSaving = false
    var errorMessage: String?
    var didSave = false

    private let repository = TransactionRepository()

    var editingTransaction: Transaction?

    init(editing transaction: Transaction? = nil, defaultCurrency: String = "USD") {
        self.currency = defaultCurrency
        if let transaction {
            self.editingTransaction = transaction
            self.type = transaction.type
            self.amount = String(CurrencyUtils.toDisplayAmount(transaction.amount, currency: transaction.currency))
            self.currency = transaction.currency
            self.accountId = transaction.accountId
            self.toAccountId = transaction.toAccountId
            self.budgetPeriodId = transaction.budgetPeriodId
            self.fixedExpenseId = transaction.fixedExpenseId
            self.description = transaction.description ?? ""
            self.transactionDate = transaction.transactionDate
        }
    }

    func loadCategories() async {
        guard let transaction = editingTransaction else { return }
        do {
            let ids = try await repository.getCategoryIds(transactionId: transaction.id)
            categoryId = ids.first
        } catch {}
    }

    var isValid: Bool {
        guard let _ = Double(amount), accountId != nil else { return false }
        if type == .transfer && toAccountId == nil { return false }
        return true
    }

    func save() async {
        guard isValid, let parsedAmount = Double(amount), let accountId else { return }

        isSaving = true
        defer { isSaving = false }

        let minorUnits = CurrencyUtils.toMinorUnits(parsedAmount, currency: currency)
        let effectiveBudgetPeriodId = type == .expense ? budgetPeriodId : nil
        let effectiveFixedExpenseId = type == .expense ? fixedExpenseId : nil

        do {
            let transactionId: UUID
            if let existing = editingTransaction {
                try await repository.update(id: existing.id, fields: [
                    "type": AnyJSON.string(type.rawValue),
                    "amount": AnyJSON.double(Double(minorUnits)),
                    "account_id": AnyJSON.string(accountId.uuidString),
                    "description": description.isEmpty ? AnyJSON.null : AnyJSON.string(description),
                    "date": AnyJSON.string(ISO8601DateFormatter().string(from: transactionDate)),
                    "transfer_account_id": toAccountId.map { AnyJSON.string($0.uuidString) } ?? AnyJSON.null,
                    "budget_period_id": effectiveBudgetPeriodId.map { AnyJSON.string($0.uuidString) } ?? AnyJSON.null,
                    "fixed_expense_id": effectiveFixedExpenseId.map { AnyJSON.string($0.uuidString) } ?? AnyJSON.null
                ])
                transactionId = existing.id
            } else {
                let created = try await repository.create(
                    accountId: accountId,
                    type: type,
                    amount: minorUnits,
                    currency: currency,
                    description: description.isEmpty ? nil : description,
                    transactionDate: transactionDate,
                    toAccountId: toAccountId,
                    budgetPeriodId: effectiveBudgetPeriodId,
                    fixedExpenseId: effectiveFixedExpenseId
                )
                transactionId = created.id
            }

            let categoryIds = categoryId.map { [$0] } ?? []
            try await repository.setCategories(transactionId: transactionId, categoryIds: categoryIds)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
