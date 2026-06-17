# Financial Management — Technical Plan: Web Application

> Covers: Vite + React SPA project setup, folder structure, Supabase client integration, authentication, data layer, pages, and deployment via GitHub Pages.
>
> **Hosting & deployment details** (GitHub repo setup, GitHub Actions workflow, PWA configuration) are in the companion document: *Financial Management — Tech Plan: GitHub Pages Hosting*.

---

## 1. Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Node.js | >= 18 | Build toolchain & dev server |
| pnpm | latest | Package manager |
| Supabase CLI | >= 1.x | Local Supabase for development |
| Git | >= 2.x | Version control |

---

## 2. Project Setup

### 2.1 Scaffold the Project

```bash
pnpm create vite financial-management-web -- --template react-ts

cd financial-management-web
```

### 2.2 Install Dependencies

```bash
# Supabase client (browser-only — no SSR package needed)
pnpm add @supabase/supabase-js

# Routing
pnpm add react-router-dom

# UI & charting
pnpm add @radix-ui/react-dialog @radix-ui/react-dropdown-menu @radix-ui/react-popover
pnpm add @radix-ui/react-progress @radix-ui/react-select @radix-ui/react-tabs
pnpm add class-variance-authority clsx tailwind-merge lucide-react
pnpm add recharts date-fns

# Forms & validation
pnpm add react-hook-form @hookform/resolvers zod

# Tailwind CSS
pnpm add -D tailwindcss @tailwindcss/vite

# Dev
pnpm add -D @types/node
```

### 2.3 Environment Variables

Create `.env.local`:

```
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_ANON_KEY=<local-anon-key>
```

For production, these are injected at build time via GitHub Actions secrets (see the GitHub Pages Hosting tech plan).

---

## 3. Project Structure

```
src/
├── main.tsx                         # Entry point — renders <App />
├── App.tsx                          # Router setup (BrowserRouter + routes)
├── pages/
│   ├── login.tsx                    # Login page
│   ├── dashboard.tsx                # Dashboard
│   ├── accounts.tsx                 # Account list
│   ├── account-detail.tsx           # Account detail + transactions
│   ├── transactions.tsx             # Transaction list (filterable)
│   ├── transaction-form.tsx         # Add/edit transaction
│   ├── budgets.tsx                  # Budget list + progress
│   ├── budget-detail.tsx            # Budget detail by month
│   ├── fixed-expenses.tsx           # Fixed expense list by month
│   ├── scheduled.tsx                # Scheduled transactions + pending
│   └── settings.tsx                 # Default currency picker + preferences
├── components/
│   ├── ui/                          # Reusable primitives (Button, Card, Input, Dialog...)
│   ├── layout/
│   │   ├── app-layout.tsx           # Authenticated layout: sidebar + header + <Outlet />
│   │   ├── sidebar.tsx
│   │   ├── header.tsx
│   │   └── mobile-nav.tsx
│   ├── auth/
│   │   └── auth-guard.tsx           # Redirects to /login if not authenticated
│   ├── dashboard/
│   │   ├── cashflow-card.tsx
│   │   ├── budget-progress-card.tsx
│   │   ├── spending-by-category.tsx
│   │   └── recent-transactions.tsx
│   ├── transactions/
│   │   ├── transaction-form.tsx
│   │   ├── transaction-list.tsx
│   │   └── transaction-row.tsx
│   ├── accounts/
│   │   ├── account-avatar.tsx        # Circular avatar: uploaded image, else type icon
│   │   ├── account-card.tsx
│   │   └── account-form.tsx          # Includes the avatar upload/remove control
│   ├── budgets/
│   │   ├── budget-card.tsx          # Shows effective amount + carry-over badge (from v_budget_progress)
│   │   └── budget-form.tsx          # Name, monthly amount, note (no carry-over toggle)
│   └── fixed-expenses/
│       ├── fixed-expense-row.tsx
│       └── fixed-expense-form.tsx
├── lib/
│   ├── supabase/
│   │   └── client.ts               # Browser Supabase client (single file — no server client)
│   ├── storage/
│   │   └── account-images.ts       # Resize→WebP upload + best-effort delete (account-images bucket)
│   ├── types/
│   │   └── database.ts             # Generated Supabase types
│   ├── utils/
│   │   ├── currency.ts             # bigint ↔ display conversion
│   │   ├── date.ts                 # year_month helpers
│   │   └── cn.ts                   # clsx + tailwind-merge
│   ├── hooks/
│   │   ├── use-auth.ts             # Auth state hook (session, user, loading)
│   │   ├── use-accounts.ts
│   │   ├── use-transactions.ts
│   │   ├── use-budgets.ts
│   │   ├── use-fixed-expenses.ts
│   │   ├── use-scheduled-transactions.ts
│   │   ├── use-currencies.ts       # Fetch currencies table + user settings
│   │   └── use-realtime.ts         # Generic Realtime subscription hook
│   └── validations/
│       ├── account.ts              # Zod schemas
│       ├── transaction.ts
│       ├── budget.ts
│       └── fixed-expense.ts
├── styles/
│   └── globals.css
├── index.html                       # Vite entry HTML (lives at project root)
└── vite.config.ts
```

