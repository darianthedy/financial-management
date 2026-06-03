# Financial Management — Technical Plan: Android (Kotlin / Jetpack Compose)

> Native Android app using Kotlin, Jetpack Compose, and the Supabase Kotlin SDK.

---

## 1. Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Android Studio | >= Ladybug (2024.2) | IDE, emulator, SDK manager |
| Kotlin | >= 2.0 | Language |
| JDK | 17 | Required by AGP |
| Android Gradle Plugin | >= 8.5 | Build system |
| Min SDK | 26 (Android 8.0) | Broad coverage with modern APIs |
| Target SDK | 35 | Latest API level |
| Supabase CLI | >= 1.x | Local Supabase for development |

---

## 2. Project Setup

### 2.1 Create the Project

1. Open Android Studio → **New Project**.
2. Choose **Empty Activity** (Compose).
3. Settings:
   - Name: `Financial Management`
   - Package name: `com.yourname.finman`
   - Minimum SDK: **API 26**
   - Build configuration language: **Kotlin DSL**
4. Finish.

### 2.2 Add Dependencies

**`gradle/libs.versions.toml`** (version catalog):

```toml
[versions]
kotlin = "2.0.21"
compose-bom = "2024.12.01"
supabase = "3.1.0"
ktor = "3.0.0"
hilt = "2.52"
hilt-navigation = "1.2.0"
navigation = "2.8.0"
lifecycle = "2.8.0"
vico = "2.0.0-beta.2"
room = "2.6.1"
datastore = "1.1.0"

[libraries]
# Compose
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-icons-extended = { group = "androidx.compose.material", name = "material-icons-extended" }
compose-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }

# Navigation
navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigation" }

# Lifecycle
lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycle" }
lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version.ref = "lifecycle" }

# Supabase
supabase-bom = { group = "io.github.jan-tennert.supabase", name = "bom", version.ref = "supabase" }
supabase-postgrest = { group = "io.github.jan-tennert.supabase", name = "postgrest-kt" }
supabase-auth = { group = "io.github.jan-tennert.supabase", name = "auth-kt" }
supabase-realtime = { group = "io.github.jan-tennert.supabase", name = "realtime-kt" }
supabase-storage = { group = "io.github.jan-tennert.supabase", name = "storage-kt" }

# Ktor (HTTP engine for Supabase)
ktor-client-android = { group = "io.ktor", name = "ktor-client-android", version.ref = "ktor" }

# DI
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-android-compiler", version.ref = "hilt" }
hilt-navigation-compose = { group = "androidx.hilt", name = "hilt-navigation-compose", version.ref = "hilt-navigation" }

# Charts
vico-compose-m3 = { group = "com.patrykandpatrick.vico", name = "compose-m3", version.ref = "vico" }

# Local storage
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }
datastore-preferences = { group = "androidx.datastore", name = "datastore-preferences", version.ref = "datastore" }

[plugins]
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp = { id = "com.google.devtools.ksp", version = "2.0.21-1.0.27" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
```

**`app/build.gradle.kts`**:

```kotlin
plugins {
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
    alias(libs.plugins.kotlin.serialization)
    id("com.android.application")
}

android {
    namespace = "com.yourname.finman"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.yourname.finman"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        buildConfigField("String", "SUPABASE_URL", "\"${project.findProperty("SUPABASE_URL") ?: "http://10.0.2.2:54321"}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${project.findProperty("SUPABASE_ANON_KEY") ?: ""}\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    // Compose
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.icons.extended)
    implementation(libs.compose.tooling.preview)
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Navigation
    implementation(libs.navigation.compose)

    // Lifecycle
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.lifecycle.viewmodel.compose)

    // Supabase
    implementation(platform(libs.supabase.bom))
    implementation(libs.supabase.postgrest)
    implementation(libs.supabase.auth)
    implementation(libs.supabase.realtime)
    implementation(libs.supabase.storage)
    implementation(libs.ktor.client.android)

    // DI
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)

    // Charts
    implementation(libs.vico.compose.m3)

    // Local storage
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
    implementation(libs.datastore.preferences)

    // Kotlin serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // Testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("io.mockk:mockk:1.13.12")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    androidTestImplementation(composeBom)
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
}
```

