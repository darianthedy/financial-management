import Foundation
import Supabase

actor BudgetRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getAll() async throws -> [Budget] {
        try await client
            .from("budgets")
            .select()
            .eq("is_active", value: true)
            .order("created_at")
            .execute()
            .value
    }

    func getPeriods(budgetId: UUID, yearMonth: String) async throws -> [BudgetPeriod] {
        try await client
            .from("budget_periods")
            .select()
            .eq("budget_id", value: budgetId)
            .eq("year_month", value: yearMonth)
            .execute()
            .value
    }

    func getAllPeriodsForMonth(yearMonth: String) async throws -> [BudgetPeriod] {
        try await client
            .from("budget_periods")
            .select()
            .eq("year_month", value: yearMonth)
            .execute()
            .value
    }

    func create(name: String, enableCarryOver: Bool) async throws -> Budget {
        let userId = try await client.auth.session.user.id

        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let enable_carry_over: Bool
        }

        return try await client
            .from("budgets")
            .insert(Insert(
                user_id: userId,
                name: name,
                enable_carry_over: enableCarryOver
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func update(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client
            .from("budgets")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    func upsertPeriod(budgetId: UUID, yearMonth: String, periodicAmount: Int64, currency: String) async throws -> BudgetPeriod {
        struct Upsert: Encodable {
            let budget_id: UUID
            let year_month: String
            let periodic_amount: Int64
            let currency: String
        }

        return try await client
            .from("budget_periods")
            .upsert(Upsert(
                budget_id: budgetId,
                year_month: yearMonth,
                periodic_amount: periodicAmount,
                currency: currency
            ))
            .select()
            .single()
            .execute()
            .value
    }
}
