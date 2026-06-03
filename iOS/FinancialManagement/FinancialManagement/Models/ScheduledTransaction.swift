import Foundation

struct ScheduledTransaction: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var accountId: UUID
    var type: TransactionType
    var amount: Int64
    var currency: String
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
        case type, amount, currency
        case description, recurrence
        case nextDueDate = "next_due_date"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
