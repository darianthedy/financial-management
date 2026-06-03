import Foundation
import Supabase

actor ScheduledTransactionRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getAll() async throws -> [ScheduledTransaction] {
        try await client
            .from("scheduled_transactions")
            .select()
            .eq("is_active", value: true)
            .order("next_due_date")
            .execute()
            .value
    }

    func getPendingTransactions() async throws -> [Transaction] {
        try await client
            .from("transactions")
            .select()
            .eq("status", value: TransactionStatus.pending.rawValue)
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
        recurrence: RecurrenceType,
        nextDueDate: Date
    ) async throws -> ScheduledTransaction {
        let userId = try await client.auth.session.user.id

        struct Insert: Encodable {
            let user_id: UUID
            let account_id: UUID
            let type: TransactionType
            let amount: Int64
            let currency: String
            let description: String?
            let recurrence: RecurrenceType
            let next_due_date: Date
        }

        return try await client
            .from("scheduled_transactions")
            .insert(Insert(
                user_id: userId,
                account_id: accountId,
                type: type,
                amount: amount,
                currency: currency,
                description: description,
                recurrence: recurrence,
                next_due_date: nextDueDate
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func confirmPending(id: UUID) async throws {
        try await client
            .from("transactions")
            .update(["status": AnyJSON.string(TransactionStatus.confirmed.rawValue)])
            .eq("id", value: id)
            .execute()
    }

    func dismissPending(id: UUID) async throws {
        try await client
            .from("transactions")
            .update(["status": AnyJSON.string(TransactionStatus.dismissed.rawValue)])
            .eq("id", value: id)
            .execute()
    }
}
