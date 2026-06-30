import Foundation

struct Tag: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case createdAt = "created_at"
    }
}

struct TransactionTag: Codable, Sendable {
    let transactionId: UUID
    let tagId: UUID

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case tagId = "tag_id"
    }
}
