# Prompt D — Budgets tab (iOS UI audit §5)

**Scope:** P0-only ("Critical captures") pass per `audit/CAPTURE-GUIDE.md`.
Only the P0 evidence below was considered; P1/P2 stills are out of scope and
listed under *Deferred (non-P0)*.

**P0 evidence reviewed**
- `captures/5.1_budgets_swipe.mp4` → stills in `captures/frames/5.1_budgets_swipe/` (16 frames)
- `captures/5.2_budget_popover.mp4` → stills in `captures/frames/5.2_budget_popover/` (16 frames)
- `captures/8_taptargets.png` — **MISSING** (no file, no frames). Tap-target
  items below were resolved against the source instead.

**Source reviewed:** `iOS/.../Views/Budgets/BudgetListView.swift`,
`BudgetCard.swift`, `BudgetFormSheet.swift`, `ActiveInstallmentsSection.swift`.

> **Build note:** this pass ran on Linux/WSL, where no Swift/Xcode toolchain is
> present (`xcodebuild` not found), so the project could not be compiled here.
> The one change made (below) is a minimal, idiomatic copy of a pattern already
> applied to the ⋮ button in the same file and was hand-reviewed for compile
> correctness. A `xcodebuild` pass on macOS is still recommended before merge.

> **State of the code:** the two destructive-confirmation fixes this prompt asks
> to "implement" (swipe-Remove confirmation, installment-Cancel confirmation)
> were already landed by the cross-cutting §9 pass (commit `30324f7`, reported in
> `audit/results/G-consistency-fixes.md`) and are present in this branch's
> source. This pass **verifies** them screen-by-screen against the P0 captures —
> they pass — and adds one consistency fix (info-button hit area).

---

## 5.1 Budgets list — `BudgetListView.swift`

- **Captures attached:** 🎥 `5.1_budgets_swipe` (frames 1–16, dark); cross-ref
  `5.2_budget_popover` frame 12 (Remove alert).
- **HIG checks:** Touch targets ✅ · Dynamic Type ▢(P1) · Dark mode ✅ ·
  Color-independent meaning ✅ · Standard controls ✅ · Destructive
  confirmation ✅ · Sheet dismissal ▢(P1) · Motion ▢(P1) · VoiceOver ▢(P2) ·
  Safe areas ✅
- **Result: Pass**
- **Notes:**
  - **Swipe Remove vs ⋮ Remove consistency — RESOLVED.** Trailing swipe reveals
    **Edit + Remove** with `allowsFullSwipe: false` (frame 11 shows both buttons
    revealed, no auto-fire). Both the swipe Remove (`BudgetListView.swift:46-51`)
    and the card ⋮ Remove (`BudgetCard.swift` → `onRemove`) set the same
    `pendingRemove` state and present the one shared alert
    (`BudgetListView.swift:142-156`). `5.2_budget_popover` frame 12 captures that
    alert ("Remove budget?" / Cancel / Remove) with the exact message in source.
    The audit's flagged inconsistency (swipe deletes directly, menu confirms) no
    longer exists.
  - Toolbar **+ menu** (New Budget / Copy from Previous Month) renders correctly
    (`5.1_budgets_swipe` frame 5).
  - Tap-card → drilldown and Edit paths work (swipe→Edit opens the edit form,
    frame 13). Inline nav title is intentional (documented VStack-over-List
    reason at `BudgetListView.swift:92-98`); reads deliberately.

## 5.2 Budget card — `BudgetCard.swift`

- **Captures attached:** 🎥 `5.2_budget_popover` (frames 1–16); card states in
  `5.1_budgets_swipe` (Food = near-full blue, Others = full red/overspent,
  Social/Transport = partial, Dummy/Test = empty track).
- **HIG checks:** Touch targets ✅ (after fix) · Dynamic Type ▢(P1) · Dark
  mode ✅ · Color-independent meaning ✅ · Standard controls ✅ · Destructive
  confirmation ✅
- **Result: Pass** (with one fix applied)
- **Notes:**
  - **Info `.popover` presents as a popover, not a sheet — Pass.** Frames 4 & 8
    show the carry-over/note popover as a small bubble with a tail anchored to
    the info button ("Test"), overlaying the list — not a full-height sheet. This
    matches `.presentationCompactAdaptation(.popover)` (`BudgetCard.swift:175`).
    Frame 15 shows the list restored after the popover dismisses (tap-outside
    dismissal works).
  - **Progress bar at 0 / partial / full / overspent — Pass.** Confirmed across
    cards: empty track (Rp 0 of Rp 20), partial fills (Social, Transport), near-
    full (Food), and full danger-red on overspent (Others). Bar color logic at
    `BudgetCard.swift:39` (primary vs `.appDanger`).
  - **Color-only overspend cue paired with text — Pass.** Overspent cards show a
    red bar **and** the text "Rp 307.907 over" (`BudgetCard.swift:54-57`); under-
    budget shows "… left". Meaning is not color-dependent.
  - **⋮ tap target — Pass.** Glyph is small but the button has a 44×44 frame +
    `contentShape(Rectangle())` (`BudgetCard.swift:107-111`); the audit's 28×28
    concern is resolved. (`8_taptargets.png` was missing, so verified from
    source.)
  - **Info-button tap target — FIXED this pass.** The `info.circle` button had
    no enlarged frame (≈22pt glyph, sub-44pt). Applied the same 44×44 frame +
    `contentShape` pattern already used by the ⋮ button so the popover anchor and
    glyph are unchanged but the hit area meets the HIG minimum
    (`BudgetCard.swift` header). Row height is unaffected (the ⋮ already sets the
    44pt row height).

