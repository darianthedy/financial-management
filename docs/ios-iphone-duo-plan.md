# Financial Management iOS: iPhone Duo Support Plan

Status: Proposal · Owner: iOS · Date: 2026-10-29
Scope: `iOS/FinancialManagement/FinancialManagement/Views/**` and `App/**`

This plan adapts every screen of the SwiftUI app to iPhone Duo: the 5.4″ outer display and the 7.6″ folding inner display, across flat, partly folded, rotated and Split View states. Each screen has ASCII mockups for each device state and each content state. Everything follows the HIG page *Designing for iPhone Duo* and Apple's Tech Talk *Prepare your app for iPhone Duo*. The rule throughout is to adapt by **size class**, and never by device, orientation or a hard-coded width.

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

Apple has **not published point sizes**. The figures below are derived: the panel pixels ÷ 3, and for the inner display the App Store Connect screenshot size (2007 × 2853) ÷ 3. Use them only to draw mockups. **Never hard-code them.** At runtime, read sizes from `GeometryReader`, from `windowScene.effectiveGeometry` and from the trait collection.

| State | Approx. points (W × H) | Size class (H / V) | System bars |
|---|---|---|---|
| **O-P** Outer, portrait | ~466 × 678 | Compact / Regular | Vertical, on the side edge (status bar and camera side) |
| **O-L** Outer, landscape (stood on its edge) | ~678 × 466 | Compact / Compact | Vertical, on the side edge |
| **I-L** Inner, landscape, flat (native) | ~951 × 669 | Regular / Regular | Vertical in landscape; tab bar can become a sidebar |
| **I-P** Inner, portrait, flat | ~669 × 951 | Regular / Regular | Horizontal |
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

### 1.3 Assumptions to verify in the Xcode 27.1 Device Hub simulator

1. The derived point sizes above.
2. Which edge carries the vertical bar on O-P and O-L. The mockups draw it on the **trailing** edge.
3. The size class at each Split View width (I-S).
4. The exact signatures of the iOS 27.1 APIs named in this plan: `ReservedRegion`, `ArrangementView`, `toolbarVerticalEdge`, `ToolbarItemVisibilityPriority`, and `defaultTabBarPlacement(.sidebar)`.

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

    // Compact (outer display / narrow Split View): keep the existing More tab.
    Tab("More", systemImage: "ellipsis", value: .more) { MoreRoot() }
        .defaultVisibility(.hidden, for: .sidebar)

    // Regular (inner display): the More destinations are promoted into the sidebar.
    TabSection("Management") {
        Tab("Tags", systemImage: "tag", value: .tags) { TagsRoot() }
        Tab("Categories", systemImage: "tag", value: .categories) { CategoriesRoot() }
        Tab("Fixed Expenses", systemImage: "receipt", value: .fixedExpenses) { FixedExpensesRoot() }
        Tab("Scheduled", systemImage: "calendar.badge.clock", value: .scheduled) { ScheduledRoot() }
    }
    .defaultVisibility(.hidden, for: .tabBar)
    Tab("Settings", systemImage: "gear", value: .settings) { NavigationStack { SettingsView() } }
        .defaultVisibility(.hidden, for: .tabBar)
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
- **Toolbars**: keep the icon-only items (+, filter, summary) vertical-friendly. Give **Add** the highest visibility priority, then Filter, then Summary, so overflow drops Summary first. A badged Filter stays visible because the HIG says badged items overflow last.
- **Fold-aware custom layouts** (iOS 27.1+): the Dashboard grid, the Tags grid and Login read `ReservedRegion` of kind division. They place the gutter on the fold and switch to a top/bottom split in tent posture through `ArrangementView` with `.split`. Below 27.1 they fall back to the plain flat layout.

### 3.4 Mockup legend

```
[=]  sidebar toggle         <  Back          (+) Add            (F) Filter (filled = active)
(S)  Summary                ...  overflow / row menu            [ ]  sheet edge
|::| vertical system bar: status bar, camera, nav buttons and tab items, drawn on the trailing edge
~~~~ fold division (partly folded only); nothing interactive sits on it
```

Sizes are schematic and not to scale. Light and dark themes share one layout.

---

## 4. Screen-by-screen design

Each screen gets mockups in this order: **O-P, O-L, I-L, I-P, I-B, I-T**. Then come the content-state variants. I-S at ≤½ width uses the O-P layout because it is compact; at ⅔ width it uses the I-P layout. Both drop sides are checked in §6.

### S1 · Splash

The splash is centered and non-interactive. It gets no structural change. In I-B and I-T the stack moves to the center of one region, the trailing half or the top half respectively, so the logo never sits on the fold.

```
O-P                                  I-L                                          I-B
+------------------------------+-+   +----------------------------------------+   +-------------------+~+-------------------+
|                              |:|   |                                        |   |                   |~|                   |
|          [banknote]          |:|   |              [banknote]                |   |                   |~|    [banknote]     |
|     Financial Management     |:|   |         Financial Management           |   |                   |~|   Financial Mgmt  |
|            (o)               |:|   |                 (o)                    |   |                   |~|       (o)         |
|                              |:|   |                                        |   |                   |~|                   |
+------------------------------+-+   +----------------------------------------+   +-------------------+~+-------------------+
O-L / I-P: same centered stack.      I-T: stack centered in the TOP region (glanceable); bottom region empty.
```

