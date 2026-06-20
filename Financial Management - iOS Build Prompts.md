# Financial Management — iOS Build Prompts

> Sequenced, **self-contained** prompts for building the iOS app from
> **`Financial Management - Tech Plan - iOS.md`** (the "iOS Tech Plan").
>
> Each prompt is meant to be pasted into its **own fresh Claude Code session**, run against
> the `financial-management` repo. Each prompt carries the rules it needs inline, so you do
> **not** have to also paste §0 — though §0 remains the canonical master copy.

---

## How to use this document

1. Open a new session **in the `financial-management` repo** (so Claude can read the plan,
   schema, and existing scaffolding).
2. Copy the prompt's **Run** line (and only that line). It tells Claude what to read and
   what to build. Everything else in the prompt is there for Claude to read in the file.
3. Do prompts **in order**, **one per session**. Review → commit → next. Don't run two at
   once; the whole point of the split is to keep each session's context tight.
4. After each prompt the app should build (Dev scheme). P01–P10 = **P0 (MVP)**,
   P11 = **P1**, P12 = polish + tests.

### Why one prompt per session
A fresh session starts cold and re-reads the plan, which is fine and intended. Trying to do
several prompts in one session burns context and quality drops. Keep it to one slice.

### Source-of-truth files (Claude should read these as needed)
- `Financial Management - Tech Plan - iOS.md` — canonical iOS spec; `§N` refs point here.
- `Financial Management - System Design.md` — schema/views/RPCs/business rules (the "why").
- `Financial Management - Tech Plan - Web.md` — sibling app; use to break ties.
- `supabase/migrations/*` — the **live schema**. Always verify table/column/view/RPC names here.

---

## ⚠️ The existing `iOS/` folder is OUTDATED — reuse the shell, rewrite the code

`iOS/FinancialManagement/` exists but was written against an **older schema**. Keep the
project scaffolding (xcodeproj, SPM resolution, fastlane/TestFlight, folder layout); rewrite
the Swift code. When a prompt says "create X" and a stale X exists, **replace it wholesale**.

| Area | Existing (wrong) | Correct (current plan + migrations) |
|---|---|---|
| Currency | per-record `currency` columns | **single-currency**, no per-record currency (`drop_currency_columns`) |
| Budgets | `is_active`/`enable_carry_over`, `BudgetPeriod` table, stored carry-over | flat `budgets` row per month, identity=`name`, carry-over live in `v_budget_progress` (`restructure_budgets`) |
| Dashboard | Cashflow/BudgetProgress/SpendingByCategory/RecentTransactions cards | 4 widgets: Verdict/Accounts/Planned/Unplanned (§8.1) |
| Txn filter | `FilterBar` (type-only) | tri-state multi-select sheet + summary over `v_transactions` (§8.3) |
| Accounts | no avatar / `show_on_dashboard` / default-in-settings | Storage avatars, `show_on_dashboard`, default on `user_settings` |
| Installments | absent | P1 virtual installments (§5.7, §8.8) |

**Delete outright:** `Models/BudgetPeriod.swift`, `Views/Dashboard/{CashflowCard,
BudgetProgressCard, SpendingByCategoryChart, RecentTransactionsCard}.swift`,
`Views/Transactions/FilterBar.swift`. **Move/rename** `Views/Shared/CurrencyPicker.swift`
→ `Views/Settings/CurrencyPickerView.swift`.

---

## §0 Shared Context (canonical rules — already inlined into each prompt below)

