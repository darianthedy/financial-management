# Financial Management — iOS Build Prompts

> A sequenced set of **scoped, copy-paste-ready prompts** for implementing the iOS app
> described in **`Financial Management - Tech Plan - iOS.md`** (referred to below as
> "the iOS Tech Plan").
>
> Each prompt is meant to be handed to a coding agent (or a developer) **one at a time**,
> in order. Every prompt is self-contained enough to be actioned on its own, but later
> prompts assume the earlier ones are merged.

---

## How to use this document

1. Read **§0 Shared Context** once. It applies to *every* prompt — paste it (or link it)
   at the top of each task so the agent has the ground rules.
2. Work the prompts **in order** (P01 → P12). The dependency graph is linear with a few
   parallelizable leaves (noted per prompt).
3. After each prompt, the app should **compile and run**. Prompts are sized so that each
   one leaves the project in a buildable state.
4. P01–P10 are **P0 (MVP)**. P11 is **P1 (virtual installments)**. P12 is cross-cutting
   polish + tests and can be folded in incrementally.

### Source-of-truth documents

| Doc | Use for |
|---|---|
| `Financial Management - Tech Plan - iOS.md` | The canonical iOS spec. Section numbers below (§N) refer to it. |
| `Financial Management - System Design.md` | Schema, views, RPCs, business rules (the "why"). |
| `Financial Management - Tech Plan - Web.md` | Sibling implementation; same data/rules, different UI idiom. Use to resolve ambiguity. |
| `Financial Management - Test Cases.md` | Acceptance behavior for QA / test prompts. |
| `supabase/migrations/*` | The live schema. Verify column/table/RPC names here before writing queries. |

---

## ⚠️ About the existing `iOS/` folder — treat as OUTDATED

There is an existing Xcode project under
`iOS/FinancialManagement/`. **It was written against an older schema and an older version
of the plan. Do not trust it.** Reuse the *scaffolding* (xcodeproj, SPM resolution,
fastlane/TestFlight setup, folder layout) but rewrite the *code* to match the current iOS
Tech Plan + migrations.

Concretely, the existing code is wrong in these ways (non-exhaustive):

| Area | Existing (outdated) | Correct (per current plan + migrations) |
|---|---|---|
| Currency | Per-record `currency` column on `Account`, `BudgetPeriod`, etc. | **Single-currency.** No per-record currency. Format via `AppState.defaultCurrency` + `decimalPlaces`. (migration `20260606000001_drop_currency_columns`) |
| Budgets | `Budget` has `is_active` + `enable_carry_over`; separate `BudgetPeriod` table; carry-over stored | Flat self-contained `budgets` row per month (identity = `name`); **no periods table, no carry-over toggle**; carry-over computed live in `v_budget_progress` (migration `20260604000001_restructure_budgets`, `budget_description`) |
| Dashboard | `CashflowCard`, `BudgetProgressCard`, `SpendingByCategoryChart`, `RecentTransactionsCard` | Four widgets: `BudgetVerdictBanner`, `AccountsCard`, `PlannedExpensesCard`, `UnplannedExpensesCard` (§8.1) |
| Transactions filter | `FilterBar` — type-only chips | Rich tri-state multi-select filter sheet + summary, reading `v_transactions` (§8.3) |
| Accounts | No avatar, no `show_on_dashboard`, no default-account-in-settings | Storage-backed avatars (`account-images` bucket), `show_on_dashboard`, default account on `user_settings` (migrations `account_images`, `account_show_on_dashboard`, `user_settings_default_account`) |
| App state | Currency only; no `defaultAccountId`, no `decimalPlaces` | Full single-currency context (§4.3) |
| Installments | Absent | P1 virtual installments (§5.7, §8.8) |

**Files to delete outright** (legacy, no replacement):
`Models/BudgetPeriod.swift`,
`Views/Dashboard/CashflowCard.swift`,
`Views/Dashboard/BudgetProgressCard.swift`,
`Views/Dashboard/SpendingByCategoryChart.swift`,
`Views/Dashboard/RecentTransactionsCard.swift`,
`Views/Transactions/FilterBar.swift`.
(`Views/Shared/CurrencyPicker.swift` should be **moved/renamed** to a Settings-only
`CurrencyPickerView` per §3 note.)

When a prompt says "create X", if a stale version of X already exists, **replace its
contents wholesale** rather than patching around the old design.

---

## §0 Shared Context (paste into every prompt)