### S2 · Login / Sign-up

Keep the card at `maxWidth: 400`; it is a maximum and stays. The HIG says displaced elements move to the trailing side in book posture, and the card is the interactive element. Wrap the layout in a fold-aware container: in I-B the header goes in the leading region and the card in the trailing region. In I-T the header goes on top and the card at the bottom, as controls. In O-L the screen scrolls, and the keyboard pushes the active field into view.

```
O-P (idle)                           O-L (keyboard up, scrolled to field)
+------------------------------+-+   +--------------------------------------------+-+
|         [banknote]           |:|   | Email                                      |:|
|    Financial Management      |:|   | [ you@example.com                      ]   |:|
|   Sign in to your account    |:|   | Password                                   |:|
| +--------------------------+ |:|   | [ ••••••••|                            ]   |:|
| | Email                    | |:|   +--------------------------------------------+-+
| | [ you@example.com      ] | |:|   |  q  w  e  r  t  y  u  i  o  p   (keyboard) |
| | Password                 | |:|   +--------------------------------------------+
| | [ ••••••••             ] | |:|
| | [       Sign in        ] | |:|
| | Don't have an account?   | |:|
| |        Sign up           | |:|
| +--------------------------+ |:|
+------------------------------+-+

I-L / I-P (flat): card centered, max 400 pt      I-B (book)                                    I-T (tent)
+----------------------------------------+       +------------------+~+------------------+     +------------------------------+
|                                        |       |                  |~| +--------------+ |     |         [banknote]           |
|            [banknote]                  |       |    [banknote]    |~| | Email        | |     |    Financial Management      |
|       Financial Management             |       |  Financial Mgmt  |~| | [          ] | |     |   Sign in to your account    |
|      Sign in to your account           |       |  Sign in to your |~| | Password     | |     |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
|     +----------------------------+     |       |     account      |~| | [          ] | |     |  +------------------------+  |
|     | Email  [               ]   |     |       |                  |~| | [ Sign in  ] | |     |  | Email [              ] |  |
|     | Password [             ]   |     |       |                  |~| |  Sign up     | |     |  | Password [           ] |  |
|     | [        Sign in       ]   |     |       |                  |~| +--------------+ |     |  | [      Sign in       ] |  |
|     +----------------------------+     |       +------------------+~+------------------+     |  +------------------------+  |
+----------------------------------------+                                                     +------------------------------+
```

States (the same layout in every device state):

```
Loading                      Error                                Sign-up mode
| [   (o) spinner    ] |     | Invalid login credentials  (red) |   | Create your account          |
|  button 50% opacity  |     | [       Sign in       ]          |   | [    Create account    ]     |
                                                                    | Already have an account? Sign in |
```

### S3 · Dashboard

This screen gets the largest change. On regular width the cards **reflow** into **2 columns**, an even count as the HIG prefers. The order is kept as two balanced stacks:

- **Left (status):** Budget Verdict, Cashflow, Cashflow Trend
- **Right (lists):** Accounts, Planned Expenses, Unplanned Expenses

The Month Navigator spans both columns. The column split comes from a `Grid` or a custom `Layout` driven by size class and the proposed width. It does not use a fixed breakpoint. `widestDashboardAmountBody` stays shared across both columns so the amounts keep one alignment.