> **Project:** Native iOS (Swift 5.10+, SwiftUI, iOS 17+), backed by Supabase (Auth,
> PostgREST, Realtime, Storage) via `supabase-swift`.
>
> **Architecture (MVVM):** `@Observable @MainActor` ViewModels · `actor` Repositories
> wrapping `SupabaseService.shared.client` · SwiftUI Views · `Codable, Sendable` model
> structs with explicit `CodingKeys` mapping snake_case → camelCase.
>
> **Non-negotiable rules:**
> 1. **Single-currency** — no per-record currency column anywhere; format via
>    `AppState.defaultCurrency` + `decimalPlaces`; the only currency picker is in Settings.
> 2. **Money = `Int64` minor units** end to end; convert only at the formatting edge.
> 3. **Budgets** — identity = `name`; one row per `(user_id, name, year_month)`; carry-over
>    always on, **computed live in `v_budget_progress`**, never stored, no toggle. Read
>    numbers from the view; write to the `budgets` table.
> 4. **Transactions** — single `category_id` (no junction); tags many-to-many via
>    `transaction_tags`; `budget_id` direct FK; column is `date` (not `transaction_date`);
>    `transfer_account_id` (not `to_account_id`). Amounts: income/expense may be negative,
>    transfers must be positive, zero never allowed.
> 5. **Verify every table/column/view/RPC against `supabase/migrations/`** before querying.
> 6. **Existing `iOS/` code is outdated** — reuse the project shell, rewrite the code.
>
> **Done = builds (Dev scheme) + no references to deleted legacy types + matches cited §§ +
> scope not exceeded.**

---

> **Per-prompt template:** **Run** = the line you paste. **Read first** = what Claude opens.
> **Build** = files to create/replace. **Rules in play** = the inlined non-negotiables for
> this slice. **Out of scope** = leave for later. **Done when** = acceptance checks.

---

# Phase P0 — MVP

## P01 — Foundation: config, client, app state, navigation, auth

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P01**, and
> `Financial Management - Tech Plan - iOS.md` §1–§7 + §11. Then implement P01 exactly as
> scoped: build the runnable skeleton (config, Supabase client, single-currency `AppState`,
> tab navigation, login), stub the feature tabs. Build the Dev scheme before finishing.
> Treat existing `iOS/` code as outdated — replace stale files wholesale.

**Read first:** iOS Tech Plan §1, §2, §3, §4, §6, §7, §11; `supabase/migrations/` for
`currencies` and `user_settings` columns.

**Build (create/replace):**
- `App/AppConfig.swift` — read `SUPABASE_URL`/`SUPABASE_ANON_KEY` from Info.plist (§2.3).
- `Config/Dev.xcconfig` + `Config/Prod.xcconfig` (git-ignored); wire Info.plist + Dev/Prod
  schemes (§2.3, §11.3); add `NSAllowsLocalNetworking` (dev) and the photo/camera usage
  strings (§11.1–11.2).
- `Services/SupabaseService.swift` (singleton client, §4.1).
- `App/FinancialManagementApp.swift` (`@main`, auth switch, §4.2).
- `App/AppState.swift` — **full** single-currency context: `isAuthenticated`, `currentUser`,
  `defaultCurrency`, `defaultAccountId`, `currencies`, computed `decimalPlaces`,
  `observeAuthState()`, `loadCurrencyData()` (§4.3). Replace the outdated version.
- `Models/Enums.swift`, `Models/Currency.swift`, `Models/UserSettings.swift` (§5.4–5.5).
- `Repositories/CurrencyRepository.swift` (§5.10).
- `Utilities/CurrencyUtils.swift`, `DateUtils.swift`,
  `Utilities/Extensions/{Date+YearMonth,Int+Currency}.swift` (§7).
- `Views/Shared/ContentRootView.swift` (5-tab TabView), `Views/More/MoreView.swift` (§6),
  `Views/Shared/EmptyStateView.swift`; feature tabs = minimal placeholders.
- `Views/Auth/LoginView.swift`, `ViewModels/AuthViewModel.swift` (email/password sign-in).

**Rules in play:** single-currency (`AppState.defaultCurrency` + `decimalPlaces` drive all
formatting; currency picker only in Settings). Money is `Int64` minor units.
`@Observable @MainActor` VMs, `actor` repos, explicit `CodingKeys`.

**Out of scope:** real feature screens (stub them), pickers, realtime, avatars.

**Done when:** cold launch → `LoginView`; after sign-in, `currencies` + user settings load
and the 5-tab shell appears; `decimalPlaces` tracks `defaultCurrency`;
`CurrencyUtils.format(1050, currency:"USD", decimalPlaces:2) == "$10.50"`; Dev scheme builds.

