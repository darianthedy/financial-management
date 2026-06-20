import Foundation

struct Account: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var type: AccountType
    var startingBalance: Int64
    var imageUrl: String?          // public URL of the avatar in Supabase Storage (nullable; set in P03)
    var isArchived: Bool
    var showOnDashboard: Bool       // hide from the dashboard Accounts card without archiving
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, type
        case startingBalance = "starting_balance"
        case imageUrl = "image_url"
        case isArchived = "is_archived"
        case showOnDashboard = "show_on_dashboard"
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
