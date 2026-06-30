import Foundation
import Supabase

actor CategoryRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func list() async throws -> [Category] {
        try await client
            .from("categories")
            .select()
            .order("name")
            .execute()
            .value
    }

    func create(name: String, color: String) async throws -> Category {
        let userId = try await client.auth.session.user.id
        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let color: String
        }
        return try await client
            .from("categories")
            .insert(Insert(user_id: userId, name: name, color: color))
            .select()
            .single()
            .execute()
            .value
    }

    func update(id: UUID, name: String, color: String) async throws {
        try await client
            .from("categories")
            .update(["name": AnyJSON.string(name), "color": AnyJSON.string(color)])
            .eq("id", value: id)
            .execute()
    }

    func delete(id: UUID) async throws {
        try await client
            .from("categories")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
