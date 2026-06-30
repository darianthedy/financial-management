import Foundation
import Supabase

struct TagRepository {
    private let supabase = SupabaseService.shared.client

    func list() async throws -> [Tag] {
        try await supabase
            .from("tags")
            .select()
            .order("name")
            .execute()
            .value
    }

    func create(name: String, userId: UUID) async throws -> Tag {
        struct Insert: Encodable {
            let user_id: UUID
            let name: String
        }

        return try await supabase
            .from("tags")
            .insert(Insert(user_id: userId, name: name))
            .select()
            .single()
            .execute()
            .value
    }

    func update(id: UUID, name: String) async throws -> Tag {
        struct Update: Encodable {
            let name: String
        }

        return try await supabase
            .from("tags")
            .update(Update(name: name))
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func delete(id: UUID) async throws {
        try await supabase
            .from("tags")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