```
O-P (compact: today's single column)          O-L (compact/compact: single column, wider cards)
+--------------------------------+-+          +----------------------------------------------+-+
| Dashboard                      |:|          | Dashboard          <  October 2026  >        |:|
| <        October 2026       >  |:|          | +------------------------------------------+ |:|
| +----------------------------+ |:|          | | ● On track · 62% of budgets used         | |:|
| | ● On track                 | |:|          | +------------------------------------------+ |:|
| | 62% of planned spent       | |[D]         | +------------------------------------------+ |[D]
| +----------------------------+ |[A]         | | Cashflow   In 12.4M   Out 8.1M  Net +4.3M| |[A]
| +----------------------------+ |[T]         | +------------------------------------------+ |[T]
| | Cashflow                   | |[B]         |           (scrolls)                          |[B]
| | In  12,400,000             | |[…]         +----------------------------------------------+-+
| | Out  8,100,000  Net +4.3M  | |:|
| +----------------------------+ |:|
| | Cashflow Trend  ▂▅▃▇▆      | |:|
| +----------------------------+ |:|
|           (scrolls)            |:|
+--------------------------------+-+

I-L (sidebar + 2-column reflow)
+--------------+-----------------------------------------------------------+-+
| Financial M. | Dashboard                <   October 2026   >             |:|
|              | +---------------------------+ +---------------------------+|:|
| > Dashboard  | | ● On track                | | Accounts                  ||:|
|   Accounts   | | 62% of planned spent      | | BCA          4,200,000    ||:|
|   Transact.  | +---------------------------+ | Jago         1,150,000    ||:|
|   Budgets    | | Cashflow                  | | Cash           300,000    ||:|
| MANAGEMENT   | | In 12.4M  Out 8.1M  +4.3M | +---------------------------+|:|
|   Tags       | +---------------------------+ | Planned Expenses          ||:|
|   Categories | | Cashflow Trend            | | Rent      ■■■■■■■■ paid   ||:|
|   Fixed Exp. | |  ▂ ▅ ▃ ▇ ▆ ▄              | | Food      ■■■■□□□□ 52%    ||:|
|   Scheduled  | |  M J J A S O              | +---------------------------+|:|
|   Settings   | +---------------------------+ | Unplanned Expenses        ||:|
+--------------+-----------------------------------------------------------+-+

I-P (sidebar collapsed behind [=], 2 columns)    I-B (book: one column per region, gutter on the fold)
+----------------------------------------+       +--------------------------+~+--------------------------+
| [=] Dashboard                          |       | [=] Dashboard            |~|                          |
|        <    October 2026    >          |       | <   October 2026   >     |~|                          |
| +-----------------+ +-----------------+|       | +----------------------+ |~| +----------------------+ |
| | ● On track      | | Accounts        ||       | | ● On track           | |~| | Accounts             | |
| +-----------------+ | BCA    4.2M     ||       | +----------------------+ |~| | BCA        4,200,000 | |
| | Cashflow        | | Jago   1.1M     ||       | | Cashflow             | |~| | Jago       1,150,000 | |
| | Net +4.3M       | +-----------------+|       | +----------------------+ |~| +----------------------+ |
| +-----------------+ | Planned         ||       | | Cashflow Trend       | |~| | Planned Expenses     | |
| | Trend ▂▅▃▇▆     | | Rent  paid      ||       | +----------------------+ |~| +----------------------+ |
| +-----------------+ +-----------------+|       +--------------------------+~+--------------------------+
|              (scrolls)                 |        The sidebar auto-hides; the two columns scroll as one ScrollView.
+----------------------------------------+        That is scrolling content, so it is never displaced.

I-T (tent: glance on top, controls + scrolling cards at the bottom)
+----------------------------------------+
|  ● On track · 62% of planned spent     |   <- read-only glance (Verdict + Cashflow net), non-scrolling
|  Net +4,300,000   In 12.4M  Out 8.1M   |
|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
|  <        October 2026          >      |   <- control moved to the bottom region
|  +----------------+ +----------------+ |
|  | Trend          | | Accounts       | |   <- scrolls
|  +----------------+ +----------------+ |
+----------------------------------------+
```

States:

```
Loading (all device states)              Partial data (no budgets this month)      Month change
|  <  October 2026  >                |   | ● No budgets set (muted)        |       Cards slide out/in left/right
|                                    |   | Planned Expenses: "None"        |       (monthPageTransition); both
|            (o)  min 200pt          |   | Accounts card renders normally  |       columns animate together on I-L.
```

### S4 · Accounts list → S5 Account detail

This tab becomes a `NavigationSplitView`. On regular width the detail column shows `AccountDetailView` and the selection is highlighted. On the outer display it pushes, as today. The **Edit** text button stays horizontal, as the HIG requires for text items.

```
O-P list                               O-P detail (pushed)                  O-L list
+--------------------------------+-+   +--------------------------------+-+ +----------------------------------------------+-+
| Accounts                       |<|   |          ( avatar 80 )         |<| | Accounts                                     |(+)
| Total             5,650,000    |(+)  | ACCOUNT INFO                   |Edit| Total                          5,650,000     |:|
| +----------------------------+ |:|   | Name                     BCA   |:| | (o) BCA     Bank         4,200,000      >    |:|
| | (o) BCA  Bank  4,200,000 > | |:|   | Type                    Bank   |:| | (o) Jago    Bank         1,150,000      >    |:|
| | (o) Jago Bank  1,150,000 > | |:|   | Starting Balance   1,000,000   |:| +----------------------------------------------+-+
| | (o) Cash Cash    300,000 > | |:|   | Current Balance    4,200,000   |:|
| +----------------------------+ |:|   | Show on Dashboard        Yes   |:|
+--------------------------------+-+   | [ Archive Account ]  (red)     |:|
                                       +--------------------------------+-+

I-L (sidebar | list | detail)
+--------------+--------------------------+---------------------------------+-+
|   Dashboard  | Accounts             (+) |                            Edit |:|
| > Accounts   | Total        5,650,000   |          ( avatar 80 )          |:|
|   Transact.  | +----------------------+ | ACCOUNT INFO                    |:|
|   Budgets    | |#(o) BCA   4,200,000 #| | Name                       BCA  |:|
| MANAGEMENT   | | (o) Jago  1,150,000  | | Type                      Bank  |:|
|   ...        | | (o) Cash    300,000  | | Current Balance      4,200,000  |:|
|              | +----------------------+ | [ Archive Account ]             |:|
+--------------+--------------------------+---------------------------------+-+
 (# = selected row highlight)

I-P (list | detail, sidebar behind [=])        I-B (list in leading region, detail in trailing region)
+------------------+---------------------+      +---------------------------+~+---------------------------+
| [=] Accounts (+) |               Edit  |      | Accounts              (+) |~|                      Edit |
| Total 5,650,000  |    ( avatar )       |      | #(o) BCA      4,200,000 # |~|        ( avatar 80 )      |
| #(o) BCA  4.2M # | Name         BCA    |      |  (o) Jago     1,150,000   |~| Name                  BCA |
|  (o) Jago 1.1M   | Current   4,200,000 |      |  (o) Cash       300,000   |~| Current Bal.    4,200,000 |
+------------------+---------------------+      +---------------------------+~+---------------------------+
                                                  Split-view columns are fold-aware in the system.

I-T: list in the top region (glance), detail actions (Edit, Archive) in the bottom region via ArrangementView(.split).
```

