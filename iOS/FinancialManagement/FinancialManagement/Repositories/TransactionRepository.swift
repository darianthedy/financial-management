import Foundation
import Supabase

actor TransactionRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    /// Paginated, account/month-scoped list ordered newest-first. Full
    /// filtering/search over `v_transactions` lands in P05.
    func list(
        accountId: UUID? = nil,
        yearMonth: String,
        offset: Int = 0,
        limit: Int = 50
    ) async throws -> [Transaction] {
        let startDate = "\(yearMonth)-01"
        let endDate = "\(DateUtils.navigate(yearMonth, by: 1))-01"

        var query = client
            .from("transactions")
            .select()
            .gte("date", value: startDate)
            .lt("date", value: endDate)

        if let accountId {
            // Match either side of a transfer.
            query = query.or("account_id.eq.\(accountId.uuidString),transfer_account_id.eq.\(accountId.uuidString)")
        }

        return try await query
            .order("date", ascending: false)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }

    // MARK: - Filtered search over v_transactions (P05)

    /// One windowed page of the filtered list, read from `v_transactions` so the
    /// tag facet is an ordinary SQL predicate (System Design §4.9). Returns the
    /// rows for `[offset, offset+limit)` plus the **exact total** matching the
    /// filters (for the match-count label and pagination). A short-circuited
    /// filter set (matches nothing) returns `([], 0)` without a round-trip.
    func search(
        filters: TransactionFilters,
        offset: Int,
        limit: Int
    ) async throws -> (rows: [Transaction], total: Int) {
        let base = client
            .from("v_transactions")
            .select("*", count: .exact)

        guard let filtered = try await applyFilters(filters, to: base, client: client) else {
            return ([], 0)
        }

        let response: PostgrestResponse<[Transaction]> = try await filtered
            .order("date", ascending: false)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()

        return (response.value, response.count ?? response.value.count)
    }

    /// Every row matching `filters` (all pages), selecting only the money /
    /// grouping columns the Summary needs. Used by `TransactionSummarySheet`.
    func fetchAll(filters: TransactionFilters) async throws -> [VTransactionRow] {
        let columns = "id,type,status,amount,account_id,transfer_account_id,category_id,budget_id,fixed_expense_id,tag_ids"
        let pageSize = 1000
        var all: [VTransactionRow] = []
        var offset = 0

        while true {
            let base = client.from("v_transactions").select(columns)
            guard let filtered = try await applyFilters(filters, to: base, client: client) else {
                return []
            }
            let page: [VTransactionRow] = try await filtered
                .order("date", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            all.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += pageSize
        }
        return all
    }

    func create(
        accountId: UUID,
        type: TransactionType,
        amount: Int64,
        description: String?,
        transactionDate: Date,
        transferAccountId: UUID?,
        categoryId: UUID?,
        budgetId: UUID?,
        fixedExpenseId: UUID?
    ) async throws -> Transaction {
        let userId = try await client.auth.session.user.id

        struct Insert: Encodable {
            let user_id: UUID
            let account_id: UUID
            let type: TransactionType
            let amount: Int64
            let description: String?
            let date: Date
            let transfer_account_id: UUID?
            let category_id: UUID?
            let budget_id: UUID?
            let fixed_expense_id: UUID?
        }

        return try await client
            .from("transactions")
            .insert(Insert(
                user_id: userId,
                account_id: accountId,
                type: type,
                amount: amount,
                description: description,
                date: transactionDate,
                transfer_account_id: transferAccountId,
                category_id: categoryId,
                budget_id: budgetId,
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

    /// Inline confirm / dismiss for pending transactions (§8.3).
    func setStatus(id: UUID, status: TransactionStatus) async throws {
        try await client
            .from("transactions")
            .update(["status": status.rawValue])
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

    // MARK: - Tags (many-to-many via transaction_tags)

    func setTags(transactionId: UUID, tagIds: Set<UUID>) async throws {
        try await client
            .from("transaction_tags")
            .delete()
            .eq("transaction_id", value: transactionId)
            .execute()

        guard !tagIds.isEmpty else { return }

        struct Row: Encodable {
            let transaction_id: UUID
            let tag_id: UUID
        }

        let rows = tagIds.map { Row(transaction_id: transactionId, tag_id: $0) }
        try await client
            .from("transaction_tags")
            .insert(rows)
            .execute()
    }

    func getTagIds(transactionId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable {
            let tag_id: UUID
        }

        let rows: [Row] = try await client
            .from("transaction_tags")
            .select("tag_id")
            .eq("transaction_id", value: transactionId)
            .execute()
            .value

        return Set(rows.map(\.tag_id))
    }
}
