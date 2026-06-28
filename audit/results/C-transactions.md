# Audit Results — Prompt C: Transactions tab (§4)

**Scope:** P0 "Critical captures" only, per `audit/CAPTURE-GUIDE.md`. P1/P2-only
items are listed under *Deferred (non-P0)* rather than evaluated.

**Platform note:** this pass ran on Linux/WSL with no Xcode/Swift toolchain
present (`xcodebuild`/`swiftc` unavailable), so the code fixes below could **not
be compiled here**. They were verified by source review only; the project still
needs a build on macOS before merge. All changes are additive/local and use
standard SwiftUI API (`.swipeActions(allowsFullSwipe:)`,
`.alert(_:isPresented:presenting:)`, `.frame`/`.contentShape`).

**Evidence used (present P0 captures):**
- 🎥 `4.1_transactions_swipe.mp4` → `captures/frames/4.1_transactions_swipe/` (16 stills)
- 🎥 `4.1_transactions_search.mp4` → frames/4.1_transactions_search/
- 🎥 `4.1_transactions_infinite.mp4` → frames/4.1_transactions_infinite/
- 🎥 `4.1_transactions_stickyheaders.mp4` → frames/4.1_transactions_stickyheaders/
- 🎥 `4.3_txn_form_types.mp4` → frames/4.3_txn_form_types/
- 🎥 `4.7_installment_flow.mp4` → frames/4.7_installment_flow/
- 📷 `8_taptargets.png` — **MISSING** (no file present); tap-target items resolved
  from source instead.

---

## 4.1 Transactions list — `TransactionListView.swift`

- **Captures:** 🎥 swipe / search / infinite / stickyheaders (all present).
- **HIG checks:** Touch targets ▢(see 4.2) · Dark mode ✓ · Color-independent
  meaning ✓ · Standard controls ✓ · **Destructive confirmation ✗→fixed** ·
  Keyboard avoidance n/a.
- **Result:** **FAIL → fixed** (swipe-Delete confirmation).

**Findings**

1. **Full trailing swipe deleted immediately, bypassing confirmation — FAIL (fixed).**
   Confirmed from `4.1_transactions_swipe` frames: frame_011 shows the partial
   trailing swipe revealing **Dismiss + Delete** on a pending row; frame_013
   shows a **full** trailing swipe expanding the red Delete to the entire row
   width; frame_016 shows the **JUN 27, 2026 pending row is gone** — deleted with
   **no confirmation alert**. Source confirmed it: `row(for:)` had
   `.swipeActions(edge: .trailing)` (default `allowsFullSwipe: true`) whose Delete
   button called `viewModel.deleteTransaction(txn)` directly, whereas the ⋮-menu
   Delete in `TransactionRow` routes through a "Delete transaction?" alert. This
   is exactly the §9 inconsistency.
   **Fix:** set `allowsFullSwipe: false` on the trailing edge and route the swipe
   Delete through a new list-level confirmation alert
   (`transactionPendingDelete` + `.alert(_:isPresented:presenting:)`) that reuses
   the **same copy** as the ⋮-menu alert. Both destructive paths now confirm
   identically.

2. **Sticky day headers — PASS.** `4.1_transactions_stickyheaders` frame_008 /
   frame_012: the pinned "JUN 26, 2026" header is **fully opaque** (no
   bleed-through of rows scrolling underneath), carries the system-style hairline,
   and the **net-amount column stays aligned** with the row amounts as the list
   scrolls (e.g. header net "−Rp 12.366.623" aligns with the row amount column).
   Matches `dateGroupHeader` (`.background(Color.appBackground)` + bottom hairline
   overlay + shared `widestAmountBody` width). No fix needed.

3. **Search (`.searchable` + debounce + clear) — PASS.**
   `4.1_transactions_search` frame_008: native search field, results filtered to
   matches, native "✕" clear control present. Source debounces at ~300ms
   (`.task(id: searchText)`). Token removal is wired via `filterTokensBinding`.
   No fix needed.

