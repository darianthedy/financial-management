# Financial Management — Technical Plan: iOS (Swift / SwiftUI)

> Native iOS app using Swift, SwiftUI, and the Supabase Swift SDK.
>
> This plan is the iOS counterpart to the **Web** tech plan and shares the same backend, schema, and feature set. Where the two differ it is only in platform idiom (SwiftUI vs. React); the data model, queries, and business rules are identical and are defined canonically in the **System Design** doc.

---

## 1. Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Xcode | >= 16 | IDE, compiler, simulator, Instruments |
| macOS | >= 14 (Sonoma) | Required by Xcode 16 |
| Swift | >= 5.10 (bundled) | Language |
| iOS deployment target | 17.0+ | SwiftUI features (Observable macro, NavigationStack) |
| Supabase CLI | >= 1.x | Local Supabase for development |
| CocoaPods or SPM | SPM preferred | Dependency management |

---

## 2. Project Setup

### 2.1 Create the Project

1. Open Xcode → **File → New → Project**.
2. Choose **App** (iOS).
3. Settings:
   - Product Name: `FinancialManagement`
   - Team: your Apple Developer team
   - Organization Identifier: `com.yourname.finman`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we use Supabase, not Core Data)
4. Create the project.

### 2.2 Add Dependencies (Swift Package Manager)

In Xcode: **File → Add Package Dependencies**, then add:

| Package | URL | Purpose |
|---|---|---|
| Supabase Swift | `https://github.com/supabase/supabase-swift` | Supabase client (Auth, PostgREST, Realtime, Storage) |
| SwiftUI Charts | Built-in (iOS 16+) | Dashboard charts / progress visuals |
| PhotosUI | Built-in (iOS 16+) | Account avatar image picking (`PhotosPicker`) |
| KeychainAccess | `https://github.com/kishikawakatsumi/KeychainAccess` | Secure token storage |

The Supabase Swift package includes all sub-libraries: `Auth`, `PostgREST`, `Realtime`, `Storage`, `Functions`. `Storage` is used in P0 for account avatar images (see §8.2 and System Design §4.10).

### 2.3 Environment Configuration

Create a configuration file that is **not committed to git**. Use an Xcode Configuration Settings file (`.xcconfig`):

**`Config/Dev.xcconfig`**

```
SUPABASE_URL = http:/$()/127.0.0.1:54321
SUPABASE_ANON_KEY = <local-anon-key>
```

**`Config/Prod.xcconfig`**

```
SUPABASE_URL = https:/$()/xxx.supabase.co
SUPABASE_ANON_KEY = <prod-anon-key>
```

Reference in `Info.plist`:

```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
```

Read at runtime:

```swift
enum AppConfig {
    static let supabaseURL = URL(string: Bundle.main.infoDictionary!["SUPABASE_URL"] as! String)!
    static let supabaseAnonKey = Bundle.main.infoDictionary!["SUPABASE_ANON_KEY"] as! String
}
```

Add `Config/*.xcconfig` to `.gitignore`.

---

## 3. Project Structure

```
FinancialManagement/
├── App/
│   ├── FinancialManagementApp.swift       # @main, Supabase init, root view
│   └── AppState.swift                     # Global app state (auth + currency/settings)
├── Config/
│   ├── Dev.xcconfig                       # Local env (git-ignored)
│   └── Prod.xcconfig                      # Production env (git-ignored)
├── Models/
│   ├── Account.swift
│   ├── AccountMonthlyBalance.swift
│   ├── Transaction.swift
│   ├── Category.swift
│   ├── Tag.swift
│   ├── Budget.swift                   # Flat self-contained monthly budget row
│   ├── BudgetProgress.swift           # Read model for v_budget_progress (carry-over computed live)
│   ├── FixedExpense.swift
│   ├── ScheduledTransaction.swift
│   ├── BudgetInstallment.swift        # P1: virtual installment header + allocation grid
│   ├── Currency.swift                 # ISO 4217 reference data from DB
│   ├── UserSettings.swift             # default_currency + default_account_id preferences
│   └── Enums.swift                        # AccountType, TransactionType, etc.
├── Repositories/
│   ├── AccountRepository.swift
│   ├── TransactionRepository.swift        # List (paginated), filters, summary
│   ├── BudgetRepository.swift             # budgets table + v_budget_progress
│   ├── FixedExpenseRepository.swift
│   ├── ScheduledTransactionRepository.swift
│   ├── InstallmentRepository.swift        # P1: spread_existing_transaction, cancel
│   ├── CurrencyRepository.swift           # Currencies + user settings (currency + default account)
│   └── DashboardRepository.swift
├── Services/
│   ├── SupabaseService.swift              # Singleton Supabase client
│   ├── RealtimeService.swift              # Manages Realtime subscriptions
│   ├── AccountImageService.swift          # Resize→WebP upload + best-effort delete (account-images bucket)
│   └── NotificationService.swift          # UNUserNotificationCenter wrapper
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── DashboardViewModel.swift
│   ├── AccountListViewModel.swift
│   ├── AccountDetailViewModel.swift
│   ├── TransactionListViewModel.swift     # Holds TransactionFilters + pager
│   ├── TransactionFormViewModel.swift
│   ├── BudgetListViewModel.swift
│   ├── FixedExpenseListViewModel.swift
│   ├── ScheduledTransactionViewModel.swift
│   └── SettingsViewModel.swift            # Manages default currency + default account
├── Views/
│   ├── Auth/
│   │   └── LoginView.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── BudgetVerdictBanner.swift       # "Am I overspending?" banner
│   │   ├── AccountsCard.swift              # Per-account end-of-month balance + total
│   │   ├── PlannedExpensesCard.swift       # Budgets (pace bars) + fixed expenses (paid/unpaid)
│   │   └── UnplannedExpensesCard.swift     # Confirmed spend with no budget/fixed, by category
│   ├── Accounts/
│   │   ├── AccountListView.swift
│   │   ├── AccountDetailView.swift
│   │   ├── AccountCard.swift
│   │   ├── AccountAvatar.swift             # Uploaded image, else type-based icon
│   │   └── AccountFormSheet.swift          # Avatar upload/remove, show-on-dashboard, default toggle
│   ├── Transactions/
│   │   ├── TransactionListView.swift
│   │   ├── TransactionRow.swift
│   │   ├── TransactionFormView.swift
│   │   ├── TransactionFilterSheet.swift    # Multi-select facets, chips, clear all
│   │   └── TransactionSummarySheet.swift   # Totals + breakdowns over the filtered set
│   ├── Budgets/
│   │   ├── BudgetListView.swift
│   │   ├── BudgetCard.swift            # Effective amount, carry-in badge, reserved line
│   │   ├── BudgetFormSheet.swift       # Name, monthly amount, note (NO carry-over toggle)
│   │   └── ActiveInstallmentsSection.swift # P1: installments reserving in the shown month
│   ├── FixedExpenses/
│   │   ├── FixedExpenseListView.swift
│   │   ├── FixedExpenseRow.swift
│   │   ├── FixedExpenseFormSheet.swift
│   │   └── FixedExpenseEditSheet.swift
│   ├── Scheduled/
│   │   ├── ScheduledListView.swift
│   │   └── PendingTransactionRow.swift
│   ├── Settings/
│   │   ├── SettingsView.swift             # Default currency + default account
│   │   └── CurrencyPickerView.swift       # Searchable list from currencies table
│   ├── More/
│   │   └── MoreView.swift                  # Groups Fixed Expenses, Scheduled, Settings
│   └── Shared/
│       ├── MonthNavigator.swift
│       ├── CurrencyField.swift
│       ├── CategoryPicker.swift           # Single-select (at most one)
│       ├── TagPicker.swift                # Multi-select
│       ├── AccountPicker.swift
│       ├── BudgetPicker.swift             # Budget picker for income/expense transactions
│       ├── FixedExpensePicker.swift       # Fixed expense picker for expense transactions
│       ├── MultiSelectFacet.swift         # Reusable tri-state multi-select (filters)
│       ├── EmptyStateView.swift
│       └── ContentRootView.swift          # TabView with navigation stacks
├── Utilities/
│   ├── CurrencyUtils.swift
│   ├── DateUtils.swift
│   ├── TransactionFilters.swift           # Filter model + serialization
│   └── Extensions/
│       ├── Date+YearMonth.swift
│       └── Int+Currency.swift
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

> **Single-currency note:** there is no `CurrencyPicker` on transaction/account/budget forms. The app is single-currency — the default currency is chosen once in Settings and applied everywhere. `CurrencyPickerView` exists **only** in Settings (to choose the default) and is backed by the `currencies` table.

---

## 4. Supabase Client Setup

### 4.1 Supabase Service (`Services/SupabaseService.swift`)

```swift
import Supabase

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }
}
```

### 4.2 App Entry Point (`App/FinancialManagementApp.swift`)

```swift
import SwiftUI

