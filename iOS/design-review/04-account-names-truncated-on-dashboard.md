# 04 — Account names truncated in the Dashboard's Accounts card

- **Severity:** Medium
- **Where:** inner display portrait, Dashboard → Accounts card; `FinancialManagement/Views/Dashboard/AccountsCard.swift:50-52`

## What

In inner portrait the Dashboard uses two ~320 pt columns. The Accounts card's
rows show "BCA Tahap…" and "BCA Credit…": the name is `.lineLimit(1)` and loses
to the right-aligned amount column. Names are the only way to tell accounts
apart, so truncating them loses the row's meaning.

Screenshot: `screenshots/L-port-dash-inner.png` (Accounts card, top right).

## Why

- `layout.md`: content adapts to the available width with the same information.
- `writing.md`: names people recognize must stay legible.

## Fix

Give the name priority and fall back to a stacked row when both don't fit:

```swift
// Before
HStack {
    icon
    Text(item.account.name).lineLimit(1)
    Spacer()
    amount(item.balance, semibold: false)
}

// After
ViewThatFits(in: .horizontal) {
    HStack {
        icon
        Text(item.account.name).lineLimit(1)
        Spacer()
        amount(item.balance, semibold: false)
    }
    HStack(alignment: .firstTextBaseline) {
        icon
        VStack(alignment: .leading, spacing: 2) {
            Text(item.account.name).lineLimit(2)
            amount(item.balance, semibold: false)
        }
        Spacer()
    }
}
```

(Alternatively `.lineLimit(2)` on the name with `.layoutPriority(1)`.)

## Verify

Inner portrait, outer display, and partially folded inner landscape, with long
account names (e.g. "BCA Tahapan Gold Savings").
