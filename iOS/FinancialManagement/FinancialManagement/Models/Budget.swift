import Foundation

struct Budget: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var isActive: Bool
    var enableCarryOver: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case isActive = "is_active"
        case enableCarryOver = "enable_carry_over"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