@main
struct FinancialManagementApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    ContentRootView()
                } else {
                    LoginView()
                }
            }
            .environment(appState)
            .task {
                await appState.observeAuthState()
            }
        }
    }
}
```

### 4.3 App State (`App/AppState.swift`)

`AppState` holds auth status plus the single-currency context (the default currency, its decimal places, and the full currencies list) that every formatter and form reads.

```swift
import Observation
import Supabase

@Observable
@MainActor
final class AppState {
    var isAuthenticated = false
    var currentUser: User?

    // Single-currency context, loaded once after sign-in.
    var defaultCurrency = "USD"
    var defaultAccountId: UUID?
    var currencies: [Currency] = []

    /// decimal_places for the active default currency (drives minor-unit scaling).
    var decimalPlaces: Int {
        currencies.first { $0.code == defaultCurrency }?.decimalPlaces ?? 2
    }

    private let supabase = SupabaseService.shared.client
    private let currencyRepo = CurrencyRepository()

    func observeAuthState() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed:
                if let session {
                    isAuthenticated = true
                    currentUser = session.user
                    await loadCurrencyData()
                } else {
                    isAuthenticated = false
                    currentUser = nil
                }
            case .signedOut:
                isAuthenticated = false
                currentUser = nil
                defaultCurrency = "USD"
                defaultAccountId = nil
                currencies = []
            default:
                break
            }
        }
    }

    func loadCurrencyData() async {
        currencies = (try? await currencyRepo.getAllCurrencies()) ?? []
        if let settings = try? await currencyRepo.getUserSettings() {
            defaultCurrency = settings.defaultCurrency
            defaultAccountId = settings.defaultAccountId
        }
    }
}
```

---

## 5. Data Layer

> All monetary amounts are stored as `bigint` minor units (`Int64` in Swift). The app is **single-currency**: there is **no per-record `currency` column** on accounts, transactions, budgets, fixed expenses, or scheduled transactions — formatting uses `AppState.defaultCurrency` and its `decimal_places`. See System Design §4.7.

### 5.1 Account Models (`Models/Account.swift`, `Models/AccountMonthlyBalance.swift`)

```swift
import Foundation

struct Account: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var type: AccountType
    var startingBalance: Int64
    var imageUrl: String?          // public URL of the avatar in Supabase Storage (nullable)
    var isArchived: Bool
    var showOnDashboard: Bool       // hide from the dashboard Accounts card without archiving
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, type
        case startingBalance = "starting_balance"
        case imageUrl = "image_url"
        case isArchived = "is_archived"
        case showOnDashboard = "show_on_dashboard"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AccountMonthlyBalance: Codable, Sendable {
    let accountId: UUID
    let yearMonth: String
    var balance: Int64
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case yearMonth = "year_month"
        case balance
        case updatedAt = "updated_at"
    }
}

enum AccountType: String, Codable, CaseIterable {
    case bankAccount = "bank_account"
    case creditCard = "credit_card"
    case digitalWallet = "digital_wallet"
    case cash
    case other

