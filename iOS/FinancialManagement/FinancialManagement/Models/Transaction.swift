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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
