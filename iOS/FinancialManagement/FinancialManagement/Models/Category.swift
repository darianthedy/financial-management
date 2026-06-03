import Foundation

struct Category: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var icon: String?
    var color: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, icon, color
        case createdAt = "created_at"
    }
}