## 5.3 Budget form sheet (Add / Edit) — `BudgetFormSheet.swift`

- **Captures attached:** New-budget form (`5.1_budgets_swipe` frame 8), Edit form
  (frame 13). No dedicated P0 form clip — `5.3_*` are P1.
- **HIG checks:** Standard controls ✅ · Destructive confirmation (discard
  guard) ✅ (source) · Save-disabled-until-valid ✅ (source)
- **Result: Pass**
- **Notes:** Title shows month context ("New budget · June 2026" / "Edit budget ·
  June 2026", frames 8/13). Save is disabled until valid (greyed in frame 8 with
  empty amount, enabled in the populated edit, frame 13). Discard-changes guard
  (`interactiveDismissDisabled` + Cancel confirmation) was added in the §9 pass.
  Multiline-note growth is a P1 still — deferred.

## 5.4 Active installments section — `ActiveInstallmentsSection.swift`

- **Captures attached:** Populated cards with span line + scrolling chips
  (`5.2_budget_popover` frames 15: "Epson L8050 · 12 months", "Installment ·
  6 months", chips Food/Others/Social). No dedicated P0 cancel-swipe clip
  (`5.4_*` is P1); cancel behavior verified from source.
- **HIG checks:** Touch targets ✅ · Dark mode ✅ · Standard controls ✅ ·
  Destructive confirmation ✅ (source)
- **Result: Pass**
- **Notes:**
  - **Cancel destructive without confirmation — RESOLVED.** The trailing swipe
    Cancel (`ActiveInstallmentsSection.swift:33-39`, `allowsFullSwipe: false`)
    routes through `onCancel → pendingCancel`, which the owning list confirms via
    a dedicated alert ("Cancel installment?" / Keep Installment / Cancel
    Installment) that explains the cascade to allocations
    (`BudgetListView.swift:159-173`). Verified from source (no P0 clip of the
    swipe).
  - **Tap vs swipe coexistence — Pass.** Row tap opens the source transaction
    (`onTapGesture`, line 26); the trailing swipe is the only destructive
    affordance. `allowsFullSwipe:false` prevents accidental auto-cancel.
  - **Inner horizontal chip scroll vs row scroll/tap — Pass (acceptable).** The
    budget-name chips live in a `ScrollView(.horizontal)` of display-only `Text`
    capsules (lines 80-91). It intercepts horizontal pans only; the List's
    vertical scroll and the row tap continue to work. Visible in frame 15 (chips
    sit inside each card without disrupting the list). Minor follow-up: a future
    VoiceOver pass (P2) should confirm the chips read as a single label.

---

## Summary

| Item | Result | Evidence |
|---|---|---|
| 5.1 Budgets list | **Pass** | `5.1_budgets_swipe` 1–16; `5.2_budget_popover` 12 |
| 5.2 Budget card | **Pass** (1 fix) | `5.2_budget_popover` 4/8/12/15; `5.1_budgets_swipe` states |
| 5.3 Budget form | **Pass** | `5.1_budgets_swipe` 8/13 |
| 5.4 Active installments | **Pass** | `5.2_budget_popover` 15; source |

**Code change this pass:** `BudgetCard.swift` — info-circle button raised to a
44×44 hit area (HIG touch-target minimum), matching the ⋮ button. The two
named destructive-confirmation fixes were already present (commit `30324f7`) and
are verified Pass against the captures.

**Missing capture (noted, not blocking):** `8_taptargets.png` — absent; all
tap-target items were resolved against the source instead.

## Deferred (non-P0)

Evidence for these is P1/P2-only, so they were not evaluated in this pass:
- 5.1/5.2/5.3/5.4 Light/Dark/XXL parity stills (`5.1_budgets*`,
  `5.2_budget_normal/overspent/reserved/carryover_*`, `5.3_budget_form_*`,
  `5.4_installment_card_*`) — Dynamic Type XXL wrapping of the card label +
  progress bar, multiline-note growth, and chip wrapping at XXL.
- Month page transition + Reduce-Motion pass (P1).
- Sheet swipe-dismiss-with-unsaved-edits interactive test (P1/P2; the source
  guard exists but the gesture wasn't captured here).
- VoiceOver pass over cards, swipe actions, and installment chips (P2).
- Pull-to-refresh spinner placement (P2).