---

## 4. Supabase Client Setup

### 4.1 Browser Client (`lib/supabase/client.ts`)

Single client module — there is no server-side client in a static SPA:

```typescript
import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/types/database";

export const supabase = createSupabaseClient<Database>(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);
```

### 4.2 Auth Guard (`components/auth/auth-guard.tsx`)

Replaces Next.js middleware. Wraps authenticated routes and redirects to `/login` if the user has no active session:

```typescript
import { useEffect, useState } from "react";
import { Navigate, Outlet } from "react-router-dom";
import { supabase } from "@/lib/supabase/client";
import type { Session } from "@supabase/supabase-js";

export function AuthGuard() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, session) => setSession(session)
    );

    return () => subscription.unsubscribe();
  }, []);

  if (loading) return null; // or a loading spinner

  if (!session) return <Navigate to="/login" replace />;

  return <Outlet />;
}
```

### 4.3 Router Setup (`App.tsx`)

```typescript
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthGuard } from "@/components/auth/auth-guard";
import { AppLayout } from "@/components/layout/app-layout";
import LoginPage from "@/pages/login";
import DashboardPage from "@/pages/dashboard";
import AccountsPage from "@/pages/accounts";
import AccountDetailPage from "@/pages/account-detail";
import TransactionsPage from "@/pages/transactions";
import TransactionFormPage from "@/pages/transaction-form";
import BudgetsPage from "@/pages/budgets";
import BudgetDetailPage from "@/pages/budget-detail";
import FixedExpensesPage from "@/pages/fixed-expenses";
import ScheduledPage from "@/pages/scheduled";
import SettingsPage from "@/pages/settings";

const basename = import.meta.env.BASE_URL;

export default function App() {
  return (
    <BrowserRouter basename={basename}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />

        <Route element={<AuthGuard />}>
          <Route element={<AppLayout />}>
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/accounts" element={<AccountsPage />} />
            <Route path="/accounts/:id" element={<AccountDetailPage />} />
            <Route path="/transactions" element={<TransactionsPage />} />
            <Route path="/transactions/new" element={<TransactionFormPage />} />
            <Route path="/budgets" element={<BudgetsPage />} />
            <Route path="/budgets/:id" element={<BudgetDetailPage />} />
            <Route path="/fixed-expenses" element={<FixedExpensesPage />} />
            <Route path="/scheduled" element={<ScheduledPage />} />
            <Route path="/settings" element={<SettingsPage />} />
          </Route>
        </Route>

        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
```

`import.meta.env.BASE_URL` is automatically set by Vite from the `base` option in `vite.config.ts`, so routes work correctly on GitHub Pages subpaths without hardcoding.

### 4.4 Generate TypeScript Types

```bash
supabase gen types typescript --linked > src/lib/types/database.ts
```

Re-run this whenever the schema changes.

---

## 5. Authentication Flow

### 5.1 Login Page (`pages/login.tsx`)

Single-user app, so only email/password sign-in:

```typescript
import { supabase } from "@/lib/supabase/client";
import { useNavigate } from "react-router-dom";
import { useState } from "react";

export default function LoginPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      setError(error.message);
    } else {
      navigate("/dashboard", { replace: true });
    }
  }

  // ... render form
}
```

### 5.2 Sign Out

```typescript
await supabase.auth.signOut();
navigate("/login");
```

---

## 6. Data Layer Pattern

All data access follows a consistent pattern using custom hooks that wrap Supabase queries and Realtime subscriptions.

### 6.1 Example: `use-accounts.ts`

```typescript
import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Database } from "@/lib/types/database";

type Account = Database["public"]["Tables"]["accounts"]["Row"];

export function useAccounts() {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from("accounts")
      .select("*")
      .eq("is_archived", false)
      .order("created_at", { ascending: true });
    setAccounts(data ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetch();

    const channel = supabase
      .channel("accounts-changes")
      .on("postgres_changes", { event: "*", schema: "public", table: "accounts" }, () => {
        fetch();
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [fetch]);

  return { accounts, loading, refetch: fetch };
}
```

