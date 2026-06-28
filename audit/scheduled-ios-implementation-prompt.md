# Prompt: Close the iOS Scheduled-Transaction Parity Gap

## Objective
Bring the iOS scheduled-transaction experience to functional parity with the current web app, using the existing iOS codebase conventions. Do not refactor unrelated areas.

## Reference implementations (read these first)
- Web schema/rules: `web/src/lib/validations/scheduled-transaction.ts`
- Web create/edit form: `web/src/components/scheduled/scheduled-form.tsx`
- Web card/row: `web/src/components/scheduled/scheduled-card.tsx`
- Web list page: `web/src/pages/scheduled.tsx`
- Web data + mutations: `web/src/lib/hooks/use-scheduled-transactions.ts`
- Web DB types: `web/src/lib/types/database.ts` (focus: `scheduled_transactions`, `scheduled_transaction_tags`, `transactions`)
- iOS list + form: `iOS/FinancialManagement/FinancialManagement/Views/Scheduled/ScheduledListView.swift`, `…/ScheduledFormView.swift`
- iOS row: `iOS/FinancialManagement/FinancialManagement/Views/Scheduled/ScheduledListView.swift` (`ScheduledRow`)
- iOS pending row: `iOS/FinancialManagement/FinancialManagement/Views/Scheduled/PendingTransactionRow.swift`
- iOS VM + repo: `iOS/FinancialManagement/FinancialManagement/ViewModels/ScheduledTransactionViewModel.swift`, `…/Repositories/ScheduledTransactionRepository.swift`
- iOS form VM: `iOS/FinancialManagement/FinancialManagement/ViewModels/ScheduledTransactionFormViewModel.swift`
- iOS shared pickers: `…/Views/Shared/{AccountPicker,CategoryPicker,TagPicker,BudgetNamePicker,FixedExpenseNamePicker}.swift`
- iOS existing budget/fixed-expense create sheets: inline in `…/Views/Shared/BudgetPicker.swift` and `…/Views/Shared/FixedExpensePicker.swift`

## Non-negotiables / DB + platform rules
- `scheduled_transactions.recurrence` only supports `monthly`. Form should show “Monthly” as a fixed read-only line.
- `budget_name` / `fixed_expense_name` are **lineage names**, not row IDs. Generator resolves them to the due month at runtime.
- Pending transactions are rows in `transactions` where `status = 'pending'`. There is **no** `pending_transactions` table.
- App is single-currency; amounts are `Int64` minor units. Formatting uses `AppState.defaultCurrency` + `decimalPlaces`.
- Existing tags are created/added via the `tags` table. Schedule ↔ tag links live in `scheduled_transaction_tags`.
- Deletion: deleting a schedule keeps already-generated transactions (`ON DELETE SET NULL` on `transactions.scheduled_txn_id`). UI text must state this.
- Editing: if the user changes the due month, any selected budget/fixed-expense lineage names must stay selectable even if no row exists for the new month.

## What is already implemented in iOS (do not redo)
- `ScheduledListView`: list active + pending, pull-to-refresh, realtime reload, empty state.
- `ScheduledRow`: description, amount by type color, “Next” / “Paused · next” + calendar-clock label, opacity when paused.
- `PendingTransactionRow`: confirm / edit / dismiss inline buttons.
- `ScheduledFormView`: type, account, amount, next due date, description, budget name picker, category picker, fixed-expense name picker (expense only), tags, active toggle, discard-changes guard, save validation.
- `ScheduledTransactionFormViewModel`: prefill, change tracking, save routing to repo, tag load.
- `ScheduledTransactionRepository`: CRUD for `scheduled_transactions`, tag link set/get, confirm/dismiss pending Txns.
- `ViewModels/ScheduledTransactionViewModel`: confirmed + dismiss pending, load, subscribe to realtime, toggle active.
- Shared/linked picker sheets: `CreateBudgetSheet` and `CreateFixedExpenseSheet` are inlined in `BudgetPicker.swift` / `FixedExpensePicker.swift` and already reused by `BudgetNamePicker` / `FixedExpenseNamePicker`.

## Gaps to close

### G1 — ScheduledRow metadata parity
Currently `ScheduledRow` shows description + next-due label + amount, but **not** the joined account/category/fixed-expense/tag/budget metadata that the web card renders.

**Required changes:**
- In `ScheduledListView.swift`, change `ScheduledRow` to accept enriched scheduled data, or load the joined metadata in the VM and pass it down.
- Enrich `scheduledTransactions` in `ScheduledTransactionViewModel.load()` with:
  - `accountName` / `accountImageUrl`
  - `categoryName` / `categoryColor`
  - `tagNames`
  - `budgetName`
  - `fixedExpenseName`
  Do this with one batched `accounts` lookup plus one batched `categories` lookup plus one batched `scheduled_transaction_tags` lookup (same pattern as web in `use-scheduled-transactions.ts`).