4. **Infinite scroll append — PASS.** `4.1_transactions_infinite` frame_010:
   deep scroll (JUN 5 → JUN 4 → JUN 3) with new day-sections appended and **no
   visible jump**; the load-more `ProgressView` row is gated on `isLoadingMore`.
   No fix needed.

5. **Filter-icon active state — PASS (source).** `filterToolbarButton` swaps to
   the filled SF symbol + `appPrimary` tint when `panelFilterCount > 0`, so the
   active state survives the search bar scrolling away (per the §4.1 check). Not
   exercised in a P0 clip but visible/correct in source.

---

## 4.2 Transaction row — `TransactionRow.swift`

- **Captures:** ⋮ button visible across all 4.1 clips; dedicated
  `8_taptargets.png` **missing**.
- **HIG checks:** **Touch targets ✗→fixed** · Dark mode ✓ · Color-independent
  meaning ✓ (refund `+` sign + color) · Destructive confirmation ✓ (⋮ menu).
- **Result:** **FAIL → fixed** (28×28 ⋮ tap target).

**Findings**

1. **⋮ menu button below 44pt — FAIL (fixed).** `8_taptargets.png` is absent, so
   resolved from source: the ⋮ `Menu` label was
   `Image("ellipsis").frame(width: 28, height: 28).contentShape(Rectangle())` —
   a **28×28** hit area, below the 44×44pt HIG minimum.
   **Fix:** the glyph stays compact but the tappable `frame` is now **44×44**.
   The day-header net column mirrors the ⋮ width for alignment, so its trailing
   spacer in `dateGroupHeader` was bumped 28→44 to keep the net amount lined up
   with the row amount column.

2. **Refund sign/color — PASS (source).** `amountSign` renders a negative expense
   (refund) as `+` with success color, distinct from the danger-colored normal
   expense — color is paired with the sign glyph, so meaning isn't color-only.

3. **⋮-menu Delete confirmation — PASS.** `TransactionRow` Delete sets
   `showDeleteConfirm` → "Delete transaction?" alert (Cancel / destructive
   Delete). This is the behavior the swipe path was made consistent with (4.1.1).

---

## 4.3 Transaction form (New / Edit) — `TransactionFormView.swift`

- **Captures:** 🎥 `4.3_txn_form_types` (present).
- **HIG checks:** Standard controls ✓ · Dark mode ✓ · **Touch targets
  ✗→fixed** (CurrencyField sign toggle) · Motion ✓ (no jank observed).
- **Result:** **PASS** (conditional fields) **+ FAIL→fixed** (sign-toggle target).

**Findings**

1. **Conditional fields animate without jank — PASS.** `4.3_txn_form_types`
   frame_004 (Expense: Account / Amount / Date / Description / Budget / Category /
   Fixed Expense) → segmented Income/Expense/Transfer. Field set switches cleanly;
   no overlap or flashing across sampled frames. Category picker menu (frame_009)
   shows the inline **"Create category"** sentinel; Tag sheet (frame_014) shows
   the searchable multi-select with checkmarks. All standard controls.

2. **CurrencyField +/− sign toggle below 44pt — FAIL (fixed).** Visible as the
   bordered "+" box in frame_004. Source (`CurrencyField.swift`) had the toggle
   at `.frame(width: 30, height: 30)` — below 44pt. It also satisfies the §8.5
   cross-cutting tap-target audit, and `8_taptargets.png` (which would have shown
   it) is missing, so resolved from source.
   **Fix:** kept the 30pt bordered box visually, expanded the tappable area to
   **44×44** via an outer `.frame(width: 44, height: 44).contentShape(Rectangle())`.

3. **Sign toggle reads as a control — PASS.** Bordered box + tint, with the
   documented rationale (numeric keypads lack a minus key). `accessibilityLabel`
   set. No fix.

---

## 4.7 Create virtual installment sheet — `CreateInstallmentSheet.swift`

