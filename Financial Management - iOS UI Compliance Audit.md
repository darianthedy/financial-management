# Financial Management — iOS UI Compliance Audit Plan

> **Purpose.** This document inventories every screen, popup, dialog, panel, sheet,
> picker, and interaction in the iOS app, then gives a concrete, per‑item plan for
> checking each against Apple's **Human Interface Guidelines (HIG)** and platform
> conventions. Each item lists exactly **what to capture (screenshot or video) and
> which parts / interactions must be recorded** so the review can be done without
> guessing.
>
> **Scope.** SwiftUI app under `iOS/FinancialManagement/`. Source‑derived; no
> device run was performed, so the "Capture" instructions exist to confirm the
> real rendered behavior (animation, spacing, Dynamic Type, dark mode, haptics).
>
> **How to use this doc.** Work top‑to‑bottom. For every item: (1) record the
> listed captures on a real device if possible (Simulator is acceptable for layout
> but not for haptics / true ProMotion scrolling), (2) walk the checklist, (3) mark
> Pass / Fail / N‑A and attach the capture. Capture **both Light and Dark mode**
> and at least **two Dynamic Type sizes** (default + XXL/Accessibility) for every
> screen.

---

## Legend & global capture conventions

- 📷 = still screenshot · 🎥 = screen recording (video).
- **Device matrix (minimum):** one notched/Dynamic‑Island device (e.g. iPhone 15/16 Pro) **and** one smaller/older device (e.g. iPhone SE) to validate safe areas and compact width.
- **Appearance:** every screen captured in **Light** and **Dark** (the app uses tokenized colors with explicit dark variants via `AppTheme` / `Assets.xcassets`).
- **Dynamic Type:** capture at default and at an Accessibility size (XXL+) to verify text scaling, truncation, and tap‑target growth.
- **Orientation:** primary check is Portrait; capture one Landscape of a long list and one form.
- **Accessibility overlays to record at least once per major screen:** VoiceOver on (🎥 swipe‑through reading order), Accessibility Inspector audit, and "Reduce Motion" on for the animated transitions.

---

## 0. App‑wide / global UI

These apply across the whole app and should be verified once, then spot‑checked per screen.

| # | UI element | Where defined | Interactions |
|---|---|---|---|
| 0.1 | Root tab bar (5 tabs: Dashboard, Accounts, Transactions, Budgets, More) | `ContentRootView.swift` | Tab tap, tab re‑tap (scroll‑to‑top / pop‑to‑root expectation) |
| 0.2 | Navigation bars (large title vs inline; scroll‑edge transparency) | `FinancialManagementApp.swift` (`configureNavigationBarAppearance`) | Scroll to collapse large title; nav‑bar background fades in on scroll |
| 0.3 | Color tokens & theming (Light / Dark / System) | `AppTheme.swift`, `ThemeManager`, `Assets.xcassets` | System appearance switch; in‑app Theme picker (Settings) |
| 0.4 | Card surface treatment (radius 10, hairline border, `shadow-sm`) | `AppTheme.appCardSurface()` | Static |
| 0.5 | Auth gate (Login vs main app) | `FinancialManagementApp.swift` | Sign in / sign out transition |

### Plan — 0.1 Tab bar
- **Check:** 5 items is within HIG's recommended ≤5 tab limit (good). Icons are SF Symbols; verify each has a text label, selected/unselected tint follows system, and labels don't truncate at large Dynamic Type. Confirm "More" is a genuine overflow destination, not a hidden critical feature.
- **HIG focus:** Tab bars should persist across the app, never be used for actions, and badge only for meaningful counts (none here). Re‑tapping the active tab should scroll to top / pop to root — verify this works.
- 📷 Tab bar in Light + Dark, default + XXL Dynamic Type (watch for label truncation/wrapping).
- 🎥 **Record:** tapping through all 5 tabs; then re‑tapping the *current* tab on a scrolled Transactions list to confirm scroll‑to‑top/pop‑to‑root behavior.

### Plan — 0.2 Navigation bars
- **Check:** The app overrides `UINavigationBarAppearance` so the bar is transparent at scroll‑edge (large title shows) and opaque after scrolling. Verify there is **no visible "pop"/flicker** at the moment the bar swaps appearances, the hairline matches system, and large‑title → inline collapse animates smoothly.
- **Per‑screen title mode is inconsistent by design** (Transactions = large; Budgets / Fixed Expenses = inline because of the `VStack`‑over‑`List`). Confirm each reads intentionally, not accidentally.
- 🎥 **Record (critical):** slow scroll up/down on **Dashboard, Transactions, Accounts** capturing the large‑title collapse and the bar background fade — this is the highest‑risk custom behavior.
- 📷 Top (scroll‑edge) state and scrolled state, Light + Dark, for each list screen.