States:

```
Empty (O-P)                       Empty (I-L detail column)          Loading            Archive alert (I-B)
|      [creditcard]           |   | list: EmptyStateView + "Add"  |  | list: blank     |  Alert moves toward the
|    No accounts yet          |   | detail: "Select an Account"   |  | detail: (o)     |  TRAILING region, never
| Add your first account...   |   |   ContentUnavailableView      |  |                 |  centered on the fold.
|     [ Add account ]         |
```

### S6 · Transactions list (+ F3 Summary inspector)

- **Compact:** today's layout: a plain list, sticky day headers, search with filter tokens, and the toolbar (S) (F) (+).
- **Regular:** list | detail. The detail is the embedded transaction form with Save and Cancel. **Summary** becomes `.inspector` in a trailing column that the (S) button toggles. Filters stay a sheet, which the system centers.
- **Vertical rail order:** `<` Back (on drill-down), then **(+)** as the prominent action, then a gap, then (F) and (S). Overflow drops (S) first.
- The day header's amount column and the 44 pt menu spacer stay as they are. Rows keep `lineLimit(1)` and get wider, so no truncation problems appear.

```
O-P                                         O-L
+--------------------------------+-+        +----------------------------------------------+-+
| Transactions                   |(+)       | Transactions  [Q Search description      ]   |(+)
| [Q Search description        ] |(F)       | 29 OCT 2026        3 items     -1,250,000    |(F)
| [Type: Expense x] [Acct: BCA x]|(S)       | (o) Food   Lunch  [Food][work]   -150,000 ...|(S)
| 29 OCT 2026  3 items -1,250,000|:|        | (o) Rent   Oct                 -1,100,000 ...|:|
| (o) Food  ● Pending  -150,000 ⋮|:|        +----------------------------------------------+-+
|     Lunch  [Food] [work]       |:|
| (o) Rent            -1,100,000⋮|:|
| 28 OCT 2026  1 item  +8,000,000|:|
| (o) Salary          +8,000,000⋮|:|
+--------------------------------+-+

I-L (sidebar | list | detail | optional Summary inspector)
+------------+----------------------------+---------------------------+-------------+-+
|  Dashboard | Transactions               | Edit Transaction     Save | Summary     |:|
|  Accounts  | [Q Search            ]     | [Expense|Income|Transfer] | TOTALS      |(+)
| >Transact. | [Type: Expense x]          | Account          BCA  >   | In   12.4M  |(F)
|  Budgets   | 29 OCT   3 items -1.25M    | Amount       150,000      | Out   8.1M  |(S)
| MANAGEMENT | #(o) Food ●Pend -150,000 # | Date      29 Oct 2026     | Net  +4.3M  |:|
|  ...       |  (o) Rent      -1,100,000  | Description  Lunch        | PENDING     |:|
|            | 28 OCT   1 item  +8.0M     | Budget        Food   >    | Out  -150K  |:|
|            |  (o) Salary    +8,000,000  | Tags   [work] (+)         |             |:|
+------------+----------------------------+---------------------------+-------------+-+
 The inspector is hidden by default; the sidebar auto-collapses when the inspector opens and the width is tight.

I-P (list | detail; the inspector covers the detail when opened)   I-B (list | detail across the fold)
+------------------+---------------------+                         +---------------------------+~+---------------------------+
| [=] Transactions | Edit Transaction    |                         | Transactions  (S)(F)(+)   |~| Edit Transaction     Save |
| [Q Search      ] | Cancel        Save  |                         | [Q Search description ]   |~| [Expense|Income|Transfer] |
| 29 OCT  -1.25M   | [Exp|Inc|Xfer]      |                         | 29 OCT 2026  -1,250,000   |~| Account             BCA > |
| #Food  -150,000# | Account   BCA  >    |                         | #(o) Food      -150,000 # |~| Amount          150,000   |
|  Rent -1,100,000 | Amount   150,000    |                         |  (o) Rent    -1,100,000   |~| Date         29 Oct 2026  |
+------------------+---------------------+                         +---------------------------+~+---------------------------+

I-T (tent)
+----------------------------------------+
| Summary  In 12.4M  Out 8.1M  Net +4.3M |  <- glance (inspector content when open, else selected txn read-only)
|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
| [Q Search description    ] (S)(F)(+)   |  <- controls at the bottom
| 29 OCT   3 items   -1,250,000          |
| (o) Food ● Pending          -150,000 ⋮ |  <- scrolls
+----------------------------------------+
```

States:

```
Loading           | (o) centered; detail "Select a Transaction"                         (all)
Empty             | [list.bullet] No Transactions / "Add your first transaction..."      (O-P, list col on I-L)
Filtered-empty    | tokens stay visible; "No transactions match these filters."; (F) filled
Searching         | search field focused, keyboard; on I-L detail stays visible beside the list
Pending row       | muted row background; swipe ▶ Confirm (green) / ◀ Delete, Dismiss (amber)
Load-more         | (o) row at list bottom; unchanged on all sizes
Delete alert      | system alert; I-B: moves to trailing region
Detail dirty + fold/unfold   | form state lives in TransactionFormViewModel held by TransactionsRoot -> preserved
Detail dirty + select other  | "Discard changes?" confirmationDialog before switching selection
Scoped (account-detail embed)| keeps MonthNavigator + labeled [Summary][Add] (text items stay horizontal)
```