- **Captures:** 🎥 `4.7_installment_flow` (present).
- **HIG checks:** Standard controls ✓ · Color-independent meaning ✓ · Keyboard
  avoidance ✓ (native `Form`) · Dark mode ✓.
- **Result:** **PASS.**

**Findings**

1. **"Remaining to allocate" color feedback explains the disabled Save — PASS.**
   `4.7_installment_flow` frame_014: an unbalanced grid shows **"Rp 47.952" in
   orange/warning** and the **Save button greyed/disabled**; frame_015/016 show a
   balanced "Rp 0" in muted color with Save enabled. Matches source
   (`summarySection`): `isBalanced → appMutedForeground`, over-allocated
   (`remaining < 0`) → `appDanger`, under-allocated → `appWarning`; and
   `canSave = !selectedNames.isEmpty && isBalanced && !isSaving`. Clear cause →
   effect. No fix.

2. **Keyboard avoidance for grid cells — PASS (native).** The grid is a standard
   SwiftUI `Form` of `Section`s with native decimal `TextField`s
   (`allocationSection`), so the system provides focus-follows-keyboard scrolling.
   Frames 14–16 show the decimal keypad up without layout breakage. The sampled
   stills did not isolate a *bottom* cell being edited while occluded, so this is
   a source-backed PASS rather than a frame-proven one — worth a targeted re-shoot
   (edit the last budget's last month with the keyboard up) if a P1 pass is run.

3. **Split evenly / Stepper / segmented Start month — PASS.** Standard controls;
   `applyEvenSplit()` re-balances on budget/months/start changes and on the
   "Split evenly" button, and the segmented + Stepper are native.

---

## Deferred (non-P0)

These §4 items have **no P0 capture**; per scope they are not evaluated here.
Their evidence is P1/P2 stills (Light/Dark/XXL parity) or unshot clips:

- **4.4 Filter sheet** (`TransactionFilterSheet.swift`) — evidence is
  `4.4_filter_top` / `4.4_filter_facet_expanded` stills (P1). Not shot.
- **4.5 Multi-select facet** (`MultiSelectFacet.swift`) — `4.5_facet_mixed` /
  `4.5_facet_collapsed` stills (P1). Not shot.
- **4.6 Summary sheet** (`TransactionSummarySheet.swift`) — `4.6_summary` still
  (P1). Not shot.
- **4.1 / 4.2 parity stills** — `_empty` / `_emptyfiltered` / `_manytags`,
  `4.2_row_*`, `4.3_txn_form_new/edit/error`, `4.7_installment_grid/balanced/
  unbalanced` (all P1). Not shot.

---

## Missing P0 captures (noted, not blocking)

- **`8_taptargets.png`** — absent. The two tap-target findings it would have
  documented (4.2 ⋮ button, 4.3 CurrencyField sign toggle) were instead resolved
  directly from source and fixed.

---

## Fixes implemented this pass

| # | File | Change |
|---|---|---|
| 1 | `TransactionListView.swift` | Trailing swipe Delete now `allowsFullSwipe: false` and routes through a `transactionPendingDelete` confirmation alert reusing the ⋮-menu copy. |
| 2 | `TransactionRow.swift` | ⋮ menu button hit area 28×28 → **44×44** (glyph unchanged). |
| 3 | `TransactionListView.swift` | Day-header net-column spacer 28 → 44 to stay aligned with the wider ⋮ button. |
| 4 | `CurrencyField.swift` | +/− sign toggle tappable area expanded to **44×44** (30pt visual box preserved). |

**Verification matrix (default + XXL type, light + dark, compact width):** not
run as live builds on this host (no Xcode). The changes are layout-local: the
44pt ⋮/toggle frames and the matched 44pt header spacer preserve column
alignment at any Dynamic Type size; the alert and `allowsFullSwipe` change are
behavioral and theme-independent. Recommend a macOS build + a quick XXL/Dark/SE
sweep before merge.
