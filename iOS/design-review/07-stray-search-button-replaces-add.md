# 07 — Stray search button replaced Budgets "+" (seen once)

- **Severity:** Medium
- **Where:** outer display (Dashboard, Budgets), observed in dark mode; root cause most likely
  `FinancialManagement/Views/Transactions/TransactionListView.swift:328` (`.searchable`) and
  the hierarchy swap in `SplitRoot.swift:101-119`

## What

After this sequence the outer display's vertical bar showed a search button on
Dashboard, and on Budgets the search button **replaced** the Add (+) button:

1. Inner display, portrait: visit all five tabs (Transactions shows its search
   as a toolbar button in this pose).
2. Rotate back to landscape, visit all five tabs.
3. Close the device (outer display), visit all five tabs.

The inner landscape Transactions screen at step 2 also showed both the inline
search field and an extra search button on the side bar. A relaunch cleared it.
Two shorter sequences did not reproduce it, so treat it as intermittent.

Dark mode itself is not the trigger: a fresh dark launch is correct.

Screenshots: `screenshots/D-closed-dash-outer.png`,
`screenshots/D-closed-budgets-outer.png` (bug), and
`screenshots/L-closed-budgets-outer.png` (correct).

## Why

- `designing-for-iphone-duo.md › Best practices`: "Keep functionality and the
  state of elements the same between displays." Losing Add on Budgets removes
  a primary action.

## Fix

1. The most likely cause is the hierarchy swap that re-creates the
   Transactions screen on every rotation: a search toolbar item from a
   torn-down `.searchable` host stays in the shared tab bar. The swap itself
   stays (the Music pattern, `docs/ios-tab-root-plan.md`), so fix it at the
   search host.
2. Attach `.searchable` where its host survives rotation, so the
   search item is never re-registered. For example, apply it on the
   Transactions `SplitRootContainer` in `ContentRootView`, bound to
   `transactionList` (already owned above the tabs), instead of inside
   `TransactionListView.content`.
3. Add a UI test for the sequence above that asserts the Budgets Add button
   exists and no search button exists outside Transactions.

## Verify

Repeat the 3-step sequence twice in each appearance. Budgets always shows Add,
and only Transactions offers search.