    /// SF Symbol used when the account has no custom image.
    var defaultIcon: String {
        switch self {
        case .bankAccount:   return "building.columns"
        case .creditCard:    return "creditcard"
        case .digitalWallet: return "wallet.pass"
        case .cash:          return "banknote"
        case .other:         return "circle.grid.2x2"
        }
    }
}
```

> The **current balance** is never stored on the account. It is computed from `starting_balance` + confirmed transactions and materialized in `account_monthly_balances` (one row per account per month). Read it from the latest ledger row, or — for a specific month on the dashboard — via the `fn_account_balances_at(p_year_month)` RPC. See System Design §4.3 / §4.6.

### 5.2 Budget Models (`Models/Budget.swift`, `Models/BudgetProgress.swift`)

A budget is **one self-contained row for one month** (identity = `name`). There is **no separate periods table, no stored carry-over, and no `enable_carry_over` toggle** — carry-over is **always on** and computed live in `v_budget_progress` by chaining each `(user_id, name)` lineage across consecutive months. See requirements → "Budgets / Carry-over" and System Design §4.1–4.2.

```swift
struct Budget: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var yearMonth: String          // 'YYYY-MM' — the month this entry applies to
    var periodicAmount: Int64      // minor units; the limit set for this month
    var description: String?       // optional free-text note
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case yearMonth = "year_month"
        case periodicAmount = "periodic_amount"
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Read model for the `v_budget_progress` view. Carry-over, spent, remaining, and
/// (P1) reserved are all computed in SQL — never stored. Clients read this for
/// progress bars, badges, the budget picker, and the budget filter.
struct BudgetProgress: Codable, Identifiable, Sendable {
    let budgetId: UUID
    let userId: UUID
    let budgetName: String
    let yearMonth: String
    let periodicAmount: Int64
    let carryOverAmount: Int64      // carry_in from the previous month in this lineage (0 on a gap)
    let effectiveAmount: Int64      // periodic + carry_in
    let spent: Int64                // NET of linked confirmed txns: expenses − income
    let remaining: Int64            // effective − spent − reserved (can be negative)
    let reserved: Int64             // P1: sum of virtual-installment reservations for this month

    var id: UUID { budgetId }

    enum CodingKeys: String, CodingKey {
        case budgetId = "budget_id"
        case userId = "user_id"
        case budgetName = "budget_name"
        case yearMonth = "year_month"
        case periodicAmount = "periodic_amount"
        case carryOverAmount = "carry_over_amount"
        case effectiveAmount = "effective_amount"
        case spent
        case remaining
        case reserved
    }
}
```

> **Why two types?** `Budget` maps the raw `budgets` table (used for create/edit/copy/remove). `BudgetProgress` maps the `v_budget_progress` view (used for everything that displays numbers). They are always read from the view — never recompute carry-over on the client.

### 5.3 Transaction Model (`Models/Transaction.swift`)

```swift
struct Transaction: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let accountId: UUID
    var type: TransactionType
    var status: TransactionStatus
    var amount: Int64
    var description: String?
    var transactionDate: Date
    var transferAccountId: UUID?
    var budgetId: UUID?
    var categoryId: UUID?
    var scheduledTxnId: UUID?
    var fixedExpenseId: UUID?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case accountId = "account_id"
        case type, status, amount
        case description
        case transactionDate = "date"
        case transferAccountId = "transfer_account_id"
        case budgetId = "budget_id"
        case categoryId = "category_id"
        case scheduledTxnId = "scheduled_txn_id"
        case fixedExpenseId = "fixed_expense_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

> **Column name mapping & relationships:**
> - `transactionDate` maps to `date` (not `transaction_date`).
> - `transferAccountId` maps to `transfer_account_id` (not `to_account_id`). Required when `type == .transfer`, and must be `nil` otherwise.
> - `budgetId` maps to `budget_id` — a **direct FK to `budgets`** (a single budget per transaction). There is **no** `budget_period_id`.
> - `categoryId` maps to `category_id` — a **single category per transaction**, stored directly on the row. There is **no `transaction_categories` junction**; only **tags** are many-to-many (`transaction_tags`).
> - `fixedExpenseId` optionally links the transaction to a fixed expense to indicate payment.

**Amount sign rules** (enforced in the form and by the DB `transactions_amount_check`): income and expenses **may be negative** (e.g. a refund recorded as a negative expense, which adds cash back and reduces the expense/category/budget totals). **Transfers must be positive** (reverse one by swapping its accounts). A **zero amount is never allowed** for any type.

#### Transaction Form Fields

The "Add/Edit Transaction" form (`TransactionFormView.swift`) includes:

| Field | Type | Visibility |
|---|---|---|
| Type | Segmented picker (income / expense / transfer) | Always |
| Amount | Currency text field (negative allowed for income/expense; transfers forced positive; zero rejected) | Always |
| Account | Account picker (defaults to the user's default account) | Always |
| To Account | Account picker | Only when type = `transfer` |
| Category | Category picker — single-select, at most one (`CategoryPicker`) | income / expense |
| Tags | Tag multi-select (`TagPicker`) | Always |
| Budget | Budget picker (`BudgetPicker`) | income / expense (hidden for transfer) |
| Fixed Expense | Fixed expense picker (`FixedExpensePicker`) | expense only |
| Description | Text field (optional) | Always |
| Date | Date picker | Always |

There is **no currency field** — the app is single-currency.

The **Budget picker** (`Views/Shared/BudgetPicker.swift`) loads `v_budget_progress` rows for the month matching the transaction's date. Each option shows the budget name and its **effective amount** (periodic + carry-in). The selection is stored as `budgetId`. It offers an inline "create a budget for this month" option when none exists. The selection is cleared before saving when the type is `transfer`.

The **Fixed Expense picker** (`Views/Shared/FixedExpensePicker.swift`) loads `fixed_expenses` for the month matching the transaction's date. Each option shows the expense name and amount. The selection is stored as `fixedExpenseId`; this link is what marks the fixed expense **paid** (a fixed expense is paid when at least one transaction references it). The selection is cleared before saving when the type is not `expense`.

### 5.4 Currency and UserSettings Models (`Models/Currency.swift`, `Models/UserSettings.swift`)

```swift
struct Currency: Codable, Identifiable, Sendable {
    let code: String
    let name: String
    let symbol: String
    let decimalPlaces: Int
    let createdAt: Date

    var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code, name, symbol
        case decimalPlaces = "decimal_places"
        case createdAt = "created_at"
    }
}

struct UserSettings: Codable, Sendable {
    let userId: UUID
    var defaultCurrency: String
    var defaultAccountId: UUID?     // pre-selected when adding a new transaction
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case defaultCurrency = "default_currency"
        case defaultAccountId = "default_account_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

> The **default account** is stored on `user_settings.default_account_id` (mirroring the Web plan §7.2), not on the account row. Only one account is the default at a time. The `currencies` table is the single source of supported ISO 4217 codes — never hardcode a currency list.

### 5.5 Category, Tag, ScheduledTransaction, and Enum Models

**`Models/Enums.swift`** — DB-aligned enums:

```swift
enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
    case transfer
}

