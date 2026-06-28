import Foundation

/// A `ScheduledTransaction` enriched with joined account, category, and tag
/// metadata resolved via batched lookups in `ScheduledTransactionRepository.enrich(_:)`,
/// mirroring web's `ScheduledTransactionWithAccount` (use-scheduled-transactions.ts).
struct EnrichedScheduledTransaction: Identifiable, Sendable {
    let base: ScheduledTransaction

    let accountName: String?
    let accountImageUrl: String?
    let accountType: AccountType?

    let categoryName: String?
    let categoryColor: String?

    let tagNames: [String]

    // Passthroughs — avoids `.base.x` at every call site.
    var id: UUID { base.id }
    var type: TransactionType { base.type }
    var amount: Int64 { base.amount }
    var description: String? { base.description }
    var isActive: Bool { base.isActive }
    var nextDueDate: Date { base.nextDueDate }
    var budgetName: String? { base.budgetName }
    var fixedExpenseName: String? { base.fixedExpenseName }
}

/// Recurring template that the server turns into `pending` transactions (System
/// Design §4.5). The column is `recurrence` (not `recurrence_interval`) and
/// `next_due_date` (not `next_occurrence`); the app is single-currency so there
/// is no per-row `currency` column. See iOS Tech Plan §5.5.
///
/// A schedule mirrors the detail of a regular transaction: a single
/// `category_id`, plus a budget and fixed-expense link stored by **lineage name**
/// (not a row id). Budgets and fixed expenses are month-scoped, so the generator
/// resolves these names to the due month's rows at run time (see the
/// `scheduled_transaction_details` / `scheduled_transaction_fixed_expense`
/// migrations). Tags live in the `scheduled_transaction_tags` junction and are
/// loaded separately.
struct ScheduledTransaction: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var accountId: UUID
    var type: TransactionType
    var amount: Int64
    var description: String?
    var recurrence: RecurrenceType
    var nextDueDate: Date
    var isActive: Bool
    var categoryId: UUID?
    var budgetName: String?
    var fixedExpenseName: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case accountId = "account_id"
        case type, amount
        case description, recurrence
        case nextDueDate = "next_due_date"
        case isActive = "is_active"
        case categoryId = "category_id"
        case budgetName = "budget_name"
        case fixedExpenseName = "fixed_expense_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