### 6.2 Currency Utility (`lib/utils/currency.ts`)

```typescript
export function toMinorUnits(amount: number, decimalPlaces = 2): number {
  const factor = Math.pow(10, decimalPlaces);
  return Math.round(amount * factor);
}

export function toDisplayAmount(minorUnits: number, decimalPlaces = 2): number {
  const factor = Math.pow(10, decimalPlaces);
  return minorUnits / factor;
}

export function formatCurrency(minorUnits: number, currency = "USD", decimalPlaces = 2): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency,
    minimumFractionDigits: decimalPlaces,
    maximumFractionDigits: decimalPlaces,
  }).format(toDisplayAmount(minorUnits, decimalPlaces));
}
```

### 6.3 Currencies Hook (`lib/hooks/use-currencies.ts`)

```typescript
import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Database } from "@/lib/types/database";

type Currency = Database["public"]["Tables"]["currencies"]["Row"];
type UserSettings = Database["public"]["Tables"]["user_settings"]["Row"];

export function useCurrencies() {
  const [currencies, setCurrencies] = useState<Currency[]>([]);
  const [userSettings, setUserSettings] = useState<UserSettings | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchCurrencies = useCallback(async () => {
    const { data } = await supabase
      .from("currencies")
      .select("*")
      .order("code");
    setCurrencies(data ?? []);
  }, []);

  const fetchSettings = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    const { data } = await supabase
      .from("user_settings")
      .select("*")
      .eq("user_id", user.id)
      .maybeSingle();
    setUserSettings(data);
  }, []);

  useEffect(() => {
    Promise.all([fetchCurrencies(), fetchSettings()]).then(() => setLoading(false));
  }, [fetchCurrencies, fetchSettings]);

  const updateDefaultCurrency = useCallback(async (currencyCode: string) => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    const { data } = await supabase
      .from("user_settings")
      .upsert({ user_id: user.id, default_currency: currencyCode })
      .select()
      .single();
    if (data) setUserSettings(data);
  }, []);

  const defaultCurrency = userSettings?.default_currency ?? "USD";

  return { currencies, defaultCurrency, loading, updateDefaultCurrency, refetch: fetchSettings };
}
```

### 6.3 Year-Month Utility (`lib/utils/date.ts`)

```typescript
import { format, parse, addMonths, subMonths } from "date-fns";

export function getCurrentYearMonth(): string {
  return format(new Date(), "yyyy-MM");
}

export function navigateMonth(yearMonth: string, offset: number): string {
  const date = parse(yearMonth, "yyyy-MM", new Date());
  const target = offset > 0 ? addMonths(date, offset) : subMonths(date, Math.abs(offset));
  return format(target, "yyyy-MM");
}

export function formatYearMonth(yearMonth: string): string {
  const date = parse(yearMonth, "yyyy-MM", new Date());
  return format(date, "MMMM yyyy");
}
```

### 6.5 Key Schema Notes

While TypeScript types are auto-generated from the database schema (see section 4.4), developers must be aware of these column names and relationships when writing queries:

**`transactions` table — column names to note:**

| Column | Type | Notes |
|---|---|---|
| `date` | `DATE` | **Not** `transaction_date` |
| `transfer_account_id` | `UUID` | **Not** `to_account_id`. Required when `type = 'transfer'` |
| `status` | `transaction_status` | `'confirmed'` \| `'pending'` \| `'dismissed'`. Default `'confirmed'` |
| `budget_id` | `UUID` | FK → `budgets`, nullable. Set via the budget dropdown (income/expense only) |
| `category_id` | `UUID` | FK → `categories`, nullable. **Single** category, set via the category combobox (income/expense only) |
| `scheduled_txn_id` | `UUID` | FK → `scheduled_transactions`, nullable |
| `fixed_expense_id` | `UUID` | FK → `fixed_expenses`, nullable. Links to a fixed expense to indicate payment. |

**Categories — single column; Tags — junction table:**

A transaction has **at most one** category, stored directly in `transactions.category_id` (set or cleared like any other column — there is no junction table for categories):

```typescript
// Set (or clear) a transaction's category
await supabase
  .from("transactions")
  .update({ category_id: catId ?? null })
  .eq("id", txnId);

// Categories are read back via the column; hydrate the row with a lookup map
// (id → category) rather than an embedded join.
```

Tags remain **many-to-many** via the `transaction_tags` junction:

```typescript
// Link a tag to a transaction
await supabase.from("transaction_tags").insert({ transaction_id: txnId, tag_id: tagId });

// Fetch a transaction's tags
const { data } = await supabase
  .from("transaction_tags")
  .select("tag_id, tags(name)")
  .eq("transaction_id", txnId);
```