### 2.3 Environment Configuration

Create `local.properties` entries (already git-ignored by default):

```properties
SUPABASE_URL=http://10.0.2.2:54321
SUPABASE_ANON_KEY=<local-anon-key>
```

For release builds, pass via Gradle properties or CI secrets:

```bash
./gradlew assembleRelease \
  -PSUPABASE_URL=https://xxx.supabase.co \
  -PSUPABASE_ANON_KEY=<prod-key>
```

---

## 3. Project Structure

```
app/src/main/java/com/yourname/finman/
├── FinManApplication.kt                    # @HiltAndroidApp
├── MainActivity.kt                         # setContent { FinManApp() }
├── di/
│   └── AppModule.kt                        # Hilt module: SupabaseClient, repositories
├── data/
│   ├── model/
│   │   ├── Account.kt
│   │   ├── Transaction.kt
│   │   ├── Category.kt
│   │   ├── Tag.kt
│   │   ├── Budget.kt
│   │   ├── BudgetPeriod.kt             // includes carryOverAmount
│   │   ├── FixedExpense.kt
│   │   ├── ScheduledTransaction.kt
│   │   ├── Currency.kt                 // ISO 4217 reference data
│   │   ├── UserSettings.kt             // default_currency preference
│   │   └── Enums.kt
│   ├── repository/
│   │   ├── AccountRepository.kt
│   │   ├── TransactionRepository.kt
│   │   ├── BudgetRepository.kt
│   │   ├── FixedExpenseRepository.kt
│   │   ├── ScheduledTransactionRepository.kt
│   │   ├── CurrencyRepository.kt       // fetch currencies + user settings
│   │   └── DashboardRepository.kt
│   └── local/                              # Room (optional offline cache)
│       ├── AppDatabase.kt
│       └── dao/
├── ui/
│   ├── FinManApp.kt                        # NavHost + bottom bar
│   ├── navigation/
│   │   ├── Screen.kt                       # Sealed class of routes
│   │   └── FinManNavGraph.kt
│   ├── theme/
│   │   ├── Theme.kt
│   │   ├── Color.kt
│   │   └── Type.kt
│   ├── auth/
│   │   ├── LoginScreen.kt
│   │   └── LoginViewModel.kt
│   ├── dashboard/
│   │   ├── DashboardScreen.kt
│   │   ├── DashboardViewModel.kt
│   │   ├── CashflowCard.kt
│   │   ├── BudgetProgressCard.kt
│   │   ├── SpendingByCategoryChart.kt
│   │   └── RecentTransactionsCard.kt
│   ├── accounts/
│   │   ├── AccountListScreen.kt
│   │   ├── AccountListViewModel.kt
│   │   ├── AccountDetailScreen.kt
│   │   ├── AccountCard.kt
│   │   └── AccountFormDialog.kt
│   ├── transactions/
│   │   ├── TransactionListScreen.kt
│   │   ├── TransactionListViewModel.kt
│   │   ├── TransactionFormScreen.kt
│   │   ├── TransactionFormViewModel.kt
│   │   ├── TransactionRow.kt
│   │   └── FilterBar.kt
│   ├── budgets/
│   │   ├── BudgetListScreen.kt
│   │   ├── BudgetListViewModel.kt
│   │   ├── BudgetCard.kt               // Shows effective amount + carry-over badge
│   │   └── BudgetFormDialog.kt         // Includes carry-over toggle
│   ├── fixedexpenses/
│   │   ├── FixedExpenseListScreen.kt
│   │   ├── FixedExpenseListViewModel.kt
│   │   ├── FixedExpenseRow.kt
│   │   ├── FixedExpenseFormDialog.kt
│   │   └── FixedExpenseEditDialog.kt
│   ├── scheduled/
│   │   ├── ScheduledListScreen.kt
│   │   ├── ScheduledListViewModel.kt
│   │   └── PendingTransactionRow.kt
│   ├── settings/
│   │   ├── SettingsScreen.kt
│   │   ├── SettingsViewModel.kt
│   │   └── CurrencyPickerDialog.kt     // Search + select from currencies table
│   └── shared/
│       ├── MonthNavigator.kt
│       ├── CurrencyField.kt
│       ├── CurrencyPicker.kt           // Reusable picker backed by currencies table
│       ├── CategoryPicker.kt
│       ├── TagPicker.kt
│       ├── AccountPicker.kt
│       ├── BudgetPicker.kt             // Budget period picker for expense transactions
│       ├── EmptyState.kt
│       └── LoadingSkeleton.kt
├── service/
│   └── NotificationService.kt
└── util/
    ├── CurrencyUtils.kt
    ├── DateUtils.kt
    └── Extensions.kt
```

