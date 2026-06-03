import Foundation

struct UserSettings: Codable, Sendable {
    let userId: UUID
    var defaultCurrency: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case defaultCurrency = "default_currency"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
