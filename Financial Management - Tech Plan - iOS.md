# Financial Management — Technical Plan: iOS (Swift / SwiftUI)

> Native iOS app using Swift, SwiftUI, and the Supabase Swift SDK.

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
| SwiftUI Charts | Built-in (iOS 16+) | Dashboard charts |
| KeychainAccess | `https://github.com/kishikawakatsumi/KeychainAccess` | Secure token storage |

The Supabase Swift package includes all sub-libraries: `Auth`, `PostgREST`, `Realtime`, `Storage`, `Functions`.

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
│   └── AppState.swift                     # Global app state (auth status)
├── Config/
│   ├── Dev.xcconfig                       # Local env (git-ignored)
│   └── Prod.xcconfig                      # Production env (git-ignored)
├── Models/
│   ├── Account.swift
│   ├── Transaction.swift
│   ├── Category.swift
│   ├── Tag.swift
│   ├── Budget.swift
│   ├── BudgetPeriod.swift             # includes carryOverAmount
│   ├── FixedExpense.swift
│   ├── ScheduledTransaction.swift
│   ├── Currency.swift                 # ISO 4217 reference data from DB
│   ├── UserSettings.swift             # default_currency preference
│   └── Enums.swift                        # AccountType, TransactionType, etc.
├── Repositories/
│   ├── AccountRepository.swift
│   ├── TransactionRepository.swift
│   ├── BudgetRepository.swift
│   ├── FixedExpenseRepository.swift
│   ├── ScheduledTransactionRepository.swift
│   ├── CurrencyRepository.swift       # Fetches currencies + user settings
│   └── DashboardRepository.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── DashboardViewModel.swift
│   ├── AccountListViewModel.swift
│   ├── AccountDetailViewModel.swift
│   ├── TransactionListViewModel.swift
│   ├── TransactionFormViewModel.swift
│   ├── BudgetListViewModel.swift
│   ├── FixedExpenseListViewModel.swift
│   ├── ScheduledTransactionViewModel.swift
│   └── SettingsViewModel.swift            # Manages default currency
├── Views/
│   ├── Auth/
│   │   └── LoginView.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── CashflowCard.swift
│   │   ├── BudgetProgressCard.swift
│   │   ├── SpendingByCategoryChart.swift
│   │   └── RecentTransactionsCard.swift
│   ├── Accounts/
│   │   ├── AccountListView.swift
│   │   ├── AccountDetailView.swift
│   │   ├── AccountCard.swift
│   │   └── AccountFormSheet.swift
│   ├── Transactions/
│   │   ├── TransactionListView.swift
│   │   ├── TransactionRow.swift
│   │   ├── TransactionFormView.swift
│   │   └── FilterBar.swift
│   ├── Budgets/
│   │   ├── BudgetListView.swift
│   │   ├── BudgetCard.swift            # Shows effective amount + carry-over badge
│   │   └── BudgetFormSheet.swift       # Includes carry-over toggle
│   ├── FixedExpenses/
│   │   ├── FixedExpenseListView.swift
│   │   ├── FixedExpenseRow.swift
│   │   ├── FixedExpenseFormSheet.swift
│   │   └── FixedExpenseEditSheet.swift
│   ├── Scheduled/
│   │   ├── ScheduledListView.swift
│   │   └── PendingTransactionRow.swift
│   ├── Settings/
│   │   ├── SettingsView.swift             # Default currency picker + preferences
│   │   └── CurrencyPickerView.swift       # Searchable list from currencies table
│   └── Shared/
│       ├── MonthNavigator.swift
│       ├── CurrencyField.swift
│       ├── CurrencyPicker.swift           # Reusable picker backed by currencies table
│       ├── CategoryPicker.swift
│       ├── TagPicker.swift
│       ├── AccountPicker.swift
│       ├── BudgetPicker.swift           # Budget period picker for expense transactions
│       ├── FixedExpensePicker.swift     # Fixed expense picker for expense transactions
│       ├── EmptyStateView.swift
│       └── ContentRootView.swift          # TabView with navigation stacks
├── Services/
│   ├── SupabaseService.swift              # Singleton Supabase client
│   ├── RealtimeService.swift              # Manages Realtime subscriptions
│   └── NotificationService.swift          # UNUserNotificationCenter wrapper
├── Utilities/
│   ├── CurrencyUtils.swift
│   ├── DateUtils.swift
│   └── Extensions/
│       ├── Date+YearMonth.swift
│       └── Int+Currency.swift
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

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

