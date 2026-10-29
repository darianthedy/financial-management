#if DEBUG
import Foundation
import Supabase

/// Canned rows for each Supabase table / view / RPC the screens read, built
/// relative to the current month so month-scoped screens always have data.
/// Amounts are IDR (0 decimal places) and deliberately large, so the narrowest
/// layouts (382 pt on the Duo's outer display) see realistic widths.
nonisolated enum FixtureStore {
    static let userId = "0000f1c7-0000-4000-8000-000000000001"
    private static let created = "2026-01-01T00:00:00Z"

    static func rows(for resource: String) -> [[String: Any]] {
        switch resource {
        case "currencies": currencies
        case "user_settings": userSettings
        case "accounts": accounts
        case "rpc/fn_account_balances_at": balances
        case "categories": categories
        case "tags": tags
        case "budgets": budgets
        case "v_budget_progress": budgetProgress
        case "fixed_expenses": fixedExpenses
        case "transactions", "v_transactions": transactions
        case "v_monthly_cashflow": cashflow
        case "scheduled_transactions": scheduled
        default: []
        }
    }

    // MARK: - Months

    // Computed here rather than via DateUtils (main-actor isolated): fixtures
    // are served from URLProtocol's background thread. Same 'YYYY-MM' format.
    static var thisMonth: String { month(0) }
    private static func month(_ offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .month, value: offset, to: Date()) ?? Date()
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 2026, parts.month ?? 1)
    }
    private static func day(_ d: Int, _ offset: Int = 0) -> String {
        "\(month(offset))-\(String(format: "%02d", d))"
    }

    // MARK: - IDs

    private static func id(_ kind: Int, _ n: Int) -> String {
        String(format: "0000f1c7-%04x-4000-8000-%012x", kind, n)
    }

    private enum Kind: Int { case account = 1, category, tag, budget, fixed, txn, scheduled }

    private static func id(_ kind: Kind, _ n: Int) -> String { id(kind.rawValue, n) }

    // MARK: - Reference data

    private static let currencies: [[String: Any]] = [
        ["code": "IDR", "name": "Indonesian Rupiah", "symbol": "Rp", "decimal_places": 0, "created_at": created],
        ["code": "USD", "name": "US Dollar", "symbol": "$", "decimal_places": 2, "created_at": created],
    ]

    private static var userSettings: [[String: Any]] {
        [[
            "user_id": userId, "default_currency": "IDR", "default_account_id": id(.account, 1),
            "created_at": created, "updated_at": created,
        ]]
    }

    private static var accounts: [[String: Any]] {
        [
            (1, "BCA Tahapan", "bank_account", 18_250_000),
            (2, "Jenius", "digital_wallet", 4_730_500),
            (3, "BCA Credit Card", "credit_card", 0),
            (4, "Cash", "cash", 650_000),
        ].map { n, name, type, start in
            [
                "id": id(.account, n), "user_id": userId, "name": name, "type": type,
                "starting_balance": start, "image_url": NSNull(), "is_archived": false,
                "show_on_dashboard": true, "created_at": created, "updated_at": created,
            ]
        }
    }

    private static var balances: [[String: Any]] {
        [(1, 21_480_250), (2, 3_915_000), (3, -2_340_750), (4, 412_000)].map {
            ["account_id": id(.account, $0.0), "balance": $0.1]
        }
    }

    private static var categories: [[String: Any]] {
        [
            (1, "Food & Drinks", "🍜", "#f97316"), (2, "Transport", "🚗", "#3b82f6"),
            (3, "Shopping", "🛍️", "#ec4899"), (4, "Health", "💊", "#22c55e"),
            (5, "Entertainment", "🎬", "#a855f7"), (6, "Salary", "💼", "#14b8a6"),
        ].map { n, name, icon, color in
            ["id": id(.category, n), "user_id": userId, "name": name, "icon": icon, "color": color, "created_at": created]
        }
    }

    private static var tags: [[String: Any]] {
        ["Vacation", "Work", "Gifts", "Kids", "Home", "Subscriptions"].enumerated().map { i, name in
            ["id": id(.tag, i + 1), "user_id": userId, "name": name, "created_at": created]
        }
    }

    // MARK: - Plan

    private static let budgetSpecs: [(Int, String, Int, Int)] = [
        // n, name, periodic, spent this month
        (1, "Groceries", 3_000_000, 2_145_300),
        (2, "Dining Out", 1_500_000, 1_682_000), // over budget
        (3, "Transport", 800_000, 310_500),
    ]

    private static var budgets: [[String: Any]] {
        budgetSpecs.map { n, name, periodic, _ in
            [
                "id": id(.budget, n), "user_id": userId, "name": name, "year_month": thisMonth,
                "periodic_amount": periodic, "description": NSNull(),
                "created_at": created, "updated_at": created,
            ]
        }
    }

    private static var budgetProgress: [[String: Any]] {
        budgetSpecs.map { n, name, periodic, spent in
            [
                "budget_id": id(.budget, n), "user_id": userId, "budget_name": name,
                "year_month": thisMonth, "periodic_amount": periodic, "carry_over_amount": 0,
                "effective_amount": periodic, "spent": spent, "remaining": periodic - spent,
                "reserved": 0, "description": NSNull(),
            ]
        }
    }

    private static var fixedExpenses: [[String: Any]] {
        [(1, "Rent", 6_500_000), (2, "Internet", 389_000), (3, "Phone Plan", 150_000)].map { n, name, amount in
            [
                "id": id(.fixed, n), "user_id": userId, "name": name, "year_month": thisMonth,
                "amount": amount, "is_active": true, "created_at": created, "updated_at": created,
            ]
        }
    }

    // MARK: - Transactions

    private static var transactions: [[String: Any]] {
        // n, day, type, amount, account, category, budget, fixed, description
        let specs: [(Int, Int, String, Int, Int, Int?, Int?, Int?, String)] = [
            (1, 1, "income", 25_000_000, 1, 6, nil, nil, "Salary"),
            (2, 2, "expense", 6_500_000, 1, nil, nil, 1, "Rent"),
            (3, 3, "expense", 389_000, 1, nil, nil, 2, "IndiHome"),
            (4, 4, "expense", 845_300, 2, 1, 1, nil, "Supermarket"),
            (5, 5, "expense", 1_300_000, 2, 1, 1, nil, "Weekly groceries"),
            (6, 6, "expense", 1_682_000, 3, 1, 2, nil, "Dinner with friends"),
            (7, 7, "expense", 310_500, 2, 2, 3, nil, "Gojek"),
            (8, 8, "expense", 1_249_000, 3, 3, nil, nil, "Running shoes"),
            (9, 9, "expense", 275_000, 4, 4, nil, nil, "Pharmacy"),
            (10, 10, "expense", 120_000, 2, 5, nil, nil, "Cinema"),
            (11, 11, "expense", 58_500, 4, nil, nil, nil, "Parking"),
            (12, 12, "transfer", 2_000_000, 1, nil, nil, nil, "Top up Jenius"),
        ]
        let current = specs.map { n, d, type, amount, account, category, budget, fixed, text in
            transaction(
                n: n, date: day(d), type: type, amount: amount, account: account,
                category: category, budget: budget, fixed: fixed, text: text,
                transferTo: type == "transfer" ? 2 : nil
            )
        }
        // A little unplanned spend in each earlier month, for the trend's stack.
        let earlier = (1...5).map { back in
            transaction(
                n: 100 + back, date: day(15, -back), type: "expense", amount: 400_000 + back * 85_000,
                account: 2, category: 3, budget: nil, fixed: nil, text: "Shopping", transferTo: nil
            )
        }
        return current + earlier
    }

    private static func transaction(
        n: Int, date: String, type: String, amount: Int, account: Int, category: Int?,
        budget: Int?, fixed: Int?, text: String, transferTo: Int?
    ) -> [String: Any] {
        [
            "id": id(.txn, n), "user_id": userId, "account_id": id(.account, account),
            "type": type, "status": "confirmed", "amount": amount, "description": text, "date": date,
            "transfer_account_id": transferTo.map { id(.account, $0) } ?? NSNull(),
            "budget_id": budget.map { id(.budget, $0) } ?? NSNull(),
            "category_id": category.map { id(.category, $0) } ?? NSNull(),
            "scheduled_txn_id": NSNull(),
            "fixed_expense_id": fixed.map { id(.fixed, $0) } ?? NSNull(),
            "tag_ids": n == 6 ? [id(.tag, 3)] : [],
            "created_at": created, "updated_at": created,
        ]
    }

    /// Recurring schedules: two active, one paused (Scheduled, D2.6).
    private static var scheduled: [[String: Any]] {
        let specs: [(Int, String, Int, Int, Int?, String?, String, Bool)] = [
            (1, "income", 25_000_000, 1, 6, nil, "Salary", true),
            (2, "expense", 389_000, 1, nil, "Internet", "IndiHome", true),
            (3, "expense", 189_000, 2, 5, nil, "Streaming", false),
        ]
        return specs.map { n, type, amount, account, category, fixed, text, active in
            [
                "id": id(.scheduled, n), "user_id": userId, "account_id": id(.account, account),
                "type": type, "amount": amount, "description": text, "recurrence": "monthly",
                "next_due_date": day(25, 1), "is_active": active,
                "category_id": category.map { id(.category, $0) } ?? NSNull(),
                "budget_name": NSNull(), "fixed_expense_name": fixed ?? NSNull(),
                "created_at": created, "updated_at": created,
            ]
        }
    }

    private static var cashflow: [[String: Any]] {
        (0..<6).map { back in
            let income = 25_000_000 - (back % 2) * 1_250_000
            let expense = back == 0 ? 12_749_300 : 14_100_000 + back * 610_000
            return [
                "year_month": month(-back), "total_income": income,
                "total_expense": expense, "net": income - expense,
            ]
        }
    }

    // MARK: - Auth

    /// A non-expiring fake JWT. Nothing verifies its signature.
    private static var accessToken: String {
        func b64(_ s: String) -> String {
            Data(s.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = #"{"alg":"HS256","typ":"JWT"}"#
        let payload = #"{"sub":"\#(userId)","role":"authenticated","aud":"authenticated","exp":4102444800}"#
        return "\(b64(header)).\(b64(payload)).fixture"
    }

    static var user: [String: Any] {
        [
            "id": userId, "aud": "authenticated", "role": "authenticated",
            "email": "duo@fixtures.invalid", "app_metadata": ["provider": "email"],
            "user_metadata": [:] as [String: Any], "created_at": created, "updated_at": created,
        ]
    }

    static var session: [String: Any] {
        [
            "access_token": accessToken, "token_type": "bearer", "expires_in": 3600 * 24 * 365,
            "expires_at": 4_102_444_800, "refresh_token": "fixture-refresh", "user": user,
        ]
    }
}

/// Auth storage holding the fixture session, so the app starts signed in
/// without touching the keychain. Sign-out removes it for the process.
nonisolated final class FixtureAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    private var removed: Set<String> = []

    func store(key: String, value: Data) throws {
        lock.withLock {
            values[key] = value
            removed.remove(key)
        }
    }

    func retrieve(key: String) throws -> Data? {
        lock.withLock {
            if let value = values[key] { return value }
            if removed.contains(key) { return nil }
            return try? JSONSerialization.data(withJSONObject: FixtureStore.session)
        }
    }

    func remove(key: String) throws {
        lock.withLock {
            values[key] = nil
            removed.insert(key)
        }
    }
}
#endif