### Plan — 0.3 Theming
- **Check:** every color is a token with a Dark variant; confirm no hard‑coded colors leak (search already shows tokens used, but verify visually). Check contrast ratios meet WCAG AA for text on `appCard`/`appBackground`, especially `appMutedForeground` and the success/danger/warning tints.
- 🎥 **Record:** toggling Settings → Theme between Light / Dark / System and the device Control‑Center appearance switch, confirming the whole app (including open sheets) updates live.
- 📷 Every screen in Light **and** Dark (this is why each screen below says "Light + Dark").

### Plan — 0.4 Card surface & 0.5 Auth gate
- 📷 A representative card (Dashboard) zoomed in to inspect corner radius, border hairline, and shadow at 1×/2×/3× scale.
- 🎥 **Record:** sign‑out from More → return to Login, and a fresh sign‑in → landing on Dashboard, to confirm the root swap isn't jarring (HIG: launch/transition should feel continuous).

---

## 1. Authentication

### 1.1 Login / Sign‑up screen — `LoginView.swift`
**Type:** Full screen (scrollable centered card).
**Interactions:** Email field, Password (secure) field, primary submit button (with loading spinner), Sign‑in/Sign‑up mode toggle, inline error text, keyboard.

- **Check (HIG):**
  - Email field uses `.emailAddress` content type + keyboard, autocaps off, autocorrect off (✓ present) — confirm QuickType / autofill (Passwords) actually appears.
  - Password uses `.password` / `.newPassword` content type — verify Strong‑Password autofill and the "Save password" prompt on sign‑up.
  - The submit button is a **custom** 44pt‑height filled button (`.buttonStyle(.plain)` + manual background). Confirm it meets the **44×44pt minimum touch target**, shows a clear disabled/loading state, and that the spinner replaces the label without layout shift.
  - Error text uses danger token at caption size — verify legibility and that it's announced by VoiceOver.
  - Keyboard avoidance: the card is in a `ScrollView`; verify fields aren't hidden behind the keyboard and Return key moves focus / submits sensibly.
- 🎥 **Record:** focusing Email (keyboard + autofill bar), moving to Password (Strong Password offer), submitting with empty/invalid creds to show the inline error, toggling Sign in ↔ Sign up (copy changes), and the button's loading spinner state.
- 📷 Light + Dark; default + XXL Dynamic Type (watch the 44pt button height and card padding at large sizes); small‑device (SE) to confirm the card isn't clipped.

---

## 2. Dashboard tab

### 2.1 Dashboard screen — `DashboardView.swift`
**Type:** Scrollable page (large title). Contains MonthNavigator + 4 cards.
**Interactions:** Vertical scroll, **pull‑to‑refresh**, month prev/next (chevrons) with **push page transition**, realtime auto‑refresh.

- **Check:** pull‑to‑refresh spinner placement under the large title; the `ProgressView` loading state (200pt min height) shouldn't cause a jarring jump when data arrives; month change uses `.push(from:)` transition — verify direction matches navigation (next = push from trailing) and respects **Reduce Motion**.
- 🎥 **Record (critical):** month forward/back several times to capture the push transition + the `MonthNavigator` numeric‑text content transition; pull‑to‑refresh; and a Reduce‑Motion pass of the same month change.
- 📷 Full scroll of all 4 cards in Light + Dark, default + XXL Dynamic Type.

### 2.2 Budget Verdict banner — `BudgetVerdictBanner.swift`
**Type:** Card with 4pt left accent stripe, status icon, headline + detail.
- **Check:** color‑only signaling (green/red) must also be distinguishable by icon (✓ check vs triangle) for color‑blind users; confirm `minimumScaleFactor(0.7)` doesn't shrink the overage figure below legibility; hidden entirely when no budgets (verify the empty case).
- 📷 On‑track (green) **and** overspent (red) states, Light + Dark, XXL type.
- 🎥 Optional: VoiceOver reading the banner (must convey status without relying on color).

### 2.3 Accounts card — `AccountsCard.swift` (+ `AmountColumnView`)
**Type:** Card listing accounts with right‑aligned aligned amounts.
- **Check:** the shared amount‑column alignment (symbol/digits) holds across rows and at XXL type; negative balances use danger color **and** sign (not color alone).
- 📷 With several accounts incl. a negative balance, Light + Dark, default + XXL type (verify the digit column stays aligned and nothing truncates badly).

### 2.4 Planned Expenses card — `PlannedExpensesCard.swift`
- **Check:** mixed budget + fixed‑expense rows, paid/unpaid affordance, amount alignment; empty state copy via `DashboardCardEmptyState` (dashed box).
- 📷 Populated state + empty state, Light + Dark, XXL type.

