import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class TransactionFormViewModel {
    // Switching type clears the fields the new type hides, mirroring web's type
    // buttons: transfers drop the budget link, non-transfers drop the transfer
    // account, and non-expenses drop the fixed-expense link. didSet does not fire
    // during init, so edit-mode prefill is preserved.
    var type: TransactionType = .expense {
        didSet {
            guard type != oldValue else { return }
            if type != .transfer {
                transferAccountId = nil
            } else {
                budgetId = nil
            }
            if type != .expense {
                fixedExpenseId = nil
            }
        }
    }
    var amount: String = ""
    var accountId: UUID?
    var transferAccountId: UUID?
    var categoryId: UUID?
    var budgetId: UUID?
    var fixedExpenseId: UUID?
    var description: String = ""
    var transactionDate = Date()
    var selectedTags: Set<UUID> = []

    var isSaving = false
    var errorMessage: String?
    var didSave = false

    let editingTransaction: Transaction?
    private let currency: String
    private let decimalPlaces: Int
    private let repository = TransactionRepository()

    /// Snapshot of the editable fields the form opened with, so unsaved edits can
    /// be detected for the discard-changes guard. Tags are tracked separately
    /// because they load asynchronously after init.
    private struct Snapshot: Equatable {
        var type: TransactionType
        var amount: String
        var accountId: UUID?
        var transferAccountId: UUID?
        var categoryId: UUID?
        var budgetId: UUID?
        var fixedExpenseId: UUID?
        var description: String
        var transactionDate: Date
    }
    private var initialSnapshot: Snapshot!
    private var initialTags: Set<UUID> = []

    private var currentSnapshot: Snapshot {
        Snapshot(
            type: type, amount: amount, accountId: accountId,
            transferAccountId: transferAccountId, categoryId: categoryId,
            budgetId: budgetId, fixedExpenseId: fixedExpenseId,
            description: description, transactionDate: transactionDate
        )
    }

    /// True once the user edits any field (or the tag set) away from the opened
    /// values — drives the form's discard-changes guard.
    var hasChanges: Bool {
        currentSnapshot != initialSnapshot || selectedTags != initialTags
    }

    init(
        editing transaction: Transaction? = nil,
        defaultAccountId: UUID? = nil,
        currency: String = "USD",
        decimalPlaces: Int = 2,
        prefillFixedExpenseId: UUID? = nil,
        prefillAmount: String? = nil,
        prefillDate: Date? = nil
    ) {
        self.currency = currency
        self.decimalPlaces = decimalPlaces
        self.editingTransaction = transaction

        if let transaction {
            self.type = transaction.type
            self.amount = String(CurrencyUtils.toDisplayAmount(transaction.amount, decimalPlaces: decimalPlaces))
            self.accountId = transaction.accountId
            self.transferAccountId = transaction.transferAccountId
            self.categoryId = transaction.categoryId
            self.budgetId = transaction.budgetId
            self.fixedExpenseId = transaction.fixedExpenseId
            self.description = transaction.description ?? ""
            self.transactionDate = transaction.transactionDate
        } else {
            // New transactions pre-select the user's default account (§5.3).
            self.accountId = defaultAccountId

            // Adding a transaction from the Fixed Expenses screen pre-links it to
            // that expense (an expense, marking it paid) and prefills the known
            // amount and month date, mirroring web's `addTransaction`. `didSet`
            // does not fire during init, so setting `type` here won't clear the
            // fixed-expense link. The prefill becomes the discard-guard baseline
            // (snapshot is captured below), so opening then saving unchanged works.
            if let prefillFixedExpenseId {
                self.type = .expense
                self.fixedExpenseId = prefillFixedExpenseId
            }
            if let prefillAmount { self.amount = prefillAmount }
            if let prefillDate { self.transactionDate = prefillDate }
        }

        // Baseline for the discard-changes guard, captured after prefill. The tag
        // baseline starts empty and is set when `loadTags` resolves.
        self.initialSnapshot = currentSnapshot
    }

    func loadTags() async {
        guard let transaction = editingTransaction else { return }
        do {
            selectedTags = try await repository.getTagIds(transactionId: transaction.id)
            initialTags = selectedTags
        } catch {}
    }

    /// Raw signed minor units parsed from the field, or nil when not a number.
    private var parsedMinorUnits: Int64? {
        guard let value = Double(amount) else { return nil }
        return CurrencyUtils.toMinorUnits(value, decimalPlaces: decimalPlaces)
    }

    var isValid: Bool {
        guard let minorUnits = parsedMinorUnits else { return false }
        // Zero is never allowed for any type.
        if minorUnits == 0 { return false }
        guard let accountId else { return false }
        if type == .transfer {
            // Transfers require a distinct destination account.
            guard let transferAccountId, transferAccountId != accountId else { return false }
        }
        return true
    }

    func save() async {
        guard isValid, var minorUnits = parsedMinorUnits, let accountId else { return }

        // Sign rules (§5.3): income/expense may be negative; transfers forced
        // positive (reverse one by swapping accounts).
        if type == .transfer {
            minorUnits = abs(minorUnits)
        }

        // Field visibility → persisted shape:
        //   transfer  → no category/budget/fixed, requires transfer account
        //   income    → category + budget, no fixed, no transfer account
        //   expense   → category + budget + fixed, no transfer account
        let effectiveTransferAccountId = type == .transfer ? transferAccountId : nil
        let effectiveCategoryId = type == .transfer ? nil : categoryId
        let effectiveBudgetId = type == .transfer ? nil : budgetId
        let effectiveFixedExpenseId = type == .expense ? fixedExpenseId : nil

        isSaving = true
        defer { isSaving = false }

        do {
            let transactionId: UUID
            if let existing = editingTransaction {
                try await repository.update(id: existing.id, fields: [
                    "type": .string(type.rawValue),
                    "amount": .double(Double(minorUnits)),
                    "account_id": .string(accountId.uuidString),
                    "description": description.isEmpty ? .null : .string(description),
                    "date": .string(DateUtils.yearMonthDay(from: transactionDate)),
                    "transfer_account_id": effectiveTransferAccountId.map { .string($0.uuidString) } ?? .null,
                    "category_id": effectiveCategoryId.map { .string($0.uuidString) } ?? .null,
                    "budget_id": effectiveBudgetId.map { .string($0.uuidString) } ?? .null,
                    "fixed_expense_id": effectiveFixedExpenseId.map { .string($0.uuidString) } ?? .null
                ])
                transactionId = existing.id
            } else {
                let created = try await repository.create(
                    accountId: accountId,
                    type: type,
                    amount: minorUnits,
                    description: description.isEmpty ? nil : description,
                    transactionDate: transactionDate,
                    transferAccountId: effectiveTransferAccountId,
                    categoryId: effectiveCategoryId,
                    budgetId: effectiveBudgetId,
                    fixedExpenseId: effectiveFixedExpenseId
                )
                transactionId = created.id
            }

            try await repository.setTags(transactionId: transactionId, tagIds: selectedTags)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
