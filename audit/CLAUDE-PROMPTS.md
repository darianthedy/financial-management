# Claude Prompts — iOS UI Compliance Audit

Paste one prompt per fresh Claude Code session. Each is self-contained. Prompts
**A–F** are *review + fix* passes that consume screenshots/recordings; prompt **G**
is *code-only fixes* for the §9 known inconsistencies and needs no captures.

**Conventions used in every prompt:**
- Audit doc: `Financial Management - iOS UI Compliance Audit.md`
- Capture guide: `audit/CAPTURE-GUIDE.md`
- Captures live in: `captures/` (the screenshots/recordings you exported)
- iOS source root: `iOS/FinancialManagement/FinancialManagement/`
- Output a findings report per pass to: `audit/results/<pass>.md` using the
  §10 checklist template (Item / Captures / HIG checks / Pass·Fail·N-A / Notes).

> Run A–F in parallel (separate sessions/worktrees) if you like — they touch
> different files. Run G last (or first, since it's independent) to land the
> confirmed-finding fixes. Tell each session: *only change code for items you can
> confirm Fail from the captures or source; leave Pass/uncertain items as report notes.*

---

## Prompt A — Global, Auth & Dashboard (audit §0, §1, §2)

```
You are doing an Apple HIG compliance audit of the iOS app's global chrome, login,
and Dashboard. Read `Financial Management - iOS UI Compliance Audit.md` sections
0, 1, and 2, and the capture guide `audit/CAPTURE-GUIDE.md`.

Evidence to review in `captures/`:
- 0.1_tabbar_*, 0.2_navbar_collapse.mov, 0.3_theme_live.mov, 0.4_card_zoom_*
- 1.1_login_* (incl. _se)
- 2.1_dashboard_*, 2.1_dashboard_month.mov, 2.1_dashboard_month_reducemotion.mov
- 2.2_verdict_ontrack_* / _overspent_*, 2.3_accounts_card_*, 2.4_planned_* / _empty_*,
  2.5_unplanned_* / _empty_*

Read the relevant source under iOS/FinancialManagement/FinancialManagement/:
Views/Shared/ContentRootView.swift, App/FinancialManagementApp.swift,
Views/Theme/AppTheme.swift, Views/Theme/ThemeManager.swift, Views/Auth/LoginView.swift,
Views/Dashboard/*.swift, Views/Shared/MonthNavigator.swift.

For each item walk the HIG checklist in the audit (touch targets, Dynamic Type,
dark-mode parity, color-independent meaning, standard controls, motion/Reduce Motion,
VoiceOver, safe areas, keyboard avoidance on Login). Use the screenshots/recordings
as the source of truth for rendered behavior; cite the filename for each verdict.

Write `audit/results/A-global-auth-dashboard.md` with one §10 checklist block per
item, marking Pass/Fail/N-A. For every Fail, propose the concrete code change.
Then implement the fixes you are confident about (small, localized), build to
confirm it compiles, and summarize what you changed vs. what needs a human decision.
Verify each visual fix mentally against both default and XXL Dynamic Type and
light + dark mode.
```

---

## Prompt B — Accounts tab (audit §3)

```
Apple HIG compliance audit of the Accounts tab. Read section 3 of
`Financial Management - iOS UI Compliance Audit.md` and `audit/CAPTURE-GUIDE.md`.

Evidence in `captures/`: 3.1_accounts_list_* / _empty_* / _longname_*,
3.2_account_detail_avatar_* / _noavatar_*, 3.2_account_archive.mov,
3.3_account_form_add_* / _edit_*, 3.3_account_dismiss.mov.

Source: iOS/FinancialManagement/FinancialManagement/Views/Accounts/*.swift
(AccountListView, AccountDetailView, AccountCard, AccountAvatar, AccountFormSheet).

Key HIG focus from the audit:
- 3.2 Archive is destructive with NO confirmation — confirm from 3.2_account_archive.mov,
  and add a confirmation dialog to match the rest of the app.
- 3.3 sheet swipe-dismiss may silently discard unsaved edits (3.3_account_dismiss.mov)
  — evaluate `interactiveDismissDisabled` / a discard-changes confirm.
- Save disabled-until-valid + during save; touch targets; dark/XXL parity; avatar
  loading/placeholder/failure.

Write `audit/results/B-accounts.md` (one §10 block per item, Pass/Fail/N-A, cite
filenames). Implement confident fixes (especially the Archive confirmation and the
unsaved-edits guard), build to confirm compilation, and report what's left for a
human decision. Check fixes at default + XXL type, light + dark.
```

---

## Prompt C — Transactions tab (audit §4) — biggest, highest-risk

```
Apple HIG compliance audit of the Transactions tab — the richest screen. Read
section 4 of `Financial Management - iOS UI Compliance Audit.md` and
`audit/CAPTURE-GUIDE.md`.

Evidence in `captures/`:
- 4.1_transactions_* / _empty_* / _emptyfiltered_* / _manytags_*
- 4.1_transactions_swipe.mov, _search.mov, _infinite.mov, _stickyheaders.mov
- 4.2_row_income/expense/transfer/pending/spread/refund_*
- 4.3_txn_form_new/edit/error_*, 4.3_txn_form_types.mov
- 4.4_filter_top_* / _facet_expanded_*, 4.5_facet_mixed_* / _collapsed_*
- 4.6_summary_*, 4.7_installment_grid/balanced/unbalanced_*, 4.7_installment_flow.mov
- 8_taptargets.png (the 28×28 ⋮ button)

Source: iOS/FinancialManagement/FinancialManagement/Views/Transactions/*.swift
(TransactionListView, TransactionRow, TransactionFormView, TransactionFilterSheet,
MultiSelectFacet, TransactionSummarySheet, CreateInstallmentSheet) plus
Views/Shared/MultiSelectFacet.swift.

Critical questions to RESOLVE from the recordings, not from the source comments:
- Does a FULL trailing swipe on a transaction Delete immediately, or route through
  the confirmation alert? (4.1_transactions_swipe.mov) The ⋮-menu Delete confirms;
  the swipe Delete appears to call deleteTransaction directly — confirm and fix to
  match (either confirm, or set allowsFullSwipe:false).
- Sticky day headers fully opaque, net-amount column stays aligned (stickyheaders.mov).
- Conditional form fields animate without jank when switching type (txn_form_types.mov).
- 28×28 ⋮ tap target vs 44pt (8_taptargets.png).
- Installment "Remaining to allocate" color feedback clearly explains why Save is
  disabled, and keyboard doesn't hide the active grid cell (installment_flow.mov).

Write `audit/results/C-transactions.md` (one §10 block per item 4.1–4.7,
Pass/Fail/N-A, cite filenames). Implement confident fixes (prioritize the swipe-Delete
confirmation consistency and tap-target floors), build, and report. Verify at
default + XXL type, light + dark, and on compact width.
```

---

## Prompt D — Budgets tab (audit §5)

```
Apple HIG compliance audit of the Budgets tab. Read section 5 of
`Financial Management - iOS UI Compliance Audit.md` and `audit/CAPTURE-GUIDE.md`.

Evidence in `captures/`: 5.1_budgets_* / _empty_*, 5.1_budgets_swipe.mov,
5.2_budget_normal/overspent/reserved/carryover_*, 5.2_budget_popover.mov,
5.3_budget_form_add_* / _edit_*, 5.4_installment_card_*, 8_taptargets.png.

Source: iOS/FinancialManagement/FinancialManagement/Views/Budgets/*.swift
(BudgetListView, BudgetCard, BudgetFormSheet, ActiveInstallmentsSection).

Key HIG focus:
- Swipe Remove deletes directly while ⋮-menu Remove confirms via alert
  (5.1_budgets_swipe.mov) — flag and make consistent.
- Info .popover presents as a popover (not full sheet) on iPhone and dismisses on
  tap-outside (5.2_budget_popover.mov).
- Active installment Cancel is destructive without confirmation (cascades to
  allocations) — flag.
- 28×28 ⋮ tap target; progress bar at 0/partial/full/overspent; color-only overspend
  cue paired with text; inner horizontal chip scroll doesn't fight row tap/scroll.

Write `audit/results/D-budgets.md` (§10 blocks, Pass/Fail/N-A, cite filenames).
Implement confident fixes (swipe-Remove confirmation, installment-Cancel confirmation),
build, report. Verify at default + XXL type, light + dark.
```

---

## Prompt E — More, Fixed Expenses, Scheduled & Settings (audit §6)

```
Apple HIG compliance audit of the More tab and its sub-screens. Read section 6 of
`Financial Management - iOS UI Compliance Audit.md` and `audit/CAPTURE-GUIDE.md`.

Evidence in `captures/`: 6.1_more_*, 6.2_fixed_list_* / _empty_*,
6.3_fixed_row_paid_* / _unpaid_*, 6.4_fixed_form_add_*, 6.5_fixed_form_edit_*,
6.6_scheduled_* / _paused_* / _empty_* / _xxl, 6.6_scheduled_permission.mov,
6.7_settings_*, 6.8_currency_picker_*.

Source: iOS/FinancialManagement/FinancialManagement/Views/More/MoreView.swift,
Views/FixedExpenses/*.swift, Views/Scheduled/ScheduledListView.swift +
PendingTransactionRow.swift, Views/Settings/SettingsView.swift + CurrencyPickerView.swift.

Key HIG focus:
- Sign Out is immediate with no confirmation (6.1) — flag/add confirm.
- Notification permission requested cold on Scheduled appear, no pre-prompt
  (6.6_scheduled_permission.mov) — flag; consider an in-context rationale.
- Scheduled inline Confirm/Edit/Dismiss use .controlSize(.small) — likely under 44pt,
  and the 3-button row is the key XXL risk (6.6_scheduled_xxl) — verify and fix.
- FixedExpenses Delete uses allowsFullSwipe:false (note inconsistency vs Transactions).
- Settings theme segmented re-themes live; changing currency reloads formatters
  app-wide with no stale values; currency picker search + select-and-pop.

Write `audit/results/E-more-settings.md` (§10 blocks, Pass/Fail/N-A, cite filenames).
Implement confident fixes (Sign Out confirm, Scheduled tap targets / XXL layout),
build, report. Verify at default + XXL type, light + dark.
```

---

## Prompt F — Shared pickers & inputs (audit §7)

```
Apple HIG compliance audit of the shared form components. Read section 7 of
`Financial Management - iOS UI Compliance Audit.md` and `audit/CAPTURE-GUIDE.md`.

Evidence in `captures/`: 7.1_accountpicker_open_*, 7.2_categorypicker_open_*,
7.3_budgetpicker_open_*, 7.4_fixedpicker_open_*, 7.5_tagpicker_sheet_*,
7.6_currencyfield_*, 7.7_monthnavigator_*, and (if captured) 7.10_avatar_fallback.mov.
Also reuse 4.3_txn_form_types.mov (pickers' inline Create + Tag sheet in context).

Source: iOS/FinancialManagement/FinancialManagement/Views/Shared/*.swift
(AccountPicker, CategoryPicker, BudgetPicker, FixedExpensePicker, TagPicker,
CurrencyField, MonthNavigator, EmptyStateView, FlowLayout, Badge, AmountColumnView,
AccountAvatar).

Key HIG focus:
- Create-sentinel pattern in Category/Budget/Fixed pickers reverts selection and
  opens the create sheet cleanly (nested sheet-over-sheet dismisses back to the form).
- TagPicker: multi-select chips via FlowLayout, Return-key select/create-on-no-match.
- CurrencyField: keypad type by decimals, live thousands grouping, +/− sign toggle
  discoverability + 44pt, caret not fought while typing, blur-settle to padded decimals.
- MonthNavigator chevrons 44pt hit area; label min-width prevents shift.
- FlowLayout wrapping at XXL / narrow width.

Write `audit/results/F-shared-components.md` (§10 blocks, Pass/Fail/N-A, cite
filenames). Implement confident fixes (especially sub-44pt targets on the +/−
toggle and chevrons), build, report. Verify at default + XXL type, light + dark.
```

---

## Prompt G — Known inconsistencies, code-only (audit §9) — no captures needed

```
Implement the cross-cutting consistency fixes from the iOS UI audit. Read section 9
(and the referenced items) of `Financial Management - iOS UI Compliance Audit.md`.
These are code-only and don't require screenshots — read the source to confirm each,
then fix. Work in iOS/FinancialManagement/FinancialManagement/.

Make these consistent across the app (HIG: confirm permanent, hard-to-undo destructive
actions; keep 44×44pt minimum targets):
1. Account Archive (Views/Accounts/AccountDetailView.swift) — add a confirmation dialog.
2. Sign Out (Views/More/MoreView.swift) — add a confirmation dialog.
3. Destructive SWIPE actions that currently bypass the alert their ⋮-menu equivalent
   shows: Transactions Delete (Views/Transactions/TransactionListView.swift), Budgets
   Remove (Views/Budgets/BudgetListView.swift), Active Installment Cancel
   (Views/Budgets/ActiveInstallmentsSection.swift). Either route them through the same
   confirmation alert OR set allowsFullSwipe:false — pick ONE rule and apply it
   everywhere, including aligning Transactions vs FixedExpenses allowsFullSwipe.
4. Tap targets below 44pt: the 28×28 ⋮ buttons (Views/Transactions/TransactionRow.swift,
   Views/Budgets/BudgetCard.swift) and the .controlSize(.small) Scheduled buttons
   (Views/Scheduled/PendingTransactionRow.swift) — raise the effective hit area to 44pt.
5. Form sheet swipe-dismiss with unsaved edits (Account, Transaction, Budget, Fixed,
   Installment, Filter forms) — add a discard-changes guard (interactiveDismissDisabled
   + a confirm) where meaningful input would be lost.

Before changing each, read the file and confirm the current behavior matches the
audit's claim (some may already be handled). Group the changes logically, build the
project to confirm it compiles, and write a summary of each fix (file, before/after,
and the consistency rule you chose) to `audit/results/G-consistency-fixes.md`.
Keep changes minimal and idiomatic to the surrounding SwiftUI code. Verify destructive
confirmations read clearly and that raised tap targets don't shift layout at XXL type.
```

---

## Suggested order
1. **G** first (independent code fixes — lands the clear §9 wins, no captures needed).
2. **A–F** in parallel once `captures/` is ready (each writes its own `audit/results/*.md`).
3. Consolidate the six result files into a single Pass/Fail summary at the end.