### 2.5 Unplanned Expenses card — `UnplannedExpensesCard.swift`
- **Check:** emoji leading glyphs render consistently; "Uncategorized" italic + muted row is still legible; negative totals show `-`.
- 📷 Populated (incl. a negative/refund category) + empty state, Light + Dark, XXL type.

---

## 3. Accounts tab

### 3.1 Accounts list — `AccountListView.swift`
**Type:** `List` (large title). Total row + account rows (`AccountCard`) as `NavigationLink`s. Toolbar **+** (add). Empty state with action.
**Interactions:** Tap row → push detail; tap **+** → add sheet; scroll; empty‑state "Add account".
- **Check:** rows are `NavigationLink` (chevron + push) — good iOS pattern; default‑account star and type/"Off dashboard" badges legible; total row reads as a header, not a tappable row. No swipe‑to‑delete here (archive lives in detail) — confirm that's intentional and discoverable.
- 🎥 **Record:** tap a row → detail push → back; tap **+** → sheet present/dismiss.
- 📷 Populated + empty state, Light + Dark, XXL type; a row with a long account name (truncation).

### 3.2 Account detail — `AccountDetailView.swift`
**Type:** `List` (inset‑grouped style sections). Avatar header, Account Info, flags, **Archive** (destructive) button. Toolbar **Edit**. Pull‑to‑refresh.
**Interactions:** Edit → sheet; Archive → deletes & pops; refresh.
- **Check (HIG):** **Archive is a destructive action with no confirmation** — HIG recommends confirming destructive, hard‑to‑undo actions (compare: budget remove & transaction delete *do* confirm). Flag this inconsistency for a confirmation dialog. `LabeledContent` rows are correct for read‑only info.
- 🎥 **Record:** Edit → sheet; Archive tap → observe immediate delete + pop (note absence of confirmation); pull‑to‑refresh.
- 📷 Detail in Light + Dark, XXL type; with and without an avatar image.

### 3.3 Account form sheet (Add / Edit) — `AccountFormSheet.swift`
**Type:** Sheet → `NavigationStack` + `Form`. Cancel / Save toolbar.
**Interactions:** **PhotosPicker** (choose photo), **Remove photo** (destructive), Name field, Type picker (menu), Starting Balance (`CurrencyField`), two **Toggles** with footnotes, error section, save (async upload).
- **Check:** Cancel/Save placement (leading/trailing) ✓; Save disabled until valid + during save (✓); confirm the photo upload shows progress and the sheet can't be accidentally swipe‑dismissed mid‑save losing work (consider `.interactiveDismissDisabled` while saving or with unsaved edits). Photos permission prompt copy. Avatar preview updates live.
- 🎥 **Record (critical):** full add flow — open PhotosPicker (permission sheet), pick an image (preview updates), toggle the two switches, edit balance, Save (watch for upload latency/spinner); then an **interactive swipe‑down dismiss with unsaved changes** to see whether data is silently lost (HIG: should confirm).
- 📷 Add + Edit modes, Light + Dark, XXL type; the photo section footer copy.

---

## 4. Transactions tab

### 4.1 Transactions list — `TransactionListView.swift`
**Type:** `List` (`.plain`, large title) with **sticky per‑day section headers**, **`.searchable` with filter tokens**, toolbar (Summary, Filter, Add), infinite scroll, pull‑to‑refresh.
**Interactions:** Vertical scroll; **pull‑to‑refresh**; **infinite scroll** (load more at last row); **search** (debounced) with **removable filter tokens**; **tap row → edit sheet**; **leading swipe → Confirm** (pending only); **trailing swipe → Delete (+ Dismiss for pending)**; per‑row **⋮ menu**; toolbar buttons → sheets.
- **Check (HIG — this is the richest screen):**
  - Search field is native `.searchable` (✓). Verify tokens render, are removable, and that the filter‑icon button reflects active state (fill + tint) when tokens are scrolled away.
  - **Swipe actions:** leading Confirm (green/success), trailing Delete (destructive red, `allowsFullSwipe` default true on trailing) + Dismiss (warning). Confirm full‑swipe on trailing doesn't *delete* without intent — Delete being the full‑swipe action on a destructive, permanent op is risky; verify it still routes through the delete confirmation alert (the ⋮ menu Delete does; the **swipe** Delete appears to call `deleteTransaction` directly **without** the alert — flag this inconsistency).
  - Sticky date headers are custom‑drawn — verify the pinned header background is fully opaque (no bleed‑through), the hairline matches system, and alignment of the net amount column stays put while scrolling.
  - Tap‑to‑edit **and** ⋮‑menu both exist — confirm not redundant/confusing; both are acceptable iOS patterns.
  - Infinite‑scroll spinner at the bottom; verify no jump when new page appends.