---

## P02 — Accounts (model, repo, list/detail, form) + default-account plumbing

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P02**, and
> `Financial Management - Tech Plan - iOS.md` §5.1, §5.8, §5.11, §8.2. Implement the
> Accounts feature **except avatar images** (that's P03). Build the Dev scheme before
> finishing. Replace any stale account files wholesale.

**Read first:** iOS Tech Plan §5.1, §5.8, §5.11, §8.2; migrations
`account_show_on_dashboard`, `monthly_balance_ledger`, `user_settings_default_account`.

**Build (create/replace):**
- `Models/Account.swift` — **drop `currency`**, add `imageUrl: String?`,
  `showOnDashboard: Bool`; keep `AccountMonthlyBalance` (§5.1).
- `Repositories/AccountRepository.swift` — `getAll`, `create` (seeds current-month
  `account_monthly_balances` row), `getCurrentBalance` (latest ledger row), `update`,
  `archive` (§5.8). Default account via `CurrencyRepository.updateDefaultAccountId` (§5.10).
- `ViewModels/AccountListViewModel.swift` (load + realtime, §5.11),
  `AccountDetailViewModel.swift`.
- `Views/Accounts/AccountListView.swift` (net-worth total header), `AccountCard.swift`,
  `AccountDetailView.swift`, `AccountFormSheet.swift` (name, type, starting balance,
  **Show on dashboard** toggle, **Set as default account** toggle) (§8.2).

**Rules in play:** single-currency (no `currency` field on accounts). Current balance is
**never stored on the account** — read the latest `account_monthly_balances` row. Default
account lives on `user_settings.default_account_id` (one at a time), not on the account row.
Archive = soft-delete (preserve history).

**Out of scope:** avatar upload / `AccountAvatar` / `AccountImageService` (P03) — show the
type-based SF Symbol for now.

**Done when:** list shows non-archived accounts + balances + net-worth header; create seeds
a month balance row; archive hides but keeps history; default toggle writes
`user_settings.default_account_id`; Dev scheme builds.

---

## P03 — Account avatars (Supabase Storage)

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P03**, iOS
> Tech Plan §2.2 + §8.2 ("Account avatars"), System Design §4.10, and migration
> `20260607000002_account_images.sql`. Add Storage-backed account avatars onto the existing
> Accounts feature. Build the Dev scheme before finishing.

**Read first:** iOS Tech Plan §2.2, §8.2; System Design §4.10; migration `account_images`.

**Build (create):**
- `Services/AccountImageService.swift` — resize ≤256px → WebP → upload to **public**
  `account-images` bucket at `{user_id}/{uuid}.webp` → return public URL; best-effort delete
  of the previous object **after** the row save succeeds.
- `Views/Accounts/AccountAvatar.swift` — render `image_url`, else `AccountType.defaultIcon`.
- Update `AccountFormSheet` to use `PhotosPicker` (stage locally, upload on submit, with
  remove); use `AccountAvatar` in `AccountCard`/`AccountDetailView`/transaction rows later.

**Rules in play:** images are a few KB (downsize + WebP). Bucket is public; store the public
URL in `accounts.image_url`. Cancelling the form must never orphan an uploaded file.

**Out of scope:** changing account fields/queries beyond `image_url`.

**Done when:** pick+save uploads a small WebP and persists `image_url`; replace/remove deletes
the old object best-effort; nil URL falls back to the type icon; Dev scheme builds.

---

## P04 — Transactions: model, repo, add/edit form, row, confirm/dismiss

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P04**, and iOS
> Tech Plan §5.3, §5.5, §8.3 (excluding §8.3.1/§8.3.2). Implement transaction create/edit/list
> with correct fields, the shared pickers, and inline confirm/dismiss. Rich filtering/summary
> is P05 — do not build it. Build the Dev scheme before finishing.

**Read first:** iOS Tech Plan §5.3, §5.5, §8.3; migrations `create_transactions`,
`allow_signed_amounts`, `categories_single_select`, `create_junction_tables`.

**Build (create/replace):**
- `Models/Transaction.swift` (§5.3), `Models/Category.swift`, `Models/Tag.swift` (§5.5).
- `Repositories/TransactionRepository.swift` — paginated list (account/month scoped), create,
  update, status change (confirm/dismiss), tag writes via `transaction_tags`.
- `ViewModels/TransactionFormViewModel.swift`; basic `TransactionListViewModel`
  (account/month scope only — full filter state is P05).
- `Views/Transactions/TransactionFormView.swift` (all §5.3 fields; enforce sign rules),
  `TransactionRow.swift` (reuse linked account image), `TransactionListView.swift`.
- Shared pickers: `Views/Shared/CategoryPicker.swift` (single-select), `TagPicker.swift`
  (multi), `AccountPicker.swift`, `BudgetPicker.swift` (reads `v_budget_progress` for the
  txn's month; inline "create budget"), `FixedExpensePicker.swift` (reads `fixed_expenses`).

**Rules in play:** single `category_id` (no junction); tags many-to-many; `budget_id` direct
FK; DB column is `date`; `transfer_account_id` (not `to_account_id`). **Amount signs:**
income/expense may be negative, transfers forced positive, zero rejected. Transfer nulls
`budget_id`; fixed-expense link only on expense. Default account pre-selects on new txn.

**Out of scope:** filter sheet, chips, summary, `v_transactions` querying (all P05).

**Note:** `v_budget_progress` and `fixed_expenses` already exist in the DB, so the budget and
fixed-expense pickers can be built now even though those *screens* land in P06/P07.

**Done when:** sign rules enforced; transfer requires `transfer_account_id`+nulls budget;
single category, multiple tags persist; pending rows confirm/dismiss inline; Dev scheme builds.

---

## P05 — Transactions: filter sheet, chips, summary, pagination

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P05**, iOS Tech
> Plan §8.3.1, §8.3.2, §9.2, and System Design §4.9. Implement the full filter/search/summary
> experience over `v_transactions`. Build the Dev scheme before finishing.

**Read first:** iOS Tech Plan §8.3.1, §8.3.2, §9.2; System Design §4.9; migration
`v_transactions`.

**Build (create/replace):**
- `Utilities/TransactionFilters.swift` — filter model + serialization + a single
  `applyFilters(_:to:)` predicate builder shared by list and summary (so they can't drift).
- `Views/Shared/MultiSelectFacet.swift` — reusable tri-state (absent / non-empty set /
  empty set) with a leading "(Blanks)" option where applicable.
- `Views/Transactions/TransactionFilterSheet.swift` (all §8.3.1 facets),
  `TransactionSummarySheet.swift` (income/expense/net/transfers/count/largest + collapsible
  breakdowns; vertical stacked money rows per §9.2).
- Extend `TransactionListViewModel`: holds `TransactionFilters`; queries `v_transactions`
  with `.range()` + `count:.exact`; active-filter chips + Clear all + match count; selectable
  page size (25/50/100/200).

**Rules in play:** **AND-across facets, OR-within a facet.** Each facet (except search/date/
amount) is tri-state; "(Blanks)" matches null rows. Budget/fixed filters resolve **by name**
to ids (budgets via `v_budget_progress`, fixed via `fixed_expenses`), scoped to the active
date range; a chosen-but-unresolved facet → empty result. Summary money math uses **confirmed
rows only** (pending = separate projection, dismissed excluded); transfers reported in/out.
Long amounts must not wrap (`lineLimit(1)` + `minimumScaleFactor(0.7)`).

**Out of scope:** cross-session filter persistence (intentionally not kept on iOS).

**Done when:** facets behave tri-state; by-name budget/fixed resolution works and is shared by
list+summary via one helper; pagination works; summary numbers correct; Dev scheme builds.

---

## P06 — Budgets

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P06**, iOS Tech
> Plan §5.2, §5.9, §8.4, and System Design §4.1–4.2. Implement month-scoped budgets with live
> carry-over from `v_budget_progress`. Delete the legacy `BudgetPeriod` model. Build the Dev
> scheme before finishing.

**Read first:** iOS Tech Plan §5.2, §5.9, §8.4; System Design §4.1–4.2; migrations
`restructure_budgets`, `budget_description`.

**Build (create/replace):**
- `Models/Budget.swift` — **replace** the outdated `is_active`/`enable_carry_over` version
  with the flat per-month row (§5.2). `Models/BudgetProgress.swift` (view read model, §5.2).
  **Delete `Models/BudgetPeriod.swift`.**
- `Repositories/BudgetRepository.swift` — **replace**: `progress(yearMonth:)` from
  `v_budget_progress`, `add`, `copyFromPreviousMonth(into:)`, `update`, `remove` (§5.9).
- `ViewModels/BudgetListViewModel.swift` (month-scoped, realtime).
- `Views/Budgets/BudgetListView.swift`, `BudgetCard.swift` (effective amount, carry-in badge,
  overspent danger styling, reserved-line placeholder for P11),
  `BudgetFormSheet.swift` (name, monthly amount, note — **no carry-over toggle**) (§8.4).

**Rules in play:** identity = `name`, one row per `(user_id, name, year_month)`. **Read
display numbers from `v_budget_progress`; write to `budgets`.** Carry-over always on, never
stored, no toggle. Remove = delete that month's row (gap resets that lineage's carry-over).
Copy skips names already present in the target month. Editing an earlier month re-flows later
months (carry-over is live). No per-row currency.

**Out of scope:** installment "Reserved" data (P11) — leave the card line as a placeholder.

**Done when:** cards show net spent vs effective (from the view); add/remove/copy/edit behave
per rules; tapping a budget opens Transactions filtered to that budget **name** scoped to its
month; Dev scheme builds.

---

## P07 — Fixed Expenses

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P07**, and iOS
> Tech Plan §5.6 + §8.5. Implement month-scoped fixed expenses with derived paid/unpaid
> status and copy/edit/delete/add. Build the Dev scheme before finishing.

**Read first:** iOS Tech Plan §5.6, §8.5; migrations `create_fixed_expenses`,
`merge_fixed_expense_periods`, `drop_fixed_expense_due_day`.

**Build (create/replace):**
- `Models/FixedExpense.swift` (§5.6 — no `currency`, no `isPaid`).
- `Repositories/FixedExpenseRepository.swift` — list for month, add, edit (single month),
  delete (single month), copy-from-previous (skip existing names), paid lookup via linked
  `transactions.fixed_expense_id`.
- `ViewModels/FixedExpenseListViewModel.swift`.
- `Views/FixedExpenses/FixedExpenseListView.swift` (unpaid/paid split + subtotals),
  `FixedExpenseRow.swift`, `FixedExpenseFormSheet.swift`, `FixedExpenseEditSheet.swift`.

**Rules in play:** one row per expense per month; **paid is derived** (≥1 transaction
references it via `fixed_expense_id`) — no standalone "mark paid" toggle. Edit/delete affect
only the selected month. Copy preserves name/amount/is_active, skips duplicates (UNIQUE
`user_id,name,year_month`). No per-row currency.

**Done when:** paid status derived correctly; edit/delete scoped to one month; copy skips
dupes; Dev scheme builds.

---

## P08 — Dashboard (four widgets)

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P08**, iOS Tech
> Plan §8.1, and System Design §4.3/§4.6/§4.9. Replace the legacy dashboard with the four
> current widgets, fetched in parallel and refreshed on realtime. Delete the legacy cards.
> Build the Dev scheme before finishing.

**Read first:** iOS Tech Plan §8.1; System Design §4.3, §4.6, §4.9; migrations
`account_balances_at` (`fn_account_balances_at`), `account_show_on_dashboard`.

**Build (create/replace):**
- **Delete** legacy `CashflowCard`, `BudgetProgressCard`, `SpendingByCategoryChart`,
  `RecentTransactionsCard`.
- `Repositories/DashboardRepository.swift` — **replace**: parallel fetches incl.
  `.rpc("fn_account_balances_at", ["p_year_month": ym])`.
- `ViewModels/DashboardViewModel.swift` — **replace**: parallel load per `year_month`;
  realtime on `transactions`, `budgets`, `fixed_expenses`, `accounts`,
  `account_monthly_balances`.
- `Views/Dashboard/DashboardView.swift` — **replace** + `BudgetVerdictBanner.swift`,
  `AccountsCard.swift`, `PlannedExpensesCard.swift`, `UnplannedExpensesCard.swift` (§8.1).

**Rules in play:** month-scoped via `MonthNavigator`. Verdict banner: count `remaining < 0`
budgets + sum overage; hidden when no budgets. Accounts card: `is_archived=false AND
show_on_dashboard=true`, balances via `fn_account_balances_at` (fallback `starting_balance`).
Unplanned: confirmed expenses with `budget_id IS NULL AND fixed_expense_id IS NULL`, grouped
by category (null → "Uncategorized"). Money rows vertical-stacked (§9.2).

**Done when:** all four widgets render correct data for the selected month and refresh on
realtime; no references to deleted legacy cards; Dev scheme builds.

---

## P09 — Scheduled transactions + Notifications

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P09**, iOS Tech
> Plan §5.5, §8.7, §10, and System Design §4.5. Implement the scheduled list, the pending
> section, and local notifications. Build the Dev scheme before finishing.

**Read first:** iOS Tech Plan §5.5, §8.7, §10; System Design §4.5; migrations
`create_scheduled_transactions`, `scheduled_transaction_details`,
`schedule_pending_transactions`, `scheduled_transaction_fixed_expense`.

**Build (create/replace):**
- `Models/ScheduledTransaction.swift` (§5.5 — `recurrence`, `next_due_date`).
- `Repositories/ScheduledTransactionRepository.swift` — active scheduled + pending
  (`transactions.status = 'pending'`).
- `ViewModels/ScheduledTransactionViewModel.swift`.
- `Views/Scheduled/ScheduledListView.swift`, `PendingTransactionRow.swift`.
- `Services/NotificationService.swift` (`UNUserNotificationCenter`, §10) + permission request.

**Rules in play:** column is `recurrence` (not `recurrence_interval`) and `next_due_date` (not
`next_occurrence`). There is **no** `pending_transactions` table — pending = rows in
`transactions` with `status='pending'`. Pending rows are generated server-side (cron + Edge
Function); the app only displays + notifies.

**Done when:** active scheduled shows next due date; pending section confirms/edits/dismisses;
notification permission requested and a local notification fires for new pending txns;
Dev scheme builds.

---

## P10 — Settings (default currency + default account)

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P10**, iOS Tech
> Plan §8.6 + §3 note + §5.10. Implement the Settings screen (default currency + default
> account) and move the currency picker into Settings. Build the Dev scheme before finishing.

**Read first:** iOS Tech Plan §8.6, §3 note, §5.10; migrations `create_currencies`,
`seed_currencies`, `user_settings_default_account`.

**Build (create/replace):**
- Move/rename `Views/Shared/CurrencyPicker.swift` → `Views/Settings/CurrencyPickerView.swift`
  (searchable list from `currencies`).
- `Views/Settings/SettingsView.swift` (default currency picker + default account picker),
  `ViewModels/SettingsViewModel.swift`. Wire into `MoreView`.

**Rules in play:** currency picker exists **only** in Settings. On change, upsert
`user_settings.default_currency` and have `AppState` reload so all formatters/forms pick up
the new currency + `decimalPlaces`. Default account writes `user_settings.default_account_id`.
Never hardcode a currency list — it comes from the `currencies` table.

**Done when:** changing currency re-formats amounts app-wide and updates `decimalPlaces`;
default account persists and pre-selects on new txns; Dev scheme builds.

---

# Phase P1 — Enhancements

## P11 — Virtual installments (spread an expense across budgets)

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P11**, iOS Tech
> Plan §5.7 + §8.8, and System Design §4.11. Implement virtual installments via the
> `spread_existing_transaction` RPC, plus the surfacing in budget cards and transaction rows.
> Build the Dev scheme before finishing.

**Read first:** iOS Tech Plan §5.7, §8.8; System Design §4.11; migrations
`budget_installments`, `spread_existing_transaction`, `installment_category_tags`.

**Build (create):**
- `Models/BudgetInstallment.swift` (header + `BudgetInstallmentAllocation`, §5.7).
- `Repositories/InstallmentRepository.swift` — `.rpc("spread_existing_transaction", …)`,
  batched lookup by `source_transaction_id`, cancel (delete header → cascade).
- `Views/Transactions/CreateInstallmentSheet.swift` — start month, budget-name multi-select,
  months stepper, allocation grid (even pre-fill + "Split evenly" + save-gated-on-exact-sum).
- Surfacing: `TransactionRow` action "Create virtual installment" (expense + not already
  spread only) + grid indicator; fill in `BudgetCard` "Reserved $X" line + negative-remaining
  rendering; `Views/Budgets/ActiveInstallmentsSection.swift`.

**Rules in play:** reservations are **budget-side only** — never enter `transactions`, never
affect balances. Action shows only for un-spread expenses (income/transfer never; second
spread rejected by RPC). Even pre-fill = `floor(total/(budgets×months))`, remainder in one
cell so the grid sums **exactly** to the expense amount; **Save disabled until it does.**
Submit nulls the source `budget_id` but keeps amount/category/fixed-link/tags. `v_budget_
progress.reserved`/`remaining` reflect reservations; cancel/delete recovers future allowance.

**Done when:** spread flow works end-to-end via the RPC; surfacing renders; cancel recovers
allowance; Dev scheme builds.

---

## P12 — Cross-cutting polish + tests

**Run:**
> In this repo, read `Financial Management - iOS Build Prompts.md` → prompt **P12**, and iOS
> Tech Plan §9.1, §9.2, §13. Apply the month-navigation UX (swipe, page transition, prefetch)
> across all month-scoped screens, audit money-row layouts, and add the test suite. Build and
> run tests (Dev scheme) before finishing. This can be done incrementally.

**Read first:** iOS Tech Plan §9.1, §9.2, §13.

**Build:**
- `Views/Shared/MonthNavigator.swift`: `.swipeToNavigateMonth`, `.monthPageTransition`,
  `.contentTransition(.numericText())`; per-VM adjacent-month prefetch cache + animated
  `navigateMonth(by:)`. Apply to Dashboard, Transactions, Budgets, Fixed Expenses.
- Audit multi-metric cards for the vertical stacked money-row layout (§9.2).
- Tests (§13): unit (Codable round-trips, `CurrencyUtils`, `DateUtils`, `applyFilters`,
  even-split grid math), repository (budget reads from `v_budget_progress`), ViewModel
  (state/filter/pager/prefetch), and a happy-path XCUITest (login → add account → add txn →
  verify dashboard).

**Rules in play:** swipe fires when horizontal displacement > 50pt and ≥1.5× vertical (so it
doesn't fight vertical scroll). Prefetch: cached → apply in `withAnimation` (no spinner);
uncached → spinner in transition; always refetch fresh afterward.

**Done when:** swipe + animated paging work on all four month-scoped screens with prefetch;
money rows don't wrap; `xcodebuild test` (Dev scheme) passes the unit/VM suites.

---

## Dependency graph

```
P01 ─┬─ P02 ─┬─ P03 ───────────────┐
     │       └─ P10 (Settings)     │
     ├─ P04 ─┬─ P05 ───────────────┼─ P08 (Dashboard) ─ P12 (polish/tests)
     │       ├─ P06 ───────────────┤
     │       ├─ P07 ───────────────┘
     │       └─ P09 (Scheduled)
     └────────── P05 + P06 ─ P11 (Installments, P1)
```

**Suggested order:** P01 → P02 → P03 → P04 → P05 → P06 → P07 → P08 → P09 → P10
(MVP done) → P11 → P12. P03/P09/P10 are leaves you can reorder once their parents land.
