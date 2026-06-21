# iOS ↔ Web Design Parity — Execution Prompts

The **web app is the single source of truth** for visual design. These prompts align the iOS
app to it, screen by screen.

Each prompt below is **fully self-contained and can be executed independently, in any order**.
Every prompt re-establishes the shared context and ensures the design-token foundation exists
before making changes, so you never need to have run an earlier prompt first.

Recommended order if running fresh: Prompt 1 → 2 → (3–7 in any order) → 8. But none of them
*depend* on another having run.

---

## Shared context (embedded in every prompt)

- The web app (`web/`) is the single source of truth for visual design. **Never modify the web app.**
- Web design tokens live in `web/src/styles/globals.css` (`@theme` block + `.dark` overrides:
  colors `primary/success/danger/warning/muted/muted-foreground/card/card-foreground/background/
  foreground/border/input/ring`, plus `--radius`), with full light + dark variants and a system
  font stack. Also see `web/src/index.css`, `web/src/App.css`, `web/src/lib/hooks/use-theme.tsx`.
- The iOS app has no native design system by default; align colors/typography/spacing/radius to
  the web tokens. Keep native iOS interaction idioms where web uses web-only patterns, but match
  the visual design (colors, typography, spacing, wording, states).
- **Verification standard:** verify every changed iOS screen at TWO sizes — small iPhone
  (SE / ~320pt) and a large iPhone — in BOTH light and dark mode.
- iOS app root: `iOS/FinancialManagement/FinancialManagement/`.

---

## Prompt 1 — Design-system foundation (iOS design tokens)

```
The web app (web/) is the single source of truth for visual design. NEVER modify the web app.

Goal: create a centralized SwiftUI design-token layer for the iOS app that mirrors web's tokens,
so any screen can be aligned by referencing these tokens instead of ad-hoc colors.

1. Read the web design tokens:
   - web/src/styles/globals.css  (the @theme block + .dark overrides: colors, --radius)
   - web/src/index.css
   - web/src/App.css
   - web/src/lib/hooks/use-theme.tsx  (how light/dark is toggled)
   Catalog every token: name, light value (HSL), dark value (HSL).

2. Audit current iOS color usage:
   - grep all Color.* / Color("...") / .foregroundColor / .tint / .background usages under
     iOS/FinancialManagement/FinancialManagement/Views and ViewModels.
   - List Assets.xcassets contents.

3. Produce a DESIGN TOKEN MAPPING TABLE (web token -> proposed iOS token) covering at least:
   primary, primary-foreground, success, danger, warning, muted, muted-foreground,
   card, card-foreground, background, foreground, border, input, ring, and --radius.

4. Implement (DO NOT touch any screen yet):
   - Add color sets to iOS/FinancialManagement/FinancialManagement/Assets.xcassets with light +
     dark ("Any/Dark") appearance values matching the HSL values from web (convert HSL -> sRGB).
   - Create a Theme/ design layer (e.g. .../Views/Theme/AppTheme.swift) exposing Color extensions
     (Color.appPrimary, .appSuccess, .appDanger, .appWarning, .appMuted, .appMutedForeground,
     .appCard, .appBorder, .appBackground, .appForeground, etc.) and a corner-radius constant
     matching --radius.
   - Confirm the app honors system light/dark like web's class-based dark mode.

5. Verify: build the iOS app and confirm it compiles. Show the token table and the new files.

Output: the mapping table, the new files, and confirmation the build succeeds.
```

---

## Prompt 2 — Layout, navigation & shared components

```
The web app (web/) is the single source of truth for visual design. NEVER modify the web app.
Align iOS global layout, navigation, and shared/reusable components to web.

FOUNDATION CHECK (do this first): ensure the iOS design-token layer exists (Color.appPrimary,
.appCard, .appBorder, .appSuccess, .appDanger, a --radius constant, etc., backed by light+dark
color sets in Assets.xcassets). If it does NOT exist, create it first by mirroring the @theme +
.dark blocks in web/src/styles/globals.css (HSL -> sRGB, light + dark appearances) before
proceeding.

Compare these pairs, produce a DISCREPANCY REPORT first, then fix iOS:

Navigation / layout:
- web: web/src/components/layout/{app-layout,header,sidebar,mobile-nav,nav-config}.tsx
- iOS: .../Views/Shared/ContentRootView.swift, .../Views/More/MoreView.swift
  Check: tab/nav item set + order + icons + labels match nav-config.ts (primary: Dashboard,
  Accounts, Transactions, Budgets; secondary: Categories, Tags, Fixed Expenses, Scheduled, Settings).

Shared components (web web/src/components/shared/* and ui/* vs iOS .../Views/Shared/*):
- currency input: web shared/currency-amount-input.tsx & currency-select.tsx
    vs iOS Shared/CurrencyField.swift, Settings/CurrencyPickerView.swift
- amount coloring: web shared/amount-column.tsx (income/expense colors) vs iOS usages
- empty states: web empty-state pattern vs iOS Shared/EmptyStateView.swift
- pickers: web ui/select.tsx / multi-select.tsx vs iOS Shared/{AccountPicker,CategoryPicker,
    TagPicker,BudgetPicker,FixedExpensePicker,MultiSelectFacet}.swift
- month navigation: web date utils vs iOS Shared/MonthNavigator.swift
- buttons/inputs/cards/dialogs: web ui/{button,input,card,dialog,popover}.tsx — extract the
    visual spec (radius, padding, font weight, colors, variants) and ensure iOS equivalents match.

For each discrepancy report: component, what web does (spacing/color/typography/states),
what iOS currently does, and the fix. Apply fixes using the iOS design tokens.

Verify every changed screen at small iPhone (SE / ~320pt) and a large iPhone, in light AND dark.
```