```swift
import Observation
import Supabase

@Observable
@MainActor
final class AppState {
    var isAuthenticated = false
    var currentUser: User?

    private let supabase = SupabaseService.shared.client

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
                currencies = []
            default:
                break
            }
        }
    }
}
```

---

## 5. Data Layer

### 5.1 Model Example (`Models/Account.swift`)

```swift
import Foundation

struct Account: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var type: AccountType
    var currency: String
    var startingBalance: Int64
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, type, currency
        case startingBalance = "starting_balance"
        case isArchived = "is_archived"
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
}
```

### 5.2 Budget Models (`Models/Budget.swift`, `Models/BudgetPeriod.swift`)

```swift
struct Budget: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var isActive: Bool
    var enableCarryOver: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case isActive = "is_active"
        case enableCarryOver = "enable_carry_over"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BudgetPeriod: Codable, Identifiable, Sendable {
    let id: UUID
    let budgetId: UUID
    let yearMonth: String
    var periodicAmount: Int64
    var carryOverAmount: Int64
    let currency: String
    let createdAt: Date
    var updatedAt: Date

    /// The actual spendable amount: periodic + carry-over
    var effectiveAmount: Int64 { periodicAmount + carryOverAmount }

    enum CodingKeys: String, CodingKey {
        case id
        case budgetId = "budget_id"
        case yearMonth = "year_month"
        case periodicAmount = "periodic_amount"
        case carryOverAmount = "carry_over_amount"
        case currency
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

### 5.3 Transaction Model (`Models/Transaction.swift`)

```swift
struct Transaction: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let accountId: UUID
    var type: TransactionType
    var status: TransactionStatus
    var amount: Int64
    var currency: String
    var description: String?
    var transactionDate: Date
    var toAccountId: UUID?
    var budgetPeriodId: UUID?
    var scheduledTxnId: UUID?
    var fixedExpenseId: UUID?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case accountId = "account_id"
        case type, status, amount, currency
        case description
        case transactionDate = "date"
        case toAccountId = "transfer_account_id"
        case budgetPeriodId = "budget_period_id"
        case scheduledTxnId = "scheduled_txn_id"
        case fixedExpenseId = "fixed_expense_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

> **Column name mapping:** `transactionDate` maps to `date` (not `transaction_date`). `toAccountId` maps to `transfer_account_id` (not `to_account_id`). There is no `category_id` column — categories are linked via the `transaction_categories` junction table. `fixedExpenseId` optionally links the transaction to a fixed expense to indicate payment.

#### Transaction Form Fields

The "Add/Edit Transaction" form (`TransactionFormView.swift`) includes the following fields:

| Field | Type | Visibility |
|---|---|---|
| Type | Segmented picker (income / expense / transfer) | Always |
| Amount | Currency text field | Always |
| Currency | Currency picker | Always |
| Account | Account picker | Always |
| To Account | Account picker | Only when type = `transfer` |
| Category | Category picker | Always |
| Budget | Budget period picker (`BudgetPicker`) | Only when type = `expense` |
| Fixed Expense | Fixed expense picker (`FixedExpensePicker`) | Only when type = `expense` |
| Description | Text field (optional) | Always |
| Date | Date picker | Always |

The **Budget picker** (`Views/Shared/BudgetPicker.swift`) loads active budgets and their `budget_periods` for the month matching the transaction's date. Each option displays the budget name and effective amount (periodic + carry-over). The selection is stored as `budgetPeriodId` on the transaction. When the type is not `expense`, the budget selection is cleared before saving.

The **Fixed Expense picker** (`Views/Shared/FixedExpensePicker.swift`) loads `fixed_expenses` for the month matching the transaction's date. Each option displays the expense name and amount. The selection is stored as `fixedExpenseId` on the transaction. This link indicates payment of the fixed expense — a fixed expense is considered "paid" when at least one transaction references it via `fixed_expense_id`. When the type is not `expense`, the selection is cleared before saving.

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
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case defaultCurrency = "default_currency"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

### 5.5 Category, ScheduledTransaction, and Enum Models

**`Models/Enums.swift`** — DB-aligned enums:

