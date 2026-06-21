import Foundation
import Observation
import Supabase
import SwiftUI

/// Selectable page sizes for the transaction list (§8.3.1).
let transactionPageSizes = [25, 50, 100, 200]

/// Identifies one active facet so a chip can clear exactly that facet.
enum FilterFacetKey: String, CaseIterable, Identifiable {
    case search, types, accounts, statuses, date, amount, categories, tags, budgets, fixedExpenses
    var id: String { rawValue }
}

/// Drives the Transactions list: the full filter/search/summary state over
/// `v_transactions` (P05). Holds a `TransactionFilters` value, queries the view
/// windowed with `.range()` + exact count for pagination, and exposes the
/// lookups the chips/summary hydrate names with.
///
/// When `scopedAccountId` is set (the account-detail embedding) the list locks
/// to that account and the filter UI is hidden; otherwise the MonthNavigator
/// supplies a default month window that an explicit Date-range filter overrides.
@Observable
@MainActor
final class TransactionListViewModel {
    var transactions: [Transaction] = []
    var accountsById: [UUID: Account] = [:]
    var categoriesById: [UUID: Category] = [:]
    var tagsById: [UUID: Tag] = [:]

    var yearMonth = DateUtils.currentYearMonth()
    var filters = TransactionFilters()
    var pageSize = 50
    var totalCount = 0

    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var navigationDirection: Edge = .trailing

    /// When set, the list is scoped to a single account (its detail screen).
    let scopedAccountId: UUID?

    private let repository = TransactionRepository()
    /// Bumped on every state change so in-flight loads from a stale state bail.
    private var loadGeneration = 0

    init(scopedAccountId: UUID? = nil) {
        self.scopedAccountId = scopedAccountId
    }

    var canLoadMore: Bool { transactions.count < totalCount }

    /// True once the user pins an explicit date range, at which point the
    /// MonthNavigator is hidden (the range governs the period instead).
    var hasExplicitDateRange: Bool { filters.dateFrom != nil || filters.dateTo != nil }

    /// The user's filters with the account lock and the default month window
    /// folded in, so the same value drives both the list and the Summary query.
    var effectiveFilters: TransactionFilters {
        var f = filters
        if let scoped = scopedAccountId {
            f.accounts = Facet(values: [scoped])
        }
        if f.dateFrom == nil, f.dateTo == nil, let range = DateUtils.monthDateRange(yearMonth) {
            f.dateFrom = range.start
            f.dateTo = range.end
        }
        return f
    }

    // MARK: - Loading

    func load() async {
        loadGeneration += 1
        let gen = loadGeneration
        if transactions.isEmpty { isLoading = true }
        defer { if gen == loadGeneration { isLoading = false } }

        do {
            async let lookups: Void = loadLookups()
            let result = try await repository.search(
                filters: effectiveFilters, offset: 0, limit: pageSize
            )
            await lookups
            guard gen == loadGeneration else { return }
            transactions = result.rows
            totalCount = result.total
        } catch {
            guard gen == loadGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        let gen = loadGeneration
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let result = try await repository.search(
                filters: effectiveFilters, offset: transactions.count, limit: pageSize
            )
            guard gen == loadGeneration else { return }
            transactions.append(contentsOf: result.rows)
            totalCount = result.total
        } catch {
            guard gen == loadGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Filter mutations (each triggers a fresh page-0 load)

    func applyFilters(_ newFilters: TransactionFilters) {
        filters = newFilters
        reload()
    }

    func clearAllFilters() {
        filters = TransactionFilters()
        reload()
    }

    func clearFacet(_ key: FilterFacetKey) {
        switch key {
        case .search: filters.search = nil
        case .types: filters.types = nil
        case .accounts: filters.accounts = nil
        case .statuses: filters.statuses = nil
        case .date: filters.dateFrom = nil; filters.dateTo = nil
        case .amount: filters.amountMin = nil; filters.amountMax = nil
        case .categories: filters.categories = nil
        case .tags: filters.tags = nil
        case .budgets: filters.budgets = nil
        case .fixedExpenses: filters.fixedExpenses = nil
        }
        reload()
    }

    func updateSearch(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let next: String? = trimmed.isEmpty ? nil : text
        guard next != filters.search else { return }
        filters.search = next
        reload()
    }

    func setPageSize(_ size: Int) {
        guard size != pageSize else { return }
        pageSize = size
        reload()
    }

    func navigateMonth(by offset: Int) {
        navigationDirection = offset > 0 ? .trailing : .leading
        withAnimation(.easeInOut(duration: 0.3)) {
            yearMonth = DateUtils.navigate(yearMonth, by: offset)
            transactions = []
            totalCount = 0
        }
        reload()
    }

    private func reload() { Task { await load() } }

    // MARK: - Row mutations (inline confirm / dismiss / delete)

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
            totalCount = max(0, totalCount - 1)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func account(for transaction: Transaction) -> Account? {
        accountsById[transaction.accountId]
    }

    // MARK: - Lookups (hydrate chips / summary / rows)

    private func loadLookups() async {
        guard accountsById.isEmpty, categoriesById.isEmpty, tagsById.isEmpty else { return }
        let client = SupabaseService.shared.client
        do {
            async let accounts: [Account] = client.from("accounts").select().execute().value
            async let categories: [Category] = client.from("categories").select().execute().value
            async let tags: [Tag] = client.from("tags").select().execute().value
            accountsById = Dictionary(uniqueKeysWithValues: try await accounts.map { ($0.id, $0) })
            categoriesById = Dictionary(uniqueKeysWithValues: try await categories.map { ($0.id, $0) })
            tagsById = Dictionary(uniqueKeysWithValues: try await tags.map { ($0.id, $0) })
        } catch {
            // Non-fatal: chips/rows fall back to ids/placeholders.
        }
    }
}
