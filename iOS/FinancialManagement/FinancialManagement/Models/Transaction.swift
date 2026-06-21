import Foundation

struct Transaction: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let accountId: UUID
    var type: TransactionType
    var status: TransactionStatus
    var amount: Int64
    var description: String?
    var transactionDate: Date
    var transferAccountId: UUID?
    var budgetId: UUID?
    var categoryId: UUID?
    var scheduledTxnId: UUID?
    var fixedExpenseId: UUID?
    /// Tag ids attached to this transaction, aggregated by the `v_transactions`
    /// view (`tag_ids`). Optional because rows decoded straight from the base
    /// `transactions` table (e.g. a create/update response) don't carry it — the
    /// synthesized decoder treats a missing key as nil, and the list's tag chips
    /// simply don't render until the row is reloaded from the view.
    var tagIds: [UUID]?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case accountId = "account_id"
        case type, status, amount
        case description
        case transactionDate = "date"
        case transferAccountId = "transfer_account_id"
        case budgetId = "budget_id"
        case categoryId = "category_id"
        case scheduledTxnId = "scheduled_txn_id"
        case fixedExpenseId = "fixed_expense_id"
        case tagIds = "tag_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Trimmed projection of `v_transactions` used by the Summary: only the money
/// and grouping columns (plus the view's aggregated `tag_ids` array) needed to
/// compute totals and per-facet breakdowns client-side (§8.3.2 / §4.9).
struct VTransactionRow: Decodable, Identifiable, Sendable {
    let id: UUID
    let type: TransactionType
    let status: TransactionStatus
    let amount: Int64
    let accountId: UUID
    let transferAccountId: UUID?
    let categoryId: UUID?
    let budgetId: UUID?
    let fixedExpenseId: UUID?
    let tagIds: [UUID]

    enum CodingKeys: String, CodingKey {
        case id, type, status, amount
        case accountId = "account_id"
        case transferAccountId = "transfer_account_id"
        case categoryId = "category_id"
        case budgetId = "budget_id"
        case fixedExpenseId = "fixed_expense_id"
        case tagIds = "tag_ids"
    }
}