---

## Prompt 3 — Dashboard

```
The web app (web/) is the single source of truth for visual design. NEVER modify the web app.
Align the iOS Dashboard screen to web.

FOUNDATION CHECK (do this first): ensure the iOS design-token layer exists (Color.appPrimary,
.appCard, .appBorder, .appSuccess, .appDanger, a --radius constant, etc.). If not, create it by
mirroring the @theme + .dark blocks in web/src/styles/globals.css (light + dark) before proceeding.

Compare:
- web: web/src/pages/dashboard.tsx + web/src/components/dashboard/{accounts-card,
  planned-expenses,unplanned-expenses,verdict-banner}.tsx + lib/hooks/use-dashboard.ts
- iOS: .../Views/Dashboard/{DashboardView,AccountsCard,PlannedExpensesCard,
  UnplannedExpensesCard,BudgetVerdictBanner}.swift + ViewModels/DashboardViewModel.swift

Produce a DISCREPANCY REPORT covering: section order, card layout/spacing/corner radius,
the verdict banner (colors for over/under budget, wording), planned vs unplanned grouping,
amount formatting & color (income/expense/success/danger), empty states, and typography
hierarchy (titles, totals, captions). Then fix iOS to match using design tokens.

Verify at small (~320pt) and large iPhone widths, light + dark.
```

---

## Prompt 4 — Accounts

```
The web app (web/) is the single source of truth for visual design. NEVER modify the web app.
Align the iOS Accounts screens to web.

FOUNDATION CHECK (do this first): ensure the iOS design-token layer exists (Color.appPrimary,
.appCard, .appBorder, .appSuccess, .appDanger, a --radius constant, etc.). If not, create it by
mirroring the @theme + .dark blocks in web/src/styles/globals.css (light + dark) before proceeding.

Compare:
- web: web/src/pages/accounts.tsx + components/accounts/{account-card,account-form,
  account-avatar}.tsx + lib/storage/account-images.ts + lib/account-types.ts
- iOS: .../Views/Accounts/{AccountListView,AccountDetailView,AccountCard,AccountAvatar,
  AccountFormSheet}.swift + ViewModels/{AccountListViewModel,AccountDetailViewModel}.swift

DISCREPANCY REPORT then fix: card layout, avatar (image/initials/colors), account-type badges
& icons, balance formatting + sign colors, list ordering/grouping, the create/edit form
(field order, labels, validation messaging), and empty state. Match via design tokens.

Verify small + large iPhone, light + dark.
```

---

## Prompt 5 — Transactions (list, form, filters, installments)

```
The web app (web/) is the single source of truth for visual design. NEVER modify the web app.
Align the iOS Transactions experience (the largest surface) to web.

FOUNDATION CHECK (do this first): ensure the iOS design-token layer exists (Color.appPrimary,
.appCard, .appBorder, .appSuccess, .appDanger, a --radius constant, etc.). If not, create it by
mirroring the @theme + .dark blocks in web/src/styles/globals.css (light + dark) before proceeding.

Compare:
- web: web/src/pages/{transactions,transaction-form}.tsx + components/transactions/*
  (transaction-row, transaction-list, transaction-display, transaction-form, transaction-filters,
  transaction-summary, transaction-pagination, installment-builder, installment-dialog,
  category-form) + lib/hooks/use-transactions.ts + lib/utils/transaction-filters.ts
- iOS: .../Views/Transactions/{TransactionListView,TransactionRow,TransactionFormView,
  FilterBar,TransactionFilterSheet,TransactionSummarySheet,CreateInstallmentSheet}.swift
  + ViewModels/{TransactionListViewModel,TransactionFormViewModel}.swift

DISCREPANCY REPORT then fix, grouped by sub-surface:
  (a) Row: layout, category/tag chips, amount color & alignment, date format, account label.
  (b) List: section grouping (by date), pagination/infinite scroll, summary header totals.
  (c) Filters: facet set, multi-select chips, active-filter display, clear behavior.
  (d) Form: field order, labels, type toggle (income/expense), category & tag pickers,
      account picker, amount input, validation messages.
  (e) Installments: builder flow, dialog content, displayed schedule.
Match visuals via design tokens; keep native iOS interaction idioms where web uses web-only
patterns, but match colors/typography/spacing/wording.

Verify small + large iPhone, light + dark.
```