- 🎥 **Record (critical, multiple clips):**
  1. **Swipe interactions:** leading swipe → Confirm on a pending row; trailing swipe → reveal Delete + Dismiss; a **full trailing swipe** to see whether it deletes immediately or asks (record the result carefully).
  2. **Search:** type a query (debounce), add/remove a filter token, clear search.
  3. **Infinite scroll:** scroll to bottom to trigger load‑more spinner + append.
  4. **Sticky headers:** slow scroll showing headers pinning/replacing and the net‑amount column staying aligned.
  5. Tap a row → edit sheet; open ⋮ menu.
- 📷 Populated list with pending + confirmed rows (badges, chips), Light + Dark, XXL type; empty state (no transactions) and empty‑with‑filters state; a row with many tags/chips (wrapping via `FlowLayout`).

### 4.2 Transaction row — `TransactionRow.swift`
**Type:** Cell: avatar + direction badge, title, subtitle, wrapping chip row, amount/date, ⋮ menu.
**Interactions:** ⋮ menu (Edit / Create virtual installment / Delete → **confirmation alert**); pending badge; spread indicator.
- **Check:** ⋮ button is 28×28 — **below the 44pt minimum**; verify the actual hit area (it sets `contentShape`) and consider whether it's comfortably tappable; chip row wraps cleanly with `FlowLayout`; amount sign logic (refund cases) is correct visually.
- 🎥 **Record:** open the ⋮ menu; tap Delete → confirmation alert (Cancel/Delete destructive); a refund (negative expense) row to confirm `+` sign + color.
- 📷 Row variants: income/expense/transfer, pending, spread, long title, many chips — Light + Dark, XXL type.

### 4.3 Transaction form (New / Edit) — `TransactionFormView.swift`
**Type:** Sheet → `NavigationStack` + `Form`. Cancel / Save.
**Interactions:** **Segmented** type picker; AccountPicker(s) (To/From for transfer); `CurrencyField` with **+/− sign toggle**; **DatePicker** (graphical/compact); Description field; **BudgetPicker / CategoryPicker / FixedExpensePicker** (menus with inline "Create…"); **TagPicker** (opens searchable sheet); error section.
- **Check:** field order matches web (documented); conditional fields (transfer hides budget/category, shows "To") animate without jank; Save disabled until valid; DatePicker style is standard; the currency sign toggle is discoverable (numeric keypads lack a minus key — good rationale, verify the toggle reads as a control).
- 🎥 **Record (critical):** switch type Expense → Transfer → Income and watch fields appear/disappear (To account, budget/category, fixed‑expense); use the +/− toggle on Amount; open the DatePicker; open each picker (Category/Budget/Fixed) and trigger its inline **Create** path; open the Tag sheet.
- 📷 New vs Edit titles; each transaction type's field set; error state; Light + Dark; XXL type (watch `Form` row label/value wrapping).

### 4.4 Filter sheet — `TransactionFilterSheet.swift`
**Type:** Sheet → `Form`. Cancel / Apply.
**Interactions:** **Horizontally‑scrolling preset chips** (This month, Last month, …, All time); From/To **DatePickers**; **Amount** min/max `CurrencyField`s; multiple **`MultiSelectFacet` disclosure groups** (Status, Type, Account, Budget, Category, Fixed, Tags); **Reset All** (destructive).
- **Check:** horizontal chip strip inside a `Form` row — verify it scrolls smoothly, the active chip is clearly selected (contrast), and it doesn't fight the vertical `Form` scroll; disclosure groups expand/collapse with standard chevrons; Apply/Cancel placement; Reset disabled when nothing set.
- 🎥 **Record:** horizontal‑scroll the preset chips and select several (active state); set a custom date range (From/To pickers appear); expand a couple of facet disclosure groups and use Select all / Clear all; Reset All; Apply → returns to list with tokens.
- 📷 Sheet top (date + presets), an expanded facet, Light + Dark, XXL type (chips + facet rows).

### 4.5 Multi‑select facet — `MultiSelectFacet.swift`
**Type:** `DisclosureGroup` with Select‑all/Clear‑all + checkbox rows + collapsed summary ("All"/"None"/"N selected").
- **Check:** tri‑state model is non‑obvious (default = all checked); verify the collapsed summary always communicates current state; checkbox glyphs (filled square vs empty) have adequate contrast and 44pt rows; "(Blanks)" option clarity.
- 🎥 **Record:** expand → uncheck a few → collapse (summary updates) → Clear all → Select all.
- 📷 Expanded with mixed selection + collapsed summary, Light + Dark.

