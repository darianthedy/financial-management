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

/// One calendar day's rows plus the day's net (income − expense; transfers move
/// money between the user's own accounts, so they're net-zero and excluded).
/// Mirrors the web transaction list's date grouping. `id` is the displayed
/// date label ("MMM d, yyyy"), so the grouping key and the header label can never
/// disagree regardless of how the `date` column was decoded.
struct TransactionDateGroup: Identifiable {
    let id: String
    let transactions: [Transaction]
    let net: Int64
    var count: Int { transactions.count }
    var dateLabel: String { id }
}

/// Drives the Transactions list: the full filter/search/summary state over
/// `v_transactions` (P05). Holds a `TransactionFilters` value, queries the view
/// windowed with `.range()` + exact count for pagination, and exposes the
/// lookups the chips/summary hydrate names with.
///
/// When `scopedAccountId` is set (the account-detail embedding) the list locks
/// to that account, hides the filter UI, and browses month-by-month via the
/// MonthNavigator. The main list mirrors web: no month navigator and no implicit
/// date window — it shows all transactions and the filters govern the period.
@Observable
@MainActor
final class TransactionListViewModel {
    var transactions: [Transaction] = []
    var accountsById: [UUID: Account] = [:]
    var categoriesById: [UUID: Category] = [:]
    var tagsById: [UUID: Tag] = [:]
    /// Budget / fixed-expense names keyed by id, so a row can title itself with
    /// (or chip) the linked budget / fixed expense — mirroring the web row, which
    /// hydrates the same names from `budgets` / `fixed_expenses` per page.
    var budgetNamesById: [UUID: String] = [:]
    var fixedNamesById: [UUID: String] = [:]
    /// Source-expense ids that are already spread across budgets (P1) — drives the
    /// row's grid indicator and gates the "Create virtual installment" action.
    var spreadTransactionIds: Set<UUID> = []

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
    private let installmentRepository = InstallmentRepository()
    /// Bumped on every state change so in-flight loads from a stale state bail.
    private var loadGeneration = 0

    init(scopedAccountId: UUID? = nil, initialFilters: TransactionFilters? = nil) {
        self.scopedAccountId = scopedAccountId
        if let initialFilters { self.filters = initialFilters }
    }

    var canLoadMore: Bool { transactions.count < totalCount }

    /// Web's "MMM d, yyyy" label — also the grouping key (see `TransactionDateGroup`).
    private static let dayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// The loaded rows partitioned into per-date groups, preserving the
    /// date-descending order. Recomputed from `transactions`, so it stays correct
    /// as pages are appended (a day split across a page boundary merges naturally).
    var dateGroups: [TransactionDateGroup] {
        var groups: [TransactionDateGroup] = []
        var label: String?
        var rows: [Transaction] = []
        var net: Int64 = 0
        func flush() {
            if let label { groups.append(TransactionDateGroup(id: label, transactions: rows, net: net)) }
        }
        for txn in transactions {
            let key = Self.dayLabelFormatter.string(from: txn.transactionDate)
            if key != label {
                flush()
                label = key
                rows = []
                net = 0
            }
            rows.append(txn)
            switch txn.type {
            case .income: net += txn.amount
            case .expense: net -= txn.amount
            case .transfer: break
            }
        }
        flush()
        return groups
    }

    /// True once the user pins an explicit date range, at which point the
    /// MonthNavigator is hidden (the range governs the period instead).
    var hasExplicitDateRange: Bool { filters.dateFrom != nil || filters.dateTo != nil }

    /// The user's filters with the account lock (and, for the scoped account-detail
    /// list, the visible month) folded in, so the same value drives both the list
    /// and the Summary query.
    ///
    /// The main Transactions list mirrors web: it applies **no** implicit date
    /// window, so it defaults to all transactions and the filters alone govern the
    /// period. Only the scoped account-detail embedding, which browses
    /// month-by-month, folds the visible month in as a default window.
    var effectiveFilters: TransactionFilters {
        var f = filters
        if let scoped = scopedAccountId {
            f.accounts = Facet(values: [scoped])
            if f.dateFrom == nil, f.dateTo == nil, let range = DateUtils.monthDateRange(yearMonth) {
                f.dateFrom = range.start
                f.dateTo = range.end
            }
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
            await refreshSpreadFlags(generation: gen)
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
            await refreshSpreadFlags(generation: gen)
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

    // MARK: - Row display hydration (mirrors web's per-row name lookups)

    /// The transfer destination account (for the "→ name" chip on transfers).
    func transferAccount(for transaction: Transaction) -> Account? {
        transaction.transferAccountId.flatMap { accountsById[$0] }
    }

    /// The single linked category (column, not junction), if loaded.
    func category(for transaction: Transaction) -> Category? {
        transaction.categoryId.flatMap { categoriesById[$0] }
    }

    /// The linked budget's name, used as the row title (web title precedence).
    func budgetName(for transaction: Transaction) -> String? {
        transaction.budgetId.flatMap { budgetNamesById[$0] }
    }

    /// The linked fixed-expense's name (row title fallback / "Fixed" chip).
    func fixedExpenseName(for transaction: Transaction) -> String? {
        transaction.fixedExpenseId.flatMap { fixedNamesById[$0] }
    }

    /// Tags attached to the row, resolved from the view's `tag_ids` array.
    func tags(for transaction: Transaction) -> [Tag] {
        (transaction.tagIds ?? []).compactMap { tagsById[$0] }
    }

    // MARK: - Virtual installments (P1)

    func isSpread(_ transaction: Transaction) -> Bool {
        spreadTransactionIds.contains(transaction.id)
    }

    /// One batched lookup over the currently loaded expense rows to flag those
    /// already spread across budgets.
    private func refreshSpreadFlags(generation gen: Int) async {
        let ids = transactions.filter { $0.type == .expense }.map(\.id)
        guard !ids.isEmpty else {
            if gen == loadGeneration { spreadTransactionIds = [] }
            return
        }
        if let flagged = try? await installmentRepository.spreadTransactionIds(among: ids),
           gen == loadGeneration {
            spreadTransactionIds = flagged
        }
    }

    // MARK: - Lookups (hydrate chips / summary / rows)

    private func loadLookups() async {
        guard accountsById.isEmpty, categoriesById.isEmpty, tagsById.isEmpty else { return }
        let client = SupabaseService.shared.client

        /// id → name rows for budgets / fixed expenses (web reads the same).
        struct NameRow: Decodable { let id: UUID; let name: String }

        do {
            async let accounts: [Account] = client.from("accounts").select().execute().value
            async let categories: [Category] = client.from("categories").select().execute().value
            async let tags: [Tag] = client.from("tags").select().execute().value
            async let budgets: [NameRow] = client.from("budgets").select("id,name").execute().value
            async let fixed: [NameRow] = client.from("fixed_expenses").select("id,name").execute().value
            accountsById = Dictionary(uniqueKeysWithValues: try await accounts.map { ($0.id, $0) })
            categoriesById = Dictionary(uniqueKeysWithValues: try await categories.map { ($0.id, $0) })
            tagsById = Dictionary(uniqueKeysWithValues: try await tags.map { ($0.id, $0) })
            budgetNamesById = Dictionary(try await budgets.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            fixedNamesById = Dictionary(try await fixed.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        } catch {
            // Non-fatal: chips/rows fall back to ids/placeholders.
        }
    }
}
