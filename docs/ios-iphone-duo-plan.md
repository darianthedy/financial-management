# Financial Management iOS: iPhone Duo Support Plan

Status: Proposal · Owner: iOS · Date: 2026-10-29
Scope: `iOS/FinancialManagement/FinancialManagement/Views/**` and `App/**`

This plan adapts every screen of the SwiftUI app to iPhone Duo: the 5.4″ outer display and the 7.6″ folding inner display, across flat, partly folded, rotated and Split View states. The mockups for each device state and each content state are on the [iPhone Duo Mockups canvas](https://claude.ai/artifact/Ptpqw6RjFrLEXJvSPMf2oS). The step-by-step build order is in [`ios-iphone-duo-implementation-plan.md`](ios-iphone-duo-implementation-plan.md). Everything follows the HIG page *Designing for iPhone Duo* and Apple's Tech Talk *Prepare your app for iPhone Duo*. The rule throughout is to adapt by **size class**, and never by device, orientation or a hard-coded width.

---

## 1. Device specs

### 1.1 Hardware (Apple Tech Specs)

| | Outer display | Inner display |
|---|---|---|
| Size | 5.4″ diagonal, OLED Super Retina XDR | 7.6″ diagonal, folding OLED Super Retina XDR |
| Pixels | 1398 × 2034 @ 460 ppi | 1878 × 2670 @ 430 ppi |
| Refresh | ProMotion up to 120 Hz, Always-On | ProMotion up to 120 Hz, Always-On |
| Camera / island | 12 MP Center Stage, Dynamic Island | Under-display camera, Dynamic Island |
| Other | Apple Pencil (USB-C), no hover | Apple Pencil (USB-C), no hover |

The device measures 164.6 × 117.8 × 5.2 mm open and 84.1 × 117.8 × 11.3 mm closed, and weighs 254 g. It ships with iOS 27 and an A20 Pro. Touch ID sits in the side button.

Because the open device is wider than it is tall, the inner display's **native orientation is landscape**.

### 1.2 Layout metrics we design against

Apple has not published point sizes. The outer-display rows below are **measured** by the CI probe (§1.3). The inner-display rows come from the simulator's device profile: the inner panel is a 2007 × 2853 px framebuffer at @3, mounted at 270°, which makes it landscape-native. Use these numbers to draw mockups only. **Never hard-code them.** At runtime, read sizes from `GeometryReader`, from `windowScene.effectiveGeometry` and from the trait collection.

| State | Approx. points (W × H) | Size class (H / V) | System bars |
|---|---|---|---|
| **O-P** Outer, portrait | **466 × 678** (measured) | **Compact / Regular** (measured) | **Right edge**. Safe area is 84 pt on the right and 34 pt at the bottom; the top and left are 0. |
| **O-L** Outer, landscape (stood on its edge) | **678 × 466** (measured) | **Compact / Compact** (measured) | **Left edge**. Safe area is 84 pt on the left and 34 pt at the bottom. The bar follows the camera side. |
| **I-L** Inner, landscape, flat (native) | 951 × 669 (device profile) | Regular / Regular | Vertical in landscape; tab bar can become a sidebar |
| **I-P** Inner, portrait, flat | 669 × 951 (device profile) | Regular / Regular | Horizontal |
| **I-B** Inner, landscape, partly folded ("book") | Two regions ~475 × 669 split by a vertical fold *division* | Regular / Regular | As I-L; the system moves sheets, alerts and menus away from the fold |
| **I-T** Inner, portrait, partly folded ("tent") | Two regions ~669 × 475 split by a horizontal fold *division* | Regular / Regular | As I-P; glanceable content goes up, controls go down |
| **I-S** Inner, Split View multitasking | Arbitrary width, on either side | Follows the width (≈½ or ⅓ width is likely Compact) | Can appear on the leading edge |
| **M** iPhone Mirroring on Mac | Arbitrary, resizable | Follows the size | — |

Rules from the HIG and the Tech Talk that shape this plan:

- The inner display **ignores `UISupportedInterfaceOrientations`**. Never branch on orientation.
- Safe areas and layout margins are **asymmetric**. Vertical bars may sit on the left or the right, so inset each edge on its own.
- Vertical bars order their items as **Back or Close at the top**, then the prominent action, a gap, and then the rest. Icon-only items can go vertical. Text buttons, segmented controls and Edit/Done toggles stay horizontal.
- Under displacement, elements in a fold region move: alerts move toward the trailing edge in book posture, and in tent posture glanceable content moves up while controls move down. **Scrolling content is never displaced.**
- Custom grids keep their outer margins, add extra spacing at the hinge, and **prefer an even column count**.
- Sheets are centered on the inner display and slide away from the fold. On the outer display, a sheet's bar buttons can stack vertically.
- `UIScreen.main` must not be used. The app already passes this check: a grep found **no usages**.

### 1.3 Verified on the iPhone Duo simulator (CI probe)

The probe is the `iOS Duo probe` workflow (`.github/workflows/ios-duo-probe.yml`, `scripts/duo-probe/`, `FinancialManagementTests/DuoProbeTests.swift`). It ran on the GitHub `xcode-27` runner with Xcode 27.1 (27A9275), iOS 27.1, and the `iPhone Duo` device (`iPhone19,4`).

**Settled:**

1. **Displays.** The simulator exposes two integrated screens.
   - Screen 1 is the outer display, "LCD": 1398 × 2034 px @3, 460 ppi, portrait-native.
   - Screen 3 is the inner display, "LCD-1": 2007 × 2853 px @3, mounted at 270°. That makes it landscape-native at 951 × 669 pt.
   - The device boots **closed**, so apps launch on the outer display.
2. **Outer display metrics.**

   | | Size | Size class (H / V) | Safe area |
   |---|---|---|---|
   | Portrait | 466 × 678 pt | compact / regular | right 84, bottom 34 |
   | Landscape | 678 × 466 pt | compact / compact | left 84, bottom 34 |

   - The usable content width in portrait is **382 pt**. That is narrower than any current iPhone, so it is the new narrowest layout to test.
   - `UIView.reservedRegions(kind: .occlusion)` reports two regions in portrait. One is the 84 × 174 pt camera and status block at the top right; the other is the 37 × 37 pt Dynamic Island inside it.
3. **System bars on the outer display.**
   - **Tab bar:** vertical, in the same strip as the status bar. It is on the **right** in portrait and on the **left** in landscape.
   - **Navigation bar:** stays horizontal at the top, with the large title.
   - **Icon-only toolbar items:** move into a vertical glass capsule on that same edge, above the tab bar.
   - **Text items stay horizontal**, matching the HIG. Examples are the detail view's "Edit" button and a sheet's "Cancel" and "Save".
   - **Sheets:** inset 8 pt on the outer display. Their content keeps a 76 pt trailing safe area.
4. **The vertical strip has limited room.**
   - **Tabs:** portrait fits about 7 tab items; landscape fits 5.
   - **Toolbar items:** whatever doesn't fit collapses into "…".
   - **Tab overflow:** with the plan's 7-tab root, Transactions' **Add, Filter and Summary all collapse into a single "…"** in landscape. In portrait only Filter stays visible, and Add sits inside "…".
5. **`defaultVisibility(.hidden, for: .tabBar)` does not hide tabs on compact width.** The sidebar-only Tags and Settings tabs showed up in the outer display's tab bar. **Fix:** choose tabs by `horizontalSizeClass`. On compact width show 4 tabs plus More; on regular width show the `TabSection`. With only 5 tabs, all three toolbar items fit on the rail (§3.1).
6. **Toolbar priority works.** `ToolbarItem { … }.visibilityPriority(.high)` keeps **Add** visible while the other items overflow. In the vertical bar, `primaryAction` items are placed last, below Filter and Summary, so give Add `.high` to keep it reachable.
7. **API names, checked against the iOS 27.1 SDK:**
   - **SwiftUI:**
     - `ArrangementView` with `.arrangementViewStyle(.split / .overlay / .automatic)`
     - `GeometryProxy.reservedRegions(kind: .division | .occlusion, options: .includeInactive)`
     - `ReservedRegion`
     - `onHingeChange { old, new in }`, which delivers a `DeviceHingeContext`
     - `toolbarVerticalEdge` (`HorizontalEdge?`, an environment value)
     - `ToolbarItem.visibilityPriority(.low / .high)`
     - `ToolbarOverflowMenu`
     - `.defaultTabBarPlacement(.sidebar)`, taking an `AdaptableTabBarPlacement`
   - **UIKit:**
     - `UIView.reservedRegions(kind:options:)`
     - `UIHingeInteraction`, where the hinge `status` reads `closed` and `angleRadians` reads 0 when closed
     - `UIArrangementViewController`
     - `UIBarButtonItem.visibilityPriority`
     - `UIViewController.preferredVerticalBarBehavior` (`.automatic` / `.disabled`)
   - **Availability:** the APIs are iOS 27.1 (`UIBarButtonItem.visibilityPriority` is iOS 27.0), so every call goes behind `#available(iOS 27.1, *)`.

**Not reachable from CI. Check these on a Mac with Xcode 27.1 or on a device:**

- The inner display (I-L, I-P), the book and tent postures (I-B, I-T), and the inner display's real fold division. `simctl` has no fold, posture or open control; Device Hub's open and close buttons are GUI-only. Powering the outer screen off with `simctl io … screenConfig power off` crashes SpringBoard instead of opening the device. The workflow keeps that experiment behind `DUO_TRY_INNER=1` so it can be retried on a newer image.
- The size class at each Split View width (I-S).
- Whether `.defaultTabBarPlacement(.sidebar)` actually shows a sidebar on the inner display. On the outer display it changes nothing, as expected.

---

## 2. Current app inventory

Root: `ContentRootView` is a compact-only `TabView` with 5 tabs, each holding a `NavigationStack`. The app targets iOS 26.1 with `TARGETED_DEVICE_FAMILY = 1,2`. It contains no `NavigationSplitView`, no size-class branching and no `.inspector`.

| # | Screen | File | Kind | Content states today |
|---|---|---|---|---|
| S1 | Splash | `Auth/SplashView.swift` | Full screen | loading |
| S2 | Login / Sign-up | `Auth/LoginView.swift` | Full screen, card ≤400 pt | idle, loading, error, sign-up mode, keyboard up |
| S3 | Dashboard | `Dashboard/DashboardView.swift` + 7 cards | Tab root, ScrollView | loading, loaded, partial (no accounts/budgets), month transition, pull-to-refresh |
| S4 | Accounts list | `Accounts/AccountListView.swift` | Tab root, List | loading, empty, loaded |
| S5 | Account detail | `Accounts/AccountDetailView.swift` | Pushed | loading (nil), loaded, archive alert |
| S6 | Transactions list | `Transactions/TransactionListView.swift` | Tab root, plain List | loading, empty, filtered-empty, loaded, pending rows, searching with tokens, load-more, swipe, delete alert |
| S7 | Budgets list | `Budgets/BudgetListView.swift` | Tab root, List + month header | loading, empty month, loaded, with installments, remove/cancel alerts |
| S8 | More | `More/MoreView.swift` | Tab root, List | static, sign-out dialog |
| S9 | Tags | `Tags/TagsListView.swift` | Pushed, adaptive grid | loading, empty, loaded |
| S10 | Categories | `Categories/CategoryListView.swift` | Pushed, List | loading, empty, loaded, delete alert |
| S11 | Fixed Expenses | `FixedExpenses/FixedExpenseListView.swift` | Pushed, List + month nav | loading, empty, loaded, paid/unpaid, delete alert |
| S12 | Scheduled | `Scheduled/ScheduledListView.swift` | Pushed, List | loading, empty, pending + recurring, paused rows, delete alert |
| S13 | Settings (+ Currency picker) | `Settings/*.swift` | Pushed, grouped List | loaded, currency search |
| F1 | Transaction form (new/edit) | `Transactions/TransactionFormView.swift` | Sheet | type variants (expense/income/transfer), error, discard dialog, keyboard |
| F2 | Filters | `Transactions/TransactionFilterSheet.swift` | Sheet | none / active, loading facets, reset dialog |
| F3 | Summary | `Transactions/TransactionSummarySheet.swift` | Sheet | loading, error, loaded, with pending projection |
| F4 | Virtual installment | `Transactions/CreateInstallmentSheet.swift` | Sheet | allocation grid, error, discard |
| F5 | Budget form | `Budgets/BudgetFormSheet.swift` | Sheet | add / edit, discard |
| F6 | Account form | `Accounts/AccountFormSheet.swift` | Sheet | new / edit, photo, error, discard |
| F7 | Fixed expense new / edit | `FixedExpenses/FixedExpense{Form,Edit}Sheet.swift` | Sheet | error, discard |
| F8 | Scheduled form | `Scheduled/ScheduledFormView.swift` | Sheet | new / edit, error, discard |
| F9 | Tag form | `Tags/TagFormSheet.swift` | Sheet | add / edit, error, discard |
| F10 | Category form | `Categories/CategoryFormSheet.swift` | Sheet | swatches, custom color, error, discard |
| F11 | Pickers + inline create | `Shared/{Tag,Category,Budget,FixedExpense}Picker.swift` | Menu / sheet | search, create-new, loading |

Layout risks found in the audit:

- `CashflowTrendCard.swift:333` uses `.frame(minWidth: 240)` on the legend, and `BudgetCard.swift:240` uses `minWidth: 180`. Both can overflow in a ⅓-width Split View or a narrow content column.
- `TagsListView` uses an adaptive grid (`minimum: 140`), which yields an **odd** column count on the inner display. The HIG prefers an even count around the hinge.
- `GeometryReader` appears in `CashflowCard`, `BudgetCard`, `PlannedExpensesCard`, `CashflowTrendCard`, `TagsListView` and `BudgetListView`. Each one must react to the resize on fold and unfold. It must not cache a width.
- The forms already use `ToolbarItem(.cancellationAction / .confirmationAction)`, which is correct for vertical bars. `AccountDetailView`'s **"Edit"** text button stays horizontal under the HIG, which is fine.

---

## 3. Target architecture

### 3.1 Root: an adaptable tab bar that becomes a sidebar

Replace `ContentRootView` with the `Tab` API, `.tabViewStyle(.sidebarAdaptable)`, and an opt-in `.defaultTabBarPlacement(.sidebar)` on iOS 27.1 or later. The HIG lists the sidebar as the recommended inner-display option for information-dense apps.

```swift
TabView(selection: $selection) {
    Tab("Dashboard", systemImage: "square.grid.2x2", value: .dashboard) { DashboardRoot() }
    Tab("Accounts", systemImage: "wallet.bifold", value: .accounts) { AccountsRoot() }
    Tab("Transactions", systemImage: "arrow.left.arrow.right", value: .transactions) { TransactionsRoot() }
    Tab("Budgets", systemImage: "target", value: .budgets) { BudgetsRoot() }

    // Chosen by size class, not `.defaultVisibility(.hidden, for: .tabBar)`:
    // the probe showed per-placement visibility does NOT hide tabs on compact
    // width (§1.3 #5), and every extra tab steals room from the toolbar rail.
    if horizontalSizeClass == .compact {
        // Outer display / narrow Split View: keep the existing More tab.
        Tab("More", systemImage: "ellipsis", value: .more) { MoreRoot() }
    } else {
        // Inner display: the More destinations are promoted into the sidebar.
        TabSection("Management") {
            Tab("Tags", systemImage: "tag", value: .tags) { TagsRoot() }
            Tab("Categories", systemImage: "tag", value: .categories) { CategoriesRoot() }
            Tab("Fixed Expenses", systemImage: "receipt", value: .fixedExpenses) { FixedExpensesRoot() }
            Tab("Scheduled", systemImage: "calendar.badge.clock", value: .scheduled) { ScheduledRoot() }
        }
        Tab("Settings", systemImage: "gear", value: .settings) { NavigationStack { SettingsView() } }
    }
}
.tabViewStyle(.sidebarAdaptable)
.modifier(DuoSidebarPlacement())   // .defaultTabBarPlacement(.sidebar) behind #available(iOS 27.1, *)
```

On regular width, Sign Out moves into the sidebar footer or into Settings. On compact width it stays in More.

**Continuity rule.** When the device folds or unfolds, a sidebar-only tab such as `.tags` must map back to `.more`, with More's stack pushed to Tags. Store `selection` in `@SceneStorage` and resolve it in `onChange(of: horizontalSizeClass)`.

### 3.2 List → detail: `NavigationSplitView` everywhere it fits

Use `NavigationSplitView` whether the width is compact or regular. It collapses to a single stack on its own on the outer display and tiles on the inner one. **Do not swap containers on a size-class change**, because a swap discards the navigation state. Selection is a binding (`@SceneStorage` for the ID), so the selected account or transaction survives a fold or unfold.

| Tab | Content column | Detail column | Empty detail |
|---|---|---|---|
| Accounts | Account list | `AccountDetailView` | `ContentUnavailableView("Select an Account")` |
| Transactions | Transaction list | Transaction detail/edit (F1 embedded) | "Select a Transaction" |
| Budgets | Budget cards | Drill-down `TransactionListView(initialFilters:)` | "Select a Budget" |
| Categories | Category list | Filtered transactions | "Select a Category" |
| Tags | Tag grid (2 columns) | Filtered transactions | "Select a Tag" |
| Fixed Expenses | List + month | Linked transactions (fixed-expense facet) | "Select a Fixed Expense" |
| Scheduled | Pending + Recurring list | `ScheduledFormView` (edit) | "Select a Schedule" |
| Dashboard, Settings | Single column (no split) | — | — |

On compact width the current behavior stays, so the outer display has **no regressions**. Tapping a transaction still opens the edit sheet: the split view's detail push is used only when `horizontalSizeClass == .regular`. The presentation choice sits in one place, `TransactionsRoot`.

### 3.3 Supporting surfaces

- **Summary (F3)** becomes an `.inspector` on Transactions. On regular width it is a trailing column. On compact width the system shows it as a sheet, the same as today.
- **Sheets**: add `.presentationSizing(.form)` to F1–F10 so they are centered on the inner display and the system displaces them at the fold. Do not use fixed widths or `.frame(width:)`.
- **Alerts, confirmation dialogs, context menus and swipe actions** are system components, so they adapt to the fold automatically. No code change.
- **Toolbars**: keep the icon-only items (+, filter, summary) vertical-friendly. Give **Add** `.visibilityPriority(.high)` and Summary `.low` (iOS 27.1). The probe showed Add is otherwise the first item to fall into "…": on the vertical bar, `primaryAction` items go last. A badged Filter stays visible because the HIG says badged items overflow last. The measured rail is **84 pt** wide and sits on the camera side (right in portrait, left in landscape), so the content column on the outer display is 382 pt wide.
- **Fold-aware custom layouts** (iOS 27.1+): the Dashboard grid, the Tags grid and Login read `ReservedRegion` of kind division. They place the gutter on the fold and switch to a top/bottom split in tent posture through `ArrangementView` with `.split`. Below 27.1 they fall back to the plain flat layout.

### 3.4 Mockups

All mockups are on the [iPhone Duo Mockups canvas](https://claude.ai/artifact/Ptpqw6RjFrLEXJvSPMf2oS). It is private until shared from its Share menu. It has one board per screen and one per state set. Each board lays out the device states from left to right: **O-P, O-L, I-L, I-P, I-B, I-T**. The overview board has the specs and the legend. The outer-display frames match the CI probe measurements in §1.3.

---

## 4. Screen-by-screen design

The mockups for each screen are on its canvas board, in this order: **O-P, O-L, I-L, I-P, I-B, I-T**, followed by the content states. I-S at ≤½ width uses the O-P layout because it is compact; at ⅔ width it uses the I-P layout. Both drop sides are checked in §6.

### S1 · Splash

Canvas board: **S1–S2 · Splash & Login**.

The splash is centered and non-interactive. It gets no structural change. In I-B and I-T the stack moves to the center of one region, the trailing half or the top half respectively, so the logo never sits on the fold.

### S2 · Login / Sign-up

Canvas board: **S1–S2 · Splash & Login**.

Keep the card at `maxWidth: 400`; it is a maximum and stays. The HIG says displaced elements move to the trailing side in book posture, and the card is the interactive element. Wrap the layout in a fold-aware container: in I-B the header goes in the leading region and the card in the trailing region. In I-T the header goes on top and the card at the bottom, as controls. In O-L the screen scrolls, and the keyboard pushes the active field into view.


### S3 · Dashboard

Canvas board: **S3 · Dashboard (+ states)**.

This screen gets the largest change. On regular width the cards **reflow** into **2 columns**, an even count as the HIG prefers. The order is kept as two balanced stacks:

- **Left (status):** Budget Verdict, Cashflow, Cashflow Trend
- **Right (lists):** Accounts, Planned Expenses, Unplanned Expenses

The Month Navigator spans both columns. The column split comes from a `Grid` or a custom `Layout` driven by size class and the proposed width. It does not use a fixed breakpoint. `widestDashboardAmountBody` stays shared across both columns so the amounts keep one alignment.


### S4 · Accounts list → S5 Account detail

Canvas board: **S4–S5 · Accounts & detail (+ states)**.

This tab becomes a `NavigationSplitView`. On regular width the detail column shows `AccountDetailView` and the selection is highlighted. On the outer display it pushes, as today. The **Edit** text button stays horizontal, as the HIG requires for text items.


### S6 · Transactions list (+ F3 Summary inspector)

Canvas board: **S6 · Transactions (+ states)**.

- **Compact:** today's layout: a plain list, sticky day headers, search with filter tokens, and the toolbar (S) (F) (+).
- **Regular:** list | detail. The detail is the embedded transaction form with Save and Cancel. **Summary** becomes `.inspector` in a trailing column that the (S) button toggles. Filters stay a sheet, which the system centers.
- **Vertical rail order:** `<` Back (on drill-down), then **(+)** as the prominent action, then a gap, then (F) and (S). Overflow drops (S) first.
- The day header's amount column and the 44 pt menu spacer stay as they are. Rows keep `lineLimit(1)` and get wider, so no truncation problems appear.


### S7 · Budgets list

Canvas board: **S7 · Budgets (+ states)**.

- **Compact:** the existing layout, with the Month Navigator in the section header and a card list.
- **Regular:** the card list goes in the content column. The detail column holds the drill-down transactions for the selected budget, replacing today's push. **Active Installments** stays below the cards.
- The `BudgetCard` minimum width of 180 pt is acceptable inside a column, but its maximum of 280 pt must stretch to the column. Check this in I-S.
- **(+)** opens a Menu with New Budget and Copy from Previous Month. A menu is icon-only, so it works on the vertical rail.


### S8 · More

Canvas board: **S8 & S13 · More, Settings, Currency**.

- **Compact only.** On regular width the More tab is hidden from the sidebar, and its destinations are sidebar items, as described in §3.1.
- **Unfold continuity:** if More's stack is at Tags when the device unfolds, select the `.tags` sidebar item. When it folds back, map `.tags` to More with Tags pushed.
- On regular width, **Sign Out** moves to the bottom of the sidebar, using the same confirmationDialog.

### S9 · Tags

Canvas board: **S9 · Tags**.

Replace `GridItem(.adaptive(minimum: 140))` with a column count that is always **even** on regular width. One way is `max(2, (width / 160).rounded(.down) & ~1)`, which is derived from the proposed width rather than a breakpoint. On compact width any count works. On regular width the grid sits in the content column and the detail holds the filtered transactions. In I-B the grid stays in the leading region, so the hinge gutter is not needed. **Stretch (optional):** in a full-width grid layout (I-T), add 24 pt extra gutter at `ReservedRegion.division`.

### S10 · Categories

Canvas board: **S10 · Categories**.

This is a list with color dots and a ⋮ menu (44 pt target). The content column holds the list and the detail holds the filtered transactions. The ⋮ menu and swipe actions are unchanged.

### S11 · Fixed Expenses

Canvas board: **S11 · Fixed Expenses**.

The list has a Month Navigator, paid and unpaid rows, a context menu, swipes (leading: add transaction; trailing: delete) and a (+) Menu. On regular width the detail column shows the linked transactions through the `fixedExpenses` facet. The "Add transaction" action keeps presenting F1 as a centered sheet.

### S12 · Scheduled

Canvas board: **S12 · Scheduled**.

The list has a Pending section, which appears only when pending items exist, and a Recurring section. On regular width the detail column holds `ScheduledFormView` in edit mode for the selected schedule. A pending item still opens F1 as a sheet.

### S13 · Settings / Currency picker

Canvas board: **S8 & S13 · More, Settings, Currency**.

This is a grouped `List` with no split. On regular width the list is constrained to a readable width through the system's `.readableContentGuide`-style margins. That keeps the segmented Theme picker from stretching to 690 pt: use `.contentMargins(.horizontal, …, for: .scrollContent)`, computed from the width. The Currency picker pushes inside the Settings stack.

---

## 5. Sheets and forms (F1–F11)

### 5.1 Shared sheet behavior

| State | Behavior |
|---|---|
| O-P / O-L | The sheet is inset 8 pt; this is measured. **Text buttons such as Cancel and Save stay horizontal beside the title**; they don't move to the vertical bar. Keep `ToolbarItem(placement: .cancellationAction / .confirmationAction)` so the system orders them. |
| I-L / I-P | `.presentationSizing(.form)` gives a centered card about 540 pt wide. The parent stays visible and dimmed. |
| I-B | The system moves the sheet into one region, away from the fold. **No custom code.** |
| I-T | The system moves the sheet clear of the fold. Long forms scroll. |
| Keyboard | Fields stay scrolled into view. `CurrencyField`'s `maxWidth: 150` is acceptable. |
| Fold / unfold mid-edit | **State must survive.** Each sheet keeps its draft in `@State` or in a view model owned *outside* any size-class branch. Verify that no `if sizeClass` wrapper re-creates the sheet. |
| Discard dialog | `confirmationDialog`: an action sheet on compact width, a popover on regular. System behavior. |

### 5.2 Per-sheet notes

Canvas boards: **F1 · Sheet pattern & Transaction form**, **F2–F4 · Filters, Summary, Installment**, **F5–F11 · Forms & pickers**.

**F1 Transaction form.** This is a sheet on compact width. On regular width it is also the **Transactions detail column** (§S6) when editing a row from the list. The New button still opens a sheet. The type segmented control stays horizontal.

**F2 Filters.** On regular width, use `.presentationSizing(.page)` so the long faceted form gets space. The date From/To pickers can sit side by side when the sheet is wide. That is an `HStack` inside a `ViewThatFits`, with no breakpoint.

On I-L, put facet sections in an even, 2-column reflow inside the page sheet. The order is kept by reading down the left column first.

**F3 Summary** is an inspector on regular width and a sheet on compact (§S6). States: `ProgressView("Summarizing…")`, `ContentUnavailableView("Couldn't Summarize")`, and a loaded view with Totals plus the Pending projection.

**F4 Virtual installment.** The start month is a segmented control (horizontal), followed by a Months stepper and an allocation grid. On regular width with `.page` sizing, the per-budget allocation sections show as a 2-column grid. The amount field's `maxWidth: 140` stays.

**F5 Budget form, F6 Account form, F7 Fixed expense new/edit, F8 Scheduled form, F9 Tag form, F10 Category form.** These are short grouped forms and use the shared pattern in §5.1 unchanged. Specific notes:

- **F6:** the PhotosPicker avatar (64 pt) is centered. The photo picker is a system sheet. "Show on dashboard" and "Set as default" are toggles.
- **F8:** the "Active" toggle and the type segmented control stay horizontal.
- **F10:** the swatch grid becomes an even column count (6 on compact, 8 on form-sized), followed by `ColorPicker`, which is a system popover on regular width.
- **F9:** errors are shown inline below the name field.

**F11 Pickers.** `CategoryPicker`, `BudgetPicker` and `FixedExpensePicker` are menu pickers: a system menu that is fold-aware. `TagPicker` is a searchable sheet with "Search or add a tag". The inline create sheets (`CreateBudgetSheet`, `CreateFixedExpenseSheet`, and New Category) are **stacked sheets**. On I-L they stack as form-sized cards, and the system keeps both clear of the fold.

---

## 6. State coverage matrix (QA checklist)

✓ marks a state to verify with a mockup above. Every screen is also checked in **light and dark** mode, at **Dynamic Type AX3**, and with **VoiceOver focus order** following the vertical rail (Back first).

| Screen | O-P | O-L | I-L | I-P | I-B | I-T | I-S ½ (lead/trail) | I-S ⅔ | Fold/unfold mid-state |
|---|---|---|---|---|---|---|---|---|---|
| S1 Splash | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| S2 Login | ✓ idle/load/err/keyboard | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | typed email kept |
| S3 Dashboard | ✓ load/loaded/partial | ✓ | ✓ 2-col | ✓ 2-col | ✓ col per region | ✓ glance/controls | ✓ 1-col | ✓ 2-col | month + scroll offset kept |
| S4/S5 Accounts | ✓ empty/list/detail | ✓ | ✓ split | ✓ | ✓ | ✓ | ✓ stack | ✓ split | selection ↔ pushed detail |
| S6 Transactions | ✓ all §S6 states | ✓ | ✓ + inspector | ✓ | ✓ | ✓ | ✓ | ✓ | search, tokens, dirty detail kept |
| S7 Budgets | ✓ empty/list/installments | ✓ | ✓ split | ✓ | ✓ | ✓ | ✓ | ✓ | month + selection kept |
| S8 More | ✓ | ✓ | hidden → sidebar | hidden | hidden | hidden | ✓ | — | tab mapping §S8 |
| S9 Tags | ✓ | ✓ 4-col | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | selection kept |
| S10 Categories | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | selection kept |
| S11 Fixed Exp. | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | month kept |
| S12 Scheduled | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | dirty edit kept |
| S13 Settings | ✓ | ✓ | ✓ readable | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| F1–F11 sheets | ✓ vertical bar | ✓ | ✓ form | ✓ | ✓ displaced | ✓ | ✓ | ✓ | **draft kept** |
| Alerts / dialogs | ✓ | ✓ | ✓ popover | ✓ | ✓ trailing | ✓ | ✓ | ✓ | stays presented |

---

## 7. Implementation

The build order, task breakdown, CI strategy and guardrails are in [`ios-iphone-duo-implementation-plan.md`](ios-iphone-duo-implementation-plan.md).

## 8. Risks and open questions

1. **Point sizes and the bar edge are unofficial.** Phase 0 measures them in the Device Hub, and this doc is updated before Phase 4 starts.
2. **Embedding the form in the Transactions detail column** adds a dirty-state rule that the sheet did not need. The fallback is to keep the sheet on regular width and get the split benefit for Summary only.
3. Whether **iOS 26.x users on other devices are unaffected** depends on the `#available` shims. Run the existing test suite on an iPhone 17 simulator in every phase.
4. **`TARGETED_DEVICE_FAMILY` includes iPad**, so the sidebar and split views also improve iPad and iPhone Mirroring. Test one iPad size as a cheap check.
5. The new APIs `ArrangementView`, `ReservedRegion` and `toolbarVerticalEdge` were in beta at the time of writing. Phase 5 is optional for a first release, and Phases 0–4 already meet the HIG through system containers.

## 9. Sources

- Apple: iPhone Duo Technical Specifications. https://www.apple.com/iphone-duo/specs/
- Apple Developer Tech Talk: Prepare your app for iPhone Duo. https://developer.apple.com/videos/play/tech-talks/111461/
- HIG summary, Designing for iPhone Duo. https://www.sagarunagar.com/blog/iphone-duo-human-interface-guidelines
- Derived point sizes and the API list (unofficial). https://blakecrosley.com/blog/iphone-duo-for-developers · https://ziplyne.agency/blog/iphone-duo-for-developers-screen-sizes-layout-rules-and-the-new-apis
