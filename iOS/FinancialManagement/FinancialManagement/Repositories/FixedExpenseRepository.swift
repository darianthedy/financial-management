import Foundation
import Supabase

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

    func create(
        name: String,
        yearMonth: String,
        amount: Int64,
        currency: String,
        dueDay: Int
    ) async throws -> FixedExpense {
        let userId = try await client.auth.session.user.id

        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let year_month: String
            let amount: Int64
            let currency: String
            let due_day: Int
        }

        return try await client
            .from("fixed_expenses")
            .insert(Insert(
                user_id: userId,
                name: name,
                year_month: yearMonth,
                amount: amount,
                currency: currency,
                due_day: dueDay
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func update(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client
            .from("fixed_expenses")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    func delete(id: UUID) async throws {
        try await client
            .from("fixed_expenses")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func copyFromPreviousMonth(from previousMonth: String, to currentMonth: String) async throws -> [FixedExpense] {
        let previous = try await getForMonth(yearMonth: previousMonth)
        let existing = try await getForMonth(yearMonth: currentMonth)
        let existingNames = Set(existing.map(\.name))

        let userId = try await client.auth.session.user.id

        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let year_month: String
            let amount: Int64
            let currency: String
            let due_day: Int
        }

        var created: [FixedExpense] = []
        for entry in previous where entry.isActive && !existingNames.contains(entry.name) {
            let newEntry: FixedExpense = try await client
                .from("fixed_expenses")
                .insert(Insert(
                    user_id: userId,
                    name: entry.name,
                    year_month: currentMonth,
                    amount: entry.amount,
                    currency: entry.currency,
                    due_day: entry.dueDay
                ))
                .select()
                .single()
                .execute()
                .value
            created.append(newEntry)
        }

        return created
    }

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
