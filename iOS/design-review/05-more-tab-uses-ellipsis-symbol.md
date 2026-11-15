# 05 — "More" tab uses the ellipsis symbol reserved for overflow

- **Severity:** Medium
- **Where:** both displays, tab bar; `FinancialManagement/Views/Shared/ContentRootView.swift:71`

## What

```swift
Tab("More", systemImage: "ellipsis", value: RootTab.more) { ... }
```

On iPhone Duo's vertical bar the tab shows only its icon, a bare "…". The
system uses the same "…" for toolbar overflow on that bar. The Transactions
Summary button is set to overflow first (`TransactionsToolbar`), so both "…"
controls can be on screen at once and mean different things.

Screenshots: `screenshots/L-closed-tx-outer.png`, `screenshots/L-closed-more-outer.png`.

## Why

- `designing-for-iphone-duo.md › Vertical controls`: "Reserve the ellipsis
  symbol for overflow, and give other menus a distinct symbol."
- `tab-bars.md`: tabs navigate; their symbols identify a destination.

## Fix

Pick a destination symbol for the management hub, e.g.:

```swift
// Before
Tab("More", systemImage: "ellipsis", value: RootTab.more)

// After
Tab("More", systemImage: "square.grid.3x3", value: RootTab.more)
// or "list.bullet.rectangle", "slider.horizontal.3"
```

Consider a more descriptive title too ("Manage"), since the tab holds Tags,
Categories, Fixed Expenses, Scheduled and Settings.

## Verify

Outer display on Transactions with Summary overflowed: exactly one "…" is
visible (the system overflow).
