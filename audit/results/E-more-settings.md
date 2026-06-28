# Prompt E — More tab & Settings (HIG audit §6)

P0-only pass. Apple HIG compliance audit of the **More** tab and its sub-screens
(Fixed Expenses, Scheduled, Settings, Currency picker) per §6 of
*Financial Management — iOS UI Compliance Audit* and `audit/CAPTURE-GUIDE.md`.

Source reviewed under `iOS/FinancialManagement/FinancialManagement/Views/`:
`More/MoreView.swift`, `FixedExpenses/*.swift`,
`Scheduled/ScheduledListView.swift` + `PendingTransactionRow.swift`,
`Settings/SettingsView.swift` + `CurrencyPickerView.swift`,
`Services/NotificationService.swift`.

> **Build note:** this pass ran on Linux/WSL, where no Swift/Xcode toolchain is
> available (`xcodebuild`/`swiftc` not present), so the project could not be
> compiled here. The one code change is minimal, idiomatic SwiftUI
> (`ViewThatFits` + a `@ViewBuilder` helper) and was reviewed by hand for
> type/compile correctness. A `xcodebuild` pass on macOS is still recommended
> before merge. Verification at default + XXL, light + dark, must be done on a
> simulator/device on macOS.

## P0 scope & evidence status

- `captures/frames/6.6_scheduled_permission/` (16 PNG stills from
  `captures/6.6_scheduled_permission.mp4`) — **present**, reviewed.
- `8_taptargets.png` — **MISSING** (no `.png` and no frames folder in
  `captures/`). Tap-target items below were resolved from source instead; the
  Accessibility-Inspector overlay this still was meant to provide is unshot.

Everything whose only evidence is a P1/P2 still (the `6.1_more_*`,
`6.2/6.3/6.4/6.5_*`, `6.7_settings_*`, `6.8_currency_picker_*`,
`6.6_scheduled[_paused/_empty/_xxl]` stills) is **out of P0 scope** and listed
under *Deferred (non-P0)*; those are evaluated from source only where a §6 HIG
flag overlaps, and not marked Pass/Fail on appearance.

---

## §10 findings

### 6.1 — More menu: Sign Out confirmation — **PASS** (fixed earlier)
- HIG flag: Sign Out is destructive and was firing immediately with no confirm.
- Source `More/MoreView.swift:36-59`: the Sign Out `Button(role: .destructive)`
  now only sets `showingSignOutConfirm`; a `.confirmationDialog("Sign out?", …)`
  with a destructive **Sign Out** + **Cancel** and an explanatory message runs
  the actual `signOut()`. This landed in commit `30324f7` (cross-cutting §9
  pass). Confirmed present and correct — no further change.
- Evidence: source; `captures/frames/6.6_scheduled_permission/frame_001.png`
  shows the More list with the destructive (red) Sign Out row.

### 6.6 — Scheduled: notification permission requested cold — **FAIL** (flagged; not auto-fixed)
- `Scheduled/ScheduledListView.swift:50-55`: the `.task` calls
  `NotificationService.shared.requestPermission()` unconditionally on first
  appearance, so the **system** permission alert fires the moment the user opens
  Scheduled, with no in-context rationale.
- Evidence: `captures/frames/6.6_scheduled_permission/frame_003.png` shows the
  cold system prompt *"FinancialManagement Would Like to Send You
  Notifications"* appearing immediately on the empty Scheduled screen — exactly
  the abrupt cold prompt §6.6 / §9 flags.
- HIG: requests for permission should be made *in context, with a pre-prompt*
  explaining the value (so a "Don't Allow" doesn't permanently burn the only
  system grant). **Left as a flag, not auto-fixed**, because the task scopes
  this to "flag; consider an in-context rationale" rather than a confident fix,
  and a proper pre-prompt is a behavioural UX change (custom rationale alert +
  deferring the system request until the user opts in, ideally tied to actually
  scheduling something rather than merely viewing the list). Recommended fix:
  gate `requestPermission()` behind a one-time in-app rationale sheet/alert
  ("Get reminded when a scheduled transaction is due?" → Enable / Not Now), and
  only request when the user has at least one scheduled item.

### 6.6 — Scheduled: pending-row inline button tap targets — **PASS** (fixed earlier)
- HIG flag: Confirm/Edit/Dismiss use `.controlSize(.small)`, likely < 44pt tall.
- `Scheduled/PendingTransactionRow.swift`: each button label carries
  `.frame(… minHeight: 44)`, so the hit area is ≥ 44pt tall while keeping the
  compact `.controlSize(.small)` look. Confirmed present (from `30324f7`).
- Evidence: source. (`8_taptargets.png`, which would have shown the hit-area
  overlay, is missing — height verified by code, not by the Inspector still.)

### 6.6 — Scheduled: 3-button row crowds / truncates at XXL & narrow widths — **FAIL → FIXED**
- HIG flag (§6.6, "the 3-button row is the key XXL risk"): three labelled
  buttons in one HStack each `frame(maxWidth: .infinity)` split the row into
  equal thirds; icon + label doesn't fit a third, so labels truncate.
