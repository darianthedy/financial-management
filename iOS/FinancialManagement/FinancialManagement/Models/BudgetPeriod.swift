import Foundation

struct BudgetPeriod: Codable, Identifiable, Sendable {
    let id: UUID
    let budgetId: UUID
    let yearMonth: String
    var periodicAmount: Int64
    var carryOverAmount: Int64
    let currency: String
    let createdAt: Date
    var updatedAt: Date

    /// The actual spendable amount: periodic + carry-over
    var effectiveAmount: Int64 { periodicAmount + carryOverAmount }

    enum CodingKeys: String, CodingKey {
        case id
        case budgetId = "budget_id"
        case yearMonth = "year_month"
        case periodicAmount = "periodic_amount"
        case carryOverAmount = "carry_over_amount"
        case currency
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
