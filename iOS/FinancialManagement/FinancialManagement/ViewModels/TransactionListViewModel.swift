import Foundation
import Observation
import SwiftUI

/// Account/month-scoped transaction list. Full filter/search/summary state
/// over `v_transactions` is P05; this holds only the month scope, optional
/// account scope, pagination, and inline confirm/dismiss.
@Observable
@MainActor
final class TransactionListViewModel {
    var transactions: [Transaction] = []
    var accountsById: [UUID: Account] = [:]
    var yearMonth = DateUtils.currentYearMonth()
    var isLoading = false
    var isLoadingMore = false
    var canLoadMore = false
    var errorMessage: String?
    var navigationDirection: Edge = .trailing

    /// When set, the list is scoped to a single account (its detail screen).
    let scopedAccountId: UUID?

    private let pageSize = 50
    private let repository = TransactionRepository()

    init(scopedAccountId: UUID? = nil) {
        self.scopedAccountId = scopedAccountId
    }

    func load() async {
        let month = yearMonth
        if transactions.isEmpty { isLoading = true }
        defer { if yearMonth == month { isLoading = false } }

        do {
            async let accounts = loadAccounts()
            let fetched = try await repository.list(
                accountId: scopedAccountId,
                yearMonth: month,
                offset: 0,
                limit: pageSize
            )
            _ = await accounts

            guard yearMonth == month else { return }
            transactions = fetched
            canLoadMore = fetched.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        let month = yearMonth
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let fetched = try await repository.list(
                accountId: scopedAccountId,
                yearMonth: month,
                offset: transactions.count,
                limit: pageSize
            )
            guard yearMonth == month else { return }
            transactions.append(contentsOf: fetched)
            canLoadMore = fetched.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func navigateMonth(by offset: Int) {
        navigationDirection = offset > 0 ? .trailing : .leading
        withAnimation(.easeInOut(duration: 0.3)) {
            yearMonth = DateUtils.navigate(yearMonth, by: offset)
            transactions = []
            canLoadMore = false
        }
        Task { await load() }
    }

    func setStatus(_ transaction: Transaction, to status: TransactionStatus) async {
        do {
            try await repository.setStatus(id: transaction.id, status: status)
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[index].status = status
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTransaction(_ transaction: Transaction) async {
        do {
            try await repository.delete(id: transaction.id)
            transactions.removeAll { $0.id == transaction.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func account(for transaction: Transaction) -> Account? {
        accountsById[transaction.accountId]
    }

    private func loadAccounts() async {
        guard accountsById.isEmpty else { return }
        do {
            let client = SupabaseService.shared.client
            let accounts: [Account] = try await client
                .from("accounts")
                .select()
                .execute()
                .value
            accountsById = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        } catch {
            // Non-fatal: rows fall back to the type icon.
        }
    }
}
