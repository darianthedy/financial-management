# 10 — Day header shows "Rp 0" on transfer-only days

- **Severity:** Low
- **Where:** both displays, Transactions list section headers; `FinancialManagement/Views/Shared/AmountColumnView.swift` (amount column) and the day-header builder in `FinancialManagement/Views/Transactions/TransactionListView.swift`

## What

Nov 12 contains only a transfer ("Top up Jenius", Rp 2.000.000). Its day header
reads `1 item   Rp            0`: a net of zero, with the currency symbol pushed
far left of the digit by the aligned amount column. It reads like a missing
value or an error, and the transfer row below it shows a non-zero amount.

Screenshots: `screenshots/L-closed-tx-outer.png`, `screenshots/L-open-tx-inner.png`.

## Why

- `writing.md`: every element should say something true and useful. A zero net
  for a transfer day isn't information.
- Craft judgment: a split "Rp …… 0" looks broken next to aligned 6–7 digit
  amounts.

## Fix

Hide the day total when the day's net is zero because it contains only
transfers, or show an en dash:

```swift
// Day header
if dayNet != 0 || !dayIsTransfersOnly {
    AmountColumnView(amount: dayNet, ...)
} else {
    Text("—").foregroundStyle(Color.appMutedForeground)
        .accessibilityLabel("No net change")
}
```

## Verify

A month with a transfer-only day: its header shows no amount (or "—"), and
other days are unchanged.
