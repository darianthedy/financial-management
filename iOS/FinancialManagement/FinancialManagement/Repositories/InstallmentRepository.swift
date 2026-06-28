import Foundation
import Supabase

/// Budget Installments (P1) — virtual installments that spread an already-recorded
/// expense across future budgets. Everything goes through the
/// `spread_existing_transaction` RPC (atomic: nulls the source `budget_id`,
/// materializes missing budget rows, writes the reservation grid). Reservations
/// are budget-side only — they never enter `transactions` or touch balances.
/// See iOS Tech Plan §5.7, §8.8 and System Design §4.11.
actor InstallmentRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    /// One non-zero allocation cell sent to the RPC's JSONB grid argument.
    struct GridCell: Encodable, Sendable {
        let budget_name: String
        let year_month: String
        let amount: Int64
    }

    /// Spread an existing expense via `spread_existing_transaction`. The grid must
    /// list **non-zero cells only** and sum exactly to the expense amount (the RPC
    /// re-validates and rejects a non-expense, an already-spread row, or a
    /// mismatched grid).
    func spread(
        transactionId: UUID,
        startYearMonth: String,
        months: Int,
        grid: [GridCell]
    ) async throws {
        struct Params: Encodable {
            let p_transaction_id: UUID
            let p_start_year_month: String
            let p_months: Int
            let p_grid: [GridCell]
        }
        try await client
            .rpc("spread_existing_transaction", params: Params(
                p_transaction_id: transactionId,
                p_start_year_month: startYearMonth,
                p_months: months,
                p_grid: grid
            ))
            .execute()
    }

    /// Batched lookup: which of these source transactions are already spread?
    /// One query against `budget_installments.source_transaction_id`, returning
    /// the flagged ids so the transaction list can show a grid indicator.
    func spreadTransactionIds(among ids: [UUID]) async throws -> Set<UUID> {
        guard !ids.isEmpty else { return [] }
        struct Row: Decodable { let source_transaction_id: UUID }
        let rows: [Row] = try await client
            .from("budget_installments")
            .select("source_transaction_id")
            .in("source_transaction_id", values: ids)
            .execute()
            .value
        return Set(rows.map(\.source_transaction_id))
    }

    /// Installments that reserve allowance in `yearMonth`, assembled for the
    /// Budgets page's "Active installments" list: each header paired with its
    /// source expense (for the title/link) and the distinct budget-name chips it
    /// reserves across.
    func activeInstallments(reservingIn yearMonth: String) async throws -> [ActiveInstallment] {
        struct AllocRow: Decodable { let installment_id: UUID }
        let monthAllocs: [AllocRow] = try await client
            .from("budget_installment_allocations")
            .select("installment_id")
            .eq("year_month", value: yearMonth)
            .execute()
            .value

        let installmentIds = Array(Set(monthAllocs.map(\.installment_id)))
        guard !installmentIds.isEmpty else { return [] }

        async let headerRows: [BudgetInstallment] = client
            .from("budget_installments")
            .select()
            .in("id", values: installmentIds)
            .order("created_at", ascending: false)
            .execute()
            .value
        async let allocationRows: [BudgetInstallmentAllocation] = client
            .from("budget_installment_allocations")
            .select()
            .in("installment_id", values: installmentIds)
            .execute()
            .value

        let headers = try await headerRows
        let allocations = try await allocationRows

        let namesByInstallment = Dictionary(grouping: allocations, by: \.installmentId)
            .mapValues { Array(Set($0.map(\.budgetName))).sorted() }

        let sourceIds = headers.map(\.sourceTransactionId)
        let sources: [Transaction] = try await client
            .from("transactions")
            .select()
            .in("id", values: sourceIds)
            .execute()
            .value
        let sourceById = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })

        // Resolve the names the title precedence needs — a linked fixed expense
        // and category — so the title can follow web's `deriveTitle`
        // (fixed expense → category → description → type). The source row's own
        // ids drive these lookups; budget never applies (the source is detached).
        let categoryIds = Array(Set(sources.compactMap(\.categoryId)))
        var categoryById: [UUID: Category] = [:]
        if !categoryIds.isEmpty {
            let categories: [Category] = try await client
                .from("categories")
                .select()
                .in("id", values: categoryIds)
                .execute()
                .value
            categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        }

        let fixedExpenseIds = Array(Set(sources.compactMap(\.fixedExpenseId)))
        var fixedExpenseNameById: [UUID: String] = [:]
        if !fixedExpenseIds.isEmpty {
            struct FixedExpenseName: Decodable { let id: UUID; let name: String }
            let rows: [FixedExpenseName] = try await client
                .from("fixed_expenses")
                .select("id, name")
                .in("id", values: fixedExpenseIds)
                .execute()
                .value
            fixedExpenseNameById = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.name) })
        }

        return headers.map { header in
            let source = sourceById[header.sourceTransactionId]
            return ActiveInstallment(
                installment: header,
                source: source,
                category: source?.categoryId.flatMap { categoryById[$0] },
                fixedExpenseName: source?.fixedExpenseId.flatMap { fixedExpenseNameById[$0] },
                budgetNames: namesByInstallment[header.id] ?? []
            )
        }
    }

    /// Cancel an installment by deleting its header; `ON DELETE CASCADE` clears
    /// the allocations and future budgets recover their allowance.
    func cancel(id: UUID) async throws {
        try await client
            .from("budget_installments")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

/// One "Active installments" entry: the header plus its source expense (for the
/// title and back-link) and the budget-name chips it reserves across. The
/// source's linked category and fixed-expense name are resolved alongside so the
/// title can follow the same precedence the Transactions list uses.
struct ActiveInstallment: Identifiable, Sendable {
    let installment: BudgetInstallment
    let source: Transaction?
    /// The source expense's linked category, if any (second in the title order).
    let category: Category?
    /// The source expense's linked fixed-expense name, if any (top of the order).
    let fixedExpenseName: String?
    let budgetNames: [String]

    var id: UUID { installment.id }

    /// Title derived from the source expense, mirroring web's `deriveTitle`
    /// (`web/src/components/transactions/transaction-display.tsx`): fixed expense
    /// → category → description → the type word. Budget never applies — the
    /// source row is detached from any single budget. The header note stands in
    /// for the description if the source's own is missing, and the type word
    /// resolves to "Expense" for these expense-only sources.
    var title: String {
        if let fixedExpenseName, !fixedExpenseName.isEmpty { return fixedExpenseName }
        if let name = category?.name, !name.isEmpty { return name }
        if let description = source?.description, !description.isEmpty { return description }
        if let note = installment.description, !note.isEmpty { return note }
        return (source?.type ?? .expense).rawValue.capitalized
    }
}
