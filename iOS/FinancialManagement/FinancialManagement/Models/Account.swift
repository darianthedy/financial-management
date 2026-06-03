import Foundation

struct Account: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var type: AccountType
    var currency: String
    var startingBalance: Int64
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, type, currency
        case startingBalance = "starting_balance"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AccountMonthlyBalance: Codable, Sendable {
    let accountId: UUID
    let yearMonth: String
    var balance: Int64
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case yearMonth = "year_month"
        case balance
        case updatedAt = "updated_at"
    }
}