---

## 4. Supabase Client Setup

### 4.1 Hilt Module (`di/AppModule.kt`)

```kotlin
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    @Provides
    @Singleton
    fun provideSupabaseClient(): SupabaseClient {
        return createSupabaseClient(
            supabaseUrl = BuildConfig.SUPABASE_URL,
            supabaseKey = BuildConfig.SUPABASE_ANON_KEY,
        ) {
            install(Auth)
            install(Postgrest)
            install(Realtime)
            install(Storage)
        }
    }

    @Provides
    @Singleton
    fun provideAccountRepository(client: SupabaseClient): AccountRepository {
        return AccountRepository(client)
    }

    // ... provide other repositories
}
```

### 4.2 Application Class (`FinManApplication.kt`)

```kotlin
import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class FinManApplication : Application()
```

---

## 5. Data Layer

### 5.1 Model Example (`data/model/Account.kt`)

```kotlin
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Account(
    val id: String,
    @SerialName("user_id") val userId: String,
    val name: String,
    val type: AccountType,
    val currency: String,
    @SerialName("starting_balance") val startingBalance: Long,
    @SerialName("is_archived") val isArchived: Boolean,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)

@Serializable
data class AccountMonthlyBalance(
    @SerialName("account_id") val accountId: String,
    @SerialName("year_month") val yearMonth: String,
    val balance: Long,
    @SerialName("updated_at") val updatedAt: String,
)

@Serializable
enum class AccountType {
    @SerialName("bank_account") BANK_ACCOUNT,
    @SerialName("credit_card") CREDIT_CARD,
    @SerialName("digital_wallet") DIGITAL_WALLET,
    @SerialName("cash") CASH,
    @SerialName("other") OTHER,
}
```

### 5.2 Budget Models (`data/model/Budget.kt`, `data/model/BudgetPeriod.kt`)

```kotlin
@Serializable
data class Budget(
    val id: String,
    @SerialName("user_id") val userId: String,
    val name: String,
    @SerialName("is_active") val isActive: Boolean,
    @SerialName("enable_carry_over") val enableCarryOver: Boolean,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)

@Serializable
data class BudgetPeriod(
    val id: String,
    @SerialName("budget_id") val budgetId: String,
    @SerialName("year_month") val yearMonth: String,
    @SerialName("periodic_amount") val periodicAmount: Long,
    @SerialName("carry_over_amount") val carryOverAmount: Long,
    val currency: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
) {
    /** The actual spendable amount: periodic + carry-over */
    val effectiveAmount: Long get() = periodicAmount + carryOverAmount
}
```

### 5.3 Transaction Model (`data/model/Transaction.kt`)