### 4.6 Summary sheet — `TransactionSummarySheet.swift`
**Type:** Sheet → `NavigationStack` + `List` (inset‑grouped). Done button.
**Interactions:** Loading `ProgressView`, error `ContentUnavailableView`, Totals + Pending sections, **DisclosureGroup breakdowns** (By Account/Category/Budget/Fixed/Tag).
- **Check:** loading → loaded transition; money rows use `minimumScaleFactor(0.7)` (verify large numbers stay legible); disclosure breakdowns expand correctly; `ContentUnavailableView` used for error (native ✓).
- 🎥 **Record:** open Summary (loading → content), expand each breakdown group; force an error if possible to see the unavailable view.
- 📷 Totals + pending + an expanded breakdown, Light + Dark, XXL type.

### 4.7 Create virtual installment sheet — `CreateInstallmentSheet.swift`
**Type:** Sheet → `Form`. Cancel / Save.
**Interactions:** Summary (Reserved/Remaining, **Split evenly** button); **segmented** Start month; **Stepper** (months 1–24); budget multi‑select (checkmark rows); **per‑budget × month amount grid** (decimal text fields); Save disabled until the grid sums **exactly** to the total.
- **Check (complex form):** the "Remaining to allocate" feedback color (muted/warning/danger) must clearly tell the user why Save is disabled; Stepper + segmented are standard; the grid of trailing‑aligned decimal fields should scroll under the keyboard without hiding the active field; "Split evenly" re‑balances. This is the **most complex form** — prioritize.
- 🎥 **Record (critical):** select budgets, change the Stepper and Start segment (grid recomputes via even split), manually edit a cell to make Remaining ≠ 0 (Save disables, color changes), tap Split evenly to re‑balance (Save enables), then Save. Capture keyboard‑avoidance while editing a bottom cell.
- 📷 The grid populated with multiple budgets × months, the Remaining banner in balanced vs unbalanced states, Light + Dark, XXL type (grid alignment under large text).

---

## 5. Budgets tab

### 5.1 Budgets list — `BudgetListView.swift`
**Type:** `VStack` = pinned **MonthNavigator** + `List` (`.plain`, **inline** title). Toolbar **+ menu**. Empty state with two actions. Month page transition.
**Interactions:** Month prev/next (push transition); **tap card → drilldown** (push to filtered Transactions); **trailing swipe → Remove (destructive) + Edit**; toolbar **Menu** (New Budget / Copy from Previous Month); Active Installments section; pull‑to‑refresh.
- **Check:** title is forced inline (documented reason: VStack detaches large‑title tracking) — confirm it still looks intentional; card has BOTH a ⋮ menu (web parity) AND swipe actions for the same Edit/Remove — verify this isn't confusing; **swipe Remove deletes directly** while the **card ⋮ Remove confirms via alert** — flag this inconsistency (swipe should arguably confirm too, or both should match); drilldown push feels right.
- 🎥 **Record:** month navigation (push transition + Reduce‑Motion pass); tap a card → filtered Transactions drilldown → back; trailing swipe → Remove (note no confirmation) and Edit; open the toolbar + menu (New / Copy); pull‑to‑refresh; empty‑state "Copy previous month" / "Add budget".
- 📷 Populated + empty, Light + Dark, XXL type.

### 5.2 Budget card — `BudgetCard.swift`
**Type:** Card: name + **info popover** button, progress bar, spent/remaining row, reserved line, ⋮ menu, **Remove confirmation alert**.
**Interactions:** **info `.popover`** (carry‑over + note); **⋮ Menu** (Edit / Remove→alert); progress bar fill; over‑budget danger styling.
- **Check:** `.popover` with `.presentationCompactAdaptation(.popover)` — on iPhone confirm it presents as a popover (not a full sheet) and is dismissible by tap‑outside; progress bar reads correctly at 0 / partial / full / overspent; ⋮ button 28×28 hit‑area (sub‑44pt — verify comfort); color‑only overspend cue is paired with text ("over").
- 🎥 **Record:** open the info popover (carry‑over + note), dismiss by tapping outside; open ⋮ → Remove → confirmation alert; a card in normal vs overspent state.
- 📷 Normal, overspent, with reserved line, with carry‑over info, Light + Dark, XXL type (progress bar + wrapping label).

### 5.3 Budget form sheet (Add / Edit) — `BudgetFormSheet.swift`
**Type:** Sheet → `Form`. Cancel / Save. Name, Monthly amount (`CurrencyField`), multiline Note.
- **Check:** title shows month context; Save disabled until valid; multiline note grows; standard.
- 🎥 **Record:** add flow incl. typing a multiline note (field grows); Save.
- 📷 Add + Edit, Light + Dark, XXL type.