enum TransactionStatus: String, Codable, CaseIterable {
    case confirmed
    case pending
    case dismissed
}

enum RecurrenceType: String, Codable, CaseIterable {
    case monthly
    // P1: weekly, quarterly, yearly, custom
}
```

**`Models/Category.swift`:**

```swift
struct Category: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var icon: String?
    var color: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, icon, color
        case createdAt = "created_at"
    }
}
```

> The `categories` table has `color` (not `type`). A transaction references **at most one** category directly via `transactions.category_id` — there is no junction table for categories.

**`Models/Tag.swift`** maps `tags` (`id`, `user_id`, `name`). The transaction ↔ tag link is the many-to-many `transaction_tags(transaction_id, tag_id)` junction.

**`Models/ScheduledTransaction.swift`:**

```swift
struct ScheduledTransaction: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var accountId: UUID
    var type: TransactionType
    var amount: Int64
    var description: String?
    var recurrence: RecurrenceType
    var nextDueDate: Date
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case accountId = "account_id"
        case type, amount
        case description, recurrence
        case nextDueDate = "next_due_date"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

> The column is `recurrence` (not `recurrence_interval`) and `next_due_date` (not `next_occurrence`). There is no separate `pending_transactions` table — pending transactions are rows in `transactions` where `status = 'pending'`.

### 5.6 Fixed Expense Model (`Models/FixedExpense.swift`)

```swift
struct FixedExpense: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var yearMonth: String
    var amount: Int64
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case yearMonth = "year_month"
        case amount
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

> Each row represents one fixed expense for one specific month. There is no separate periods table and **no per-row currency**. There is no `isPaid` column — paid status is derived from whether any transaction references this fixed expense via `fixed_expense_id`.

#### Fixed Expense Operations

**Copy from Previous Month:** Queries `fixed_expenses` for `year_month = previousMonth` and `user_id = currentUser`, then inserts new rows with `year_month = currentMonth`, preserving `name`, `amount`, and `is_active`. Skips entries whose name already exists (UNIQUE constraint on `user_id, name, year_month`).

**Edit Fixed Expense:** Opens `FixedExpenseEditSheet` to update `name` or `amount` on an existing row. Only edits the specific month's entry — other months are unaffected.

**Delete Fixed Expense:** Deletes the `fixed_expenses` row for that month. Any transactions that referenced it have their `fixed_expense_id` set to NULL via `ON DELETE SET NULL`.

### 5.7 Budget Installment Models (P1) (`Models/BudgetInstallment.swift`)

P1 "virtual installments" (see requirements → "Budget Installments / Virtual Installments" and System Design §4.11). Reservations are **budget-side only** — they never enter `transactions` and never affect account balances.

```swift
struct BudgetInstallment: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let sourceTransactionId: UUID
    var totalAmount: Int64          // = the source expense amount
    var description: String?
    var startYearMonth: String
    var months: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sourceTransactionId = "source_transaction_id"
        case totalAmount = "total_amount"
        case description
        case startYearMonth = "start_year_month"
        case months
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// One row per non-zero grid cell. Targets a budget LINEAGE by name, not a budget id.
struct BudgetInstallmentAllocation: Codable, Identifiable, Sendable {
    let id: UUID
    let installmentId: UUID
    let userId: UUID
    var budgetName: String
    var yearMonth: String
    var amount: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case installmentId = "installment_id"
        case userId = "user_id"
        case budgetName = "budget_name"
        case yearMonth = "year_month"
        case amount
    }
}
```

### 5.8 Repository Example (`Repositories/AccountRepository.swift`)

```swift
import Supabase

actor AccountRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getAll() async throws -> [Account] {
        try await client
            .from("accounts")
            .select()
            .eq("is_archived", value: false)
            .order("created_at")
            .execute()
            .value
    }

    func create(name: String, type: AccountType, startingBalance: Int64,
                imageUrl: String?, showOnDashboard: Bool) async throws -> Account {
        let userId = try await client.auth.session.user.id

        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let type: AccountType
            let starting_balance: Int64
            let image_url: String?
            let show_on_dashboard: Bool
        }

        let account: Account = try await client
            .from("accounts")
            .insert(Insert(
                user_id: userId,
                name: name,
                type: type,
                starting_balance: startingBalance,
                image_url: imageUrl,
                show_on_dashboard: showOnDashboard
            ))
            .select()
            .single()
            .execute()
            .value

        // Seed the current month's balance row with the starting balance.
        let yearMonth = DateUtils.currentYearMonth()
        try await client
            .from("account_monthly_balances")
            .insert([
                "account_id": AnyJSON.string(account.id.uuidString),
                "year_month": AnyJSON.string(yearMonth),
                "balance": AnyJSON.integer(Int(startingBalance))
            ])
            .execute()

        return account
    }

    /// Current balance = latest ledger row for the account.
    func getCurrentBalance(accountId: UUID) async throws -> Int64 {
        let row: AccountMonthlyBalance = try await client
            .from("account_monthly_balances")
            .select()
            .eq("account_id", value: accountId)
            .order("year_month", ascending: false)
            .limit(1)
            .single()
            .execute()
            .value
        return row.balance
    }

    func update(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client.from("accounts").update(fields).eq("id", value: id).execute()
    }

    func archive(id: UUID) async throws {
        try await client.from("accounts").update(["is_archived": true]).eq("id", value: id).execute()
    }
}
```

### 5.9 Budget Repository (`Repositories/BudgetRepository.swift`)

Reads numbers from the view, writes to the table.

```swift
actor BudgetRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient = SupabaseService.shared.client) { self.client = client }

    /// Progress rows (effective/spent/remaining/carry-in/reserved) for one month.
    func progress(yearMonth: String) async throws -> [BudgetProgress] {
        try await client
            .from("v_budget_progress")
            .select()
            .eq("year_month", value: yearMonth)
            .order("budget_name")
            .execute()
            .value
    }

    func add(name: String, yearMonth: String, periodicAmount: Int64, note: String?) async throws {
        let userId = try await client.auth.session.user.id
        struct Insert: Encodable {
            let user_id: UUID; let name: String; let year_month: String
            let periodic_amount: Int64; let description: String?
        }
        try await client.from("budgets")
            .insert(Insert(user_id: userId, name: name, year_month: yearMonth,
                           periodic_amount: periodicAmount, description: note))
            .execute()
    }

    /// Copy from previous month: duplicate M-1 rows into M (name, note, periodic_amount),
    /// skipping names already present in M.
    func copyFromPreviousMonth(into yearMonth: String) async throws { /* … */ }

    func update(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client.from("budgets").update(fields).eq("id", value: id).execute()
    }

    /// "Remove" a budget for a month = delete that month's row (a deliberate gap
    /// resets that lineage's carry-over to 0).
    func remove(id: UUID) async throws {
        try await client.from("budgets").delete().eq("id", value: id).execute()
    }
}
```

### 5.10 Currency Repository (`Repositories/CurrencyRepository.swift`)

```swift
import Supabase

