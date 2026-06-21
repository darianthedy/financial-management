import Foundation
import Supabase

/// Reads the active recurring templates and the server-generated pending
/// transactions, and confirms / dismisses pending rows. There is no
/// `pending_transactions` table — pending = rows in `transactions` with
/// `status = 'pending'`, generated server-side by the cron + Edge Function
/// (System Design §4.5). The app only displays + acts on them. See §8.7.
actor ScheduledTransactionRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    /// Active scheduled transactions, soonest due first.
    func getAll() async throws -> [ScheduledTransaction] {
        try await client
            .from("scheduled_transactions")
            .select()
            .eq("is_active", value: true)
            .order("next_due_date")
            .execute()
            .value
    }

    /// Pending transactions awaiting confirmation (`status = 'pending'`).
    func getPendingTransactions() async throws -> [Transaction] {
        try await client
            .from("transactions")
            .select()
            .eq("status", value: TransactionStatus.pending.rawValue)
            .order("date", ascending: false)
            .execute()
            .value
    }

    /// Promote a pending transaction to confirmed; the balance trigger then
    /// applies it to the account (System Design §4.5).
    func confirmPending(id: UUID) async throws {
        try await client
            .from("transactions")
            .update(["status": AnyJSON.string(TransactionStatus.confirmed.rawValue)])
            .eq("id", value: id)
            .execute()
    }

    /// Dismiss a pending transaction; it never affects the balance.
    func dismissPending(id: UUID) async throws {
        try await client
            .from("transactions")
            .update(["status": AnyJSON.string(TransactionStatus.dismissed.rawValue)])
            .eq("id", value: id)
            .execute()
    }
}