### 5.4 Active installments section — `ActiveInstallmentsSection.swift`
**Type:** `List` section of cards under a custom pinned header.
**Interactions:** **tap → source transaction sheet**; **trailing swipe → Cancel (destructive)**; **horizontally‑scrolling budget‑name chips** inside each card.
- **Check:** tap target vs swipe coexistence; Cancel destructive without confirmation (consistency flag — cascades to allocations); the inner horizontal chip scroll shouldn't conflict with the row's vertical scroll/tap.
- 🎥 **Record:** tap a card → source sheet; trailing swipe → Cancel; horizontally scroll the budget chips inside a card.
- 📷 A populated installment card (span line + chips), Light + Dark, XXL type.

---

## 6. More tab

### 6.1 More menu — `MoreView.swift`
**Type:** Grouped `List` of `NavigationLink`s (Management: Fixed Expenses, Scheduled; Settings; **Sign Out** destructive).
- **Check:** standard grouped list; destructive Sign Out — HIG suggests confirming sign‑out (currently signs out immediately, no confirm) — flag for a confirmation dialog; section headers/footers conventional.
- 🎥 **Record:** navigate into each link and back; tap Sign Out (note immediate sign‑out, no confirm).
- 📷 Light + Dark, XXL type.

### 6.2 Fixed Expenses list — `FixedExpenseListView.swift`
**Type:** `VStack` = MonthNavigator + `List` (`.insetGrouped`). Toolbar **+ menu**. Unpaid/Paid sections with subtotals + header count/total. Month page transition. Pull‑to‑refresh.
**Interactions:** Month nav (push transition); **trailing swipe → Delete (destructive) + Edit**; toolbar Menu (New / Copy from Previous Month); pull‑to‑refresh.
- **Check:** paid/unpaid split clarity; subtotal headers; swipe actions standard (note: Delete here is `allowsFullSwipe: false` — safer than Transactions, inconsistency worth noting); copy‑from‑previous affordance.
- 🎥 **Record:** month nav; trailing swipe → Delete + Edit; toolbar menu; pull‑to‑refresh; empty state.
- 📷 Unpaid + Paid populated, empty state, Light + Dark, XXL type.

### 6.3 Fixed Expense row — `FixedExpenseRow.swift`
- **Check:** paid indicator, amount alignment, legibility. 📷 paid vs unpaid, Light + Dark, XXL type.

### 6.4 Fixed Expense form sheet — `FixedExpenseFormSheet.swift` / **6.5** Edit sheet — `FixedExpenseEditSheet.swift`
**Type:** Sheet → `Form`. Cancel / Save. Name + Amount (`CurrencyField`).
- 🎥 **Record:** add + edit flow, Save‑disabled‑until‑valid.
- 📷 Both, Light + Dark, XXL type.

### 6.6 Scheduled list — `ScheduledListView.swift`
**Type:** `List`. Pending section (action rows) + Scheduled section. Pull‑to‑refresh. **Requests notification permission** on appear.
**Interactions:** Pending row inline **Confirm / Edit / Dismiss** buttons; Edit → form sheet; pull‑to‑refresh; **notification permission prompt**.
- **Check (HIG):** notification permission is requested on first view of this screen — HIG prefers requesting permission **in context with a pre‑prompt explanation** rather than abruptly; flag whether the cold prompt is well‑timed/justified. Inline `Confirm/Edit/Dismiss` buttons in a row — verify they meet 44pt height (they use `.controlSize(.small)` — **likely under 44pt**, check tap comfort) and that the three‑button row doesn't crowd at large Dynamic Type / narrow devices.
- 🎥 **Record:** first‑appearance notification permission prompt; tap Confirm and Dismiss on a pending row (processing/disabled state); Edit → sheet; pull‑to‑refresh; empty state.
- 📷 Pending + scheduled populated, paused scheduled (dimmed), empty state, Light + Dark, **XXL type (the 3‑button row is the key risk)**.

### 6.7 Settings — `SettingsView.swift`
**Type:** Grouped `List` form. Sections: Currency (push picker), Theme (**segmented**), Default Account (**menu picker**), each with footnote helper text.
**Interactions:** Currency → push to searchable list; **Theme segmented control** (live app re‑theme); Default Account picker.
- **Check:** segmented theme control matches web's 3‑way; changing currency reloads formatters app‑wide (verify no stale currency lingers in open views); section footers are conventional helper text.
- 🎥 **Record:** flip the Theme segmented control and watch the whole app re‑theme live; change Default Currency (push picker → select → values update); change Default Account.
- 📷 Light + Dark, XXL type (segmented control + footnotes).

