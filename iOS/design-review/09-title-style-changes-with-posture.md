# 09 — Navigation title style changes with posture

- **Severity:** Low
- **Where:** Accounts and Budgets (inner landscape vs elsewhere); `FinancialManagement/Views/Accounts/AccountListView.swift:53`, `FinancialManagement/Views/Budgets/BudgetListView.swift:130`, `FinancialManagement/Views/Transactions/TransactionListView.swift:236`

## What

- Accounts and Budgets show a **large** title on the outer display and inner
  portrait, but a small **inline** title in inner landscape. In that pose they
  are the split view's list column, which defaults to inline.
- Transactions forces `.large` and keeps a large title in every pose.

So the same three peer tabs use different title styles side by side, and two of
them change style when the device rotates or folds.

Screenshots: `screenshots/D-open-budgets-inner.png` (inline) vs
`screenshots/L-closed-budgets-outer.png` (large); `screenshots/L-open-tx-inner.png` (large).

## Why

- `designing-for-iphone-duo.md › Best practices`: keep a consistent experience
  across displays and poses.
- `designing-for-iphone-duo.md › Avoid extreme layout changes`: favor small
  adjustments as the device changes pose.

## Fix

Give the three list tabs the same explicit style:

```swift
.navigationTitle("Budgets")
.navigationBarTitleDisplayMode(.large)
```

Or use `.inline` in all three if the split's list column should stay compact.
Either way, the choice should not depend on pose.

## Verify

Accounts, Transactions, Budgets on outer, inner portrait, inner landscape: same
title style everywhere.