```swift
enum TransactionStatus: String, Codable, CaseIterable {
    case confirmed
    case pending
    case dismissed
}

enum RecurrenceType: String, Codable, CaseIterable {
    case monthly
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

> The `categories` table has `color` (not `type`). Category–transaction links use the `transaction_categories` junction table.

**`Models/ScheduledTransaction.swift`:**

```swift
struct ScheduledTransaction: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var accountId: UUID
    var type: TransactionType
    var amount: Int64
    var currency: String
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
        case type, amount, currency
        case description, recurrence
        case nextDueDate = "next_due_date"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

> The column is `recurrence` (not `recurrence_interval`) and `next_due_date` (not `next_occurrence`). There is no separate `pending_transactions` table — pending transactions are rows in `transactions` where `status = 'pending'`.

### 5.5 Fixed Expense Model (`Models/FixedExpense.swift`)

```swift
struct FixedExpense: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var yearMonth: String
    var amount: Int64
    var currency: String
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case yearMonth = "year_month"
        case amount, currency
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

> Each row represents one fixed expense for one specific month. There is no separate periods table. The `amount` and `currency` fields allow values to differ between months. There is no `isPaid` column — paid status is derived from whether any transaction references this fixed expense via `fixed_expense_id`.

#### Fixed Expense Operations

**Copy from Previous Month:** Queries `fixed_expenses` for `year_month = previousMonth` and `user_id = currentUser`, then inserts new rows with `year_month = currentMonth`. Skips entries that already exist (UNIQUE constraint on `user_id, name, year_month`). This is triggered from the `FixedExpenseListView` toolbar when the current month has no entries.

**Edit Fixed Expense:** Opens `FixedExpenseEditSheet` to update `name`, `amount`, or `currency` on an existing `fixed_expenses` row. Only edits the specific month's entry — other months are unaffected.

**Delete Fixed Expense:** Deletes the `fixed_expenses` row for that month. Any transactions that referenced it will have their `fixed_expense_id` set to NULL (via the database's `ON DELETE SET NULL` foreign key constraint).

### 5.6 Repository Example (`Repositories/AccountRepository.swift`)

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

    func create(name: String, type: AccountType, currency: String, startingBalance: Int64) async throws -> Account {
        let userId = try await client.auth.session.user.id

        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let type: AccountType
            let currency: String
            let starting_balance: Int64
        }

        let account: Account = try await client
            .from("accounts")
            .insert(Insert(
                user_id: userId,
                name: name,
                type: type,
                currency: currency,
                starting_balance: startingBalance
            ))
            .select()
            .single()
            .execute()
            .value

        // Create the initial monthly balance row for the current month
        let yearMonth = Self.currentYearMonth()
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

    func getMonthlyBalances(accountId: UUID) async throws -> [AccountMonthlyBalance] {
        try await client
            .from("account_monthly_balances")
            .select()
            .eq("account_id", value: accountId)
            .order("year_month")
            .execute()
            .value
    }

    private static func currentYearMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    func update(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client
            .from("accounts")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    func archive(id: UUID) async throws {
        try await client
            .from("accounts")
            .update(["is_archived": true])
            .eq("id", value: id)
            .execute()
    }
}
```

### 5.7 Currency Repository (`Repositories/CurrencyRepository.swift`)

```swift
import Supabase

actor CurrencyRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getAllCurrencies() async throws -> [Currency] {
        try await client
            .from("currencies")
            .select()
            .order("code")
            .execute()
            .value
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

        struct Upsert: Encodable {
            let user_id: UUID
            let default_currency: String
        }

        return try await client
            .from("user_settings")
            .upsert(Upsert(user_id: userId, default_currency: currencyCode))
            .select()
            .single()
            .execute()
            .value
    }
}
```

