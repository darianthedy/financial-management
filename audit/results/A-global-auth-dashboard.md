# Audit A — Global chrome, Auth, Dashboard (Apple HIG compliance)

**Scope of this pass:** P0 ("Critical captures") only, per `audit/CAPTURE-GUIDE.md`.
Items whose only evidence is a P1/P2 capture are listed under **Deferred (non-P0)**
unless they could be confirmed directly from source. Source reviewed under
`iOS/FinancialManagement/FinancialManagement/`.

**P0 captures available and used as source of truth:**
- `captures/0.2_navbar_collapse.mp4` → frames `captures/frames/0.2_navbar_collapse/`
- `captures/0.3_theme_live.mp4` → frames `captures/frames/0.3_theme_live/`
- `captures/2.1_dashboard_month.mp4` → frames `captures/frames/2.1_dashboard_month/`
- `captures/2.1_dashboard_month_reducemotion.mp4` → frames `captures/frames/2.1_dashboard_month_reducemotion/`

(.mp4 clips can't be opened directly; the driver sampled 16 PNG stills per clip and
those were read in order.)

**Build status:** This host (Linux/WSL) has no Swift/Xcode toolchain, so
`xcodebuild` could not be run to confirm compilation. The three edits below were
hand-verified for syntax; they use only standard SwiftUI already present in the
codebase (`AnyTransition` ternary, `.frame`/`.contentShape` on `Image`, and the
existing `sign:` parameter on `AmountColumnView`). **A human should compile on a Mac
before merge.**

---

## §10 checklist blocks

### 0.1 Root tab bar — `ContentRootView.swift`
- **Captures:** 🎥 `0.2_navbar_collapse` (tab bar visible across Dashboard/Budgets/Scheduled), `0.3_theme_live` (tab bar in light + dark). No dedicated `0.1_tabbar_xxl` (P1, absent).
- **HIG checks:** Touch targets ✅ (system tab bar) · Dynamic Type ▢ (XXL truncation unverifiable — P1 still absent) · Dark mode ✅ (frames show correct light/dark tab bar) · Color-independent meaning ✅ · Standard controls ✅ (`TabView` + SF Symbols + text labels, 5 items ≤ HIG limit) · Motion N-A · VoiceOver ▢ · Safe areas ✅ (tab bar respects home indicator in all frames).
- **Result:** **Pass** (structure). Re-tap scroll-to-top / pop-to-root and XXL label truncation deferred — need the P1 `0.1_tabbar` stills + the tab re-tap clip.
- **Notes:** `Label(_, systemImage:)` per tab gives each a text label and an SF Symbol; tints follow system. Genuine overflow "More" tab.