### S7 · Budgets list

- **Compact:** the existing layout, with the Month Navigator in the section header and a card list.
- **Regular:** the card list goes in the content column. The detail column holds the drill-down transactions for the selected budget, replacing today's push. **Active Installments** stays below the cards.
- The `BudgetCard` minimum width of 180 pt is acceptable inside a column, but its maximum of 280 pt must stretch to the column. Check this in I-S.
- **(+)** opens a Menu with New Budget and Copy from Previous Month. A menu is icon-only, so it works on the vertical rail.

```
O-P                                    I-L
+--------------------------------+-+   +-------------+-----------------------------+--------------------------+-+
| Budgets                        |(+)  |  Dashboard  | Budgets                 (+) | Food · Oct 2026          |:|
| <       October 2026        >  |:|   |  Accounts   | <     October 2026     >    | 29 OCT     -150,000      |:|
| +----------------------------+ |:|   |  Transact.  | +-------------------------+ | (o) Lunch     -150,000   |:|
| |▌Food   1,200,000 / 2,000,000| |:|   | > Budgets   | |#▌Food  1.2M / 2.0M  60%#| | 27 OCT     -420,000      |:|
| | ■■■■■■□□□□  60%        ⋮  | |:|   |  MANAGEMENT | | ▌Transport 0.4M/0.5M 80%| | (o) Groceries -420,000   |:|
| +----------------------------+ |:|   |  ...        | +-------------------------+ |                          |:|
| |▌Transport  400,000/500,000 | |:|   |             | ACTIVE INSTALLMENTS         |                          |:|
| | ■■■■■■■■□□  80%        ⋮  | |:|   |             | Laptop  3/12  -500,000/mo   |                          |:|
| +----------------------------+ |:|   +-------------+-----------------------------+--------------------------+-+
| ACTIVE INSTALLMENTS            |:|
| Laptop   3/12   -500,000 / mo  |:|
+--------------------------------+-+

O-L: as O-P, with wider cards.   I-P: list | drill-down, sidebar behind [=].
I-B: cards in the leading region | drill-down in the trailing region.
I-T: Month Navigator + verdict summary in the top region; the scrolling card list in the bottom region,
     with the navigator moved down beside the list because it is a control.
```

States:

```
Empty month (O-P)                          Empty month (I-L)
| <    October 2026     >         |        | content col: same EmptyStateView        | detail: "Select a Budget" |
|          [target]               |        |   [Copy previous month] [Add budget]    |                           |
|   No budgets this month         |
| [Copy previous month]           |        Loading: (o) under the navigator.  Month change: content col slides;
| [Add budget]                    |        detail clears to "Select a Budget" (selection keyed by name+month).
Remove alert / Cancel-installment alert: system alerts (trailing region on I-B).
```

### S8 · More

- **Compact only.** On regular width the More tab is hidden from the sidebar, and its destinations are sidebar items, as described in §3.1.
- **Unfold continuity:** if More's stack is at Tags when the device unfolds, select the `.tags` sidebar item. When it folds back, map `.tags` to More with Tags pushed.
- On regular width, **Sign Out** moves to the bottom of the sidebar, using the same confirmationDialog.

```
O-P                                  O-L                                         I-L sidebar footer
+--------------------------------+-+ +----------------------------------------------+-+   |   Settings     |
| More                           |:| | More                                         |:|   |                |
| MANAGEMENT                     |:| | MANAGEMENT                                   |:|   | [->] Sign Out  |  (red)
| [tag] Tags                   > |:| | [tag] Tags        [tag] Categories         > |:|   +----------------+
| [tag] Categories             > |:| |  (single column list; rows just get wider)    |:|
| [rcpt] Fixed Expenses        > |:| +----------------------------------------------+-+
| [cal] Scheduled              > |:|
| SETTINGS                       |:|  Sign-out dialog: action sheet on compact; on I-L it becomes
| [gear] Settings              > |:|  a popover anchored to the sidebar row (system default).
| [->] Sign Out          (red)   |:|
+--------------------------------+-+
```

### S9 · Tags

Replace `GridItem(.adaptive(minimum: 140))` with a column count that is always **even** on regular width. One way is `max(2, (width / 160).rounded(.down) & ~1)`, which is derived from the proposed width rather than a breakpoint. On compact width any count works. On regular width the grid sits in the content column and the detail holds the filtered transactions. In I-B the grid stays in the leading region, so the hinge gutter is not needed. **Stretch (optional):** in a full-width grid layout (I-T), add 24 pt extra gutter at `ReservedRegion.division`.

