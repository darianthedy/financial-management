import Foundation

/// Recurring template that the server turns into `pending` transactions (System
/// Design §4.5). The column is `recurrence` (not `recurrence_interval`) and
/// `next_due_date` (not `next_occurrence`); the app is single-currency so there
/// is no per-row `currency` column. See iOS Tech Plan §5.5.
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