**`categories` table:**

| Column | Type | Notes |
|---|---|---|
| `name` | `TEXT` | Unique per user |
| `icon` | `TEXT` | Nullable emoji or icon identifier |
| `color` | `TEXT` | Nullable hex color |

> There is no `type` column on `categories`.

**`scheduled_transactions` table — column names to note:**

| Column | Type | Notes |
|---|---|---|
| `recurrence` | `recurrence_type` | **Not** `recurrence_interval`. Only `'monthly'` for P0 |
| `next_due_date` | `DATE` | **Not** `next_occurrence` |

> There is no separate `pending_transactions` table. Pending transactions are rows in `transactions` where `status = 'pending'`.

**`fixed_expenses` table:**

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` | Primary key |
| `user_id` | `UUID` | FK → `auth.users` |
| `name` | `TEXT` | Display name |
| `year_month` | `TEXT` | `'YYYY-MM'` format |
| `amount` | `BIGINT` | Minor units |
| `currency` | `TEXT` | ISO 4217 code |
| `due_day` | `SMALLINT` | 1–31 |
| `is_active` | `BOOLEAN` | Default `true` |

> Each row is one fixed expense for one specific month. Paid status is derived from linked transactions — a fixed expense is considered paid when at least one `transactions` row references it via `fixed_expense_id`.

**`budget_installments` / `budget_installment_allocations` tables (P1 — Budget Installments, see §7.8):**

| Table | Key columns | Notes |
|---|---|---|
| `budget_installments` | `source_transaction_id` (FK → `transactions`, `ON DELETE CASCADE`), `total_amount`, `start_year_month`, `months` | One header per spread expense. |
| `budget_installment_allocations` | `installment_id` (FK, `ON DELETE CASCADE`), `budget_name`, `year_month`, `amount` | One row per non-zero grid cell. Targets a budget **lineage by name**, not a budget `id`. `UNIQUE(installment_id, budget_name, year_month)`. |

> Reservations are **budget-side only** — they never appear in `transactions` and never affect account balances or cash flow. `v_budget_progress` exposes a `reserved` column and its `remaining` already subtracts it (`periodic + carry_in − spent − reserved`). The source expense itself has `budget_id = null`.

---

## 7. Page Breakdown & Key Queries

### 7.1 Dashboard

The dashboard is **month-scoped**: a header month navigator (`ChevronLeft` / `ChevronRight` around the formatted month, defaulting to the current month) drives every widget, plus a "Transactions" button that opens the Transactions page pre-filtered to the shown month's date bounds (`from`/`to` query params). All reads run for the selected `year_month` inside a single `useDashboard(yearMonth)` hook (`lib/hooks/use-dashboard.ts`), which fetches them in parallel and re-runs on realtime `postgres_changes` to `transactions`, `budgets`, `fixed_expenses`, `accounts`, and `account_monthly_balances`.

| Widget | Component | Data Source | Query |
|---|---|---|---|
| Budget Verdict | `dashboard/verdict-banner.tsx` | `v_budget_progress` | `.from("v_budget_progress").select("*").eq("year_month", yearMonth)` — banner counts budgets with `remaining < 0` and sums the overage; on-track (green) vs. over (red). Hidden when there are no budgets. |
| Accounts | `dashboard/accounts-card.tsx` | `accounts` + `fn_account_balances_at` RPC | `.from("accounts").select("*").eq("is_archived", false).eq("show_on_dashboard", true)` joined with `.rpc("fn_account_balances_at", { p_year_month: yearMonth })` (latest balance at or before the month per account). Accounts with no ledger row fall back to `starting_balance`. Shows each balance + the combined total in the default currency. |
| Planned Expenses | `dashboard/planned-expenses.tsx` | `v_budget_progress` + `fixed_expenses` | Budgets reuse the `v_budget_progress` query above for pace-aware bars (fill colored by **projected** month-end using elapsed-month fraction, with a tick at linear pace mid-month); fixed expenses come from `.from("fixed_expenses").eq("year_month", yearMonth)`, split into Unpaid / Paid with subtotals. Paid status is derived from linked `transactions` (`fixed_expense_id`). Headline = Σ budget `effective_amount` + Σ fixed-expense `amount`. |
| Unplanned Expenses | `dashboard/unplanned-expenses.tsx` | `transactions` | `.from("transactions").select("category_id, amount").eq("type", "expense").eq("status", "confirmed").is("budget_id", null).is("fixed_expense_id", null).gte("date", start).lt("date", endExclusive)` — aggregated by category in the hook (null category → "Uncategorized"), sorted by amount desc. Category metadata (`icon`, `color`, `name`) is fetched in a follow-up `categories` query for the ids present. |

**Budget bar pacing:** `monthElapsedFraction(yearMonth)` gives how far through the month we are. For the in-progress month the fill is red when projected month-end spend (`spent / fractionElapsed`) exceeds `effective_amount`, and a tick marks linear pace; the marker is hidden at fraction 0 (future) or 1 (past), where the bar falls back to actual over/under.

**Currency:** all amounts render in the default currency via `formatCurrency` (the app is single-currency); the `v_monthly_cashflow`, `v_spending_by_category`, and `v_account_current_balance` views are not read by this layout.

### 7.2 Accounts Page

- List all non-archived accounts with their current balance (queried from `account_monthly_balances` — latest `year_month` row per account, or via the `v_account_current_balance` view).
- Clicking an account shows its transactions filtered by `account_id`.
- Add/edit account via dialog form.
- Archive (soft-delete) instead of hard-delete.
- **Account avatar:** each card (and the detail header) shows the account's uploaded image via the shared `AccountAvatar`, falling back to a type-based icon when `image_url` is null. The form's upload control stages the picked file locally (object-URL preview) and uploads to the `account-images` bucket on submit through `lib/storage/account-images.ts` — see System Design §4.10. The image is downsized to ≤256px WebP client-side; the replaced/removed object is deleted best-effort after the row save succeeds.
- **Avatars reuse the image elsewhere:** the transaction row (`transaction-display.tsx`) shows the linked account's logo when present — keeping the transaction-direction badge — and falls back to colored initials otherwise, so `use-transactions` selects `image_url` and carries it through to the row's `accounts` shape. The dashboard's Accounts card (`use-dashboard` selects the full `accounts` row) renders the same `AccountAvatar`.

### 7.3 Transactions Page

- Inline confirm/dismiss for pending transactions.
- **Filter & Search** (see §7.3.1 below).
- "Add Transaction" form with:
  - Type selector (income/expense/transfer)
  - Account picker (+ transfer destination if transfer)
  - Amount (single-currency; income/expense may be negative — e.g. a refund as a negative expense — while transfers are forced positive and zero is rejected, per `transactionFormSchema`)
  - Date picker
  - Category single-select (autocomplete + create; at most one per transaction)
  - Tag multi-select (autocomplete + create)
  - Budget picker (income & expense; hidden for transfers) — loads `budgets` for the transaction's month, displaying budget name + effective amount (from `v_budget_progress`). Selection stored as `budget_id`. Offers an inline "create budget for this month" option when none exists. Cleared when type is `transfer`.
  - Fixed expense picker (expense only) — loads `fixed_expenses` for the transaction's month (filtered by `year_month`). Selection stored as `fixed_expense_id`. Linking a transaction indicates the fixed expense is paid. Cleared when type is not `expense`.
  - Description

#### 7.3.1 Filter & Search

The transaction list can be narrowed by any combination of filters. The query strategy (reading from `v_transactions`, the SQL-side tag array, the budget/fixed-by-name resolution, and the AND-across / OR-within semantics) is defined in the System Design doc §4.9; this section covers the web implementation.

Every facet except search, date, and amount is an **Excel-style multi-select** (`MultiSelect`) and is **tri-state**: absent = no filter, a non-empty set matches any selected value, and a present-but-empty set matches nothing. The category, tag, budget, and fixed facets lead their option list with a `(Blanks)` row (`NO_VALUE`, labelled "No category / No tags / No budget / No fixed expense") to match rows with no value for that facet.

**Filters**

| Filter | Control | State shape |
|---|---|---|
| Search | Always-visible text input (debounced ~300ms) | `search?: string` |
| Type | Multi-select (income / expense / transfer) | `types?: TransactionType[]` |
| Account | Multi-select (each account; matches the source or transfer side) | `accountIds?: string[]` |
| Status | Multi-select (confirmed / pending / dismissed) | `statuses?: TransactionStatus[]` |
| Date range | From/to date inputs + preset buttons (This month, Last month, Last 3 months, This year, All time) | `dateFrom?`, `dateTo?` |
| Categories | Multi-select (+ "No category"); matches if the one category is any selected | `categoryIds?: string[]` |
| Tags | Multi-select (+ "No tags") | `tagIds?: string[]` |
| Amount range | Two `CurrencyAmountInput`s (min/max). Stored in **minor units**; the widget shows major units using the default currency's decimals | `amountMin?`, `amountMax?` |
| Budget | Multi-select of budget **names** (+ "No budget"). Options come from `v_budget_progress` (distinct `budget_name`), scoped to the active date range's months; selected names stay listed even if the range no longer lists them | `budgetNames?: string[]` |
| Fixed expense | Multi-select of fixed-expense **names** (+ "No fixed expense"), mirroring the budget filter; options from `fixed_expenses` | `fixedExpenseNames?: string[]` |

**Budget & fixed-expense filter semantics** (see System Design §4.9): selecting budget/fixed **names** resolves to the set of `budget_id`s / `fixed_expense_id`s for those names — budgets via `v_budget_progress`, fixed expenses via `fixed_expenses` — narrowed to the date range's months when a date filter is set (otherwise all periods). Transactions are then matched with `in('budget_id', ids)` / `in('fixed_expense_id', ids)`, OR-ed with the `(Blanks)` option (`…is.null`) when chosen. The transaction `date` filter still applies independently. `resolveBudgetIds` reads `v_budget_progress` — **not** the `budgets` table — so the budget filter stays consistent with the Budgets page and the transaction budget picker (the raw table is RLS-scoped differently from the view the rest of the app reads). `resolveRestrictions` performs these lookups once and feeds the shared `applyFilters` used by both the list and Summary queries.

**UI layout**

- The search input stays visible in the bar. A **"Filters" button** (with an active-count badge) opens a panel holding the remaining controls — a Radix **Popover** on desktop and a full-height **sheet/Dialog** on mobile (the existing PWA-first pattern).
- **Active filters render as removable chips** below the bar (e.g. `Expense ✕`, `Food, Travel ✕`, `≥ $50 ✕`), plus a **"Clear all"** button and a **count of matching transactions**.
- Empty state when no transactions match the active filters.

**URL synchronization**

Filters are the **single source of truth in the URL query string** via `react-router`'s `useSearchParams` (no `useState` mirror, no cross-session persistence). This makes filtered views shareable/bookmarkable and survives reload while resetting on a fresh navigation to `/transactions`.

- Serialize each present filter to a param: `?type=expense&from=2026-06-01&to=2026-06-30&cat=<id>,<id>&tag=<id>&amtMin=5000&search=coffee&budget=Food,Rent&fixed=Netflix`. Every multi-select is a comma-joined value list (`budget`/`fixed` carry **names**; the others carry ids/enum values). A present-but-empty facet round-trips as `key=` ("none selected"); only absent facets are omitted.
- A small `parseFilters(searchParams)` / `serializeFilters(filters)` pair (in `lib/utils/transaction-filters.ts`) converts between the URL and the `TransactionFilters` object. Amount params are **minor-unit** integers in the URL (parse/serialize stay currency-decimal-agnostic); only the amount input widget converts to/from major units for display.
- The page also keeps the **pager** in the URL alongside the filters: `page` (1-based, omitted on page 1) and `size` (omitted at the default of 25; options 25/50/100/200). Changing a filter resets to page 1 but preserves the size; the list query is windowed with `.range()` and `count: 'exact'`, so the pager's "x–y of N" reflects the full filtered count.

**Hook changes (`use-transactions.ts`)**

`TransactionFilters` carries every facet and `fetch` reads from `v_transactions`:

- Column-level operators for `search` (`.ilike`), `amountMin`/`amountMax` (`.gte`/`.lte` on `amount`, in minor units), `types`/`statuses` (`.in`), `accountIds` (`.or` over both account columns), and `categoryIds` (`.or` of `category_id.in.(…)` and, for `(Blanks)`, `category_id.is.null`).
- `tagIds` filters **in SQL** via the view's `tag_ids` array — `.or('tag_ids.ov.{ids},tag_ids.eq.{}')` (overlap for chosen tags, empty-array for "untagged") — so no junction pre-query is needed and pagination stays accurate.
- `budgetNames`/`fixedExpenseNames` are resolved to id lists by `resolveRestrictions` (see §4.9) and applied as a shared `.or(…)` clause; a chosen-but-unresolved facet short-circuits to an empty result.
- A stable serialization of each array facet is added to the `useCallback` dependency array so the list refetches when any filter changes. The `useTransactions(filters, { page, pageSize })` overload windows the query; omitting `page` fetches the whole set (used by the scheduled page).

**Summary**

A "Summary" dialog calls `fetchTransactionSummaryRows(filters)` — the same `applyFilters` against `v_transactions` but selecting only the money/grouping columns for the **whole filtered set** (all pages), fetched on demand when opened. `TransactionSummary` reduces it to income / expense / net / transfers in-out / count / largest expense plus collapsible breakdowns by account, category, budget, fixed expense, and tag (confirmed rows only; pending shown as a separate projection, dismissed excluded).

**Supporting data**

The filter panel needs the lists of accounts (`useAccounts`), categories & tags (`fetchCategories`/`fetchTags`), and budgets (`useBudgets`) to populate its selectors.

### 7.4 Budgets Page

- Current month's budgets with progress bars showing **net spent** vs. **effective amount** (periodic + carry-in), read from `v_budget_progress`.
- Display the carry-in and the optional note in a per-card info popover (shown only when the carry-in is non-zero or a note exists), e.g. "+$10 carried over" / "−$20 overspent". Carry-over is always on; there is no toggle.
- Clicking a budget card opens the Transactions list filtered to that budget's **name** and scoped to the budget's own month (so it shows the spend the card's bar reflects).
- Overspent budgets (`remaining < 0`) render the bar and the "$X over" label in the danger color.
- Month navigator (prev / next). On mobile/touch viewports, support swipe left/right to navigate months.
- Add budget → inserts a single `budgets` row for the selected month (`name`, `periodic_amount`, optional `description`). Identity is **name** (the app is single-currency, so budgets carry no per-row currency). There is no header record.
- Edit `periodic_amount`, `name`, or the note for the selected month only — past months are untouched, but because carry-over is computed live, editing an earlier month re-flows every later month in the lineage.
- "Remove" a budget for a month = delete that month's row. Future months stop being created; a deliberate gap resets that lineage's carry-over to 0.
- **Copy from Previous Month:** copies every budget from the previous month into the current month (same `name`, `description`, `periodic_amount`), skipping names that already exist for the current month.
- No carry-over is stored or precomputed — `v_budget_progress` derives it on read by chaining each `(name)` lineage across consecutive months.

### 7.5 Fixed Expenses Page

- Current month's fixed expenses with paid/unpaid status. Paid status is derived: a fixed expense is considered paid when at least one transaction references it via `fixed_expense_id`.
- Month navigator. On mobile/touch viewports, support swipe left/right to navigate months.
- To mark a fixed expense as paid, the user creates (or edits) a transaction and links it to the fixed expense. There is no standalone "mark as paid" toggle.
- **Copy from Previous Month:** Button that copies all fixed expenses from the previous month into the current month (same `name`, `amount`, `currency`, `due_day`, `is_active`). Skips expenses that already exist for the current month.
- **Edit:** Edit individual fixed expenses — update `name`, `amount`, or `due_day` for the selected month only.
- **Delete:** Remove an individual fixed expense for the selected month. Does not affect other months.
- Add new fixed expenses for the current month.

### 7.6 Settings Page

- Default currency picker — searchable dropdown populated from the `currencies` table.
- On change, upserts `user_settings` with the new `default_currency`.
- All forms (new account, new transaction, etc.) read the default currency from `user_settings` as the initial value.

### 7.7 Scheduled Transactions Page

- List of active scheduled transactions with next due date.
- Section for pending transactions awaiting confirmation.
- Confirm / edit / dismiss actions on pending items.

### 7.8 Budget Installments (P1) — Spread an Expense Across Budgets

Lets a large expense be absorbed gradually by reserving future budget allowance. The account is debited in full immediately; only the **budgets** shown for future months shrink. See requirements doc → "Budget Installments" and System Design §4.11 for the model.

**Where it lives.** An optional **"Spread across budgets"** toggle on the **expense** transaction form (income/transfer excluded). When enabled, the form reveals the installment builder:

1. **Start month** — segmented control: *This month* / *Next month*.
2. **Budgets** — multi-select of budget **names** (lineages). Source the candidate names from `fetchBudgetNames()` / `v_budget_progress` (the same names the Budgets page shows).
3. **Months** — number stepper (consecutive months from the start month).
4. **Allocation grid** — a budgets × months matrix of currency inputs, **pre-filled with an even split**: each cell = `floor(total / (budgets * months))` minor units, with the rounding remainder dropped into one cell so the grid sums exactly to the expense amount. The header shows a live **total reserved** and **remaining to allocate**; **Save is disabled until the grid total equals the expense amount.**
   - Editing the budget set or month count **re-runs the even pre-fill** (grid shape changed). A **"Split evenly"** button re-applies it on demand. Editing a cell never changes the shape; cells may be set to `0` to skip a budget that month.

**On submit (single logical operation — wrap in one RPC for atomicity):**

1. Insert the expense `transactions` row as usual, with `budget_id = null` (the spread, not this row, accounts for the budget impact).
2. For each distinct cell budget+month, **ensure the budget row exists** — `insert … on conflict (user_id, name, year_month) do nothing`, defaulting `periodic_amount` to the latest known value in that lineage (else 0). This keeps carry-over lineages unbroken.
3. Insert one `budget_installments` header (`source_transaction_id`, `total_amount`, `start_year_month`, `months`).
4. Bulk-insert one `budget_installment_allocations` row per **non-zero** cell (`budget_name`, `year_month`, `amount`).

> A Postgres RPC (`create_budget_installment`) is the clean home for steps 1–4 so the expense and its reservations commit together. The client builds the grid; the RPC persists it.

**Budgets page (§7.4) changes.** `v_budget_progress` now returns a `reserved` column and `remaining` already nets it out. Each budget card:

- shows a **"Reserved $X"** line when `reserved > 0` (e.g. "−$300 installment"), distinct from the carry-over label;
- renders **negative `remaining`** gracefully (reservations can exceed the month's room — the intended "spend nothing" signal);
- a tooltip/expander can list the source installment(s).

**Managing installments.** A lightweight list (e.g. under the Budgets page or Settings) of active installments with their source expense, total, span, and a **Cancel** action that deletes the `budget_installments` row (cascades to allocations; future budgets recover their allowance). Deleting the source transaction cancels the installment automatically (`ON DELETE CASCADE`).

**Hooks.** Add `use-installments.ts` (create via the RPC, list, cancel). The existing `useBudgets` realtime channel should also subscribe to `budget_installment_allocations` changes so reserved amounts refresh live, alongside the current `budgets` / `transactions` subscriptions.

---

## 8. UI & Styling

| Concern | Choice |
|---|---|
| CSS framework | Tailwind CSS (via `@tailwindcss/vite` plugin) |
| Component primitives | Radix UI (unstyled, accessible) |
| Icons | Lucide React |
| Charts | Recharts (for cash flow bar chart, spending pie/donut chart) |
| Responsive | Mobile-first; sidebar collapses to bottom nav on small screens |
| Dark mode | Tailwind `dark:` variant, toggled via `class` strategy on `<html>` |

### 8.1 Month Navigation — Swipe + Page Animation

All pages with a month navigator (Dashboard, Transactions, Budgets, Fixed Expenses) should support **swipe left / right to navigate months** on touch devices. Use pointer/touch event listeners (or a lightweight library like `use-gesture`) to detect horizontal swipe gestures on the page content area. Require the horizontal distance to exceed the vertical distance to avoid conflicting with vertical scrolling.

**Page transition animation:** When the month changes, the content area below the month navigator should perform a horizontal slide transition (CSS `transform: translateX` with `transition` or Framer Motion `AnimatePresence` with `slide` variants). The old month slides out in one direction and the new month slides in from the opposite direction, producing a pagination-like effect.

**Adjacent-month prefetching:** Each page's data hook should cache fetched month data in-memory (e.g., a `useRef<Map<string, Data>>()`). After loading the current month, prefetch `yearMonth - 1` and `yearMonth + 1` in the background. On navigation, if cached data exists, display it immediately (skip loading spinner) for an instant transition. Always re-fetch fresh data after displaying the cache to keep it current.

---

## 9. Deployment

The app is deployed as static files to **GitHub Pages** (free, even for private repos). Pushing to `main` triggers a GitHub Actions workflow that builds the Vite app and deploys the `dist/` output.

For full setup instructions — repository creation, GitHub Actions workflow, secrets configuration, PWA setup, and custom domain — see the companion document: ***Financial Management — Tech Plan: GitHub Pages Hosting***.

### 9.1 Quick Reference

```bash
# Build locally (for testing)
pnpm build

# Deploy — just push to main
git push origin main
# GitHub Actions builds & deploys automatically

# Site URL
# https://<username>.github.io/financial-management-web/
```

---

## 10. Development Workflow

```bash
# Terminal 1: Supabase local
cd ../financial-management
supabase start

# Terminal 2: Vite dev server
cd financial-management-web
pnpm dev
# → http://localhost:5173

# Regenerate types after schema changes
supabase gen types typescript --linked > src/lib/types/database.ts
```

---

## 11. Testing Strategy

| Layer | Tool | What to Test |
|---|---|---|
| Unit | Vitest | Currency utils, date utils, Zod schemas |
| Component | Vitest + Testing Library + jsdom | Form components, dashboard widgets |
| E2E | Playwright | Full login → create account → add transaction → verify dashboard |
| API / DB | Supabase local + pgTAP | RLS policies, trigger correctness |

```bash
pnpm add -D vitest @testing-library/react @testing-library/jest-dom jsdom playwright
```