```kotlin
@Serializable
data class Transaction(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("account_id") val accountId: String,
    val type: TransactionType,
    val status: TransactionStatus,
    val amount: Long,
    val currency: String,
    val description: String? = null,
    val date: String,
    @SerialName("transfer_account_id") val transferAccountId: String? = null,
    @SerialName("budget_period_id") val budgetPeriodId: String? = null,
    @SerialName("scheduled_txn_id") val scheduledTxnId: String? = null,
    @SerialName("fixed_expense_id") val fixedExpenseId: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)

@Serializable
enum class TransactionStatus {
    @SerialName("confirmed") CONFIRMED,
    @SerialName("pending") PENDING,
    @SerialName("dismissed") DISMISSED,
}
```

> **Column name mapping:** The date column is `date` (not `transaction_date`). The transfer account column is `transfer_account_id` (not `to_account_id`). There is no `category_id` column on this table — categories are linked via the `transaction_categories` junction table. `fixedExpenseId` optionally links the transaction to a fixed expense to indicate payment.

#### Transaction Form Fields

The "Add/Edit Transaction" form (`TransactionFormScreen.kt`) includes the following fields:

| Field | Type | Visibility |
|---|---|---|
| Type | Segmented button (income / expense / transfer) | Always |
| Amount | Currency text field | Always |
| Currency | Currency picker | Always |
| Account | Account picker | Always |
| To Account | Account picker | Only when type = `transfer` |
| Category | Category picker | Always |
| Budget | Budget period picker (`BudgetPicker`) | Only when type = `expense` |
| Fixed Expense | Fixed expense picker | Only when type = `expense` |
| Description | Text field (optional) | Always |
| Date | Date picker | Always |

The **Budget picker** (`ui/shared/BudgetPicker.kt`) loads active budgets and their `budget_periods` for the month matching the transaction's date. Each option displays the budget name and effective amount (periodic + carry-over). The selection is stored as `budgetPeriodId` on the transaction. When the type is not `expense`, the budget selection is cleared before saving.

The **Fixed Expense picker** loads `fixed_expenses` for the month matching the transaction's date (filtered by `year_month`). The selection is stored as `fixedExpenseId` on the transaction. This link indicates payment of the fixed expense — a fixed expense is considered "paid" when at least one transaction references it via `fixed_expense_id`. When the type is not `expense`, the selection is cleared before saving.

### 5.4 Currency and UserSettings Models (`data/model/Currency.kt`, `data/model/UserSettings.kt`)

```kotlin
@Serializable
data class Currency(
    val code: String,
    val name: String,
    val symbol: String,
    @SerialName("decimal_places") val decimalPlaces: Int,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class UserSettings(
    @SerialName("user_id") val userId: String,
    @SerialName("default_currency") val defaultCurrency: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)
```

### 5.5 Category, ScheduledTransaction, and Enum Models

**`data/model/Enums.kt`** — additional DB-aligned enums:

```kotlin
@Serializable
enum class RecurrenceType {
    @SerialName("monthly") MONTHLY,
}
```

**`data/model/Category.kt`:**

```kotlin
@Serializable
data class Category(
    val id: String,
    @SerialName("user_id") val userId: String,
    val name: String,
    val icon: String? = null,
    val color: String? = null,
    @SerialName("created_at") val createdAt: String,
)
```

> The `categories` table has `color` (not `type`). Category–transaction links use the `transaction_categories` junction table.

**`data/model/ScheduledTransaction.kt`:**

```kotlin
@Serializable
data class ScheduledTransaction(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("account_id") val accountId: String,
    val type: TransactionType,
    val amount: Long,
    val currency: String,
    val description: String? = null,
    val recurrence: RecurrenceType,
    @SerialName("next_due_date") val nextDueDate: String,
    @SerialName("is_active") val isActive: Boolean,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)
```

> The column is `recurrence` (not `recurrence_interval`) and `next_due_date` (not `next_occurrence`). There is no separate `pending_transactions` table — pending transactions are rows in `transactions` where `status = 'pending'`.