- Evidence: `captures/frames/6.6_scheduled_permission/frame_005.png` and
  `frame_010.png` show truncation **even at default Dynamic Type** — the buttons
  read **"Conf…"**, "Edit", **"Dis…"**. At XXL this only gets worse. The
  prior `minHeight: 44` fix addressed *height* but not this *horizontal*
  crowding.
- **Fix applied** (`PendingTransactionRow.swift`): the three buttons were
  extracted into an `actionButtons(fillWidth:)` `@ViewBuilder` and wrapped in
  `ViewThatFits(in: .horizontal)`. The preferred candidate is an `HStack` of
  natural-width buttons (so "Confirm"/"Edit"/"Dismiss" show in full at default
  width); when three labelled buttons can't fit the row (large Dynamic Type /
  narrow device) it falls back to a **full-width vertical `VStack`** where each
  button gets the whole width and its full label. Each button keeps
  `minHeight: 44` and `lineLimit(1)` in both layouts.
- **Needs on-device verification** at default + XXL, light + dark, to confirm
  the horizontal→vertical switch fires at the right size and no label truncates.

### 6.2 — Fixed Expenses: destructive swipe `allowsFullSwipe: false` (inconsistency note) — **PASS (with note)**
- `FixedExpenses/FixedExpenseListView.swift:137-149`: trailing swipe Delete uses
  `allowsFullSwipe: false` (long swipe reveals the button rather than
  auto-deleting) **and** routes through a shared `.alert("Delete fixed
  expense?")` confirmation (lines 64-78). This is the *safer* behaviour and, per
  the §9 cross-cutting pass (`30324f7`), the rest of the app's destructive
  swipes were aligned to the same rule — so the inconsistency the audit flagged
  (Fixed Expenses vs Transactions) is resolved in the conservative direction.
  No change needed.

### 6.4 / 6.5 — Fixed Expense form sheets: discard guard — **PASS** (out of strict P0 evidence, confirmed in source)
- `FixedExpenseFormSheet.swift:62-67` and `FixedExpenseEditSheet.swift:76-81`
  both present a "Discard Changes / Keep Editing" `.confirmationDialog`. Noted
  as already-correct; no P0 capture for these forms, so not graded on appearance.

### 6.7 — Settings: theme segmented control & live currency reload — **N/A for P0** (no present P0 capture)
- Source is consistent with the §6.7 description (segmented `Picker` bound to
  `themeManager.preference`; `onChange(of: defaultCurrency)` calls
  `appState.updateDefaultCurrency`, which reloads formatters app-wide). The live
  re-theme and currency-reload behaviour can only be confirmed from
  `0.3_theme_live.mp4` / the `6.7_settings_*` stills, which are P1/out of scope
  here. **Deferred.**

### 6.8 — Currency picker: search + select-and-pop — **N/A for P0** (no present P0 capture)
- `CurrencyPickerView.swift`: `.searchable` filters by code/name, checkmark on
  selected, tap sets `selectedCode` + `dismiss()` (select-and-pop). Matches the
  §6.8 description in source; "feels abrupt vs back button" is a judgement that
  needs the `6.8_currency_picker_*` stills (P1). **Deferred.**

---

## Deferred (non-P0)

Evidence for these is P1/P2 only (per-screen light/dark/XXL stills or full
matrix), so they are out of scope for this pass and were not graded on
appearance:

- `6.1_more_*` (grouped-list appearance, section headers/footers).
- `6.2_fixed_list_* / _empty_*`, `6.3_fixed_row_paid_* / _unpaid_*`
  (paid/unpaid split, subtotals, row legibility, empty state).
- `6.4_fixed_form_add_*`, `6.5_fixed_form_edit_*` (form appearance, Save-disabled).
- `6.6_scheduled_* / _paused_* / _empty_* / _xxl` stills (the **`_xxl` still is
  the one that would visually confirm the 3-button fix** — capture it next pass).
- `6.7_settings_*` (segmented theme control + footnotes; live re-theme via
  `0.3_theme_live.mp4`).
- `6.8_currency_picker_*` (searchable list + checkmark, light/dark/XXL).

## Missing captures (noted, not blocked)

- `8_taptargets.png` — absent. Tap-target heights (Scheduled buttons, etc.) were
  verified from source (`minHeight: 44`) rather than from an Accessibility
  Inspector overlay.
- `6.6_scheduled_xxl` — not present in `captures/`; the XXL 3-button layout fix
  was driven by the truncation visible at default type in the permission clip
  and reasoned through for XXL. On-device XXL verification still pending.

## Changes in this pass

- `Views/Scheduled/PendingTransactionRow.swift` — wrap the Confirm/Edit/Dismiss
  actions in `ViewThatFits` (horizontal natural-width row → full-width vertical
  stack fallback) to stop label truncation at default width and crowding at XXL,
  preserving the 44pt hit targets.

All other §6 P0 HIG flags (Sign Out confirm, pending-row 44pt height, Fixed
Expense delete confirmation) were already satisfied by commit `30324f7` and
required no change. The notification cold-prompt remains an open flag with a
recommended in-context-rationale fix.
