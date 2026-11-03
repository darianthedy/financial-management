import Foundation
import Supabase

actor AccountRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getAll() async throws -> [Account] {
        try await client
            .from("accounts")
            .select()
            .eq("is_archived", value: false)
            .order("created_at")
            .execute()
            .value
    }

    func getById(_ id: UUID) async throws -> Account {
        try await client
            .from("accounts")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func create(name: String, type: AccountType, startingBalance: Int64,
                imageUrl: String?, showOnDashboard: Bool) async throws -> Account {
        let userId = try await client.auth.session.user.id

        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let type: AccountType
            let starting_balance: Int64
            let image_url: String?
            let show_on_dashboard: Bool
        }

        let account: Account = try await client
            .from("accounts")
            .insert(Insert(
                user_id: userId,
                name: name,
                type: type,
                starting_balance: startingBalance,
                image_url: imageUrl,
                show_on_dashboard: showOnDashboard
            ))
            .select()
            .single()
            .execute()
            .value

        // The current month's balance row is seeded by the database
        // (trg_seed_account_balance, migration 20260604000001), as on web.
        // Inserting it here too violates its primary key, so the save fails
        // after the account has been created.
        return account
    }

    /// Current balance = latest ledger row for the account.
    func getCurrentBalance(accountId: UUID) async throws -> Int64 {
        let row: AccountMonthlyBalance = try await client
            .from("account_monthly_balances")
            .select()
            .eq("account_id", value: accountId)
            .order("year_month", ascending: false)
            .limit(1)
            .single()
            .execute()
            .value
        return row.balance
    }

    func update(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client
            .from("accounts")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    /// Archive = soft-delete: hide the account but preserve its transaction history.
    func archive(id: UUID) async throws {
        try await client
            .from("accounts")
            .update(["is_archived": true])
            .eq("id", value: id)
            .execute()
    }
}
