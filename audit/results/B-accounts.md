# Audit Results — Prompt B: Accounts tab (P0-only pass)

Apple HIG compliance audit of the **Accounts tab**, scoped to the **P0 "Critical
captures"** tier per `audit/CAPTURE-GUIDE.md`. Source of truth:
`iOS/.../Views/Accounts/*.swift`. Section references are to
`Financial Management - iOS UI Compliance Audit.md` §3.

## Scope & evidence used

P0 captures available for this tab (reviewed as sampled PNG stills under
`captures/frames/<clip>/`):

- `captures/3.2_account_archive.mp4` → `captures/frames/3.2_account_archive/` (16 stills)
- `captures/3.3_account_dismiss.mp4` → `captures/frames/3.3_account_dismiss/` (16 stills)

Every other §3 capture (`3.1_accounts_list/_empty/_longname`,
`3.2_account_detail_avatar/_noavatar`, `3.3_account_form_add/_edit`) is a **P1
still** and is therefore **out of scope** for this pass — listed under
*Deferred (non-P0)* below, not evaluated.

**Build verification:** this machine (WSL2 Linux) has **no Xcode/Swift
toolchain** (`xcodebuild`/`swiftc` absent), so I could not run a compile. The
two fixes use only standard SwiftUI APIs already used elsewhere in the codebase
(`.alert`, `.confirmationDialog`, `.interactiveDismissDisabled`) and the
existing `Self.balanceString(_:decimalPlaces:)`; they were verified by
inspection. **A human must run an Xcode build** to confirm compilation.

---

## §10 findings

### 3.2 — Archive is destructive with NO confirmation — **FAIL → FIXED**

**Evidence:** `captures/frames/3.2_account_archive/` frame_012 shows the detail
screen for "Test archive" with the red **Archive Account** button. frame_013
shows the view already popping back to the list immediately after the tap, and
frame_014/015 show the list with **"Test archive" gone** — no intervening alert
or action sheet at any frame. This confirms the §3.2 / §9 flag: a destructive,
hard-to-undo action fires with zero confirmation, inconsistent with the rest of
the app (`BudgetCard.swift:82` "Remove budget?" alert, `TransactionRow.swift:103`
"Delete transaction?" alert).

**Fix** (`Views/Accounts/AccountDetailView.swift`): the Archive button now sets
`showingArchiveConfirm = true` instead of archiving directly. Added a
`.alert("Archive account?", …)` with a **Cancel** (`.cancel`) and **Archive**
(`.destructive`) button, matching the app's existing confirmation pattern. The
archive + `dismiss()` now run only from the destructive button. Copy reflects
the real semantics — archive is a **soft-delete** (`AccountRepository.swift:96`
sets `is_archived = true`), so the message states the account is hidden and its
transaction history is preserved (it does not claim permanent deletion).

### 3.3 — Sheet swipe-dismiss silently discards unsaved edits — **FAIL → FIXED**

**Evidence:** `captures/frames/3.3_account_dismiss/` frame_007 shows the name
field being edited (caret after "Budget Adjustment"); frame_010 shows it changed
to **"Budget Adjustment 1"**; frame_013 shows the sheet mid swipe-down dismiss;
frame_016 shows the underlying detail back with **Name = "Budget Adjustment"** —
the "1" edit was silently lost with no confirmation. Confirms §3.3 / §9: no
`interactiveDismissDisabled`, no discard-changes guard.

**Fix** (`Views/Accounts/AccountFormSheet.swift`):
- Added a `hasUnsavedChanges` computed property comparing current field state
  against the initial state (add-mode defaults, or the loaded account for edit
  mode), including staged/removed avatar.
- `.interactiveDismissDisabled(hasUnsavedChanges || isSaving)` — blocks the
  interactive swipe-down whenever there are unsaved edits **or** a save is in
  flight (the latter also covers the §3.3 "can't be swipe-dismissed mid-save"
  concern).
- The **Cancel** button now shows a `.confirmationDialog("Discard Changes?", …)`
  (Discard Changes / Keep Editing) when there are unsaved edits, and dismisses
  directly otherwise — the canonical iOS discard pattern, giving the user the
  intentional exit path the blocked swipe no longer provides.

### 3.3 — Save disabled until valid + during save — **PASS** (source)

`AccountFormSheet.swift:109` `.disabled(name.isEmpty || isSaving)` — Save is
disabled until a name is entered and while a save is in flight. Cancel/Save
placement is correct (`.cancellationAction` leading / `.confirmationAction`
trailing). Verified from source.

---

## Deferred (non-P0) — evidence is P1/P2-only, not evaluated this pass

- **3.1 Accounts list** (`3.1_accounts_list/_empty/_longname` — P1 stills): row
  `NavigationLink` chevron/push, default-star + type/"Off dashboard" badge
  legibility, total row reading as a header, long-name truncation, empty state,
  Light/Dark/XXL parity. *(Source note, not a finding: `AccountListView` uses
  `NavigationLink` rows and a toolbar **+**, consistent with the audit's
  description; no swipe-to-delete in the list, which is intentional since archive
  lives in detail.)*
- **3.2 Account detail** remaining checks (`3.2_account_detail_avatar/_noavatar`
  — P1 stills): avatar present/absent rendering, `LabeledContent` read-only rows,
  Light/Dark + XXL parity, pull-to-refresh.
- **3.2 / 7.10 AccountAvatar** loading / placeholder / failure states (P2 clip
  `7.10_avatar_fallback.mov`, not captured).
- **3.3 Account form** remaining checks (`3.3_account_form_add/_edit` — P1
  stills): photo-upload progress indicator, PhotosPicker permission-prompt copy,
  live avatar preview update, footer copy, Add vs Edit titles, Light/Dark + XXL
  parity, touch targets.

---

## Left for a human decision

1. **Run an Xcode build** of the two changed files — no Swift toolchain on this
   (Linux/WSL2) machine, so compilation was not verified here.
2. **Re-verify both fixes in the running app** at default + XXL Dynamic Type and
   in Light + Dark: (a) Archive → alert appears, Cancel aborts, Archive removes
   the account; (b) edit a field → swipe-down bounces back, Cancel offers
   "Discard Changes?", Save still dismisses normally. (Frames could not exercise
   the post-fix behavior; the captures predate the change.)
3. **Discard UX choice:** the discard guard uses a `.confirmationDialog`
   (action sheet — Apple's canonical discard pattern) while the archive guard
   uses an `.alert` (matching the app's other destructive confirms). If strict
   in-app consistency is preferred over the platform discard idiom, the discard
   guard could be switched to an `.alert`; left as-is intentionally.
4. **Archive button label vs. behavior:** the button reads "Archive Account" and
   the action is a soft-delete (`is_archived = true`). The new alert copy makes
   this explicit; confirm the wording matches product intent.

---

## Missing-capture notes

All P0 captures for this tab were present. No §3 P0 clip was missing.