> **Project:** Native iOS app (Swift 5.10+, SwiftUI, iOS 17+) for the "Financial
> Management" product, backed by Supabase (Auth, PostgREST, Realtime, Storage) via the
> `supabase-swift` SDK. Canonical spec: `Financial Management - Tech Plan - iOS.md`;
> data model/rules: `Financial Management - System Design.md`; live schema:
> `supabase/migrations/`.
>
> **Architecture:** MVVM. `@Observable @MainActor` ViewModels; `actor` Repositories that
> wrap a shared `SupabaseClient` (`SupabaseService.shared.client`); SwiftUI Views;
> plain `Codable, Sendable` model structs with explicit `CodingKeys` mapping snake_case
> DB columns → camelCase Swift.
>
> **Non-negotiable rules:**
> - **Single-currency.** There is **no** per-record currency column anywhere. All money
>   formatting uses `AppState.defaultCurrency` and its `decimalPlaces`. The only currency
>   picker is in Settings.
> - **Money is `Int64` minor units** end to end. Convert only at the formatting edge.
> - **Budgets:** identity is `name`; one row per `(user_id, name, year_month)`; carry-over
>   is always on and **computed live** in `v_budget_progress` — never stored, no toggle.
>   Read display numbers from `v_budget_progress`; write to the `budgets` table.
> - **Transactions:** single `category_id` (no junction); many-to-many tags via
>   `transaction_tags`; `budget_id` is a direct FK; `date` column (not `transaction_date`);
>   `transfer_account_id` (not `to_account_id`). Amount sign rules: income/expense may be
>   negative; transfers must be positive; zero never allowed.
> - **Verify every table/column/view/RPC name against `supabase/migrations/` before
>   querying.** Do not invent columns.
>
> **The existing `iOS/` code is outdated** (old schema). Reuse the Xcode project shell,
> but rewrite code to match the current plan. See the "About the existing iOS folder"
> section of the Build Prompts doc.
>
> **Definition of done for every prompt:** the project builds (`xcodebuild` Dev scheme),
> no leftover references to deleted legacy types, and the slice matches the cited Tech Plan
> sections. Keep changes scoped to the prompt; don't pre-build later slices.

---

# Phase P0 — MVP

## P01 — Foundation: config, client, app state, navigation shell, auth

**Goal:** A runnable skeleton: app launches, single-currency context loads after sign-in,
tab navigation renders, login works. Everything else is empty stubs.

**Tech Plan refs:** §1, §2, §3 (structure), §4 (client + AppState), §6 (navigation),
§7 (utilities), §11 (Info.plist / xcconfig / schemes).

**Scope — create/replace:**
- `App/AppConfig.swift` — reads `SUPABASE_URL` / `SUPABASE_ANON_KEY` from Info.plist (§2.3).
- `Config/Dev.xcconfig`, `Config/Prod.xcconfig` (git-ignored) + `.gitignore` entry; wire
  Info.plist keys and Dev/Prod schemes (§2.3, §11.3). Add `NSAllowsLocalNetworking` (dev)
  and the `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription` strings (§11.1–11.2).
- `Services/SupabaseService.swift` — singleton client (§4.1).
- `App/FinancialManagementApp.swift` — `@main`, root auth switch (§4.2).
- `App/AppState.swift` — **full single-currency context**: `isAuthenticated`, `currentUser`,
  `defaultCurrency`, `defaultAccountId`, `currencies`, computed `decimalPlaces`,
  `observeAuthState()`, `loadCurrencyData()` (§4.3). (Replace the outdated 62-line version.)
- `Models/Enums.swift` (`AccountType`, `TransactionType`, `TransactionStatus`,
  `RecurrenceType`) (§5.5), `Models/Currency.swift`, `Models/UserSettings.swift` (§5.4).
- `Repositories/CurrencyRepository.swift` (§5.10).
- `Utilities/CurrencyUtils.swift`, `Utilities/DateUtils.swift`,
  `Utilities/Extensions/{Date+YearMonth,Int+Currency}.swift` (§7).
- `Views/Shared/ContentRootView.swift` (TabView, 5 tabs) + `Views/More/MoreView.swift` (§6).
  Other tabs point at minimal placeholder views for now.
- `Views/Auth/LoginView.swift` + `ViewModels/AuthViewModel.swift` (email/password sign-in).
- `Views/Shared/EmptyStateView.swift`.

**Out of scope:** real feature screens (stub them), pickers, realtime.

**Acceptance:**
- Cold launch shows `LoginView`; after sign-in, `AppState.currencies` and user settings load
  and `ContentRootView` appears with 5 tabs.
