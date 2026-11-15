# 02 — Budget card amounts wrap mid-phrase

- **Severity:** Medium
- **Where:** outer display, Budgets tab; `FinancialManagement/Views/Budgets/BudgetCard.swift:60-71`

## What

On the outer display's compact width, the "spent of budget" label wraps as

```
Rp 1.682.000 of            Rp 182.000 over
Rp 1.500.000
```

The break falls inside the phrase, and the two lines no longer line up with the
single-line "over"/"left" figure beside them. Inner display and portrait are fine.

Screenshot: `screenshots/L-closed-budgets-outer.png` (Dining Out, Groceries).

## Why

- `layout.md`: layouts adapt to available space with hierarchy intact.
- Craft judgment: a currency pair split across lines is harder to scan than
  either a one-line row or a deliberately stacked one.

## Fix

Let the row choose a layout that fits:

```swift
// Before
HStack {
    Text("\(spent) of \(budget)")
    Spacer()
    Text("\(remaining) left")
}

// After
ViewThatFits(in: .horizontal) {
    HStack {
        Text("\(spent) of \(budget)")
        Spacer()
        Text("\(remaining) left")
    }
    VStack(alignment: .leading, spacing: 2) {
        Text("\(spent) of \(budget)")
        Text("\(remaining) left").foregroundStyle(statusColor)
    }
}
.lineLimit(1)
```

## Verify

Outer display, light and dark, Budgets for a month with 7–8 digit amounts, also
at the largest non-accessibility Dynamic Type size.