---

## Prompt 6 — Budgets (incl. installments)

```
The web app (web/) is the single source of truth for visual design. NEVER modify the web app.
Align the iOS Budgets screens to web.

FOUNDATION CHECK (do this first): ensure the iOS design-token layer exists (Color.appPrimary,
.appCard, .appBorder, .appSuccess, .appDanger, a --radius constant, etc.). If not, create it by
mirroring the @theme + .dark blocks in web/src/styles/globals.css (light + dark) before proceeding.

Compare:
- web: web/src/pages/budgets.tsx + components/budgets/{budget-card,budget-form,
  installment-list}.tsx + lib/hooks/{use-budgets,use-installments}.ts
- iOS: .../Views/Budgets/{BudgetListView,BudgetCard,BudgetFormSheet,
  ActiveInstallmentsSection}.swift + ViewModels/BudgetListViewModel.swift

DISCREPANCY REPORT then fix: budget card layout, progress bar (track/fill colors for
under/near/over budget, percentage, remaining amount), spent vs limit typography, the
create/edit form, active installments section layout, and empty state. Match via design tokens.

Verify small + large iPhone, light + dark.
```

---

## Prompt 7 — Secondary screens: Categories, Tags, Fixed Expenses, Scheduled

```
The web app (web/) is the single source of truth for visual design. NEVER modify the web app.
Align the four iOS secondary management screens to web.

FOUNDATION CHECK (do this first): ensure the iOS design-token layer exists (Color.appPrimary,
.appCard, .appBorder, .appSuccess, .appDanger, a --radius constant, etc.). If not, create it by
mirroring the @theme + .dark blocks in web/src/styles/globals.css (light + dark) before proceeding.

Compare each pair, one DISCREPANCY REPORT per screen, then fix:
- Categories: web pages/categories.tsx + components/categories/category-form.tsx +
  lib/hooks/use-categories.ts  vs  iOS category management UI (Shared/CategoryPicker.swift +
  any category list/form). Check: color swatch, icon, list layout, form fields.
- Tags: web pages/tags.tsx + components/tags/tag-form.tsx + lib/hooks/use-tags.ts
  vs iOS Shared/TagPicker.swift + any tag list/form. Check chip styling & colors.
- Fixed Expenses: web pages/fixed-expenses.tsx + components/fixed-expenses/{fixed-expense-row,
  fixed-expense-form}.tsx + lib/hooks/use-fixed-expenses.ts  vs  iOS .../Views/FixedExpenses/*
  (Row, ListView, FormSheet, EditSheet). Check row layout, amount/cadence display, forms.
- Scheduled: web pages/scheduled.tsx + components/scheduled/{scheduled-card,scheduled-form}.tsx
  + lib/hooks/use-scheduled-transactions.ts  vs  iOS .../Views/Scheduled/{ScheduledListView,
  PendingTransactionRow}.swift. Check card/row layout, next-run date, pending state styling.

Match via design tokens. Verify small + large iPhone, light + dark.
```

---

## Prompt 8 — Settings, Login & final parity pass

```
The web app (web/) is the single source of truth for visual design. NEVER modify the web app.
Align the remaining iOS screens, then do a holistic parity sweep.

FOUNDATION CHECK (do this first): ensure the iOS design-token layer exists (Color.appPrimary,
.appCard, .appBorder, .appSuccess, .appDanger, a --radius constant, etc.). If not, create it by
mirroring the @theme + .dark blocks in web/src/styles/globals.css (light + dark) before proceeding.

Compare:
- Settings: web pages/settings.tsx + lib/hooks/use-theme.tsx (theme toggle, default currency,
  default account) vs iOS .../Views/Settings/{SettingsView,CurrencyPickerView}.swift +
  ViewModels/SettingsViewModel.swift. Check section grouping, row styling, theme control,
  default-currency / default-account selectors.
- Login/Auth: web pages/login.tsx + components/auth/auth-guard.tsx vs iOS
  .../Views/Auth/LoginView.swift + ViewModels/AuthViewModel.swift. Check layout, branding,
  field styling, button, error messaging.

Then a FINAL HOLISTIC PASS across the whole iOS app:
- Confirm NO remaining ad-hoc colors (Color.red/.green/.accentColor/.secondary) where a design
  token should be used; replace them.
- Confirm consistent corner radius, spacing, and typography hierarchy app-wide.
- Produce a short "design parity" summary: per screen, Aligned / Minor deltas / Intentional
  native deviation (with reason).

Verify the full app at small (~320pt) and large iPhone widths, in light AND dark mode.
```
