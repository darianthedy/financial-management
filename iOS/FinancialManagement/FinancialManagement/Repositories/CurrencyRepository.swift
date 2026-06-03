import Foundation
import Supabase

actor CurrencyRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getAllCurrencies() async throws -> [Currency] {
        try await client
            .from("currencies")
            .select()
            .order("code")
            .execute()
            .value
    }

    func getUserSettings() async throws -> UserSettings? {
        let userId = try await client.auth.session.user.id
        let results: [UserSettings] = try await client
            .from("user_settings")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return results.first
    }

    func upsertDefaultCurrency(_ currencyCode: String) async throws -> UserSettings {
        let userId = try await client.auth.session.user.id

        struct Upsert: Encodable {
            let user_id: UUID
            let default_currency: String
        }

        return try await client
            .from("user_settings")
            .upsert(Upsert(user_id: userId, default_currency: currencyCode))
            .select()
            .single()
            .execute()
            .value
    }
}
