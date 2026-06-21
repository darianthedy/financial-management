import Foundation
import Supabase

/// Reads display numbers from `v_budget_progress`; writes to the `budgets` table.
/// Budgets are flat per-month rows (identity = `name`); carry-over is always on
/// and computed live in the view, never stored. See iOS Tech Plan §5.9 and
/// System Design §4.1–4.2.
actor BudgetRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    /// Progress rows (effective / spent / remaining / carry-in / reserved) for one month.
    func progress(yearMonth: String) async throws -> [BudgetProgress] {
        try await client
            .from("v_budget_progress")
            .select()
            .eq("year_month", value: yearMonth)
            .order("budget_name")
            .execute()
            .value
    }

    func add(name: String, yearMonth: String, periodicAmount: Int64, note: String?) async throws {
        let userId = try await client.auth.session.user.id
        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let year_month: String
            let periodic_amount: Int64
            let description: String?
        }
        try await client
            .from("budgets")
            .insert(Insert(
                user_id: userId,
                name: name,
                year_month: yearMonth,
                periodic_amount: periodicAmount,
                description: note
            ))
            .execute()
    }

    /// Copy from previous month: duplicate M-1 rows into M (name, note,
    /// periodic_amount), skipping names already present in M.
    func copyFromPreviousMonth(into yearMonth: String) async throws {
        let userId = try await client.auth.session.user.id
        let previousMonth = DateUtils.navigate(yearMonth, by: -1)

        struct NameRow: Decodable { let name: String }
        let existing: [NameRow] = try await client
            .from("budgets")
            .select("name")
            .eq("year_month", value: yearMonth)
            .execute()
            .value
        let existingNames = Set(existing.map(\.name))

        let previous: [Budget] = try await client
            .from("budgets")
            .select()
            .eq("year_month", value: previousMonth)
            .execute()
            .value

        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let year_month: String
            let periodic_amount: Int64
            let description: String?
        }
        let rows = previous
            .filter { !existingNames.contains($0.name) }
            .map { Insert(
                user_id: userId,
                name: $0.name,
                year_month: yearMonth,
                periodic_amount: $0.periodicAmount,
                description: $0.description
            ) }

        guard !rows.isEmpty else { return }
        try await client.from("budgets").insert(rows).execute()
    }

    func update(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client
            .from("budgets")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    /// "Remove" a budget for a month = delete that month's row (a deliberate gap
    /// resets that lineage's carry-over to 0).
    func remove(id: UUID) async throws {
        try await client
            .from("budgets")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
