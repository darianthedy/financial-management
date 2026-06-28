# Prompt G — Cross-cutting consistency fixes (iOS UI audit §9)

Code-only consolidation of the critical/P0 consistency findings from
*Financial Management — iOS UI Compliance Audit* §9 (and the §8 cross-cutting
checks it references). Each item below was confirmed against the source before
changing. Work is in `iOS/FinancialManagement/FinancialManagement/`.

> **Build note:** this audit pass ran on Linux/WSL, where no Swift/Xcode
> toolchain is available (`xcodebuild`/`swiftc` not present), so the project
> could not be compiled here. Changes were kept minimal and idiomatic to the
> surrounding SwiftUI and reviewed by hand for type/compile correctness; a
> `xcodebuild` pass on macOS is still recommended before merge.

---

## Consistency rules chosen (applied app-wide)

1. **Permanent destructive actions are always confirmed.** Archive, Sign Out,
   and every destructive list action (Transaction Delete, Budget Remove,
   Installment Cancel, Fixed Expense Delete) present a confirmation before
   acting.
2. **One destructive-swipe rule everywhere:** a destructive swipe action uses
   `allowsFullSwipe: false` (so a long swipe reveals the button instead of
   auto-firing) **and** routes through the *same* confirmation as the row's ⋮
   menu. The confirmation alert is owned by the list view so the menu path and
   the swipe path are literally the same dialog. This also aligns the
   `allowsFullSwipe` mismatch the audit flagged (Transactions vs Fixed
   Expenses).
3. **44×44pt minimum hit targets**, raised without changing the visible glyph or
   shifting layout at large Dynamic Type.
4. **Discard-changes guard on every form sheet:** `interactiveDismissDisabled`
   while there are unsaved edits, plus a "Discard Changes / Keep Editing"
   confirmation surfaced through the Cancel button.

Style note: full-screen primary destructive buttons (Archive, Sign Out) and the
discard guards use `.confirmationDialog` (the idiomatic action-sheet for a single
button-triggered destructive choice); list-row deletes use `.alert`, matching the
alert style the ⋮ menus already used.

---

## 1. Account Archive — `Views/Accounts/AccountDetailView.swift`

- **Confirmed:** the "Archive Account" button called `viewModel.archiveAccount()`
  immediately, no confirmation.
- **After:** the button sets `showingArchiveConfirm`; a `.confirmationDialog`
  ("Archive this account?") performs the archive + dismiss on confirm.
- **Rule:** #1 (confirm permanent destructive actions).

## 2. Sign Out — `Views/More/MoreView.swift`

- **Confirmed:** the Sign Out button signed out immediately.
- **After:** the button sets `showingSignOutConfirm`; a `.confirmationDialog`
  ("Sign out?") runs `AuthViewModel().signOut()` on confirm.
- **Rule:** #1.

## 3. Destructive swipe actions vs. their ⋮-menu confirmation

Chosen rule #2 applied to all destructive rows.

- **Transactions Delete** — `Views/Transactions/TransactionListView.swift`
  (+ `TransactionRow.swift`)
  - **Confirmed:** the trailing swipe Delete called `deleteTransaction` directly
    with default `allowsFullSwipe` (true), bypassing the alert the ⋮ menu showed.
  - **After:** the delete confirmation alert was lifted out of `TransactionRow`
    up to `TransactionListView` (`@State pendingDelete: Transaction?`). Both the
    ⋮ menu's Delete (`onDelete` now means "request delete") and the swipe button
    set `pendingDelete`; one shared `.alert` performs the delete. Swipe set to
    `allowsFullSwipe: false`.
- **Budgets Remove** — `Views/Budgets/BudgetListView.swift` (+ `BudgetCard.swift`)
  - **Confirmed:** swipe Remove called `removeBudget` directly, default
    `allowsFullSwipe`, bypassing the card's alert.
  - **After:** the remove alert was lifted out of `BudgetCard` to
    `BudgetListView` (`@State pendingRemove: BudgetProgress?`); ⋮ menu and swipe
    both set it; swipe set to `allowsFullSwipe: false`.
