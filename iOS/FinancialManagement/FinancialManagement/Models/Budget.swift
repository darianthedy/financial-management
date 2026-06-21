import Foundation

/// A budget is **one self-contained row for one month** (identity = `name`).
/// There is no separate periods table, no stored carry-over, and no
/// `enable_carry_over` toggle — carry-over is always on and computed live in
/// `v_budget_progress`. This type maps the raw `budgets` table and is used for
/// create / edit / copy / remove; display numbers come from `BudgetProgress`.
/// See iOS Tech Plan §5.2 and System Design §4.1–4.2.
struct Budget: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var yearMonth: String          // 'YYYY-MM' — the month this entry applies to
    var periodicAmount: Int64      // minor units; the limit set for this month
    var description: String?       // optional free-text note
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case yearMonth = "year_month"
        case periodicAmount = "periodic_amount"
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
