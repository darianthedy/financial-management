import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class AccountListViewModel {
    var accounts: [Account] = []
    var balances: [UUID: Int64] = [:]
    var isLoading = false
    var errorMessage: String?

    private let repository = AccountRepository()
    private let supabase = SupabaseService.shared.client
    private let realtime = RealtimeTableWatch()

    /// Bumped on every load so a slower, older load can't overwrite a newer one.
    private var loadGeneration = 0

    func load() async {
        loadGeneration += 1
        let gen = loadGeneration
        if accounts.isEmpty { isLoading = true }
        // Unstructured, so cancelling the caller can't abort the load: on the
        // outer display the collapsed split can start the list's `.task` and
        // cancel it straight away, which left the list empty (device report).
        await Task { await self.performLoad(generation: gen) }.value
    }

    private func performLoad(generation gen: Int) async {
        defer { if gen == loadGeneration { isLoading = false } }
        do {
            async let fetchedBalances = loadCurrentBalances()
            let fetched = try await repository.getAll()
            let allBalances = try await fetchedBalances
            guard gen == loadGeneration else { return }
            accounts = fetched
            balances = Dictionary(allBalances.map { ($0.accountId, $0.currentBalance) }, uniquingKeysWith: { a, _ in a })
            errorMessage = nil
        } catch {
            guard gen == loadGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Loading failed and nothing is on screen: the list offers a retry rather
    /// than claiming there are no accounts.
    var failedToLoad: Bool { accounts.isEmpty && !isLoading && errorMessage != nil }

    private func loadCurrentBalances() async throws -> [CurrentBalanceRow] {
        try await supabase
            .from("v_account_current_balance")
            .select()
            .execute()
            .value
    }

    /// Keeps the list live until the calling task is cancelled.
    func subscribeToChanges() async {
        await realtime.watch(topic: "accounts-realtime", tables: ["accounts", "account_monthly_balances"]) { [weak self] in
            await self?.load()
        }
    }

    func balance(for accountId: UUID) -> Int64 {
        balances[accountId] ?? 0
    }

    var totalBalance: Int64 {
        accounts.reduce(0) { $0 + balance(for: $1.id) }
    }
}

private struct CurrentBalanceRow: Codable {
    let accountId: UUID
    let currentBalance: Int64

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case currentBalance = "current_balance"
    }
}
