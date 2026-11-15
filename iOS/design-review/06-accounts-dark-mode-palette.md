# 06 — Accounts list in dark mode uses a different palette

- **Severity:** Medium
- **Where:** both displays, dark mode, Accounts tab; `FinancialManagement/Views/Accounts/AccountListView.swift:49-52`

## What

```swift
.listStyle(.insetGrouped)
.scrollContentBackground(.hidden)
.background(Color.appBackground)
```

The page background is the app's navy `appBackground`, but the rows keep the
system's neutral grey grouped-row background. Dashboard, Budgets and
Transactions put navy `appCard` surfaces on the background. In dark mode,
Accounts is the only main screen with grey surfaces. In light mode the
difference is invisible.

Screenshots: `screenshots/D2-closed-accounts-outer.png` vs
`screenshots/D-closed-dash-outer.png` and `screenshots/D-closed-budgets-outer.png`.

## Why

- `color.md`: one color means one thing; use colors consistently.
- `dark-mode.md`: test both appearances; surfaces should keep their relative
  hierarchy in dark mode.

## Fix

```swift
// Before
Section { ForEach(...) { AccountCard(...) } }

// After
Section { ForEach(...) { AccountCard(...) } }
    .listRowBackground(Color.appCard)
```

Apply the same to the Total row's section. Audit More, Settings, Tags,
Categories, Fixed Expenses and Scheduled, which use the same
`.scrollContentBackground(.hidden)` pattern.

## Verify

Dark mode, outer and inner: Accounts rows match the Dashboard card color.
Light mode unchanged.
