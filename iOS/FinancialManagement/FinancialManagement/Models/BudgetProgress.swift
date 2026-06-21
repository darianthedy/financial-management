import Foundation

/// Read model for the `v_budget_progress` view. Carry-over, spent, remaining,
/// and (P1) reserved are all computed in SQL — never stored. Clients read this
/// for progress bars, badges, the budget picker, and the budget filter. The
/// `description` (note) is surfaced by the view so the card can show it and the
/// edit form can prefill it without a second fetch. See iOS Tech Plan §5.2.
struct BudgetProgress: Codable, Identifiable, Sendable {
    let budgetId: UUID
    let userId: UUID
    let budgetName: String
    let yearMonth: String
    let periodicAmount: Int64
    let carryOverAmount: Int64      // carry_in from the previous month in this lineage (0 on a gap)
    let effectiveAmount: Int64      // periodic + carry_in
    let spent: Int64                // NET of linked confirmed txns: expenses − income
    let remaining: Int64            // effective − spent − reserved (can be negative)
    let reserved: Int64             // P1: sum of virtual-installment reservations for this month
    let description: String?        // optional free-text note (from the underlying budgets row)

    var id: UUID { budgetId }

    enum CodingKeys: String, CodingKey {
        case budgetId = "budget_id"
        case userId = "user_id"
        case budgetName = "budget_name"
        case yearMonth = "year_month"
        case periodicAmount = "periodic_amount"
        case carryOverAmount = "carry_over_amount"
        case effectiveAmount = "effective_amount"
        case spent
        case remaining
        case reserved
        case description
    }
}