```
O-P (2 cols)                         I-L (content col 2 cols | detail)
+--------------------------------+-+ +-------------+---------------------------+-----------------------------+-+
| Tags                           |(+)|  ...        | Tags                  (+) | work · Transactions         |:|
| +-----------+ +-----------+    |:| | >Tags       | +----------+ +----------+ | 29 OCT          -150,000    |:|
| |# work     | |# travel   |    |:| |  Categories | |##work   #| |# travel  | | (o) Lunch       -150,000    |:|
| +-----------+ +-----------+    |:| |  Fixed Exp. | +----------+ +----------+ | 12 OCT          -890,000    |:|
| |# family   | |# health   |    |:| |  Scheduled  | |# family  | |# health  | | (o) Hotel       -890,000    |:|
| +-----------+ +-----------+    |:| |  Settings   | +----------+ +----------+ |                             |:|
+--------------------------------+-+ +-------------+---------------------------+-----------------------------+-+

O-L: 4 cols.  I-P: grid (2) | detail.  I-B: grid in the leading region | detail in the trailing region.
I-T: grid on top (glance), detail list at the bottom.
States: Loading (o) · Empty [tag] "No tags yet" + [Add tag] · Context menu "Edit" (system, fold-aware).
```

### S10 · Categories

This is a list with color dots and a ⋮ menu (44 pt target). The content column holds the list and the detail holds the filtered transactions. The ⋮ menu and swipe actions are unchanged.

```
O-P                                  I-L
+--------------------------------+-+ +-------------+---------------------------+-----------------------------+-+
| Categories                     |(+)|  ...        | Categories            (+) | Food · Transactions         |:|
| ● Food                       ⋮ |:| | >Categories | #● Food               ⋮ # | 29 OCT          -150,000    |:|
| ● Transport                  ⋮ |:| |  ...        |  ● Transport          ⋮   | (o) Lunch       -150,000    |:|
| ● Salary                     ⋮ |:| |             |  ● Salary             ⋮   |                             |:|
+--------------------------------+-+ +-------------+---------------------------+-----------------------------+-+
O-L: wider rows.  I-P / I-B / I-T: the split patterns from S9.
States: Loading · Empty [tag] "No categories yet" + [Add category] · Delete alert (system).
```

### S11 · Fixed Expenses

The list has a Month Navigator, paid and unpaid rows, a context menu, swipes (leading: add transaction; trailing: delete) and a (+) Menu. On regular width the detail column shows the linked transactions through the `fixedExpenses` facet. The "Add transaction" action keeps presenting F1 as a centered sheet.

```
O-P                                  I-L
+--------------------------------+-+ +-------------+-----------------------------+---------------------------+-+
| Fixed Expenses                 |(+)|  ...        | Fixed Expenses          (+) | Rent · Oct 2026           |:|
| <       October 2026        >  |:| | >Fixed Exp. | <     October 2026     >    | 01 OCT      -1,100,000    |:|
| Rent       1,100,000   ✓ Paid  |:| |             | #Rent   1,100,000  ✓ Paid # | (o) Rent    -1,100,000    |:|
| Internet     350,000   Unpaid  |:| |             |  Internet 350,000  Unpaid   |                           |:|
+--------------------------------+-+ +-------------+-----------------------------+---------------------------+-+
I-T: Month Navigator in the bottom region with the list; the top region shows "Paid 1.1M / 1.45M" (glance).
States: Loading · Empty "No fixed expenses" + [Copy previous month][Add] · Delete alert.
```

### S12 · Scheduled

The list has a Pending section, which appears only when pending items exist, and a Recurring section. On regular width the detail column holds `ScheduledFormView` in edit mode for the selected schedule. A pending item still opens F1 as a sheet.

```
O-P                                  I-L
+--------------------------------+-+ +-------------+-----------------------------+---------------------------+-+
| Scheduled                      |(+)|  ...        | Scheduled               (+) | Edit Scheduled       Save |:|
| PENDING                        |:| | >Scheduled  | PENDING                     | [Expense|Income|Transfer] |:|
| Netflix  -186,000 [✓][✎][x]    |:| |             | Netflix -186,000 [✓][✎][x]  | Account          BCA  >   |:|
| RECURRING                      |:| |             | RECURRING                   | Next date   1 Nov 2026    |:|
| Netflix   monthly  -186,000    |:| |             | #Netflix monthly -186,000#  | Active             [on]   |:|
| Gym ⏸ (paused)     -500,000    |:| |             |  Gym ⏸ paused   -500,000    |                           |:|
+--------------------------------+-+ +-------------+-----------------------------+---------------------------+-+
States: Loading · Empty "No scheduled transactions" · Paused (muted + ⏸) · Pending only · Delete alert.
Swipe: ◀ Delete / Edit, ▶ Pause/Resume. The context menu is fold-aware in the system.
```

### S13 · Settings / Currency picker

This is a grouped `List` with no split. On regular width the list is constrained to a readable width through the system's `.readableContentGuide`-style margins. That keeps the segmented Theme picker from stretching to 690 pt: use `.contentMargins(.horizontal, …, for: .scrollContent)`, computed from the width. The Currency picker pushes inside the Settings stack.

```
O-P                                  I-L (readable width, centered in the detail area)
+--------------------------------+-+ +-------------+-----------------------------------------------------+-+
| Settings                       |:| |  ...        | Settings                                            |:|
| CURRENCY                       |:| | >Settings   |        CURRENCY                                     |:|
| Default Currency     IDR     > |:| |             |        Default Currency                 IDR  >      |:|
| THEME                          |:| |             |        THEME                                        |:|
| [ Light | Dark | System ]      |:| |             |        [   Light   |   Dark   |  System  ]         |:|
| DEFAULT ACCOUNT                |:| |             |        DEFAULT ACCOUNT                              |:|
| Default Account      BCA     ⌄ |:| |             |        Default Account                  BCA  ⌄      |:|
+--------------------------------+-+ +-------------+-----------------------------------------------------+-+
I-B: the list is scrolling content, so it is not displaced. The readable width keeps rows clear of the fold
where possible. Currency picker: searchable list (search field + keyboard); unchanged layout on all sizes.
```

