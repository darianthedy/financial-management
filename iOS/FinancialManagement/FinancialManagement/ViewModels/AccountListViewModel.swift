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

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            accounts = try await repository.getAll()
            let allBalances = try await loadCurrentBalances()
            balances = Dictionary(uniqueKeysWithValues: allBalances.map { ($0.accountId, $0.currentBalance) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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
