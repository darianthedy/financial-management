# Audit F — Shared form components (P0-only pass)

**Scope:** This run is a **P0 "Critical captures" only** pass per
`audit/CAPTURE-GUIDE.md`. For Prompt F the relevant P0 evidence is:

- `captures/8_taptargets.png` — the dedicated tap-target capture (⋮ buttons,
  Scheduled buttons, **MonthNavigator chevrons**, **CurrencyField +/− toggle**
  vs the 44pt minimum). **MISSING** — no `.mp4`, no `frames/` folder.
- `captures/4.3_txn_form_types.mp4` (P0) — present, sampled to
  `captures/frames/4.3_txn_form_types/` (16 stills). Shows the pickers in form
  context and a picker menu open.

Because `8_taptargets.png` is absent, the two P0 tap-target items
(MonthNavigator chevrons §7.7, CurrencyField sign toggle §7.6) were resolved
**directly from the iOS source as source of truth**, as the pass rules allow.

All remaining §7 items (create-sentinel pickers, TagPicker/FlowLayout, currency
grouping/blur-settle, label-shift, avatar fallback, etc.) have **P1/P2-only
evidence** (the `7.x_*` stills, `7.10_avatar_fallback.mov`) and are therefore
**out of scope** — listed under *Deferred (non-P0)* below, not evaluated.

**Build status:** This host (Linux/WSL) has no Swift/Xcode toolchain, so
`xcodebuild` could not be run. The one code edit was hand-verified: it adds an
outer `.frame(width: 44, height: 44)` + `.contentShape(Rectangle())` to the
`Button`'s `Image` label — the **identical idiom already shipping in
`MonthNavigator.swift`** for the chevrons. A human should compile on a Mac
before merge.

---

## P0 items evaluated

### §7.7 — MonthNavigator chevron hit area — **Pass**
`MonthNavigator.swift` (lines 16–22, 37–41). Each chevron `Image` is wrapped in
`.frame(width: 44, height: 44)` + `.contentShape(Rectangle())`, so the full
44×44pt region is tappable even though the glyph is much smaller — meets the HIG
44pt minimum. The centered label uses `.frame(minWidth: 128)` so the month name
cannot shift the chevrons as it changes (label-shift check satisfied). No change
needed.

### §7.6 — CurrencyField +/− sign toggle hit area — **Fail → Fixed**
`CurrencyField.swift` (lines 38–51, before fix). The toggle `Button`'s tappable
area was bounded by `.frame(width: 30, height: 30)` on the `Image` label — a
**30×30pt** target, below the HIG 44pt minimum. The 30pt bordered square is the
intended *visual* chrome (mirrors the web `+/−` button), but the hit region must
not be that small.

**Fix applied:** kept the 30×30 bordered visual, then expanded the tappable
region by adding `.frame(width: 44, height: 44)` + `.contentShape(Rectangle())`
around it (same pattern as the MonthNavigator chevrons). The button still reads
as a 30pt square but now accepts taps across the full 44×44pt area.

```swift
Image(systemName: isNegative ? "minus" : "plus")
    .font(.system(size: 15, weight: .medium))
    .frame(width: 30, height: 30)
    .foregroundStyle(isNegative ? Color.appDanger : Color.secondary)
    .overlay(RoundedRectangle(cornerRadius: 6).stroke(...))
    // Keep the 30pt bordered chrome (mirrors web's +/− button)
    // but expand the tappable region to the 44×44pt HIG minimum.
    .frame(width: 44, height: 44)
    .contentShape(Rectangle())
```

Discoverability of the toggle (the secondary check on §7.6) is satisfied by
design: the bordered button sits inline before the amount field with a clear
`plus`/`minus` glyph and an `accessibilityLabel("Toggle positive or negative")`,
and only renders when `allowNegative` is true (income/expense), so it doesn't
appear where a sign is invalid (budgets, transfers, balances). Confirmed against
`4.3_txn_form_types` frames: the Transfer amount row correctly shows **no**
toggle (`frame_001`, `allowNegative` off).

### §7.2–7.4 — picker create-sentinel in context — **Pass (partial, P0 frames)**
`4.3_txn_form_types/frame_008` shows the Budget picker **menu open** over the
transaction form with the form rows (Account/Amount/Date/Budget/Category/Fixed
Expense) intact behind it, confirming the picker presents and dismisses back to
the form cleanly. The dedicated *inline Create → nested CreateCategorySheet*
sentinel flow is only fully shown by the P1 `7.x_*_open` stills, so the
sentinel-revert behavior itself is deferred (see below); source review of the
sentinel logic was not in P0 scope this pass.

---

## Deferred (non-P0) — evidence is P1/P2 only, not evaluated this pass

| # | Item | Evidence needed (not P0) |
|---|---|---|
| 7.1 | AccountPicker async load / no empty flash | `7.1_accountpicker_open_*` |
| 7.2 | CategoryPicker create-sentinel reverts + opens `CreateCategorySheet`; swatch contrast | `7.2_categorypicker_open_*` |
| 7.3 | BudgetPicker create-sentinel; date-scoped options | `7.3_budgetpicker_open_*` |
| 7.4 | FixedExpensePicker create-sentinel | `7.4_fixedpicker_open_*` |
| 7.5 | TagPicker multi-select chips, Return-key select/create-on-no-match | `7.5_tagpicker_sheet_*` |
| 7.6 | CurrencyField live thousands-grouping, caret-not-fought, blur-settle padding | `7.6_currencyfield_*` |
| 7.7 | MonthNavigator numeric content transition + label min-width at XXL | `7.7_monthnavigator_*` |
| 7.8 | EmptyStateView (`ContentUnavailableView`) action styling | P1 per-screen stills |
| 7.9 | FlowLayout wrapping at XXL / narrow width | `4.1_transactions_manytags`, XXL stills |
| 7.10 | AccountAvatar progress → fallback-icon path; Badge / AmountColumnView | `7.10_avatar_fallback.mov` (P2) |
| — | Light/Dark/XXL parity for every component | P1 stills |

---

## Notes / missing captures

- **`8_taptargets.png` was not captured.** The two P0 tap-target items it would
  cover were resolved from source instead (chevrons Pass; sign toggle Fail→Fixed).
  Re-shooting it with Accessibility Inspector is recommended to visually confirm
  the now-44pt sign-toggle hit area and the existing 44pt chevrons.
- Re-verify the fix at **default + XXL** Dynamic Type and **light + dark** once a
  Mac build is available; the 14pt of extra hit-area width on the toggle is
  absorbed by the trailing layout and should not affect the amount field.