### 5.5 Fixed Expense Model (`data/model/FixedExpense.kt`)

```kotlin
@Serializable
data class FixedExpense(
    val id: String,
    @SerialName("user_id") val userId: String,
    val name: String,
    @SerialName("year_month") val yearMonth: String,
    val amount: Long,
    val currency: String,
    @SerialName("due_day") val dueDay: Int,
    @SerialName("is_active") val isActive: Boolean,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)
```

> Each row represents one fixed expense for one specific month. There is no separate periods table. Paid status is derived from linked transactions via `fixed_expense_id`.

#### Fixed Expense Operations

- **Copy from Previous Month:** Queries all `fixed_expenses` where `year_month` equals the previous month, then inserts new rows for the current month with the same `name`, `amount`, `currency`, `due_day`, and `is_active` values. Skips expenses that already exist for the current month (matched by `name` + `year_month`).
- **Edit:** Opens `FixedExpenseEditDialog.kt` to update `name`, `amount`, or `due_day` on an existing fixed expense row. Only the selected month's row is modified.
- **Delete:** Removes an individual fixed expense row for the selected month. Does not affect other months' rows or linked transactions (the `fixed_expense_id` FK on transactions should be set to `NULL` on delete).

### 5.6 Repository Example (`data/repository/AccountRepository.kt`)

```kotlin
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.Serializable
import javax.inject.Inject

class AccountRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    suspend fun getAll(): List<Account> {
        return client.from("accounts")
            .select {
                filter { eq("is_archived", false) }
                order("created_at", ascending = true)
            }
            .decodeList()
    }

    suspend fun create(name: String, type: AccountType, currency: String, startingBalance: Long): Account {
        val userId = client.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("Not authenticated")

        @Serializable
        data class Insert(
            @SerialName("user_id") val userId: String,
            val name: String,
            val type: AccountType,
            val currency: String,
            @SerialName("starting_balance") val startingBalance: Long,
        )

        val account = client.from("accounts")
            .insert(Insert(userId, name, type, currency, startingBalance)) {
                select()
            }
            .decodeSingle<Account>()

        // Create the initial monthly balance row for the current month
        val yearMonth = java.time.LocalDate.now().format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM"))
        client.from("account_monthly_balances")
            .insert(buildJsonObject {
                put("account_id", account.id)
                put("year_month", yearMonth)
                put("balance", startingBalance)
            })

        return account
    }

    suspend fun getCurrentBalance(accountId: String): Long {
        return client.from("account_monthly_balances")
            .select {
                filter { eq("account_id", accountId) }
                order("year_month", ascending = false)
                limit(1)
            }
            .decodeSingle<AccountMonthlyBalance>()
            .balance
    }

    suspend fun getMonthlyBalances(accountId: String): List<AccountMonthlyBalance> {
        return client.from("account_monthly_balances")
            .select {
                filter { eq("account_id", accountId) }
                order("year_month", ascending = true)
            }
            .decodeList()
    }

    suspend fun archive(id: String) {
        client.from("accounts")
            .update({ set("is_archived", true) }) {
                filter { eq("id", id) }
            }
    }

    fun observeChanges(): Flow<PostgresAction> {
        val channel = client.channel("accounts-realtime")
        return channel.postgresChangeFlow<PostgresAction>(schema = "public") {
            table = "accounts"
        }
    }
}
```

### 5.7 Currency Repository (`data/repository/CurrencyRepository.kt`)