---

## 5. Sheets and forms (F1–F11)

### 5.1 Shared sheet behavior

| State | Behavior |
|---|---|
| O-P / O-L | Full-height sheet. Bar buttons can stack vertically on the side: **Cancel at the top, then the prominent Save**. Keep `ToolbarItem(placement: .cancellationAction / .confirmationAction)` so the system orders them. |
| I-L / I-P | `.presentationSizing(.form)` gives a centered card about 540 pt wide. The parent stays visible and dimmed. |
| I-B | The system moves the sheet into one region, away from the fold. **No custom code.** |
| I-T | The system moves the sheet clear of the fold. Long forms scroll. |
| Keyboard | Fields stay scrolled into view. `CurrencyField`'s `maxWidth: 150` is acceptable. |
| Fold / unfold mid-edit | **State must survive.** Each sheet keeps its draft in `@State` or in a view model owned *outside* any size-class branch. Verify that no `if sizeClass` wrapper re-creates the sheet. |
| Discard dialog | `confirmationDialog`: an action sheet on compact width, a popover on regular. System behavior. |

```
Shared pattern: O-P                    I-L (form-sized, centered)                       I-B (displaced by system)
+--------------------------------+-+   +----------------------------------------+       +-----------------+~+-------------------+
| New Transaction                |x|   |   (dimmed parent)                      |       |  (dimmed)       |~| [ New Transaction]|
|                                |✓|   |    +----------------------------+      |       |                 |~| [ Cancel    Save ]|
| [Expense | Income | Transfer]  |:|   |    | Cancel  New Transaction Save|     |       |                 |~| [ [Exp|Inc|Xfer] ]|
| Account              BCA     > |:|   |    | [Expense|Income|Transfer]  |      |       |                 |~| [ Account  BCA > ]|
| Amount           150,000       |:|   |    | Account            BCA  >  |      |       |                 |~| [ Amount 150,000 ]|
| Date             29 Oct 2026   |:|   |    | Amount         150,000     |      |       |                 |~| [ ...scrolls...  ]|
| ...                            |:|   |    +----------------------------+      |       +-----------------+~+-------------------+
+--------------------------------+-+   +----------------------------------------+
 x = Cancel (top), ✓ = Save (prominent), both on the vertical bar
```

### 5.2 Per-sheet notes and mockups

**F1 Transaction form.** This is a sheet on compact width. On regular width it is also the **Transactions detail column** (§S6) when editing a row from the list. The New button still opens a sheet. The type segmented control stays horizontal.

```
Expense                               Transfer                                Error
| [Expense|Income|Transfer] |         | [Expense|Income|Transfer]  |          | ... fields ...                      |
| Account        BCA  >     |         | From           BCA   >     |          | ⚠ Amount must be greater than 0 (red)|
| Amount     150,000        |         | To             Jago  >     |
| Budget / Category / Fixed |         | Amount     1,000,000       |          Discard dialog: "Discard changes?"
| Tags  [work] (+)          |         | (no budget/category rows)  |
```

**F2 Filters.** On regular width, use `.presentationSizing(.page)` so the long faceted form gets space. The date From/To pickers can sit side by side when the sheet is wide. That is an `HStack` inside a `ViewThatFits`, with no breakpoint.

```
O-P                                   I-L (.page sizing)
| Cancel     Filters      Reset |     | Cancel               Filters                  Reset |
| DATE  From [1 Oct] To [31 Oct]|     | DATE   From [ 1 Oct 2026 ]   To [ 31 Oct 2026 ]     |
| TYPE  ● Expense ○ Income ...  |     | TYPE                       | ACCOUNTS                  |
| ACCOUNTS ● BCA ○ Jago ...     |     |  ● Expense ○ Income ○ Xfer |  ● BCA ○ Jago ○ Cash      |
| (loading facets: (o))         |     | CATEGORIES (multi-select)  | TAGS (multi-select)       |
```

On I-L, put facet sections in an even, 2-column reflow inside the page sheet. The order is kept by reading down the left column first.

**F3 Summary** is an inspector on regular width and a sheet on compact (§S6). States: `ProgressView("Summarizing…")`, `ContentUnavailableView("Couldn't Summarize")`, and a loaded view with Totals plus the Pending projection.

**F4 Virtual installment.** The start month is a segmented control (horizontal), followed by a Months stepper and an allocation grid. On regular width with `.page` sizing, the per-budget allocation sections show as a 2-column grid. The amount field's `maxWidth: 140` stays.

```
O-P                                     I-L (.page)
| Start month [This|Next]         |     | Start month [ This month | Next month ]   Months  [-] 6 [+]  |
| Months: 6              [-][+]   |     | FOOD                         | TRANSPORT                     |
| BUDGETS ● Food ● Transport      |     | Nov  [ 100,000 ]  Dec [ … ]  | Nov  [ 50,000 ]  Dec [ … ]    |
| FOOD  Nov [100,000] Dec [...]   |     | ⚠ Allocations must total 1,200,000 (red, full width)          |
```

