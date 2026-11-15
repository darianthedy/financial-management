# 03 — Overspending banner text shrinks to ~11 pt

- **Severity:** Medium
- **Where:** inner display portrait, Dashboard; `FinancialManagement/Views/Dashboard/BudgetVerdictBanner.swift:120-128`

## What

The banner line "Overspending in 1 budget · Rp 182.000 over" is
`.lineLimit(1).minimumScaleFactor(0.7)`. In the inner-portrait two-column
Dashboard (~320 pt columns) it shrinks to roughly 11 pt, visibly smaller than
every other line on the screen. It is the most important status on the Dashboard.

The same `minimumScaleFactor(0.7)` pattern is used on many Dashboard amounts
(`AccountsCard.swift:81`, `PlannedExpensesCard.swift:109/192/283/342`,
`UnplannedExpensesCard.swift:49/85`). With larger Dynamic Type sizes those
amounts shrink instead of wrapping.

Screenshot: `screenshots/L-port-dash-inner.png` (top-left banner).

## Why

- `typography.md`: iOS minimum text size is 11 pt, default 17 pt. Text must
  scale with the system setting and keep its hierarchy.
- `accessibility.md`: layouts survive the largest text sizes.

## Fix

Let the sentence wrap; keep shrink-to-fit only for single numeric values that
must stay on one line:

```swift
// Before
(Text(row.label) ... + Text(" · \(detail)") ...)
    .lineLimit(1)
    .minimumScaleFactor(0.7)

// After
(Text(row.label) ... + Text(" · \(detail)") ...)
    .lineLimit(2)
    .fixedSize(horizontal: false, vertical: true)
```

## Verify

Inner portrait and outer display, default and XXXL Dynamic Type. The banner
text stays at `.subheadline` size and wraps to a second line when needed.