```kotlin
class CurrencyRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    suspend fun getAllCurrencies(): List<Currency> {
        return client.from("currencies")
            .select {
                order("code", ascending = true)
            }
            .decodeList()
    }

    suspend fun getUserSettings(): UserSettings? {
        val userId = client.auth.currentUserOrNull()?.id ?: return null
        return try {
            client.from("user_settings")
                .select {
                    filter { eq("user_id", userId) }
                }
                .decodeSingleOrNull()
        } catch (e: Exception) {
            null
        }
    }

    suspend fun upsertDefaultCurrency(currencyCode: String): UserSettings {
        val userId = client.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("Not authenticated")

        @Serializable
        data class Upsert(
            @SerialName("user_id") val userId: String,
            @SerialName("default_currency") val defaultCurrency: String,
        )

        return client.from("user_settings")
            .upsert(Upsert(userId, currencyCode)) {
                select()
            }
            .decodeSingle()
    }
}
```

### 5.8 ViewModel Example (`ui/accounts/AccountListViewModel.kt`)

```kotlin
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AccountListUiState(
    val accounts: List<Account> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class AccountListViewModel @Inject constructor(
    private val repository: AccountRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(AccountListUiState())
    val uiState: StateFlow<AccountListUiState> = _uiState.asStateFlow()

    init {
        load()
        observeRealtime()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val accounts = repository.getAll()
                _uiState.value = _uiState.value.copy(accounts = accounts, isLoading = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(error = e.message, isLoading = false)
            }
        }
    }

    private fun observeRealtime() {
        viewModelScope.launch {
            repository.observeChanges().collect { load() }
        }
    }
}
```

---

## 6. Navigation (`ui/navigation/Screen.kt` + `FinManNavGraph.kt`)

### 6.1 Route Definitions

```kotlin
sealed class Screen(val route: String) {
    data object Login : Screen("login")
    data object Dashboard : Screen("dashboard")
    data object Accounts : Screen("accounts")
    data object AccountDetail : Screen("accounts/{accountId}") {
        fun createRoute(accountId: String) = "accounts/$accountId"
    }
    data object Transactions : Screen("transactions")
    data object TransactionForm : Screen("transactions/new")
    data object Budgets : Screen("budgets")
    data object FixedExpenses : Screen("fixed-expenses")
    data object Scheduled : Screen("scheduled")
    data object Settings : Screen("settings")
}
```

### 6.2 App Composable (`ui/FinManApp.kt`)

```kotlin
@Composable
fun FinManApp() {
    val navController = rememberNavController()
    val currentBackStack by navController.currentBackStackEntryAsState()
    val currentRoute = currentBackStack?.destination?.route

    val bottomBarScreens = listOf(
        Screen.Dashboard, Screen.Accounts, Screen.Transactions, Screen.Budgets
    )

    Scaffold(
        bottomBar = {
            if (currentRoute in bottomBarScreens.map { it.route }) {
                NavigationBar {
                    NavigationBarItem(
                        selected = currentRoute == Screen.Dashboard.route,
                        onClick = { navController.navigate(Screen.Dashboard.route) },
                        icon = { Icon(Icons.Default.PieChart, contentDescription = null) },
                        label = { Text("Dashboard") },
                    )
                    NavigationBarItem(
                        selected = currentRoute == Screen.Accounts.route,
                        onClick = { navController.navigate(Screen.Accounts.route) },
                        icon = { Icon(Icons.Default.CreditCard, contentDescription = null) },
                        label = { Text("Accounts") },
                    )
                    NavigationBarItem(
                        selected = currentRoute == Screen.Transactions.route,
                        onClick = { navController.navigate(Screen.Transactions.route) },
                        icon = { Icon(Icons.Default.List, contentDescription = null) },
                        label = { Text("Transactions") },
                    )
                    NavigationBarItem(
                        selected = currentRoute == Screen.Budgets.route,
                        onClick = { navController.navigate(Screen.Budgets.route) },
                        icon = { Icon(Icons.Default.TrackChanges, contentDescription = null) },
                        label = { Text("Budgets") },
                    )
                }
            }
        },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Dashboard.route,
            modifier = Modifier.padding(padding),
        ) {
            composable(Screen.Login.route) { LoginScreen(navController) }
            composable(Screen.Dashboard.route) { DashboardScreen(navController) }
            composable(Screen.Accounts.route) { AccountListScreen(navController) }
            composable(Screen.Transactions.route) { TransactionListScreen(navController) }
            composable(Screen.Budgets.route) { BudgetListScreen(navController) }
            composable(Screen.FixedExpenses.route) { FixedExpenseListScreen(navController) }
            composable(Screen.Scheduled.route) { ScheduledListScreen(navController) }
            // ... detail & form routes
        }
    }
}
```

