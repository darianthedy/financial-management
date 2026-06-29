import Foundation
import Observation
import Supabase

/// Drives the Scheduled screen: the active recurring templates and the
/// server-generated pending transactions (`status = 'pending'`). Pending rows
/// are produced server-side by the cron + Edge Function (System Design §4.5);
/// the app only displays, acts on, and notifies for them. A local notification
/// fires for pending transactions that appear after the first load (§10).
@Observable
@MainActor
final class ScheduledTransactionViewModel {
    var scheduledTransactions: [EnrichedScheduledTransaction] = []
    var pendingTransactions: [Transaction] = []
    /// Budget / fixed-expense / category names keyed by id, used to derive pending
    /// transaction row titles following the same rule as the main Transactions list.
    var budgetNamesById: [UUID: String] = [:]
    var fixedNamesById: [UUID: String] = [:]
    var categoriesById: [UUID: String] = [:]
    var isLoading = false
    var errorMessage: String?

    /// Currency used to format notification bodies; set by the view from
    /// `AppState.defaultCurrency` (the app is single-currency).
    var currencyCode = "USD"

    private let repository = ScheduledTransactionRepository()
    private let supabase = SupabaseService.shared.client
    private var realtimeChannel: RealtimeChannelV2?

    /// Pending IDs already surfaced to the user. `nil` until the first load so
    /// the initial backlog isn't announced — only rows that arrive afterwards
    /// (e.g. from the daily server job) trigger a notification.
    private var knownPendingIds: Set<UUID>?

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let rawScheduledFetch = repository.getAll()
            async let pendingFetch = repository.getPendingTransactions()

            let rawScheduled = try await rawScheduledFetch
            let fetchedPending = try await pendingFetch

            scheduledTransactions = try await repository.enrich(rawScheduled)
            await notifyNewPending(fetchedPending)
            pendingTransactions = fetchedPending
            await loadPendingLookups()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Resolves budget, fixed-expense, and category names for pending transaction
    /// title derivation, mirroring the lookups in TransactionListViewModel.
    private func loadPendingLookups() async {
        let client = SupabaseService.shared.client
        struct NameRow: Decodable { let id: UUID; let name: String }
        struct CategoryRow: Decodable { let id: UUID; let name: String }
        do {
            async let budgets: [NameRow] = client.from("budgets").select("id,name").execute().value
            async let fixed: [NameRow] = client.from("fixed_expenses").select("id,name").execute().value
            async let cats: [CategoryRow] = client.from("categories").select("id,name").execute().value
            budgetNamesById = Dictionary(try await budgets.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            fixedNamesById = Dictionary(try await fixed.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            categoriesById = Dictionary(try await cats.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        } catch {
            // Non-fatal: rows fall back to description / type word.
        }
    }

    func budgetName(for txn: Transaction) -> String? {
        txn.budgetId.flatMap { budgetNamesById[$0] }
    }

    func fixedExpenseName(for txn: Transaction) -> String? {
        txn.fixedExpenseId.flatMap { fixedNamesById[$0] }
    }

    func categoryName(for txn: Transaction) -> String? {
        txn.categoryId.flatMap { categoriesById[$0] }
    }

    /// Fires one local notification per pending transaction not seen on a prior
    /// load. The first load only seeds the baseline.
    private func notifyNewPending(_ pending: [Transaction]) async {
        let ids = Set(pending.map(\.id))
        defer { knownPendingIds = ids }

        guard let known = knownPendingIds else { return }  // first load: seed only
        for txn in pending where !known.contains(txn.id) {
            let amount = txn.amount.asCurrency(code: currencyCode)
            await NotificationService.shared.showPendingTransaction(
                title: "New pending transaction",
                body: "\(txn.description ?? txn.type.rawValue.capitalized) — \(amount) is awaiting confirmation."
            )
        }
    }

    func confirmPending(_ pending: Transaction) async {
        do {
            try await repository.confirmPending(id: pending.id)
            pendingTransactions.removeAll { $0.id == pending.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissPending(_ pending: Transaction) async {
        do {
            try await repository.dismissPending(id: pending.id)
            pendingTransactions.removeAll { $0.id == pending.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Pause / resume a schedule without opening the editor (web's Pause/Resume).
    func toggleActive(_ scheduled: EnrichedScheduledTransaction) async {
        do {
            try await repository.setActive(id: scheduled.id, isActive: !scheduled.isActive)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Delete a schedule. Already-generated transactions are kept; only the
    /// schedule is removed (web's delete copy).
    func deleteScheduled(_ scheduled: EnrichedScheduledTransaction) async {
        do {
            try await repository.delete(id: scheduled.id)
            scheduledTransactions.removeAll { $0.id == scheduled.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Live updates: confirms/edits/dismisses and newly generated pending rows
    /// all land in `transactions`; advancing `next_due_date` touches
    /// `scheduled_transactions`. Reload on either.
    func subscribeToChanges() async {
        let channel = supabase.realtimeV2.channel("scheduled-realtime")
        let streams = ["transactions", "scheduled_transactions"].map {
            channel.postgresChange(AnyAction.self, schema: "public", table: $0)
        }

        await channel.subscribe()

        for stream in streams {
            Task {
                for await _ in stream { await load() }
            }
        }

        realtimeChannel = channel
    }

    func unsubscribe() async {
        if let channel = realtimeChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
    }
}
