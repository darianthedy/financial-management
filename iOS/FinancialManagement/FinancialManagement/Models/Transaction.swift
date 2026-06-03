import Foundation

struct Transaction: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let accountId: UUID
    var type: TransactionType
    var status: TransactionStatus
    var amount: Int64
    var currency: String
    var description: String?
    var transactionDate: Date
    var toAccountId: UUID?
    var budgetPeriodId: UUID?
    var scheduledTxnId: UUID?
    var fixedExpenseId: UUID?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case accountId = "account_id"
        case type, status, amount, currency
        case description
        case transactionDate = "date"
        case toAccountId = "transfer_account_id"
        case budgetPeriodId = "budget_period_id"
        case scheduledTxnId = "scheduled_txn_id"
        case fixedExpenseId = "fixed_expense_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
