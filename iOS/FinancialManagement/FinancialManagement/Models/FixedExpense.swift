import Foundation

struct FixedExpense: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    let yearMonth: String
    var amount: Int64
    var currency: String
    var dueDay: Int
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case yearMonth = "year_month"
        case amount, currency
        case dueDay = "due_day"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
