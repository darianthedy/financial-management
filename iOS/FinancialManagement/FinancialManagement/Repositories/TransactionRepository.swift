import Foundation
import Supabase

actor TransactionRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getAll(accountId: UUID? = nil, yearMonth: String? = nil, type: TransactionType? = nil) async throws -> [Transaction] {
        var query = client
            .from("transactions")
            .select()

        if let accountId {
            query = query.eq("account_id", value: accountId)
        }

        if let yearMonth {
            let startDate = "\(yearMonth)-01"
            let endYearMonth = DateUtils.navigate(yearMonth, by: 1)
            let endDate = "\(endYearMonth)-01"
            query = query
                .gte("date", value: startDate)
                .lt("date", value: endDate)
        }

        if let type {
            query = query.eq("type", value: type.rawValue)
        }

        return try await query
            .order("date", ascending: false)
            .execute()
            .value
    }

    func create(
        accountId: UUID,
        type: TransactionType,
        amount: Int64,
        currency: String,
        description: String?,
        transactionDate: Date,
        toAccountId: UUID?,
        budgetPeriodId: UUID?,
        fixedExpenseId: UUID? = nil
    ) async throws -> Transaction {
        let userId = try await client.auth.session.user.id

        struct Insert: Encodable {
            let user_id: UUID
            let account_id: UUID
            let type: TransactionType
            let amount: Int64
            let currency: String
            let description: String?
            let date: Date
            let transfer_account_id: UUID?
            let budget_period_id: UUID?
            let fixed_expense_id: UUID?
        }

        return try await client
            .from("transactions")
            .insert(Insert(
                user_id: userId,
                account_id: accountId,
                type: type,
                amount: amount,
                currency: currency,
                description: description,
                date: transactionDate,
                transfer_account_id: toAccountId,
                budget_period_id: budgetPeriodId,
                fixed_expense_id: fixedExpenseId
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func update(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client
            .from("transactions")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    func delete(id: UUID) async throws {
        try await client
            .from("transactions")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Junction Table: transaction_categories

    func setCategories(transactionId: UUID, categoryIds: [UUID]) async throws {
        try await client
            .from("transaction_categories")
            .delete()
            .eq("transaction_id", value: transactionId)
            .execute()

        guard !categoryIds.isEmpty else { return }

        struct Row: Encodable {
            let transaction_id: UUID
            let category_id: UUID
        }

        let rows = categoryIds.map { Row(transaction_id: transactionId, category_id: $0) }
        try await client
            .from("transaction_categories")
            .insert(rows)
            .execute()
    }

    func getCategoryIds(transactionId: UUID) async throws -> [UUID] {
        struct Row: Decodable {
            let category_id: UUID
        }

        let rows: [Row] = try await client
            .from("transaction_categories")
            .select("category_id")
            .eq("transaction_id", value: transactionId)
            .execute()
            .value

        return rows.map(\.category_id)
    }
}
