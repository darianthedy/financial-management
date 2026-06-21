import Foundation
import Supabase

/// CRUD for `fixed_expenses`, all scoped to a single `year_month` (§5.6, §8.5).
/// Each row is self-contained — one expense for one month. Paid status is not
/// stored; it is derived from `transactions.fixed_expense_id` via `getPaidIds`.
actor FixedExpenseRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getForMonth(yearMonth: String) async throws -> [FixedExpense] {
        try await client
            .from("fixed_expenses")
            .select()
            .eq("year_month", value: yearMonth)
            .order("name")
            .execute()
            .value
    }

    // No `currency`/`due_day` — the DB defaults currency and the day column was
    // dropped (drop_fixed_expense_due_day).
    private struct Insert: Encodable {
        let user_id: UUID
        let name: String
        let year_month: String
        let amount: Int64
        let is_active: Bool
    }

    func create(name: String, yearMonth: String, amount: Int64) async throws -> FixedExpense {
        let userId = try await client.auth.session.user.id

        return try await client
            .from("fixed_expenses")
            .insert(Insert(
                user_id: userId,
                name: name,
                year_month: yearMonth,
                amount: amount,
                is_active: true
            ))
            .select()
            .single()
            .execute()
            .value
    }

    /// Edit a single month's row (name/amount). Other months are untouched.
    func update(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client
            .from("fixed_expenses")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    /// Delete a single month's row. Linked transactions keep their record but
    /// have `fixed_expense_id` set to NULL via `ON DELETE SET NULL`.
    func delete(id: UUID) async throws {
        try await client
            .from("fixed_expenses")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Copy the previous month's expenses into `currentMonth`, preserving
    /// name/amount/is_active and skipping any name that already exists this month
    /// (UNIQUE `user_id, name, year_month`).
    @discardableResult
    func copyFromPreviousMonth(from previousMonth: String, to currentMonth: String) async throws -> [FixedExpense] {
        let previous = try await getForMonth(yearMonth: previousMonth)
        let existingNames = Set(try await getForMonth(yearMonth: currentMonth).map(\.name))

        let toCopy = previous.filter { !existingNames.contains($0.name) }
        guard !toCopy.isEmpty else { return [] }

        let userId = try await client.auth.session.user.id
        let rows = toCopy.map {
            Insert(
                user_id: userId,
                name: $0.name,
                year_month: currentMonth,
                amount: $0.amount,
                is_active: $0.isActive
            )
        }

        return try await client
            .from("fixed_expenses")
            .insert(rows)
            .select()
            .execute()
            .value
    }

    /// The subset of the given fixed-expense ids that are paid — i.e. referenced
    /// by at least one transaction via `fixed_expense_id`.
    func getPaidIds(fixedExpenseIds: [UUID]) async throws -> Set<UUID> {
        guard !fixedExpenseIds.isEmpty else { return [] }

        struct Row: Decodable {
            let fixed_expense_id: UUID
        }

        let rows: [Row] = try await client
            .from("transactions")
            .select("fixed_expense_id")
            .in("fixed_expense_id", values: fixedExpenseIds.map(\.uuidString))
            .execute()
            .value

        return Set(rows.map(\.fixed_expense_id))
    }
}