- `decimalPlaces` reflects the chosen `defaultCurrency`.
- `CurrencyUtils.format(1050, currency:"USD", decimalPlaces:2) == "$10.50"`.

---

## P02 — Accounts (model, repo, list/detail, form) + default account plumbing

**Goal:** Full Accounts feature *except* avatar images (that's P03). Net-worth header,
list, detail (transactions placeholder ok), add/edit/archive, `show_on_dashboard` toggle,
set-as-default-account toggle.

**Tech Plan refs:** §5.1, §5.8 (`AccountRepository`), §5.11 (`AccountListViewModel`), §8.2.

**Depends on:** P01.

**Scope — create/replace:**
- `Models/Account.swift` — **drop `currency`**, add `imageUrl: String?` and
  `showOnDashboard: Bool`; keep `AccountMonthlyBalance` (§5.1).
- `Repositories/AccountRepository.swift` — `getAll`, `create` (seeds current-month balance
  row), `getCurrentBalance` (latest ledger row), `update`, `archive` (§5.8). Default-account
  read/write goes through `CurrencyRepository.updateDefaultAccountId` (§5.10).
- `ViewModels/AccountListViewModel.swift` (load + realtime subscribe, §5.11),
  `ViewModels/AccountDetailViewModel.swift`.
- `Views/Accounts/AccountListView.swift` (net-worth header + total),
  `AccountCard.swift`, `AccountDetailView.swift`,
  `AccountFormSheet.swift` (name, type, starting balance, **Show on dashboard** toggle,
  **Set as default account** toggle) (§8.2).

**Out of scope:** avatar upload/`AccountAvatar`/`AccountImageService` (P03). Form shows the
type-based SF Symbol only for now.

**Acceptance:**
- List shows non-archived accounts with current balance + a net-worth total header.
- Create seeds an `account_monthly_balances` row for the current month.
- Archive hides the account but keeps history; default-account toggle writes
  `user_settings.default_account_id` (only one at a time).

---

## P03 — Account avatars (Supabase Storage)

**Goal:** Layer image avatars onto Accounts: pick → downscale → WebP → upload to the public
`account-images` bucket → store public URL; fallback to type icon; best-effort cleanup.

**Tech Plan refs:** §2.2 (PhotosUI, Storage), §8.2 ("Account avatars"); System Design §4.10;
migration `20260607000002_account_images.sql`.

**Depends on:** P02.

**Scope — create:**
- `Services/AccountImageService.swift` — resize ≤256px, encode WebP, upload to
  `account-images` at `{user_id}/{uuid}.webp`, return public URL; best-effort delete of the
  previous object **after** the row save succeeds.
- `Views/Accounts/AccountAvatar.swift` — renders `image_url` else `AccountType.defaultIcon`.
- Update `AccountFormSheet` to use `PhotosPicker` (stage locally, upload on submit) with
  upload/remove; update `AccountCard`/`AccountDetailView` to use `AccountAvatar`.

**Acceptance:**
- Picking an image and saving uploads a small WebP and persists `accounts.image_url`.
- Replacing/removing deletes the old object best-effort; cancelling never orphans a file.
- Nil `image_url` falls back to the type icon.

---

## P04 — Transactions: model, repo, add/edit form, row, confirm/dismiss

**Goal:** Create/edit/list transactions with correct field model and pickers; inline
confirm/dismiss for pending. (Rich filtering + summary is P05.)

**Tech Plan refs:** §5.3 (model + form fields + sign rules), §8.3 (minus 8.3.1/8.3.2);
migrations `20260509000007_create_transactions`, `20260612000001_allow_signed_amounts`,
`20260607000001_categories_single_select`.

**Depends on:** P02 (accounts/pickers), P06 budgets picker can stub until P06 lands — see note.

**Scope — create/replace:**
- `Models/Transaction.swift` (§5.3), `Models/Category.swift`, `Models/Tag.swift` (§5.5).
- `Repositories/TransactionRepository.swift` — list (paginated) for an account/month, create,
  update, confirm/dismiss status change, tag junction writes (`transaction_tags`).
- `ViewModels/TransactionFormViewModel.swift`, basic `TransactionListViewModel` (account/month
  scoped; full filter state comes in P05).
- `Views/Transactions/TransactionFormView.swift` (all fields per §5.3 table; enforce sign
  rules; clear budget for transfers, clear fixed-expense unless expense),
  `TransactionRow.swift` (reuses linked account image), `TransactionListView.swift`.
- Shared pickers: `Views/Shared/CategoryPicker.swift` (single-select),
  `TagPicker.swift` (multi), `AccountPicker.swift`, `BudgetPicker.swift` (reads
  `v_budget_progress` for the txn's month; inline "create budget" option),
  `FixedExpensePicker.swift` (reads `fixed_expenses` for the txn's month).

> **Note on picker dependencies:** `BudgetPicker` reads `v_budget_progress` and
> `FixedExpensePicker` reads `fixed_expenses` — both views/tables already exist in the DB,
> so the pickers can be built now even though the Budgets (P06) and Fixed Expenses (P07)
> *screens* aren't done yet.

**Acceptance:**
- Income/expense allow negative amounts; transfers forced positive; zero rejected.
- Transfer requires `transfer_account_id` and nulls `budget_id`; fixed-expense link only on
  expense; single category; multiple tags persist via junction.
- Pending rows confirm/dismiss inline; default account pre-selected on new txn.

---

## P05 — Transactions: filter sheet, chips, summary, pagination

**Goal:** The full filter/search/summary experience over `v_transactions` with
tri-state multi-select facets and AND-across/OR-within semantics.

**Tech Plan refs:** §8.3.1, §8.3.2, §9.2 (money row layout); System Design §4.9;
migration `20260612000001_v_transactions.sql`.

**Depends on:** P04.

**Scope — create/replace:**
- `Utilities/TransactionFilters.swift` — filter model + serialization + a single
  `applyFilters(_:to:)` predicate builder shared by list and summary (so they can't drift).
- `Views/Shared/MultiSelectFacet.swift` — reusable tri-state multi-select (absent / set /
  empty-set) with leading "(Blanks)" option where applicable.
- `Views/Transactions/TransactionFilterSheet.swift` (all facets per the §8.3.1 table),
  `TransactionSummarySheet.swift` (income/expense/net/transfers/count/largest + collapsible
  breakdowns; vertical stacked money rows per §9.2).
- Extend `TransactionListViewModel`: holds `TransactionFilters`, queries `v_transactions`
  with `.range()` + `count: .exact`; active-filter chips with Clear all + match count;
  selectable page size (25/50/100/200).

**Acceptance:**
- Each facet is tri-state; budget/fixed filters resolve **by name** to ids (budgets via
  `v_budget_progress`, fixed via `fixed_expenses`), scoped to the active date range.
- "(Blanks)" matches null-value rows; a chosen-but-unresolved facet yields empty results.
- Summary uses confirmed rows only; pending shown as separate projection; transfers
  reported as in/out. Long IDR amounts don't wrap (lineLimit(1)+minimumScaleFactor).

---

## P06 — Budgets

**Goal:** Month-scoped budget list with live carry-over from `v_budget_progress`;
add/edit/remove/copy-from-previous-month.

**Tech Plan refs:** §5.2 (`Budget` + `BudgetProgress`), §5.9 (`BudgetRepository`), §8.4;
System Design §4.1–4.2; migrations `20260604000001_restructure_budgets`,
`20260613000001_budget_description`.

**Depends on:** P04 (so tapping a budget can deep-link into the filtered transaction list).

**Scope — create/replace:**
- `Models/Budget.swift` (**replace** outdated `is_active`/`enable_carry_over` version with the
  flat row, §5.2), `Models/BudgetProgress.swift` (view read model, §5.2). Delete
  `Models/BudgetPeriod.swift`.
- `Repositories/BudgetRepository.swift` (**replace**): `progress(yearMonth:)` from
  `v_budget_progress`, `add`, `copyFromPreviousMonth(into:)`, `update`, `remove` (§5.9).
- `ViewModels/BudgetListViewModel.swift` (month-scoped, realtime).
- `Views/Budgets/BudgetListView.swift`, `BudgetCard.swift` (effective amount, carry-in badge,
  reserved line placeholder for P11, overspent danger styling),
  `BudgetFormSheet.swift` (name, monthly amount, note — **no carry-over toggle**) (§8.4).

**Acceptance:**
- Cards show net spent vs effective (periodic + carry-in) read from the view.
- Add inserts one row; remove deletes that month's row (gap resets carry-over); copy skips
  names already present in the target month; editing an earlier month re-flows later months.
- Tapping a budget opens Transactions filtered to that budget **name**, scoped to its month.

---

## P07 — Fixed Expenses

**Goal:** Month-scoped fixed expenses with derived paid/unpaid status; copy/edit/delete/add.

**Tech Plan refs:** §5.6 (model + operations), §8.5; migrations
`20260509000005_create_fixed_expenses`, `20260510100000_merge_fixed_expense_periods`,
`20260610000001_drop_fixed_expense_due_day`.

**Depends on:** P04.

**Scope — create/replace:**
- `Models/FixedExpense.swift` (§5.6 — no `currency`, no `isPaid`; paid is derived).
- `Repositories/FixedExpenseRepository.swift` — list for month, add, edit (single month),
  delete (single month), copy-from-previous-month (skip existing names), paid lookup via
  linked `transactions.fixed_expense_id`.
- `ViewModels/FixedExpenseListViewModel.swift`.
- `Views/FixedExpenses/FixedExpenseListView.swift` (unpaid/paid split + subtotals),
  `FixedExpenseRow.swift`, `FixedExpenseFormSheet.swift`, `FixedExpenseEditSheet.swift` (§8.5).

**Acceptance:**
- Paid = at least one transaction references the row; no standalone "mark paid" toggle.
- Edit/delete affect only the selected month; copy preserves name/amount/is_active and skips
  duplicates (UNIQUE `user_id,name,year_month`).

---

## P08 — Dashboard (four widgets)

**Goal:** Month-scoped dashboard composed of the four current widgets, fetched in parallel,
refreshed on realtime. Removes all legacy cards.

**Tech Plan refs:** §8.1; System Design §4.3/§4.6 (balances), §4.9; migrations
`20260614000001_account_balances_at` (`fn_account_balances_at`),
`20260617000001_account_show_on_dashboard`.

**Depends on:** P02/P03 (accounts), P05 (transactions/v_transactions), P06 (budgets),
P07 (fixed expenses).

**Scope — create/replace:**
- Delete legacy `CashflowCard`, `BudgetProgressCard`, `SpendingByCategoryChart`,
  `RecentTransactionsCard`.
- `Repositories/DashboardRepository.swift` (**replace**) — parallel fetches for the 4 widgets
  incl. `.rpc("fn_account_balances_at", ["p_year_month": ym])`.
- `ViewModels/DashboardViewModel.swift` (**replace**) — parallel load per `year_month`,
  realtime on `transactions`, `budgets`, `fixed_expenses`, `accounts`,
  `account_monthly_balances`.
- `Views/Dashboard/DashboardView.swift` (**replace**) +
  `BudgetVerdictBanner.swift`, `AccountsCard.swift`, `PlannedExpensesCard.swift`,
  `UnplannedExpensesCard.swift` (§8.1).

**Acceptance:**
- Verdict banner counts `remaining < 0` budgets + sums overage; hidden when no budgets.
- Accounts card honors `is_archived = false AND show_on_dashboard = true`, uses
  `fn_account_balances_at` (fallback to `starting_balance`), shows per-account + total.
- Planned card: pace-aware budget bars + fixed-expense paid/unpaid subtotals; Unplanned card:
  confirmed expenses with `budget_id IS NULL AND fixed_expense_id IS NULL`, grouped by category.

---

## P09 — Scheduled transactions + Notifications

**Goal:** Scheduled list + pending-transactions section with confirm/edit/dismiss; local
notifications when pending transactions appear.

**Tech Plan refs:** §5.5 (`ScheduledTransaction`), §8.7, §10; System Design §4.5; migrations
`20260509000006_create_scheduled_transactions`, `20260608000001_scheduled_transaction_details`,
`20260606000002_schedule_pending_transactions`, `20260611000001_scheduled_transaction_fixed_expense`.

**Depends on:** P04.

**Scope — create/replace:**
- `Models/ScheduledTransaction.swift` (§5.5 — `recurrence`, `next_due_date`).
- `Repositories/ScheduledTransactionRepository.swift` — list active scheduled + pending
  (`transactions.status = 'pending'`).
- `ViewModels/ScheduledTransactionViewModel.swift`.
- `Views/Scheduled/ScheduledListView.swift`, `PendingTransactionRow.swift`.
- `Services/NotificationService.swift` (`UNUserNotificationCenter`, §10) + permission request.

**Acceptance:**
- Active scheduled list shows next due date; pending section confirms/edits/dismisses.
- Notification permission requested; a local notification fires for new pending txns.

---

## P10 — Settings (default currency + default account)

**Goal:** Settings screen wiring the single-currency default and the default account.

**Tech Plan refs:** §8.6, §3 note (CurrencyPickerView lives only in Settings); §5.10;
migrations `20260509000013_create_currencies`, `20260509000015_seed_currencies`,
`20260610000001_user_settings_default_account`.

**Depends on:** P01, P02.

**Scope — create/replace:**
- Move/rename `Views/Shared/CurrencyPicker.swift` → `Views/Settings/CurrencyPickerView.swift`
  (searchable list from `currencies`).
- `Views/Settings/SettingsView.swift` (default currency picker + default account picker),
  `ViewModels/SettingsViewModel.swift`.
- On currency change, upsert `user_settings.default_currency` and have `AppState` reload so
  every formatter/form picks up the new currency + decimals. Wire into `MoreView`.

**Acceptance:**
- Changing default currency re-formats amounts app-wide (and updates `decimalPlaces`).
- Default account writes `user_settings.default_account_id` and pre-selects on new txns.

---

# Phase P1 — Enhancements

## P11 — Virtual installments (spread an expense across budgets)

**Goal:** Reserve future budget allowance for a large already-recorded expense, budget-side
only (no new transactions, no balance impact), via the `spread_existing_transaction` RPC.

**Tech Plan refs:** §5.7 (models), §8.8 (flow + surfacing); System Design §4.11; migrations
`20260618000001_budget_installments`, `20260618000002_spread_existing_transaction`,
`20260618000003_installment_category_tags`.

**Depends on:** P05, P06.

**Scope — create:**
- `Models/BudgetInstallment.swift` (header + `BudgetInstallmentAllocation`, §5.7).
- `Repositories/InstallmentRepository.swift` — `.rpc("spread_existing_transaction", …)`,
  batched lookup by `source_transaction_id`, cancel (delete header → cascade).
- `Views/Transactions/CreateInstallmentSheet.swift` — start month, budget-name multi-select,
  months stepper, allocation grid with even pre-fill + "Split evenly" + save-gated-on-exact-sum
  (§8.8).
- Surfacing: `TransactionRow` "Create virtual installment" action (expense + not already
  spread only) + grid indicator; `BudgetCard` "Reserved $X" line + negative-remaining
  rendering; `Views/Budgets/ActiveInstallmentsSection.swift`.

**Acceptance:**
- Action shows only for un-spread expenses; second spread rejected by RPC.
- Grid pre-fills even split, save disabled until grid total == expense amount; submit nulls
  the source `budget_id`, keeps category/tags/fixed link, ensures budget rows exist, inserts
  header + non-zero allocations.
- `v_budget_progress.reserved`/`remaining` reflect reservations; cancel/delete recovers
  future allowance.

---

## P12 — Cross-cutting polish + tests

**Goal:** Apply the UX guidelines uniformly and add the test suite. Can be folded in
incrementally rather than as one big task.

**Tech Plan refs:** §9.1 (swipe + page transition + prefetch), §9.2 (money rows), §13 (tests).

**Depends on:** the screens it touches.

**Scope:**
- `Views/Shared/MonthNavigator.swift`: `.swipeToNavigateMonth`, `.monthPageTransition`,
  `.contentTransition(.numericText())`; per-VM adjacent-month prefetch cache + animated
  `navigateMonth(by:)` (§9.1). Apply to Dashboard, Transactions, Budgets, Fixed Expenses.
- Audit multi-metric cards for the vertical stacked money-row layout (§9.2).
- Tests (§13): unit (Codable round-trips, `CurrencyUtils`, `DateUtils`, `applyFilters`
  predicate building, even-split grid math), repository (reads come from `v_budget_progress`),
  ViewModel (state/filter/pager/prefetch), and a happy-path XCUITest
  (login → add account → add transaction → verify dashboard).

**Acceptance:**
- Swipe + animated month paging work on all four month-scoped screens with prefetch.
- `xcodebuild test` (Dev scheme) passes the unit/VM suites.

---

## Dependency graph (quick reference)

```
P01 ─┬─ P02 ─┬─ P03 ───────────────┐
     │       └─ P10 (Settings)     │
     │                             │
     ├─ P04 ─┬─ P05 ───────────────┼─ P08 (Dashboard) ─ P12 (polish/tests)
     │       ├─ P06 ───────────────┤        │
     │       ├─ P07 ───────────────┘        │
     │       └─ P09 (Scheduled)             │
     │                                      │
     └────────── P05 + P06 ─ P11 (Installments, P1)
```

> **Suggested order:** P01 → P02 → P03 → P04 → P05 → P06 → P07 → P08 → P09 → P10
> (MVP complete) → P11 → P12. P03, P09, and P10 are leaves that can be reordered or
> parallelized once their parents are in.