**F5 Budget form, F6 Account form, F7 Fixed expense new/edit, F8 Scheduled form, F9 Tag form, F10 Category form.** These are short grouped forms and use the shared pattern in §5.1 unchanged. Specific notes:

- **F6:** the PhotosPicker avatar (64 pt) is centered. The photo picker is a system sheet. "Show on dashboard" and "Set as default" are toggles.
- **F8:** the "Active" toggle and the type segmented control stay horizontal.
- **F10:** the swatch grid becomes an even column count (6 on compact, 8 on form-sized), followed by `ColorPicker`, which is a system popover on regular width.
- **F9:** errors are shown inline below the name field.

```
F10 Category form (O-P)               F10 (I-L form sheet)                   F6 Account form (I-L form sheet)
| Cancel  New category   Save |       | Cancel   New category     Save |   | Cancel   New Account     Save |
| Name [ Groceries         ]  |       | Name [ Groceries             ] |   |        ( + photo 64 )         |
| COLOR                       |       | COLOR                          |   | Name [ BCA                  ] |
| ● ● ● ● ● ●                 |       | ● ● ● ● ● ● ● ●                |   | Type            Bank  ⌄       |
| ● ● ● ● ● ●                 |       | ● ● ● ● ● ● ● ●                |   | Show on dashboard      [on]   |
| Custom color          (◐)   |       | Custom color              (◐)  |   | Set as default        [off]   |
```

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

## 7. Implementation phases

| Phase | Work | Files | Done when |
|---|---|---|---|
| **0. Toolchain** | Build with Xcode 27.1 / the iOS 27.1 SDK. **Keep the deployment target at 26.1** and gate new APIs with `if #available(iOS 27.1, *)` or a ViewModifier shim. Do not set `UIRequiresFullScreen`. Add an iPhone Duo simulator to the fastlane `scan` devices. | `project.pbxproj`, `fastlane/Fastfile` | The app launches full-screen on both displays in the Device Hub. |
| **1. Root navigation** | Use `sidebarAdaptable` TabView, `TabSection`, and visibility per placement. Store the selection in `@SceneStorage`, add the More ↔ sidebar mapping, and move Sign Out. | `Views/Shared/ContentRootView.swift`, `More/MoreView.swift` | Outer shows 5 tabs. Inner shows the sidebar. Fold/unfold keeps the destination. |
| **2. Split views** | Add `*Root` wrappers with `NavigationSplitView` and selection bindings for Accounts, Budgets, Categories, Tags, Fixed Expenses and Scheduled, with `ContentUnavailableView` placeholders. Detail views take IDs, not models, so realtime reloads stay correct. | New `Views/<Feature>/<Feature>Root.swift`, list views (`.navigationDestination` → selection) | Compact behavior is pixel-identical to today. Regular width tiles. |
| **3. Transactions** | Embed the regular-width detail form, the dirty-check on selection change, `.inspector` for Summary, toolbar visibility priorities and `.page` sizing for Filters. | `TransactionListView.swift`, `TransactionFormView.swift`, `TransactionSummarySheet.swift`, `TransactionFilterSheet.swift` | All §S6 states pass. |
| **4. Dashboard reflow** | A 2-column `Layout` for regular width with a shared amount column. Fix the legend `minWidth: 240` with `ViewThatFits`, which falls back to a vertical legend. | `DashboardView.swift`, `CashflowTrendCard.swift` | No clipping from ⅓ Split View up to I-L. |
| **5. Fold awareness (27.1+)** | `ReservedRegion` division for the Dashboard, Login, Splash and the full-width Tags grid. `ArrangementView(.split)` for the tent-posture glance/controls split (Dashboard, Transactions, Budgets, Fixed Expenses). Even columns in Tags (S9) and swatches (F10). | `Views/Shared/FoldAwareLayout.swift` (new), affected views | Nothing interactive overlaps the division in I-B or I-T. |
| **6. Sheets** | `.presentationSizing(.form/.page)` on F1–F10. Check that the toolbar placements are semantic. Audit that sheet state is owned outside size-class branches. | All `*Sheet.swift` / `*FormView.swift` | A draft survives fold/unfold. |
| **7. Readable width** | Width-derived content margins for Settings and the single-column lists in the I-S ⅔ and I-P cases. | `SettingsView.swift`, `MoreView.swift` | No 690 pt-wide segmented controls. |
| **8. Tests** | UI tests that rotate and fold through the Device Hub controls. Snapshot tests per §6 row in each size class. Unit tests for the tab-selection mapping. Run the "App Resizability" agent skill in Xcode 27.1 as a linter. | `FinancialManagementUITests/`, `FinancialManagementTests/` | §6 matrix is green in CI. |

**Guardrails for every phase:**

- No `UIScreen.main`. No orientation checks. No `userInterfaceIdiom` checks.
- No fixed numeric breakpoints. Layouts may derive from the proposed width; do not compare against device constants.
- Inset each safe-area edge on its own. Never write `bounds.width - inset.left * 2`.
- Use `ConcentricRectangle` for any new full-bleed container so its corners match the display's corners.
- Keep the system bars standard. A custom bar must use `ReservedRegion` and would lose the automatic vertical layout, so avoid custom bars.
- Re-check every UI change on O-P (the narrowest case) as well as I-L, extending the existing desktop and mobile double-check rule.

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
