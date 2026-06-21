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

        return headers.map { header in
            ActiveInstallment(
                installment: header,
                source: sourceById[header.sourceTransactionId],
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
/// title and back-link) and the budget-name chips it reserves across.
struct ActiveInstallment: Identifiable, Sendable {
    let installment: BudgetInstallment
    let source: Transaction?
    let budgetNames: [String]

    var id: UUID { installment.id }

    /// Title derived from the source expense, falling back to the header note.
    var title: String {
        if let description = source?.description, !description.isEmpty { return description }
        if let note = installment.description, !note.isEmpty { return note }
        return "Installment"
    }
}