### 0.2 Navigation bars — `FinancialManagementApp.configureNavigationBarAppearance()`
- **Captures:** 🎥 `0.2_navbar_collapse` frames 001 (Dashboard scroll-edge, transparent, large title), 009 (Budgets scrolled — opaque inline bar + hairline + toolbar **+**), 013 (Scheduled scrolled — opaque inline bar).
- **HIG checks:** Standard controls ✅ · Dark mode ✅ (opaque bar keyed to `AppBackground` token; renders correct in dark frames) · Safe areas ✅ · Motion ✅ (collapse animates with the system; no flicker visible across sampled stills, though sub-frame "pop" can't be fully ruled out from stills) · Touch targets ✅.
- **Result:** **Pass.** Scroll-edge transparent → scrolled opaque transition renders correctly; the two-appearance split (separate `scrollEdgeAppearance`) is the right fix for iOS 26 translucent bars and preserves the large title at the top.
- **Notes:** Large-vs-inline title mix is intentional per the doc (Dashboard large; Budgets/Scheduled inline). Reads deliberately in the frames.

### 0.3 Color tokens & theming — `AppTheme.swift`, `ThemeManager.swift`
- **Captures:** 🎥 `0.3_theme_live` frames 002 (dark Accounts list), 008 & 014 (light Settings with the Light/Dark/System segmented control; tab bar themed light).
- **HIG checks:** Dark mode ✅ (every surface re-themes; tokens carry explicit dark variants) · Standard controls ✅ (segmented theme picker) · Color-independent meaning ✅ · Live update ✅ (whole app, incl. tab bar, re-themes when the picker flips).
- **Result:** **Pass.** `.preferredColorScheme(themeManager.colorScheme)` at the app root re-themes live; "System" → `nil` defers to device.
- **Notes:** Sampled frames did not isolate an *open sheet* re-theming, but app-wide live re-theme is confirmed. WCAG-AA contrast of `appMutedForeground` / status tints not formally measured here — recommend a one-time contrast audit (deferred, needs the per-screen P1 stills).

### 0.4 Card surface treatment — `AppTheme.appCardSurface()`
- **Captures:** dedicated `0.4_card_zoom` (P1) absent; cards visible in 2.1 dashboard frames.
- **HIG checks:** Dark mode ✅ (cards render with fill + hairline + corner radius in dark frames) · Standard ✅.
- **Result:** **Pass** on what's visible (radius 10, hairline border, subtle shadow). Pixel-level radius/border/shadow inspection deferred — needs the P1 `0.4_card_zoom` stills.

### 0.5 Auth gate — `FinancialManagementApp.swift`
- **Captures:** sign-out/sign-in transition clip (P1/P2) absent.
- **Result:** **Deferred (non-P0).** Source swaps `ContentRootView`/`LoginView` on `appState.isAuthenticated` inside a `Group` with no custom transition; nothing source-level looks wrong, but the "not jarring" check needs the recording.

### 1.1 Login / Sign-up — `LoginView.swift`
- **Captures:** `1.1_login_*` (incl. `_se`) are P1/P2 — **absent**. Evaluated from source only.
- **HIG checks:** Touch targets ✅ (submit button `.frame(height: 44)`; fields `.frame(height: 44)`) · Standard controls ✅ (`TextField`/`SecureField`) · Color-independent meaning ✅ (error in danger token *plus* its own text line) · Dark mode ✅ (all tokenized) · Content types ✅ (`.emailAddress` + email keyboard, autocaps/autocorrect off; password `.password`/`.newPassword` for sign-in/up) · Keyboard avoidance ▢ (card is in a `ScrollView`, which auto-scrolls the focused field into view — plausible but **unverified without the 1.1 clip**) · Loading state ✅ (spinner replaces label inside the fixed-height button, so no layout shift).
- **Result:** **Pass** on source-checkable items; keyboard avoidance + autofill/Strong-Password rendering **Deferred** (need `1.1_login` and `1.1_login_se`).
- **Notes:** No Fail found in source. Minor follow-up (not a Fail): the error `Text` has no `.accessibilityAddTraits`/announcement hint; VoiceOver will read it on focus but won't auto-announce on appearance. Track for a P2 VoiceOver pass.

### 2.1 Dashboard screen — `DashboardView.swift`, `DashboardViewModel.swift`, `MonthNavigator.swift`
- **Captures:** 🎥 `2.1_dashboard_month` (frames 001/006 June, 008 April loading spinner) and 🎥 `2.1_dashboard_month_reducemotion` (frames 004–006 show **September→November sliding horizontally**).
- **HIG checks:** Standard controls ✅ · Dark mode ✅ · Pull-to-refresh ✅ (source `.refreshable`) · Loading state ✅ (frame 008: 200pt-min `ProgressView`, no jarring collapse) · **Motion / Reduce Motion ❌ → fixed** · Touch targets ❌ → fixed (MonthNavigator chevrons, see below).
- **Result:** **Fail → fixed (2 issues).**
  1. **Reduce Motion not respected.** `monthPageTransition` applied `.transition(.push(from:))` unconditionally; the viewModel drives it with `withAnimation(.easeInOut)`. The `…_reducemotion` clip proves the horizontal **push slide still plays** with Reduce Motion ON (frames 005–006: old cards slide left, next month's cards enter from the right edge). HIG requires suppressing large sliding motion. **Fix:** converted `monthPageTransition` to a `ViewModifier` that reads `@Environment(\.accessibilityReduceMotion)` and substitutes `.opacity` (cross-fade) for `.push` when on. Because the modifier is shared, this also fixes Transactions (4.x), Budgets (5.1) and Fixed Expenses (6.2) month transitions.
  2. **MonthNavigator chevron tap targets < 44pt** (also §8.5 / §9). The buttons wrapped only a `.font(.body)` glyph (~17–18pt) with no frame, so the hit area was the glyph. **Fix:** gave each chevron a `44×44` frame + `.contentShape(Rectangle())` and an `.accessibilityLabel` ("Previous month" / "Next month").

### 2.2 Budget Verdict banner — `BudgetVerdictBanner.swift`
- **Captures:** 🎥 `2.1_dashboard_month` (overspent: red `exclamationmark.triangle` + "Overspending in 1 budget") and `…_reducemotion` frame 004 (on-track: green `checkmark.circle` + "On track. All 5 budgets within target."). **Both states captured.**
- **HIG checks:** Color-independent meaning ✅ (distinct icon **and** text per state, not color alone) · Dark mode ✅ · Standard ✅ · Legibility ✅ (`minimumScaleFactor(0.7)` on detail). Empty case hidden when `budgets.isEmpty` ✅ (source).
- **Result:** **Pass.** XXL stress (P1 `2.2_verdict_*_xxl`) deferred, but the default-size both-state rendering is confirmed from P0 captures.

### 2.3 Accounts card — `AccountsCard.swift` (+ `AmountColumnView`)
- **Captures:** 🎥 `2.1_dashboard_month` (positive balances, column aligned). A **negative** balance row (`2.3_accounts_card`, P1) is **absent** — issue confirmed from source instead.
- **HIG checks:** Standard ✅ · Dark mode ✅ · Column alignment ✅ (shared `widestAmountBody` across cards) · **Color-independent meaning ❌ → fixed**.
- **Result:** **Fail → fixed.** `AmountColumnView` renders **magnitude only** unless a `sign` is passed (see its doc-comment; `UnplannedExpensesCard` already passes one). `AccountsCard` passed no sign, so a **negative balance was signalled by the danger color alone** — fails HIG "don't encode meaning in color only." **Fix:** pass `sign: balance < 0 ? "-" : ""` to the per-account rows **and** the total row, and color the total danger when negative (matching the per-row treatment). Mirrors the existing `UnplannedExpensesCard` pattern.
- **Notes:** dead helper `amount(_:semibold:)` in this file is unused (pre-existing); left untouched to keep the change localized.

### 2.4 Planned Expenses card — `PlannedExpensesCard.swift`
- **Captures:** 🎥 `2.1_dashboard_month` frames 001/006: Total planned, Budgets with pace bars (overspent "Others" = red bar **and** red spent/total figures; under-budget = blue), Fixed Expenses Unpaid section.
- **HIG checks:** Color-independent meaning ✅ (overspent rows pair the red bar with red numeric `spent / total`, and paid/unpaid use labelled icons `clock` / `checkmark.circle`) · Alignment ✅ · Dark mode ✅ · Standard ✅.
- **Result:** **Pass** at default type. XXL grid/label wrapping (P1) deferred.

### 2.5 Unplanned Expenses card — `UnplannedExpensesCard.swift`
- **Captures:** card present at the bottom of 2.1 dashboard frames (partly below fold). Negative/refund row (`2.5_unplanned`, P1) absent.
- **HIG checks:** Color-independent meaning ✅ (negative totals get an explicit `-` via `amountSign`; "Uncategorized" uses italic + `❓` glyph, not color) · Dark mode ✅ · Standard ✅.
- **Result:** **Pass** (source + visible portion). Negative-category row rendering and XXL deferred to P1 stills.

---

## Summary — what I changed

All three are small, localized, and mirror patterns already in the codebase:

1. **`Views/Shared/MonthNavigator.swift` — Reduce Motion (P0, capture-confirmed).**
   `monthPageTransition` is now a `ViewModifier` that cross-fades (`.opacity`)
   instead of `.push` when `accessibilityReduceMotion` is on. Fixes Dashboard +
   Transactions + Budgets + Fixed Expenses month transitions in one place.
2. **`Views/Shared/MonthNavigator.swift` — chevron touch targets (source-confirmed).**
   Each chevron now has a `44×44` hit area + `contentShape` + an accessibility label.
3. **`Views/Dashboard/AccountsCard.swift` — color-independent negative balances (source-confirmed).**
   Negative balances (per-row and total) now show an explicit `-` sign in addition
   to the danger color.

## Needs a human decision / follow-up (not changed)
- **Compile on a Mac:** no Swift toolchain on this host; `xcodebuild` not run.
- **WCAG-AA contrast** of `appMutedForeground` and status tints (0.3) — needs the
  per-screen P1 stills or a contrast-checker pass.
- **Login keyboard avoidance + autofill / Strong-Password** (1.1) — needs the
  `1.1_login` / `1.1_login_se` captures (P1/P2, absent).
- **VoiceOver** announcement of the Login inline error and Dashboard reading order
  — P2 pass.

## Deferred (non-P0) — evidence is P1/P2-only and not present
- 0.1 tab-bar XXL label truncation + re-tap scroll-to-top/pop-to-root (`0.1_tabbar*`, tab re-tap clip).
- 0.4 card-surface pixel inspection (`0.4_card_zoom`).
- 0.5 auth-gate sign-in/out transition clip.
- 1.1 Login rendered states (`1.1_login*`, incl. `_se`).
- 2.2 / 2.3 / 2.4 / 2.5 XXL Dynamic Type stills and the specific negative/refund/empty-state stills.
