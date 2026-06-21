import Foundation

/// P1 "virtual installments" (see System Design §4.11 and iOS Tech Plan §5.7).
/// Reservations are **budget-side only** — they never enter `transactions` and
/// never affect account balances. One header per spread expense; the allocation
/// grid records the reserved minor units per budget lineage × month.
struct BudgetInstallment: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let sourceTransactionId: UUID
    var totalAmount: Int64          // = the source expense amount
    var description: String?
    var startYearMonth: String
    var months: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sourceTransactionId = "source_transaction_id"
        case totalAmount = "total_amount"
        case description
        case startYearMonth = "start_year_month"
        case months
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// One row per non-zero grid cell. Targets a budget LINEAGE by name, not a budget id.
struct BudgetInstallmentAllocation: Codable, Identifiable, Sendable {
    let id: UUID
    let installmentId: UUID
    let userId: UUID
    var budgetName: String
    var yearMonth: String
    var amount: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case installmentId = "installment_id"
        case userId = "user_id"
        case budgetName = "budget_name"
        case yearMonth = "year_month"
        case amount
    }
}