---

## 7. Shared Utilities

### 7.1 Currency (`util/CurrencyUtils.kt`)

```kotlin
import java.text.NumberFormat
import java.util.Currency as JavaCurrency
import java.util.Locale

object CurrencyUtils {
    fun toMinorUnits(amount: Double, decimalPlaces: Int = 2): Long {
        val factor = Math.pow(10.0, decimalPlaces.toDouble())
        return (amount * factor).toLong()
    }

    fun toDisplayAmount(minorUnits: Long, decimalPlaces: Int = 2): Double {
        val factor = Math.pow(10.0, decimalPlaces.toDouble())
        return minorUnits / factor
    }

    fun format(minorUnits: Long, currency: String = "USD", decimalPlaces: Int = 2): String {
        val formatter = NumberFormat.getCurrencyInstance(Locale.US).apply {
            this.currency = JavaCurrency.getInstance(currency)
            minimumFractionDigits = decimalPlaces
            maximumFractionDigits = decimalPlaces
        }
        return formatter.format(toDisplayAmount(minorUnits, decimalPlaces))
    }
}
```

### 7.2 Year-Month (`util/DateUtils.kt`)

```kotlin
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.Locale

object DateUtils {
    private val yearMonthFormatter = DateTimeFormatter.ofPattern("yyyy-MM")
    private val displayFormatter = DateTimeFormatter.ofPattern("MMMM yyyy", Locale.US)

    fun currentYearMonth(): String = YearMonth.now().format(yearMonthFormatter)

    fun navigate(yearMonth: String, months: Long): String {
        val ym = YearMonth.parse(yearMonth, yearMonthFormatter)
        return ym.plusMonths(months).format(yearMonthFormatter)
    }

    fun formatYearMonth(yearMonth: String): String {
        val ym = YearMonth.parse(yearMonth, yearMonthFormatter)
        return ym.format(displayFormatter)
    }
}
```

---

## 8. UI / UX Guidelines

### 8.1 Month Navigation — Swipe + Page Animation

All screens that display a `MonthNavigator` (Dashboard, Transactions, Budgets, Fixed Expenses) must support **horizontal swipe gestures** to navigate between months. Use Compose's `detectHorizontalDragGestures` (from `Modifier.pointerInput`) on the screen-level content. Require the horizontal displacement to exceed a minimum threshold (~50 dp) and to be greater than the vertical displacement to avoid conflicting with vertical scroll. Swipe right → previous month; swipe left → next month.

**Page transition animation:** When the month changes, the content area below the `MonthNavigator` should perform a horizontal slide animation. Use `AnimatedContent` with `slideInHorizontally` / `slideOutHorizontally` transitions, keyed on `yearMonth`. The direction should match the navigation: navigating forward slides from the right, backward slides from the left.

**Adjacent-month prefetching:** Each ViewModel should maintain an in-memory cache (e.g., `Map<String, UiState>`) keyed by `year_month`. After loading the current month, prefetch `yearMonth - 1` and `yearMonth + 1` in background coroutines. On navigation, if the cache contains data for the target month, emit it immediately (skip the loading state) for an instant transition. Always re-fetch fresh data after applying cached data to keep it current.

### 8.2 Cash Flow Card Layout

