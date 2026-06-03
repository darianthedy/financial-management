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
│   │   ├── account-card.tsx
│   │   └── account-form.tsx
│   ├── budgets/
│   │   ├── budget-card.tsx          # Shows effective amount + carry-over badge
│   │   └── budget-form.tsx          # Includes carry-over toggle
│   └── fixed-expenses/
│       ├── fixed-expense-row.tsx
│       └── fixed-expense-form.tsx
├── lib/
│   ├── supabase/
│   │   └── client.ts               # Browser Supabase client (single file — no server client)
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
| `budget_period_id` | `UUID` | FK → `budget_periods`, nullable |
| `scheduled_txn_id` | `UUID` | FK → `scheduled_transactions`, nullable |
| `fixed_expense_id` | `UUID` | FK → `fixed_expenses`, nullable. Links to a fixed expense to indicate payment. |

**Categories — junction table pattern:**

There is **no** `category_id` column on `transactions`. Categories are linked via a many-to-many junction table:

```typescript
// Link a category to a transaction
await supabase.from("transaction_categories").insert({
  transaction_id: txnId,
  category_id: catId,
});

// Fetch a transaction's categories
const { data } = await supabase
  .from("transaction_categories")
  .select("category_id, categories(name, icon, color)")
  .eq("transaction_id", txnId);
```

The same pattern applies to tags via `transaction_tags`.

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

---

## 7. Page Breakdown & Key Queries

### 7.1 Dashboard

| Widget | Data Source | Query |
|---|---|---|
| Monthly Cash Flow | `v_monthly_cashflow` | `.from("v_monthly_cashflow").select("*").eq("year_month", currentMonth)` |
| Budget Progress | `v_budget_progress` | `.from("v_budget_progress").select("*").eq("year_month", currentMonth)` — includes `effective_amount` (periodic + carry-over), `carry_over_amount`, and `remaining` |
| Spending by Category | `v_spending_by_category` | `.from("v_spending_by_category").select("*").eq("year_month", currentMonth)` |
| Recent Transactions | `transactions` | `.from("transactions").select("*, accounts(name)").order("date", { ascending: false }).limit(10)` |

**Cash Flow Card layout:** Use a vertical stacked layout (one row per metric: Income, Expense, Net) with the label on the left and the formatted amount on the right. Do **not** use a 3-column side-by-side layout — currencies with long symbols (e.g., IDR `Rp1.234.567`) overflow or wrap in narrow viewports. Each amount should use `text-nowrap` with `text-ellipsis` / `overflow-hidden` as a safety net.

### 7.2 Accounts Page

- List all non-archived accounts with their current balance (queried from `account_monthly_balances` — latest `year_month` row per account, or via the `v_account_current_balance` view).
- Clicking an account shows its transactions filtered by `account_id`.
- Add/edit account via dialog form.
- Archive (soft-delete) instead of hard-delete.

### 7.3 Transactions Page

- Filterable list: by date range, type, account, category, status.
- Inline confirm/dismiss for pending transactions.
- "Add Transaction" form with:
  - Type selector (income/expense/transfer)
  - Account picker (+ transfer destination if transfer)
  - Amount + currency
  - Date picker
  - Category multi-select
  - Tag multi-select (autocomplete + create)
  - Budget picker (expense only) — loads active `budget_periods` for the transaction's month, displays budget name + effective amount. Selection stored as `budget_period_id`. Cleared when type is not `expense`.
  - Fixed expense picker (expense only) — loads `fixed_expenses` for the transaction's month (filtered by `year_month`). Selection stored as `fixed_expense_id`. Linking a transaction indicates the fixed expense is paid. Cleared when type is not `expense`.
  - Description

### 7.4 Budgets Page

- Current month's budgets with progress bars showing **effective amount** (periodic + carry-over).
- If carry-over is active, display the carry-over amount as a label (e.g., "+$10 carried over" or "-$20 overspent").
- Month navigator (prev / next). On mobile/touch viewports, support swipe left/right to navigate months.
- Add budget → creates header + current month's period entry. Toggle to enable/disable carry-over.
- Edit periodic amount for any month.
- Deactivate budget (stops generating future period entries).
- When creating a new month's period for a carry-over-enabled budget, the app computes `carry_over_amount` from the previous period's remaining and stores it on the new row.

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