### 5.8 ViewModel Example (`ViewModels/AccountListViewModel.swift`)

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

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "accounts"
        )

        await channel.subscribe()

        Task {
            for await _ in changes {
                await load()
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
```

---

## 6. Navigation (`Views/Shared/ContentRootView.swift`)

```swift
import SwiftUI

struct ContentRootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Dashboard", systemImage: "chart.pie") }

            NavigationStack {
                AccountListView()
            }
            .tabItem { Label("Accounts", systemImage: "creditcard") }

            NavigationStack {
                TransactionListView()
            }
            .tabItem { Label("Transactions", systemImage: "list.bullet") }

            NavigationStack {
                BudgetListView()
            }
            .tabItem { Label("Budgets", systemImage: "target") }

            NavigationStack {
                MoreView()
            }
            .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}
```

The **More** tab groups: Fixed Expenses, Scheduled Transactions, and Settings.

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

### 7.2 Year-Month (`Utilities/DateUtils.swift`)

```swift
import Foundation

enum DateUtils {
    private static let yearMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static func currentYearMonth() -> String {
        yearMonthFormatter.string(from: Date())
    }

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

## 8. UI / UX Guidelines

### 8.1 Month Navigation — Swipe + Page Animation

All screens that embed `MonthNavigator` (Dashboard, Transactions, Budgets, Fixed Expenses) must support **horizontal swipe gestures** to navigate between months. A `.swipeToNavigateMonth(onPrevious:onNext:)` view modifier (defined in `MonthNavigator.swift`) applies a `.simultaneousGesture(DragGesture)` that fires the callback when horizontal displacement exceeds 50 pt and is at least 1.5× the vertical displacement, so it does not conflict with vertical `ScrollView` scrolling.

**Page transition animation:** When the month changes, the content below the `MonthNavigator` performs a horizontal push transition (slide in from the direction of navigation). This is achieved with a `.monthPageTransition(yearMonth:direction:)` modifier that applies `.id(yearMonth)` and `.transition(.push(from: direction))`. Each ViewModel's `navigateMonth(by:)` wraps state changes in `withAnimation(.easeInOut(duration: 0.3))` to trigger the transition. The `MonthNavigator` title text uses `.contentTransition(.numericText())` for a smooth label change.

**Adjacent-month prefetching:** Each ViewModel maintains an in-memory cache keyed by `year_month`. After loading the current month's data, the ViewModel prefetches the previous and next months in the background. On navigation:

1. If cached data exists for the target month → apply it immediately inside `withAnimation` (no loading spinner, instant content).
2. If no cache → show a loading spinner inside the animated transition.
3. Always fetch fresh data from the server after displaying cached data, to keep it up-to-date.

This makes month transitions feel instantaneous for ±1 months. The `MonthNavigator` label text uses `.contentTransition(.numericText())` for a polished title change.

### 8.2 Cash Flow Card Layout

`CashflowCard.swift` uses a **vertical stacked layout** — one row per metric (Income, Expense, Net) — with the label + icon on the left and the formatted amount on the right. A 3-column `HStack` layout must **not** be used: currencies with long formatted values (e.g., IDR `Rp1.234.567`) cause text wrapping on narrow screens. Each amount `Text` sets `lineLimit(1)` with `minimumScaleFactor(0.7)` as a safety net.

---

## 9. Notifications

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

## 10. Platform Configuration

### 10.1 Info.plist Permissions (for P1 receipt scanning)

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used to scan receipts.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library is used to select receipt images.</string>
```

### 10.2 Local Network Access (Development)

For connecting to local Supabase during development:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

Remove or restrict this in production builds.

### 10.3 Xcode Schemes

Create two schemes:

| Scheme | Build Configuration | xcconfig |
|---|---|---|
| `FinancialManagement (Dev)` | Debug | `Config/Dev.xcconfig` |
| `FinancialManagement (Prod)` | Release | `Config/Prod.xcconfig` |

---

## 11. Build & Deployment

### 11.1 Run on Simulator

```bash
# From terminal (or use Xcode)
xcodebuild -scheme "FinancialManagement (Dev)" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  build
```

### 11.2 App Store Deployment

1. Ensure **Apple Developer Program** membership ($99/year).
2. In Xcode: Runner target → **Signing & Capabilities** → select your team and provisioning profile.
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

### 11.3 TestFlight

After uploading to App Store Connect, enable **TestFlight** to distribute beta builds to testers before going live.

---

## 12. Testing Strategy

| Layer | Tool | What to Test |
|---|---|---|
| Unit | XCTest | Models (Codable round-trip), CurrencyUtils, DateUtils |
| Repository | XCTest + mock Supabase | Repository methods return expected models |
| ViewModel | XCTest + `@Observable` | State transitions, loading/error states |
| UI | XCTest + SwiftUI Previews | Visual correctness of key views |
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

## 13. Development Workflow

```bash
# Terminal 1: Start local Supabase
cd financial-management
supabase start

# Xcode: Select "FinancialManagement (Dev)" scheme
# Run on simulator (Cmd+R)

# Local Supabase dashboard (manage test data)
open http://127.0.0.1:54323
```