actor CurrencyRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient = SupabaseService.shared.client) { self.client = client }

    func getAllCurrencies() async throws -> [Currency] {
        try await client.from("currencies").select().order("code").execute().value
    }

    func getUserSettings() async throws -> UserSettings? {
        let userId = try await client.auth.session.user.id
        return try? await client
            .from("user_settings")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
    }

    func upsertDefaultCurrency(_ currencyCode: String) async throws -> UserSettings {
        let userId = try await client.auth.session.user.id
        struct Upsert: Encodable { let user_id: UUID; let default_currency: String }
        return try await client.from("user_settings")
            .upsert(Upsert(user_id: userId, default_currency: currencyCode))
            .select().single().execute().value
    }

    func updateDefaultAccountId(_ accountId: UUID?) async throws -> UserSettings {
        let userId = try await client.auth.session.user.id
        struct Upsert: Encodable { let user_id: UUID; let default_account_id: UUID? }
        return try await client.from("user_settings")
            .upsert(Upsert(user_id: userId, default_account_id: accountId))
            .select().single().execute().value
    }
}
```

### 5.11 ViewModel Example (`ViewModels/AccountListViewModel.swift`)

```swift
import Observation
import Supabase

@Observable
@MainActor
final class AccountListViewModel {
    var accounts: [Account] = []
    var isLoading = false
    var errorMessage: String?

    private let repository = AccountRepository()
    private let supabase = SupabaseService.shared.client
    private var realtimeChannel: RealtimeChannelV2?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            accounts = try await repository.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func subscribeToChanges() async {
        let channel = supabase.realtimeV2.channel("accounts-realtime")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "accounts")
        await channel.subscribe()
        Task {
            for await _ in changes { await load() }
        }
        realtimeChannel = channel
    }

    func unsubscribe() async {
        if let channel = realtimeChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
    }
}
```

---

## 6. Navigation (`Views/Shared/ContentRootView.swift`)

```swift
import SwiftUI

struct ContentRootView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Dashboard", systemImage: "chart.pie") }

            NavigationStack { AccountListView() }
                .tabItem { Label("Accounts", systemImage: "creditcard") }

            NavigationStack { TransactionListView() }
                .tabItem { Label("Transactions", systemImage: "list.bullet") }

            NavigationStack { BudgetListView() }
                .tabItem { Label("Budgets", systemImage: "target") }

            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}
```

The **More** tab (`Views/More/MoreView.swift`) groups: Fixed Expenses, Scheduled Transactions, and Settings.

---

## 7. Shared Utilities

### 7.1 Currency (`Utilities/CurrencyUtils.swift`)

```swift
import Foundation

enum CurrencyUtils {
    static func toMinorUnits(_ amount: Double, decimalPlaces: Int = 2) -> Int64 {
        let factor = pow(10.0, Double(decimalPlaces))
        return Int64((amount * factor).rounded())
    }

    static func toDisplayAmount(_ minorUnits: Int64, decimalPlaces: Int = 2) -> Double {
        let factor = pow(10.0, Double(decimalPlaces))
        return Double(minorUnits) / factor
    }

    static func format(_ minorUnits: Int64, currency: String = "USD", decimalPlaces: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        return formatter.string(from: NSNumber(value: toDisplayAmount(minorUnits, decimalPlaces: decimalPlaces))) ?? "$0.00"
    }
}
```

> Pass the active `currency`/`decimalPlaces` from `AppState` (single-currency). A small `View` helper or environment value can wrap `format` so call sites don't repeat the lookup.

### 7.2 Year-Month (`Utilities/DateUtils.swift`)

```swift
import Foundation

enum DateUtils {
    private static let yearMonthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    static func currentYearMonth() -> String { yearMonthFormatter.string(from: Date()) }

    static func navigate(_ yearMonth: String, by months: Int) -> String {
        guard let date = yearMonthFormatter.date(from: yearMonth),
              let result = Calendar.current.date(byAdding: .month, value: months, to: date)
        else { return yearMonth }
        return yearMonthFormatter.string(from: result)
    }

