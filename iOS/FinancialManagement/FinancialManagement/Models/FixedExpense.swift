import Foundation

/// One fixed expense for one specific month (§5.6). There is no separate periods
/// table and **no per-row currency**. There is no `isPaid` column — paid status
/// is derived from whether any transaction references this row via
/// `fixed_expense_id`.
struct FixedExpense: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var yearMonth: String
    var amount: Int64
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case yearMonth = "year_month"
        case amount
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