### 6.8 Currency picker — `CurrencyPickerView.swift` (`CurrencyPickerList`)
**Type:** Pushed `List` with **`.searchable`**, checkmark on selected, inline title.
- **Check:** search filters by code/name; selected checkmark; tapping selects + pops (verify it doesn't feel abrupt vs leaving a back button); large list scroll performance.
- 🎥 **Record:** search "eur", select a currency (pop back), confirm Settings reflects it.
- 📷 Light + Dark, XXL type.

---

## 7. Shared pickers & inputs (used inside forms)

| # | Component | File | Interaction | Key check |
|---|---|---|---|---|
| 7.1 | AccountPicker | `AccountPicker.swift` | Menu picker | "Select Account" placeholder; loads async — verify no empty flash |
| 7.2 | CategoryPicker | `CategoryPicker.swift` | Menu w/ color dots + inline **Create** → sheet | Sentinel "Create" item reverts selection & opens `CreateCategorySheet`; color swatch contrast |
| 7.3 | BudgetPicker | `BudgetPicker.swift` | Menu w/ inline **Create** → sheet | Same create‑sentinel pattern; date‑scoped options |
| 7.4 | FixedExpensePicker | `FixedExpensePicker.swift` | Menu w/ inline **Create** → sheet | Same pattern |
| 7.5 | TagPicker + sheet | `TagPicker.swift` | Row → **searchable sheet**, toggle chips, **create inline**, ⏎ to select/create | Multi‑select chips via `FlowLayout`; Return‑key behavior; create‑on‑no‑match |
| 7.6 | CurrencyField | `CurrencyField.swift` | Decimal keypad, live grouping, **+/− sign toggle**, blur‑settle | Keypad type by decimals; sign toggle discoverability/44pt; cursor not fought while typing |
| 7.7 | MonthNavigator | `MonthNavigator.swift` | Prev/next chevrons + numeric content transition | Chevron 44pt hit area; label min‑width prevents shift |
| 7.8 | EmptyStateView | `EmptyStateView.swift` | Native `ContentUnavailableView` + action | Native component ✓; action button styling |
| 7.9 | FlowLayout | `FlowLayout.swift` | Wrapping chip container | Wrapping correctness at XXL type / narrow width |
| 7.10 | Badge / AccountAvatar / AmountColumnView | resp. files | Static | Avatar async‑image loading/placeholder/failure; amount column alignment |

### Plan — shared components
- **CreateCategorySheet** (inside CategoryPicker) is a nested sheet‑over‑sheet — 🎥 **record** opening Create from within the transaction form's Category picker to confirm the stacked presentation dismisses cleanly back to the form.
- 🎥 **TagPicker:** open sheet, search, toggle several tags (chips update on the form row), type a new name → Create inline, press Return to select/create.
- 🎥 **CurrencyField:** type a large amount (watch live thousands‑grouping), toggle the sign, blur (settle to padded decimals), then re‑focus — confirm the cursor/caret isn't disrupted.
- 🎥 **AccountAvatar:** a row whose image URL is slow/broken to capture the `ProgressView` → fallback‑icon path.
- 📷 Each picker's menu open state; the create‑sentinel item; Light + Dark.

---

## 8. Cross‑cutting interaction checks (record once, applies broadly)

These are the gesture/animation behaviors to validate holistically.

1. **Swipe actions consistency (🎥 critical):** record swipe on Transactions, Budgets, Fixed Expenses, and Active Installments side‑by‑side. **Open question to resolve:** destructive **swipe** Delete/Remove/Cancel currently bypass confirmation on Transactions / Budgets / Installments, while the **menu** equivalents confirm. Decide one consistent rule (HIG: confirm permanent, hard‑to‑undo destructive actions; allow undo or `allowsFullSwipe:false` otherwise).
2. **Pull‑to‑refresh (🎥):** Dashboard, Transactions, Account detail, Budgets, Fixed Expenses, Scheduled — confirm spinner placement and that refresh doesn't fight the large‑title collapse.
3. **Sheet dismissal (🎥):** for every form sheet (Account, Transaction, Budget, Fixed Expense, Installment, Filter), test the **interactive swipe‑down** with unsaved edits — HIG wants a confirmation when dismissing would discard meaningful input. Currently none use `interactiveDismissDisabled` — flag.
4. **Month page transitions (🎥):** Dashboard, Transactions(scoped), Budgets, Fixed Expenses — confirm `.push` direction matches nav direction and a **Reduce Motion** pass replaces it gracefully.
5. **Tap‑target audit (📷 + Accessibility Inspector):** the recurring **28×28 ⋮ buttons** (TransactionRow, BudgetCard), **`.controlSize(.small)` buttons** (Scheduled pending row), MonthNavigator chevrons, and CurrencyField sign toggle — measure against the **44×44pt** minimum.
6. **VoiceOver pass (🎥):** swipe‑navigate Dashboard, Transactions list (incl. swipe actions exposed as accessibility actions), and one form — confirm labels (many `.accessibilityLabel` set ✓), reading order, and that color‑coded amounts/statuses are announced.
7. **Dynamic Type stress (📷):** every screen at Accessibility XXL — watch the 3‑button Scheduled row, the installment grid, Form label/value rows, chips, and the tab bar labels.
8. **Dark Mode parity (📷):** every screen (token‑based, but verify the few hand‑built surfaces: Login button, verdict banner stripe, sticky headers).
9. **Haptics (🎥 + note):** confirm whether destructive swipes / toggles / pickers emit expected system haptics (currently none are explicitly added — note whether system defaults suffice).
10. **Loading & empty & error states (📷):** capture each list's loading `ProgressView`, empty state, and (where applicable) error (`ContentUnavailableView`) — verify they're not blank/janky.

---

## 9. Known inconsistencies flagged for decision (summary)

| Item | Observation | HIG guidance |
|---|---|---|
| Account **Archive** (3.2) | Destructive, **no confirmation** | Confirm destructive/irreversible actions |
| **Sign Out** (6.1) | Immediate, no confirmation | Confirm sign‑out |
| Swipe **Delete/Remove/Cancel** (4.1, 5.1, 5.4) | Bypass the alert that the ⋮ menu shows | Be consistent; confirm permanent deletes |
| Sheet **swipe‑dismiss** (all forms) | No discard‑changes guard | Confirm before discarding user input |
| **28pt ⋮** & **small** action buttons (4.2, 5.2, 6.6) | Below 44pt | Maintain 44×44pt targets |
| **Notification permission** (6.6) | Requested on screen appear, no pre‑prompt | Request in context with rationale |
| **Nav‑title mode** mix (large vs inline) | Intentional but inconsistent across list screens | Verify each reads deliberately |
| `allowsFullSwipe` mismatch | Transactions Delete allows full‑swipe; Fixed Expenses disables it | Pick one for destructive rows |

---

## 10. Review checklist template (use per item)

For each numbered item above, fill in:

- **Item:** _e.g. 4.1 Transactions list_
- **Captures attached:** 📷 Light / 📷 Dark / 📷 XXL / 🎥 interaction(s): ______
- **HIG checks:** Touch targets ▢ · Dynamic Type ▢ · Dark mode ▢ · Color‑independent meaning ▢ · Standard controls ▢ · Destructive confirmation ▢ · Sheet dismissal ▢ · Motion/Reduce Motion ▢ · VoiceOver labels & order ▢ · Safe areas / notch ▢ · Keyboard avoidance (forms) ▢
- **Result:** Pass / Fail / N‑A
- **Notes / follow‑up:** ______

---

### Appendix — file → item index

- `ContentRootView.swift` → 0.1 · `FinancialManagementApp.swift` → 0.2, 0.5 · `AppTheme.swift`/`ThemeManager` → 0.3, 0.4
- `LoginView.swift` → 1.1
- `DashboardView.swift` → 2.1 · `BudgetVerdictBanner.swift` → 2.2 · `AccountsCard.swift` → 2.3 · `PlannedExpensesCard.swift` → 2.4 · `UnplannedExpensesCard.swift` → 2.5 · `DashboardCard.swift` → 2.x (chrome)
- `AccountListView.swift` → 3.1 · `AccountDetailView.swift` → 3.2 · `AccountFormSheet.swift` → 3.3 · `AccountCard.swift` → 3.1 · `AccountAvatar.swift` → 7.10
- `TransactionListView.swift` → 4.1 · `TransactionRow.swift` → 4.2 · `TransactionFormView.swift` → 4.3 · `TransactionFilterSheet.swift` → 4.4 · `MultiSelectFacet.swift` → 4.5 · `TransactionSummarySheet.swift` → 4.6 · `CreateInstallmentSheet.swift` → 4.7 · `FilterBar.swift` → (legacy chip bar; verify if still reachable)
- `BudgetListView.swift` → 5.1 · `BudgetCard.swift` → 5.2 · `BudgetFormSheet.swift` → 5.3 · `ActiveInstallmentsSection.swift` → 5.4
- `MoreView.swift` → 6.1 · `FixedExpenseListView.swift` → 6.2 · `FixedExpenseRow.swift` → 6.3 · `FixedExpenseFormSheet.swift` → 6.4 · `FixedExpenseEditSheet.swift` → 6.5 · `ScheduledListView.swift` → 6.6 · `PendingTransactionRow.swift` → 6.6 · `SettingsView.swift` → 6.7 · `CurrencyPickerView.swift` → 6.8
- `AccountPicker.swift` → 7.1 · `CategoryPicker.swift` → 7.2 · `BudgetPicker.swift` → 7.3 · `FixedExpensePicker.swift` → 7.4 · `TagPicker.swift` → 7.5 · `CurrencyField.swift` → 7.6 · `MonthNavigator.swift` → 7.7 · `EmptyStateView.swift` → 7.8 · `FlowLayout.swift` → 7.9 · `Badge.swift`/`AmountColumnView.swift` → 7.10
</content>
</invoke>
