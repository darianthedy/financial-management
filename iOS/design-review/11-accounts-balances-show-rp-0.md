# 11 — Accounts shows "Rp 0" for every balance (fixtures) / missing balance renders as 0

- **Severity:** Low
- **Where:** both displays, Accounts tab with `DUO_FIXTURES=1`;
  `FinancialManagement/Debug/FixtureStore.swift:14-26`,
  `FinancialManagement/ViewModels/AccountListViewModel.swift:51-56`, `:65-66`

## What

With the fixture backend, the Accounts list shows Rp 0 for every account and
for Total. The Dashboard's Accounts card shows the real balances (Rp 21.480.250,
Rp 3.915.000, …).

Cause: `AccountListViewModel.loadCurrentBalances()` reads
`v_account_current_balance`, which `FixtureStore` doesn't serve. It serves
`rpc/fn_account_balances_at`, which the Dashboard uses. Production is
unaffected, but every fixture-based screenshot and layout test of Accounts shows
wrong data.

The underlying presentation issue applies to production too:

```swift
func balance(for accountId: UUID) -> Int64 {
    balances[accountId] ?? 0
}
```

A balance that failed to load, or hasn't loaded yet, is shown as a confident
"Rp 0", which is misleading in a finance app.

Screenshots: `screenshots/L-closed-accounts-outer.png` vs
`screenshots/L-port-dash-inner.png`.

## Why

- `loading.md` / `feedback.md`: show that content is loading or unavailable;
  don't present placeholder values as real data.

## Fix

1. Add a `v_account_current_balance` fixture to `FixtureStore` (one row per
   fixture account, matching the `fn_account_balances_at` values).
2. Make the balance optional in the UI:

```swift
// Before
func balance(for accountId: UUID) -> Int64 { balances[accountId] ?? 0 }

// After
func balance(for accountId: UUID) -> Int64? { balances[accountId] }
// AccountCard: show a redacted placeholder / "—" when nil
Text(balance.map { $0.asCurrency(code: code) } ?? "—")
    .redacted(reason: balance == nil ? .placeholder : [])
```

The Total row should likewise show "—" when any balance is missing.

## Verify

Fixture run: Accounts balances match the Dashboard card. Simulate a failing
balance request: rows show "—", not Rp 0.