- **Active Installment Cancel** — `Views/Budgets/ActiveInstallmentsSection.swift`
  (+ `BudgetListView.swift`)
  - **Confirmed:** swipe Cancel called `onCancel` directly, no confirmation, no
    ⋮ menu equivalent at all.
  - **After:** `onCancel` now requests cancellation; `BudgetListView`
    (`@State pendingCancel: ActiveInstallment?`) presents a "Cancel installment?"
    confirmation before cascading. Swipe set to `allowsFullSwipe: false`.
- **Fixed Expenses Delete** — `Views/FixedExpenses/FixedExpenseListView.swift`
  - **Confirmed:** already `allowsFullSwipe: false`, but deleted with **no**
    confirmation (and no ⋮ menu) — the inverse inconsistency.
  - **After:** swipe now sets `@State pendingDelete: FixedExpense?`; a
    "Delete fixed expense?" `.alert` confirms. `allowsFullSwipe` already false,
    so the two list styles now match.
- **`allowsFullSwipe` alignment:** all four destructive rows now use
  `allowsFullSwipe: false`, resolving the Transactions-vs-FixedExpenses mismatch
  the §9 table called out.

## 4. Tap targets below 44pt

- **28×28 ⋮ buttons** — `Views/Transactions/TransactionRow.swift`,
  `Views/Budgets/BudgetCard.swift`
  - **Confirmed:** the `ellipsis` Menu label used `.frame(width: 28, height: 28)`.
  - **After:** `.frame(width: 44, height: 44)` with the existing
    `.contentShape(Rectangle())` — the glyph stays visually small, only the
    tappable region grows. Fixed frame, so it does not change with Dynamic Type.
  - **Layout follow-up:** `TransactionListView`'s date-group header reserved a
    matching `Color.clear.frame(width: 28)` to keep the day-net aligned over the
    menu column — bumped to 44 to stay aligned.
- **`.controlSize(.small)` Scheduled buttons** —
  `Views/Scheduled/PendingTransactionRow.swift`
  - **Confirmed:** the three Confirm/Edit/Dismiss buttons used
    `.controlSize(.small)` with `.frame(maxWidth: .infinity)` (height < 44pt).
  - **After:** labels changed to `.frame(maxWidth: .infinity, minHeight: 44)` —
    keeps the compact small-control look and equal widths, guarantees a 44pt-tall
    hit area, and `minHeight` (not fixed height) still lets the row grow at XXL.

## 5. Form sheet swipe-dismiss discard guard

Rule #4 applied to all six form families (seven files). Each adds a `hasChanges`
check, `.interactiveDismissDisabled(hasChanges)`, a Cancel button that confirms
when dirty, and a "Discard Changes / Keep Editing" `.confirmationDialog`.

- **Account** — `Views/Accounts/AccountFormSheet.swift`: `hasChanges` compares
  name/type/balance/toggles (and staged/removed avatar) against the editing
  account, or against empty defaults when creating.
- **Transaction** — `Views/Transactions/TransactionFormView.swift`
  (+ `ViewModels/TransactionFormViewModel.swift`): added `hasChanges` to the view
  model via a field `Snapshot` captured at init, with the tag baseline captured
  when `loadTags()` resolves.
- **Budget** — `Views/Budgets/BudgetFormSheet.swift`: add vs. edit comparison
  against the opening row values.
- **Fixed Expense (new)** — `Views/FixedExpenses/FixedExpenseFormSheet.swift`:
  dirty when any field has input.
- **Fixed Expense (edit)** — `Views/FixedExpenses/FixedExpenseEditSheet.swift`:
  captures the opening name/amount and compares.
- **Installment** — `Views/Transactions/CreateInstallmentSheet.swift`: dirty once
  budgets are selected or the month span / start month leaves its defaults.
- **Filter** — `Views/Transactions/TransactionFilterSheet.swift`: dirty when the
  working facets or the amount fields differ from the values the sheet opened
  with.

---

## Verification notes

- **Destructive copy** reads clearly and names the consequence + irreversibility
  (e.g. "This permanently removes the transaction and updates the affected
  account balances. This can't be undone.").
- **Raised tap targets** use fixed 44×44 frames (⋮) or `minHeight: 44` (Scheduled
  buttons), so they don't shift or clip at Accessibility XXL; the date-group
  header spacer was updated to keep the amount column aligned.
- **Not built here** — no Swift toolchain on the audit host; recommend a
  `xcodebuild` compile + a quick pass over the destructive confirmations and the
  Scheduled row at XXL on macOS before merge.
