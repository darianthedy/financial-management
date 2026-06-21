import Foundation
import Supabase

/// Aggregate read model for the four month-scoped dashboard widgets — Budget
/// Verdict, Accounts, Planned Expenses, Unplanned Expenses (iOS Tech Plan §8.1,
/// System Design §4.6). All sources are fetched in parallel for one `year_month`.
struct DashboardData: Sendable {
    var budgets: [BudgetProgress]           // Verdict banner + Planned budget bars (v_budget_progress)
    var accounts: [DashboardAccount]        // Accounts card
    var fixedExpenses: [FixedExpense]       // Planned fixed expenses for the month
    var paidFixedExpenseIds: Set<UUID>      // derived from linked transactions.fixed_expense_id
    var unplanned: [UnplannedGroup]         // confirmed budget-less / fixed-less expenses, by category
}

/// One account on the dashboard with its balance **as of** the selected month —
/// the latest `account_monthly_balances` row at or before the month (via
/// `fn_account_balances_at`), or `starting_balance` when no ledger row exists.
struct DashboardAccount: Identifiable, Sendable {
    let account: Account
    let balance: Int64
    var id: UUID { account.id }
}

/// Unplanned expenses aggregated client-side by category (null → "Uncategorized").
struct UnplannedGroup: Identifiable, Sendable {
    let categoryId: UUID?
    let categoryName: String
    let total: Int64
    var id: String { categoryId?.uuidString ?? "uncategorized" }
}

actor DashboardRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    /// Fetch every widget's data for `yearMonth` in parallel.
    func load(yearMonth: String) async throws -> DashboardData {
        async let budgets = fetchBudgets(yearMonth: yearMonth)
        async let accounts = fetchAccounts(yearMonth: yearMonth)
        async let fixed = fetchFixedExpenses(yearMonth: yearMonth)
        async let unplanned = fetchUnplanned(yearMonth: yearMonth)

        let (fixedExpenses, paidIds) = try await fixed
        return DashboardData(
            budgets: try await budgets,
            accounts: try await accounts,
            fixedExpenses: fixedExpenses,
            paidFixedExpenseIds: paidIds,
            unplanned: try await unplanned
        )
    }

    // MARK: - Budget Verdict + Planned budgets

    private func fetchBudgets(yearMonth: String) async throws -> [BudgetProgress] {
        try await client
            .from("v_budget_progress")
            .select()
            .eq("year_month", value: yearMonth)
            .order("budget_name")
            .execute()
            .value
    }

    // MARK: - Accounts

    private struct AccountBalanceAt: Decodable {
        let accountId: UUID
        let balance: Int64

        enum CodingKeys: String, CodingKey {
            case accountId = "account_id"
            case balance
        }
    }

    private func fetchAccounts(yearMonth: String) async throws -> [DashboardAccount] {
        async let accountRows: [Account] = client
            .from("accounts")
            .select()
            .eq("is_archived", value: false)
            .eq("show_on_dashboard", value: true)
            .order("created_at")
            .execute()
            .value

        async let balanceRows = balances(asOf: yearMonth)

        let accounts = try await accountRows
        // fn_account_balances_at returns at most one row per account (DISTINCT ON).
        let byAccount = Dictionary(
            uniqueKeysWithValues: (try await balanceRows).map { ($0.accountId, $0.balance) }
        )

        return accounts.map {
            DashboardAccount(account: $0, balance: byAccount[$0.id] ?? $0.startingBalance)
        }
    }

    /// Latest balance at or before `yearMonth`, one row per account.
    private func balances(asOf yearMonth: String) async throws -> [AccountBalanceAt] {
        try await client
            .rpc("fn_account_balances_at", params: ["p_year_month": yearMonth])
            .execute()
            .value
    }

    // MARK: - Planned fixed expenses

    private func fetchFixedExpenses(yearMonth: String) async throws -> ([FixedExpense], Set<UUID>) {
        let expenses: [FixedExpense] = try await client
            .from("fixed_expenses")
            .select()
            .eq("year_month", value: yearMonth)
            .order("name")
            .execute()
            .value

        let paid = try await paidFixedExpenseIds(expenses.map(\.id))
        return (expenses, paid)
    }

    /// The subset of the given fixed-expense ids referenced by at least one
    /// transaction via `fixed_expense_id` — i.e. the paid ones.
    private func paidFixedExpenseIds(_ ids: [UUID]) async throws -> Set<UUID> {
        guard !ids.isEmpty else { return [] }

        struct Row: Decodable { let fixed_expense_id: UUID }

        let rows: [Row] = try await client
            .from("transactions")
            .select("fixed_expense_id")
            .in("fixed_expense_id", values: ids.map(\.uuidString))
            .execute()
            .value

        return Set(rows.map(\.fixed_expense_id))
    }

    // MARK: - Unplanned expenses

    private func fetchUnplanned(yearMonth: String) async throws -> [UnplannedGroup] {
        let startDate = "\(yearMonth)-01"
        let endDate = "\(DateUtils.navigate(yearMonth, by: 1))-01"

        let rows: [Transaction] = try await client
            .from("transactions")
            .select()
            .eq("type", value: TransactionType.expense.rawValue)
            .eq("status", value: TransactionStatus.confirmed.rawValue)
            .gte("date", value: startDate)
            .lt("date", value: endDate)
            .is("budget_id", value: nil)
            .is("fixed_expense_id", value: nil)
            .execute()
            .value

        // Resolve category names client-side; null category → "Uncategorized".
        let categoryIds = Set(rows.compactMap(\.categoryId))
        var nameById: [UUID: String] = [:]
        if !categoryIds.isEmpty {
            let categories: [Category] = try await client
                .from("categories")
                .select()
                .in("id", values: categoryIds.map(\.uuidString))
                .execute()
                .value
            nameById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        }

        return Dictionary(grouping: rows, by: \.categoryId)
            .map { categoryId, txns in
                UnplannedGroup(
                    categoryId: categoryId,
                    categoryName: categoryId.flatMap { nameById[$0] } ?? "Uncategorized",
                    total: txns.reduce(Int64(0)) { $0 + $1.amount }
                )
            }
            .sorted { $0.total > $1.total }
    }
}