`CashflowCard.kt` must use a **vertical stacked layout** — one row per metric (Income, Expense, Net) — with the label + icon on the left and the formatted amount on the right. Do **not** use a 3-column `Row` layout: currencies with long formatted values (e.g., IDR `Rp1.234.567`) cause text wrapping or truncation on narrow screens. Each amount `Text` should set `maxLines = 1` with `AutoSize` or `TextOverflow.Ellipsis` as a safety net.

---

## 9. Notifications

```kotlin
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NotificationService @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val channelId = "pending_transactions"

    init {
        val channel = NotificationChannel(
            channelId,
            "Pending Transactions",
            NotificationManager.IMPORTANCE_HIGH,
        )
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    fun showPendingTransaction(title: String, body: String) {
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(System.currentTimeMillis().toInt(), notification)
    }
}
```

---

## 10. Platform Configuration

### 10.1 AndroidManifest Permissions

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- P1: receipt scanning -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

### 10.2 Network Security (Development)

For connecting to local Supabase, create `res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
    </domain-config>
</network-security-config>
```

Reference in `AndroidManifest.xml`:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

Use `10.0.2.2` from the emulator to reach the host machine's `127.0.0.1`. On a physical device on the same Wi-Fi, use the machine's LAN IP instead.

### 10.3 ProGuard Rules

Add to `proguard-rules.pro` for Supabase + Ktor:

```proguard
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**
-keepattributes *Annotation*
-keepclassmembers class * {
    @kotlinx.serialization.Serializable *;
}
```

---

## 11. Build & Deployment

### 11.1 Run on Emulator

```bash
# Start emulator
emulator -avd Pixel_8_API_35

# Build and install
./gradlew installDebug
```

Or simply press **Run** in Android Studio.

### 11.2 Release Build

```bash
# Signed APK
./gradlew assembleRelease \
  -PSUPABASE_URL=https://xxx.supabase.co \
  -PSUPABASE_ANON_KEY=<prod-key>

# Signed App Bundle (for Play Store)
./gradlew bundleRelease \
  -PSUPABASE_URL=https://xxx.supabase.co \
  -PSUPABASE_ANON_KEY=<prod-key>
```

### 11.3 Signing Configuration

Create `keystore.properties` (git-ignored):

```properties
storeFile=../finman-release.jks
storePassword=<password>
keyAlias=finman
keyPassword=<password>
```

Reference in `app/build.gradle.kts`:

```kotlin
val keystoreProperties = java.util.Properties().apply {
    load(rootProject.file("keystore.properties").inputStream())
}

android {
    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### 11.4 Play Store Deployment

1. **Google Play Developer Account** ($25 one-time).
2. Create app in Google Play Console.
3. Upload the `.aab` from `app/build/outputs/bundle/release/`.
4. Complete store listing (screenshots, description, privacy policy).
5. Submit for review.

---

## 12. Testing Strategy

| Layer | Tool | What to Test |
|---|---|---|
| Unit | JUnit + MockK | Models, CurrencyUtils, DateUtils, repository logic (mocked Supabase) |
| ViewModel | JUnit + Turbine + MockK | State transitions, loading/error, UiState emissions |
| UI | Compose UI Test | Individual screens and components |
| Integration | Compose UI Test + Hilt | Full flows: login → add account → add transaction → verify dashboard |

```bash
# Unit tests
./gradlew test

# Instrumented tests
./gradlew connectedAndroidTest
```

Example test:

```kotlin
class CurrencyUtilsTest {
    @Test
    fun `toMinorUnits converts correctly`() {
        assertEquals(1050L, CurrencyUtils.toMinorUnits(10.50))
    }

    @Test
    fun `format produces currency string`() {
        assertEquals("$10.50", CurrencyUtils.format(1050L, "USD"))
    }
}
```

---

## 13. Development Workflow

```bash
# Terminal 1: Start local Supabase
cd financial-management
supabase start

# Android Studio: Run app on emulator
# Supabase URL is http://10.0.2.2:54321 by default in debug builds

# Local Supabase dashboard (manage test data)
open http://127.0.0.1:54323
```
