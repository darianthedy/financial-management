import Foundation

struct UserSettings: Codable, Sendable {
    let userId: UUID
    var defaultCurrency: String
    var defaultAccountId: UUID?     // pre-selected when adding a new transaction
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case defaultCurrency = "default_currency"
        case defaultAccountId = "default_account_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
