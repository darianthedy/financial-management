import Foundation

struct Currency: Codable, Identifiable, Sendable {
    let code: String
    let name: String
    let symbol: String
    let decimalPlaces: Int
    let createdAt: Date

    var id: String { code }

    var displayName: String { "\(code) – \(name)" }

    enum CodingKeys: String, CodingKey {
        case code, name, symbol
        case decimalPlaces = "decimal_places"
        case createdAt = "created_at"
    }
}