- Update `ScheduledRow` to render:
  - account avatar fallback circle (initial + color by type) — if image URL exists, use it; else fallback
  - title from `deriveTitle`-like logic: category/fixed-expense/budget should be shown but **not duplicated** with description (web’s title-first, subtitle-second pattern)
  - chips for category / fixed expense / tags, excluding anything already used in the title (mirror web’s `excludeCategoryId`/`excludeFixedExpense`)
  - footer: “Next / Paused · next MMM d, yyyy”
  - amount with type color: income → success, expense → danger, transfer → foreground
- If fetching joined fields would change load time, keep it async inside load and show the same loading states already present.

### G2 — Form parity: budget/fixed-expense as read-only when missing-from-month
The pickers already show “Name · none this month” when a stored lineage is absent in the due month. The web form keeps those selectable too. Ensure iOS keeps them selectable without error or clearing. (Looks like it’s already modeled; verify by exercising an edit flow with a missing month row.)

### G3 — Validation parity in form VM
Web enforces via Zod:
- `account_id` required
- `type` in `income | expense`
- `amount > 0`
- `description` max 200 chars, trimmed
- `recurrence` fixed `monthly`
- `next_due_date` required
- `category_id` / `budget_name` / `fixed_expense_name` accept null
- `tag_ids` optional UUID array
- Fixed expense dropped on income

IOS currently checks `isValid` on minor units > 0 and account != nil. Add trim/limit enforcement in `ScheduledTransactionFormViewModel.save()`:
- `description` trimmed; reject or strip beyond 200 chars
- `fixedExpenseName` must be nil when `type != .expense` (current code enforces via didSet but reassert before save)
- Reject save if `parsedMinorUnits` is nil or ≤ 0, with `errorMessage` set

### G4 — Scheduled-form row creation parity (UI)
Web supports category creation inline inside the scheduled form (`CategoryForm` sheet). iOS `CategoryPicker` already supports inline creation via `CreateCategorySheet`, so this is already covered.

Similarly for tags: web supports inline create. iOS `TagPickerSheet` already supports it.

So do not duplicate these pickers; instead, verify they’re all wired when the form is embedded as a modal/sheet over the scheduled list.

### G5 — Delete confirmation text parity
Web confirms: “Delete <label>? Already-generated transactions are kept; only the schedule is removed.”
Use the same wording in iOS’s `pendingDelete` alert.

### G6 — Pending-row tap targets
Web has its own row design. iOS uses small `.controlSize(.small)` buttons. Confirm each confirm/edit/dismiss button remains ≥ 44pt effective hit area. Keep the `ActionButtons` pattern and minimum height guards already in `PendingTransactionRow`.

## Wiki rules to encode
- Scheduled transactions are income or expense only (no transfers), because the generator cannot set a destination account.
- `is_active = false` is a pause, not a deletion. The row remains editable.
- Recurrence is monthly-only in v1.
- Budget and fixed-expense links are stored by name, scoped to the due month at generation time.
- Editing a schedule does **not** delete or recreate already-generated transactions; it changes future generations only.

## Prompt to the implementer
Implement the remaining iOS scheduled-transaction gaps G1 through G6 in-place, following the file paths and conventions already established in this repo.
- Do not change `ScheduledTransactionRepository` tags CRUD semantics.
- Keep realtime behavior unchanged.
- Add missing joined-metadata loads in the VM using one batched lookup per entity, not N+1 queries.
- In `ScheduledRow`, mirror web `ScheduledCard`’s visual hierarchy: title on top, subtitle only when title is not the description, chips between title and footer, amount trailing.
- Update iOS `ScheduledTransactionFormViewModel` validation/limits to match web Zod schema.
- Reuse existing shared pickers and sheets; do not add duplicate “create budget/fixed-expense/category” flows.
- Verify by running the app and:
  1) creating, editing, pausing, and deleting a schedule;
  2) editing a schedule whose selected budget/fixed-expense lineage is missing in the new due month;
  3) confirming and dismissing a pending transaction;
  4) scrolling the list while realtime updates are triggered.

## Acceptance criteria
- Scheduled list rows show account/category/tag/fixed-expense/budget chips (when present) plus next-due footer and colored amount.
- Pause/resume and delete affordances still work; delete dialog text matches web verbatim.
- Form rejects empty account, blank/overlong description, non-positive amount; still allows null category/budget/fixed-expense and any existing tag set.
- Switching type away from expense clears fixed-expense selection.
- Creating a category/budget/fixed-expense/tag from within the form still works through the existing shared pickers.
- Targets: Dev scheme builds; existing scheduled tests (if any) still pass.