    static func formatYearMonth(_ yearMonth: String) -> String {
        guard let date = yearMonthFormatter.date(from: yearMonth) else { return yearMonth }
        return displayFormatter.string(from: date)
    }
}
```

---

## 8. Feature Breakdown & Key Queries

This mirrors the Web plan §7 (same data sources and rules), expressed in SwiftUI/repository terms. Queries reference the schema and views in System Design §2 and §4.

### 8.1 Dashboard

The dashboard is **month-scoped**: a `MonthNavigator` (prev / next, defaulting to the current month) drives every widget, plus a shortcut that opens the Transactions list pre-filtered to the shown month's date bounds. `DashboardViewModel` fetches all widgets in parallel for the selected `year_month` and re-runs on realtime changes to `transactions`, `budgets`, `fixed_expenses`, `accounts`, and `account_monthly_balances`. Amounts render in the default currency.

| Widget | View | Data source | Query |
|---|---|---|---|
| **Budget Verdict** | `BudgetVerdictBanner` | `v_budget_progress` | `.from("v_budget_progress").eq("year_month", yearMonth)` — counts budgets with `remaining < 0` and sums the overage; green (on-track) vs. red (over). Hidden when there are no budgets. |
| **Accounts** | `AccountsCard` | `accounts` + `fn_account_balances_at` RPC | `accounts` where `is_archived = false` **and** `show_on_dashboard = true`, joined with `.rpc("fn_account_balances_at", ["p_year_month": yearMonth])` (latest balance at or before the month per account). Accounts with no ledger row fall back to `starting_balance`. Shows each balance + the combined total. |
| **Planned Expenses** | `PlannedExpensesCard` | `v_budget_progress` + `fixed_expenses` | Budgets reuse the progress query for **pace-aware** bars (fill colored by projected month-end using elapsed-month fraction, tick at linear pace mid-month); fixed expenses from `fixed_expenses` for the month, split into Unpaid / Paid with subtotals (paid = has a linked `transactions.fixed_expense_id`). Headline = Σ budget `effective_amount` + Σ fixed-expense `amount`. |
| **Unplanned Expenses** | `UnplannedExpensesCard` | `transactions` | Confirmed expenses for the month with `budget_id IS NULL` **and** `fixed_expense_id IS NULL`, aggregated by category client-side (null category → "Uncategorized"), sorted by amount desc. |

> The legacy Cashflow / Spending-by-Category / Recent-Transactions cards are replaced by the four widgets above. The `v_monthly_cashflow`, `v_spending_by_category`, and `v_account_current_balance` views remain defined but are not read by this layout.

### 8.2 Accounts

- List non-archived accounts with their **current balance** (latest `account_monthly_balances` row, or the `v_account_current_balance` view). A header shows the **total balance** (net worth) across all accounts in the single currency.
- Tapping an account shows its transactions filtered by `account_id`.
- Add/edit via `AccountFormSheet`. Fields: **name**, **type** (bank account / credit card / digital wallet / cash / other), **starting balance**, optional **avatar image**, a **Show on dashboard** toggle, and a **Set as default account** toggle.
- **Archive** (soft-delete) instead of hard-delete — preserves transaction history.
- **Show on dashboard:** the `show_on_dashboard` toggle controls whether the account appears on the dashboard Accounts card. When off, the card shows an "Off dashboard" badge but the account behaves normally.
- **Default account:** stored on `user_settings.default_account_id` (via `updateDefaultAccountId`), not on the account row. Pre-selected when adding a new transaction. Only one at a time — setting it on another account replaces the prior one; clearing it removes the default.

**Account avatars (Supabase Storage).** Each card and the detail header render the account's image via `AccountAvatar`, falling back to `AccountType.defaultIcon` when `image_url` is nil. `AccountFormSheet` uses `PhotosPicker` (PhotosUI) to stage a picked image locally (preview), and uploads it on submit through `Services/AccountImageService.swift`:

- Downsize to ≤256px and re-encode to **WebP** before upload (objects stay a few KB).
- Upload to the **public** `account-images` bucket at path `{user_id}/{uuid}.webp`; store the resulting public URL in `accounts.image_url`.
- On replace/remove, delete the previous object **best-effort after** the row save succeeds (cancelling the form never orphans a file).

The transaction row reuses the linked account's image too (logo when present, colored initials otherwise), so transaction queries select `image_url` alongside the account name. See System Design §4.10.

### 8.3 Transactions

- Inline **confirm / dismiss** for pending transactions.
- **Filter & Search** — see §8.3.1.
- **Add/Edit** form per §5.3 (single category, multi tags, budget picker for income/expense, fixed-expense picker for expense, no currency field, sign rules enforced).

#### 8.3.1 Filter & Search

The list can be narrowed by any combination of filters. The query strategy — reading from the `v_transactions` view, the SQL-side `tag_ids` array, the budget/fixed-by-name resolution, and the **AND-across / OR-within** semantics — is defined in System Design §4.9. `TransactionListViewModel` holds a `TransactionFilters` value and issues PostgREST queries against `v_transactions` (windowed with `.range()` + `count: .exact` for pagination).

Every facet except search, date range, and amount range is a **tri-state multi-select**: absent = no filter, a non-empty set matches any selected value, a present-but-empty set matches nothing. The category, tag, budget, and fixed facets lead with a **"(Blanks)"** option that matches rows with no value for that facet.

| Filter | Control | State |
|---|---|---|
| Search | Text field (debounced ~300ms) → `.ilike("description", …)` | `search: String?` |
| Type | Multi-select (income / expense / transfer) → `.in("type", …)` | `types: [TransactionType]?` |
| Account | Multi-select; matches source **or** transfer side → `.or("account_id.eq.…,transfer_account_id.eq.…")` | `accountIds: [UUID]?` |
| Status | Multi-select (confirmed / pending / dismissed) → `.in("status", …)` | `statuses: [TransactionStatus]?` |
| Date range | From/to + presets (This month, Last month, Last 3 months, This year, All time) → `.gte/.lte("date", …)` | `dateFrom`, `dateTo` |
| Categories | Multi-select (+ "(Blanks)") → `.or("category_id.in.(…),category_id.is.null")` | `categoryIds: [UUID]?` |
| Tags | Multi-select (+ "(Blanks)") → `.or("tag_ids.ov.{…},tag_ids.eq.{}")` on the view's array | `tagIds: [UUID]?` |
| Amount range | Min/max (minor units) → `.gte/.lte("amount", …)` | `amountMin`, `amountMax` |
| Budget | Multi-select of budget **names** (+ "(Blanks)") from `v_budget_progress`, scoped to the active date range's months | `budgetNames: [String]?` |
| Fixed expense | Multi-select of fixed-expense **names** (+ "(Blanks)") from `fixed_expenses`, mirroring the budget filter | `fixedExpenseNames: [String]?` |

**Budget & fixed-expense filters (by name):** selecting names resolves to a set of `budget_id`s / `fixed_expense_id`s (budgets via `v_budget_progress` — **not** the `budgets` table — fixed via `fixed_expenses`), narrowed to the date range's months when a date filter is set, then applied as `.in("budget_id", …)` / `.in("fixed_expense_id", …)`, OR-ed with the `(Blanks)` (`…is.null`) option when chosen. A chosen-but-unresolved facet short-circuits to an empty result. A single `applyFilters(_:to:)` helper builds the predicate set so the list and Summary queries can never drift.

**UI:** the search field stays in the bar; a **Filters** button (with an active-count badge) opens `TransactionFilterSheet`. Active filters render as removable chips below the bar with a **Clear all** action and a **count of matching transactions**; an empty state shows when nothing matches. The list is **paginated** (selectable page size 25/50/100/200) via `.range()`.

> **No URL state on iOS.** The Web plan keeps filters in the URL query string for shareable links; on iOS the filters live in `TransactionListViewModel`. The `Utilities/TransactionFilters.swift` serializer is still useful for deep links / state restoration, but cross-session persistence is intentionally not kept.

#### 8.3.2 Summary

`TransactionSummarySheet` runs the same `applyFilters` against `v_transactions` over the **whole filtered set** (all pages, fetched on demand), selecting only money/grouping columns. It reduces to **income / expense / net / transfers in-out / count / largest expense**, with collapsible breakdowns by account, category, budget, fixed expense, and tag. Money math uses **confirmed rows only** (pending shown separately as a projection, dismissed excluded); transfers are reported as "transfer out" / "transfer in", not income/expense.

### 8.4 Budgets

- Current month's budgets with progress bars showing **net spent** vs. **effective amount** (periodic + carry-in), read from `v_budget_progress`.
- A per-card info popover shows the carry-in and the optional note when either is present (e.g. "+$10 carried over" / "−$20 overspent"). **Carry-over is always on; there is no toggle.**
- Tapping a budget opens the Transactions list filtered to that budget's **name**, scoped to the budget's own month.
- Overspent budgets (`remaining < 0`) render the bar and "$X over" label in the danger color.
- `MonthNavigator` (prev / next) with swipe support (§9.1).
- **Add** → inserts a single `budgets` row for the selected month (`name`, `periodic_amount`, optional note). Identity is **name**; budgets carry no per-row currency. There is no header record.
- **Edit** `periodic_amount`, `name`, or note for the selected month only — past months are untouched, but because carry-over is computed live, editing an earlier month re-flows every later month in the lineage.
- **Remove** a budget for a month = delete that month's row; a deliberate gap resets that lineage's carry-over to 0.
- **Copy from Previous Month:** copies every budget from M-1 into M (`name`, note, `periodic_amount`), skipping names already present in M.
- `BudgetFormSheet` has **no carry-over toggle** (carry-over is always on and never stored).

### 8.5 Fixed Expenses

- Current month's fixed expenses with paid/unpaid status (paid = at least one transaction references it via `fixed_expense_id`).
- `MonthNavigator` with swipe support.
- To mark one paid, the user creates/edits a transaction and links it — there is no standalone "mark as paid" toggle.
- **Copy from Previous Month**, **Edit** (name/amount, selected month only), **Delete** (selected month only), and **Add** — per §5.6.

### 8.6 Settings

- **Default currency** picker — searchable `CurrencyPickerView` populated from the `currencies` table; on change, upserts `user_settings.default_currency`. `AppState` reloads so every formatter/form picks up the new currency and its decimals.
- **Default account** picker — writes `user_settings.default_account_id`.

### 8.7 Scheduled Transactions

- List of active scheduled transactions with next due date.
- A section for **pending** transactions (`status = 'pending'`) awaiting confirmation, with confirm / edit / dismiss actions. Pending transactions are generated server-side by a `pg_cron` + Edge Function job (System Design §4.5); the app is notified via `NotificationService` (§10).

### 8.8 Budget / Virtual Installments (P1) — Spread an Expense Across Budgets

Lets a large expense be absorbed gradually by reserving future budget allowance; the account is debited in full immediately and only the **budgets** shown for future months shrink. See requirements → "Budget Installments / Virtual Installments" and System Design §4.11.

**Entry point.** Created from an **already-recorded expense**, not from the add/edit form. `TransactionRow`'s actions menu (the ⋮) shows **"Create virtual installment"** only when the row is an **expense** that is **not already spread** (income/transfer never show it; a second spread is rejected by the RPC). It opens a `CreateInstallmentSheet` over the expense's own amount:

1. **Start month** — segmented: *This month* / *Next month*.
2. **Budgets** — multi-select of budget **names** (lineages), sourced from `v_budget_progress`.
3. **Months** — stepper (consecutive months from the start).
4. **Allocation grid** — budgets × months currency inputs, **pre-filled with an even split** (`floor(total / (budgets × months))` minor units, remainder dropped into one cell so the grid sums exactly to the expense amount). A live **total reserved** / **remaining to allocate** header; **Save is disabled until the grid total equals the expense amount.** Changing the budget set or month count **re-runs the even pre-fill**; a "Split evenly" action re-applies it on demand; cells may be set to `0`.

> **Fields that stay.** Spreading replaces only the single **budget** link. The expense's **category**, **fixed-expense link**, and **tags** are left untouched.

**On submit — single RPC `spread_existing_transaction`** (Supabase §3.10) for atomicity:

1. Load the source expense; reject if not an expense, already spread, or the grid doesn't sum to its amount.
2. `UPDATE transactions SET budget_id = NULL` on the source (so it doesn't double-count as that budget's spend); amount, category, fixed-expense link, and tags are kept.
3. For each distinct cell `(budget_name, year_month)`, **ensure the budget row exists** (`INSERT … ON CONFLICT (user_id, name, year_month) DO NOTHING`, defaulting `periodic_amount` to the latest known value in that lineage, else 0) — keeps carry-over lineages unbroken.
4. Insert one `budget_installments` header; bulk-insert one `budget_installment_allocations` row per **non-zero** cell.

**Surfacing.**
- `TransactionRow` shows a small grid indicator on flagged expenses (`InstallmentRepository` does one batched lookup against `budget_installments.source_transaction_id`).
- `BudgetCard` shows a **"Reserved $X"** line when `reserved > 0`, renders **negative `remaining`** gracefully (the intended "spend nothing" signal), and can list the source installment(s).
- `ActiveInstallmentsSection` (below the budgets) lists only installments that reserve in the displayed month; each shows the source expense's title, total, month span, and budget-name chips, navigates to the source transaction, and offers a per-entry **Cancel** (deletes the `budget_installments` row → cascades to allocations; future budgets recover their allowance).

`v_budget_progress` exposes the `reserved` column and its `remaining` already nets it (`periodic + carry_in − spent − reserved`). Deleting the source expense cancels the installment automatically (`ON DELETE CASCADE`).

---

## 9. UI / UX Guidelines

### 9.1 Month Navigation — Swipe + Page Animation

All screens that embed `MonthNavigator` (Dashboard, Transactions, Budgets, Fixed Expenses) must support **horizontal swipe gestures** to navigate between months. A `.swipeToNavigateMonth(onPrevious:onNext:)` view modifier (defined in `MonthNavigator.swift`) applies a `.simultaneousGesture(DragGesture)` that fires when horizontal displacement exceeds 50 pt and is at least 1.5× the vertical displacement, so it does not conflict with vertical `ScrollView` scrolling.

**Page transition animation:** When the month changes, the content below the `MonthNavigator` performs a horizontal push transition. This is achieved with a `.monthPageTransition(yearMonth:direction:)` modifier that applies `.id(yearMonth)` and `.transition(.push(from: direction))`. Each ViewModel's `navigateMonth(by:)` wraps state changes in `withAnimation(.easeInOut(duration: 0.3))`. The `MonthNavigator` title text uses `.contentTransition(.numericText())`.

**Adjacent-month prefetching:** Each ViewModel maintains an in-memory cache keyed by `year_month`. After loading the current month, it prefetches the previous and next months in the background. On navigation:

1. Cached → apply immediately inside `withAnimation` (no spinner).
2. No cache → show a loading spinner inside the transition.
3. Always fetch fresh data afterward to keep it current.

### 9.2 Money Row Layout (multi-metric cards)

Cards that stack several labeled amounts (e.g. the Transactions **Summary**, the Planned/Unplanned headlines) must use a **vertical stacked layout** — one row per metric with the label + icon on the left and the formatted amount on the right. A 3-column `HStack` of amounts must **not** be used: long formatted values (e.g. IDR `Rp1.234.567`) cause text wrapping on narrow screens. Each amount `Text` sets `lineLimit(1)` with `minimumScaleFactor(0.7)` as a safety net.

---

## 10. Notifications

Use `UNUserNotificationCenter` to notify the user when pending transactions are created:

```swift
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func showPendingTransaction(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
```

---

## 11. Platform Configuration

### 11.1 Info.plist Permissions

```xml
<!-- P0: account avatar images (PhotosPicker reads from the library) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library is used to choose an account avatar image.</string>

<!-- P1: receipt scanning -->
<key>NSCameraUsageDescription</key>
<string>Camera is used to scan receipts.</string>
```

> `PhotosPicker` (PhotosUI) does not require the photo-library permission for simply picking an item, but the usage string is required if the app later needs broader library access; declare it up front for the avatar flow.

### 11.2 Local Network Access (Development)

For connecting to local Supabase during development:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

Remove or restrict this in production builds.

### 11.3 Xcode Schemes

| Scheme | Build Configuration | xcconfig |
|---|---|---|
| `FinancialManagement (Dev)` | Debug | `Config/Dev.xcconfig` |
| `FinancialManagement (Prod)` | Release | `Config/Prod.xcconfig` |

---

## 12. Build & Deployment

### 12.1 Run on Simulator

```bash
# From terminal (or use Xcode)
xcodebuild -scheme "FinancialManagement (Dev)" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  build
```

### 12.2 App Store Deployment

1. Ensure **Apple Developer Program** membership ($99/year).
2. In Xcode: target → **Signing & Capabilities** → select your team and provisioning profile.
3. **Product → Archive** → opens Organizer.
4. **Distribute App → App Store Connect → Upload**.
5. In [App Store Connect](https://appstoreconnect.apple.com), complete the listing and submit for review.

Alternatively use CLI:

```bash
xcodebuild -scheme "FinancialManagement (Prod)" \
  -archivePath build/FinancialManagement.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath build/FinancialManagement.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

### 12.3 TestFlight

After uploading to App Store Connect, enable **TestFlight** to distribute beta builds to testers before going live.

---

## 13. Testing Strategy

| Layer | Tool | What to Test |
|---|---|---|
| Unit | XCTest | Models (Codable round-trip), CurrencyUtils, DateUtils, `applyFilters` predicate building, even-split grid math |
| Repository | XCTest + mock Supabase | Repository methods return expected models; budget reads come from `v_budget_progress` |
| ViewModel | XCTest + `@Observable` | State transitions, loading/error, filter/pager state, month prefetch cache |
| UI | XCTest + SwiftUI Previews | Visual correctness of key views (avatar fallback, overspent budget bar) |
| Integration | XCUITest | Full flow: login → add account → add transaction → verify dashboard |

```swift
// Example: CurrencyUtils test
import XCTest
@testable import FinancialManagement

final class CurrencyUtilsTests: XCTestCase {
    func testToMinorUnits() {
        XCTAssertEqual(CurrencyUtils.toMinorUnits(10.50), 1050)
    }

    func testFormat() {
        XCTAssertEqual(CurrencyUtils.format(1050, currency: "USD"), "$10.50")
    }
}
```

---

## 14. Development Workflow

```bash
# Terminal 1: Start local Supabase
cd financial-management
supabase start

# Xcode: Select "FinancialManagement (Dev)" scheme
# Run on simulator (Cmd+R)

# Local Supabase dashboard (manage test data)
open http://127.0.0.1:54323
```
