# Financial Management — Technical Plan: Supabase

> Covers: project creation, database migrations, Row-Level Security, Edge Functions, cron jobs, Realtime, and environment configuration.

---

## 1. Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| [Supabase CLI](https://supabase.com/docs/guides/cli) | >= 1.x | Local dev, migrations, Edge Function deployment |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | latest | Required by `supabase start` for local Postgres |
| [Deno](https://deno.land/) | >= 1.40 | Edge Function runtime |
| Node.js | >= 18 | Only for seed scripts / tooling (optional) |

Install the CLI:

```bash
# macOS
brew install supabase/tap/supabase

# or via npm
npm install -g supabase
```

---

## 2. Project Setup

### 2.1 Create Supabase Project (Cloud)

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard) and create a new project.
2. Note down the following from **Settings → API**:
   - **Project URL** (`https://<project-ref>.supabase.co`)
   - **Anon (public) key** — used by clients
   - **Service role key** — used only by Edge Functions / admin scripts (never expose to clients)
3. Under **Settings → Auth**, configure:
   - Enable **Email/Password** sign-in (disable all other providers for P0).
   - Disable **"Enable email confirmations"** for faster dev iteration (re-enable for production).

### 2.2 Initialize Local Development

```bash
mkdir financial-management && cd financial-management

supabase init
# Creates: supabase/ directory with config.toml
```

Link to your cloud project:

```bash
supabase link --project-ref <your-project-ref>
```

Start local Supabase (Postgres, Auth, PostgREST, Realtime, Storage — all in Docker):

```bash
supabase start
```

This prints local URLs and keys. Save them in `.env.local` for client apps:

```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=<local-anon-key>
SUPABASE_SERVICE_ROLE_KEY=<local-service-role-key>
```

---

## 3. Database Migrations

Supabase manages schema changes through sequential SQL migration files in `supabase/migrations/`.

### 3.1 Migration File Structure

```
supabase/
├── config.toml
├── migrations/
│   ├── 20260509000001_create_enums.sql
│   ├── 20260509000002_create_currencies.sql
│   ├── 20260509000003_create_user_settings.sql
│   ├── 20260509000004_create_accounts.sql
│   ├── 20260509000004b_create_account_monthly_balances.sql
│   ├── 20260509000005_create_categories_tags.sql
│   ├── 20260509000006_create_budgets.sql
│   ├── 20260509000007_create_fixed_expenses.sql
│   ├── 20260509000008_create_scheduled_transactions.sql
│   ├── 20260509000009_create_transactions.sql
│   ├── 20260509000010_create_junction_tables.sql
│   ├── 20260509000011_enable_rls.sql
│   ├── 20260509000012_create_triggers.sql
│   ├── 20260509000013_create_views.sql
│   ├── 20260509000014_seed_currencies.sql
│   ├── 20260509000015_backfill_monthly_balances.sql
│   └── 20260604000001_restructure_budgets.sql   # forward migration (see §3.8)
├── seed.sql
└── functions/
    └── generate-pending-transactions/
        └── index.ts
```

### 3.2 Creating Migrations

Generate a new migration file:

```bash
supabase migration new create_enums
```

This creates a timestamped file in `supabase/migrations/`. Paste the relevant SQL from the System Design doc into each file.

### 3.3 Migration Contents

Each migration corresponds to a section of the DDL from the System Design doc. Below is the mapping:

**Migration 1 — Enums**

```sql
-- 20260509000001_create_enums.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE account_type AS ENUM (
  'bank_account', 'credit_card', 'digital_wallet', 'cash', 'other'
);

CREATE TYPE transaction_type AS ENUM (
  'income', 'expense', 'transfer'
);

CREATE TYPE transaction_status AS ENUM (
  'confirmed', 'pending', 'dismissed'
);

CREATE TYPE recurrence_type AS ENUM (
  'monthly'
);
```

**Migration 2 — Currencies**

```sql
-- 20260509000002_create_currencies.sql
CREATE TABLE currencies (
  code           TEXT PRIMARY KEY,
  name           TEXT NOT NULL,
  symbol         TEXT NOT NULL DEFAULT '',
  decimal_places SMALLINT NOT NULL DEFAULT 2,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE currencies ENABLE ROW LEVEL SECURITY;

CREATE POLICY policy_currencies_read ON currencies FOR SELECT
  USING (auth.role() = 'authenticated');
```

**Migration 3 — User Settings**

```sql
-- 20260509000003_create_user_settings.sql
CREATE TABLE user_settings (
  user_id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  default_currency TEXT NOT NULL DEFAULT 'USD' REFERENCES currencies(code),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY policy_owner_user_settings ON user_settings FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
```

**Migration 4 — Accounts**

> **Note on Budgets:** The original budgets schema (a `budgets` header + `budget_periods` child, with a stored `carry_over_amount` snapshot and an `enable_carry_over` toggle) has been **superseded**. Budgets are now a single flat table identified by **name**, one row per month, with carry-over always on and computed live in `v_budget_progress`. Because the schema is already deployed, this is delivered as a **forward migration** (`20260604000001_restructure_budgets.sql`, see §3.8), not by editing the original create migration. That restructure originally kept a per-row `currency` column, which the later single-currency migration (`20260606000001_drop_currency_columns.sql`) dropped along with the rest of the per-record currencies; `20260613000001_budget_description.sql` then added the optional `description` note. Refer to the System Design doc for the full target DDL.

```sql
-- 20260509000004_create_accounts.sql
CREATE TABLE accounts (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  type             account_type NOT NULL DEFAULT 'other',
  currency         TEXT NOT NULL DEFAULT 'USD',
  starting_balance BIGINT NOT NULL DEFAULT 0,
  is_archived      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_accounts_user ON accounts(user_id);
```

> Since superseded: the `currency` column was dropped by `20260606000001_drop_currency_columns.sql` (single-currency), `20260607000002_account_images.sql` added `image_url`, and `20260617000001_account_show_on_dashboard.sql` added `show_on_dashboard`. The §3.4 DDL reference lists the current accounts shape.

**Migration 4b — Account Monthly Balances**

```sql
-- 20260509000004b_create_account_monthly_balances.sql
CREATE TABLE account_monthly_balances (
  account_id  UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  year_month  TEXT NOT NULL,
  balance     BIGINT NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, year_month)
);

CREATE INDEX idx_amb_account ON account_monthly_balances(account_id);
CREATE INDEX idx_amb_month   ON account_monthly_balances(year_month);

ALTER TABLE account_monthly_balances ENABLE ROW LEVEL SECURITY;

CREATE POLICY policy_owner_amb ON account_monthly_balances FOR ALL
  USING (
    EXISTS (SELECT 1 FROM accounts a WHERE a.id = account_id AND a.user_id = auth.uid())
  );
```

**Migrations 3–8** follow the same pattern, one per table group from the DDL in the System Design doc.

**Migration 9 — RLS** contains all `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` and `CREATE POLICY` statements.

**Migration 10 — Triggers** contains the balance update triggers and `updated_at` triggers.

**Migration 11 — Views** contains `v_monthly_cashflow`, `v_budget_progress`, and `v_spending_by_category`. `v_budget_progress` is later replaced by `20260604000001_restructure_budgets.sql` (see §3.8) with a recursive version that computes carry-over live.

### 3.4 Complete DDL Reference

Below is the full DDL for every table. All client platforms (iOS, Android, Web) must use these exact column names when querying Supabase.

**Enums**

```sql
CREATE TYPE account_type AS ENUM ('bank_account', 'credit_card', 'digital_wallet', 'cash', 'other');
CREATE TYPE transaction_type AS ENUM ('income', 'expense', 'transfer');
CREATE TYPE transaction_status AS ENUM ('confirmed', 'pending', 'dismissed');
CREATE TYPE recurrence_type AS ENUM ('monthly');
```

**currencies**

| Column | Type | Notes |
|---|---|---|
| `code` | `TEXT` | PK, ISO 4217 (e.g. `'USD'`, `'EUR'`) |
| `name` | `TEXT` | e.g. `'US Dollar'` |
| `symbol` | `TEXT` | e.g. `'$'`, `'€'`. Default `''` |
| `decimal_places` | `SMALLINT` | Default `2` |
| `created_at` | `TIMESTAMPTZ` | |

> This is a **reference table** with no `user_id`. All authenticated users can read; only admins/migrations insert/update. All `currency` columns on other tables reference `currencies(code)` via FK.

**user_settings**

| Column | Type | Notes |
|---|---|---|
| `user_id` | `UUID` | PK, FK → `auth.users` |
| `default_currency` | `TEXT` | FK → `currencies(code)`. Default `'USD'` |
| `default_account_id` | `UUID` | Nullable. FK → `accounts(id)` `ON DELETE SET NULL`. The account pre-selected when adding a new transaction. Added by `20260610000001_user_settings_default_account.sql`. |
| `created_at` | `TIMESTAMPTZ` | |
| `updated_at` | `TIMESTAMPTZ` | |

> One row per user. Created on first sign-in or when the user sets a preference (default currency, default account). Clients upsert on save.

**accounts**

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` | PK, auto-generated |
| `user_id` | `UUID` | FK → `auth.users` |
| `name` | `TEXT` | |
| `type` | `account_type` | Default `'other'` (`bank_account` / `credit_card` / `digital_wallet` / `cash` / `other`) |
| `starting_balance` | `BIGINT` | Default `0`. Minor units. The live balance is derived from the monthly-balance ledger, not stored here. |
| `image_url` | `TEXT` | Nullable. Public URL of the account's avatar image (Supabase Storage); falls back to a type icon when null. Added by `20260607000002_account_images.sql`. |
| `is_archived` | `BOOLEAN` | Default `FALSE`. Archiving hides the account from lists/pickers without deleting its history. |
| `show_on_dashboard` | `BOOLEAN` | Default `TRUE`. When `FALSE`, the account (and its balance) is hidden from the dashboard Accounts card without archiving it. Added by `20260617000001_account_show_on_dashboard.sql`. |
| `created_at` | `TIMESTAMPTZ` | |
| `updated_at` | `TIMESTAMPTZ` | |

**account_monthly_balances**

| Column | Type | Notes |
|---|---|---|
| `account_id` | `UUID` | PK (composite), FK → `accounts` |
| `year_month` | `TEXT` | PK (composite), format: `'YYYY-MM'` |
| `balance` | `BIGINT` | End-of-month balance, maintained by trigger + cron |
| `updated_at` | `TIMESTAMPTZ` | |

> One row per account per month. Created by a monthly cron job (`fn_create_monthly_balance_rows`) and recalculated by a trigger on `transactions` changes. To get an account's current balance, query the latest `year_month` row. The `v_account_current_balance` view returns this latest-overall balance per account; for a balance **as of an arbitrary past month** (what the month-scoped dashboard needs), call `fn_account_balances_at('YYYY-MM')` — see §3.9.

**categories**

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` | PK |
| `user_id` | `UUID` | FK → `auth.users` |
| `name` | `TEXT` | Unique per user |
| `icon` | `TEXT` | Nullable |
| `color` | `TEXT` | Nullable |
| `created_at` | `TIMESTAMPTZ` | |

**tags**

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` | PK |
| `user_id` | `UUID` | FK → `auth.users` |
| `name` | `TEXT` | Unique per user |
| `created_at` | `TIMESTAMPTZ` | |

**transactions**

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` | PK |
| `user_id` | `UUID` | FK → `auth.users` |
| `account_id` | `UUID` | FK → `accounts` |
| `transfer_account_id` | `UUID` | FK → `accounts`, nullable. Required when `type = 'transfer'` |
| `type` | `transaction_type` | |
| `status` | `transaction_status` | Default `'confirmed'` |
| `amount` | `BIGINT` | Minor units. `CHECK (amount <> 0 AND (type <> 'transfer' OR amount > 0))` — income/expense may be **negative** (e.g. a refund as a negative expense), transfers are strictly positive, zero is never allowed. |
| `description` | `TEXT` | Nullable |
| `date` | `DATE` | Default `CURRENT_DATE` |
| `budget_id` | `UUID` | FK → `budgets`, nullable. Set via the budget dropdown; only income/expense (not transfers) may link. |
| `category_id` | `UUID` | FK → `categories`, nullable, `ON DELETE SET NULL`. At most one category per transaction (single-select). |
| `scheduled_txn_id` | `UUID` | FK → `scheduled_transactions`, nullable |
| `fixed_expense_id` | `UUID` | FK → `fixed_expenses`, nullable. Links this transaction to a fixed expense to indicate payment. |
| `created_at` | `TIMESTAMPTZ` | |
| `updated_at` | `TIMESTAMPTZ` | |

> **Important:** The date column is named `date`, not `transaction_date`. The transfer account column is named `transfer_account_id`, not `to_account_id`. Category is **single-select** via the `category_id` column directly on this table — there is no `transaction_categories` junction (it was dropped when categories became single-select). There is **no** per-row `currency` column either; the app is single-currency (`user_settings.default_currency`).

> **`v_transactions` view.** The Transactions list and Summary read from `v_transactions` (`transactions.*` plus a `tag_ids` UUID array aggregated from `transaction_tags`), `SECURITY INVOKER`, so the tag facet — including "untagged" (`tag_ids = '{}'`) — is an ordinary SQL predicate and the whole query stays paginatable.

**transaction_tags** (junction table — many-to-many)

| Column | Type | Notes |
|---|---|---|
| `transaction_id` | `UUID` | FK → `transactions`, composite PK |
| `tag_id` | `UUID` | FK → `tags`, composite PK |

**budgets**

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` | PK |
| `user_id` | `UUID` | FK → `auth.users` |
| `name` | `TEXT` | Identity (with `year_month`) |
| `year_month` | `TEXT` | Format: `'YYYY-MM'` |
| `periodic_amount` | `BIGINT` | Minor units |
| `description` | `TEXT` | Nullable; optional free-text note |
| `created_at` | `TIMESTAMPTZ` | |
| `updated_at` | `TIMESTAMPTZ` | |

> Flat, self-contained one row per budget per month, like `fixed_expenses`. `UNIQUE(user_id, name, year_month)`. The app is single-currency, so budgets carry **no** per-row `currency`. There is **no** `budget_periods` table, no `is_active`/`enable_carry_over`, and no stored carry-over column. Carry-over is always on and derived in `v_budget_progress`: it compounds along each `(user_id, name)` lineage, resets to 0 after any missing month, and `spent` is net (linked expenses − linked income).

**fixed_expenses**

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` | PK |
| `user_id` | `UUID` | FK → `auth.users` |
| `name` | `TEXT` | |
| `year_month` | `TEXT` | Format: `'YYYY-MM'`, unique per user + name |
| `amount` | `BIGINT` | Minor units |
| `currency` | `TEXT` | Default `'USD'` |
| `due_day` | `SMALLINT` | 1–31 |
| `is_active` | `BOOLEAN` | Default `TRUE` |
| `created_at` | `TIMESTAMPTZ` | |
| `updated_at` | `TIMESTAMPTZ` | |

> Each row represents one fixed expense for one specific month. There is no separate periods table. Paid status is derived from whether any `transactions` row references this fixed expense via `fixed_expense_id`.

**budget_installments** (P1 — see §3.9)

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` | PK |
| `user_id` | `UUID` | FK → `auth.users` |
| `source_transaction_id` | `UUID` | FK → `transactions`, `ON DELETE CASCADE`. The real expense being spread. |
| `total_amount` | `BIGINT` | Minor units; equals the expense amount. `> 0`. |
| `description` | `TEXT` | Nullable |
| `start_year_month` | `TEXT` | `'YYYY-MM'`, first reserved month (display convenience) |
| `months` | `SMALLINT` | Span in months (display convenience) |
| `created_at` / `updated_at` | `TIMESTAMPTZ` | |

> One header per spread expense. The reservation math lives in the allocations table; the header carries display convenience fields.

**budget_installment_allocations** (P1 — see §3.9)

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` | PK |
| `installment_id` | `UUID` | FK → `budget_installments`, `ON DELETE CASCADE` |
| `user_id` | `UUID` | FK → `auth.users` (denormalized for RLS / the view join) |
| `budget_name` | `TEXT` | The budget **lineage** this cell reserves from (not a budget `id`) |
| `year_month` | `TEXT` | `'YYYY-MM'` |
| `amount` | `BIGINT` | Reserved minor units, `> 0`. Zero cells are not stored. |
| `created_at` | `TIMESTAMPTZ` | |

> One row per non-zero grid cell. `UNIQUE(installment_id, budget_name, year_month)`. Reservations are **budget-side only** — never in `transactions`, never affecting account balances. `v_budget_progress` subtracts them: `remaining = periodic + carry_in − spent − reserved`.

**scheduled_transactions**

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` | PK |
| `user_id` | `UUID` | FK → `auth.users` |
| `account_id` | `UUID` | FK → `accounts` |
| `type` | `transaction_type` | |
| `amount` | `BIGINT` | |
| `currency` | `TEXT` | Default `'USD'` |
| `description` | `TEXT` | Nullable |
| `recurrence` | `recurrence_type` | Default `'monthly'` |
| `next_due_date` | `DATE` | |
| `is_active` | `BOOLEAN` | Default `TRUE` |
| `created_at` | `TIMESTAMPTZ` | |
| `updated_at` | `TIMESTAMPTZ` | |

> **Important:** The recurrence column is named `recurrence` (not `recurrence_interval`). The date column is `next_due_date` (not `next_occurrence`). There is no separate `pending_transactions` table — pending transactions are rows in `transactions` with `status = 'pending'`.

### 3.5 Applying Migrations

```bash
# Apply to local DB
supabase db reset        # drops & recreates from migrations + seed.sql

# Apply to cloud (production)
supabase db push
```

### 3.6 Seed Data (`supabase/seed.sql`)

Optional seed data for development:

```sql
-- Create a test user (local dev only — Supabase Auth handles this in production)
-- The local auth emulator auto-creates users via the dashboard at http://127.0.0.1:54323

-- Seed categories (run after signing up a test user and replacing the UUID)
INSERT INTO categories (user_id, name, icon, color) VALUES
  ('<test-user-uuid>', 'Food & Dining',    '🍔', '#FF6B6B'),
  ('<test-user-uuid>', 'Transportation',    '🚗', '#4ECDC4'),
  ('<test-user-uuid>', 'Housing',           '🏠', '#45B7D1'),
  ('<test-user-uuid>', 'Entertainment',     '🎬', '#96CEB4'),
  ('<test-user-uuid>', 'Shopping',          '🛍️', '#FFEAA7'),
  ('<test-user-uuid>', 'Healthcare',        '🏥', '#DDA0DD'),
  ('<test-user-uuid>', 'Utilities',         '💡', '#98D8C8'),
  ('<test-user-uuid>', 'Salary',            '💰', '#52C41A'),
  ('<test-user-uuid>', 'Freelance',         '💻', '#1890FF'),
  ('<test-user-uuid>', 'Investment Return', '📈', '#722ED1');
```

### 3.7 Seed Currencies (Migration or Manual Insert)

The `currencies` table should be pre-populated with all ISO 4217 currency codes. This is done via a dedicated migration (`20260509000014_seed_currencies.sql`) or can be run manually. See the SQL query in the System Design doc appendix for the full INSERT statement covering all active ISO 4217 currencies.

```sql
-- Example (subset — full list in migration file):
INSERT INTO currencies (code, name, symbol, decimal_places) VALUES
  ('USD', 'US Dollar', '$', 2),
  ('EUR', 'Euro', '€', 2),
  ('GBP', 'Pound Sterling', '£', 2),
  ('JPY', 'Japanese Yen', '¥', 0),
  ('IDR', 'Indonesian Rupiah', 'Rp', 2)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  symbol = EXCLUDED.symbol,
  decimal_places = EXCLUDED.decimal_places;
```

### 3.8 Forward Migration — Restructure Budgets (`20260604000001_restructure_budgets.sql`)

The budgets schema is already deployed, so the move from the header+period model to the flat name+currency model is delivered as a forward migration rather than by editing the original create migration. It assumes little/no production budget data; if real `budget_periods` rows exist, the optional copy step preserves them.

```sql
-- 20260604000001_restructure_budgets.sql
BEGIN;

-- 1. Point transactions at budgets directly (was budget_period_id -> budget_periods).
ALTER TABLE transactions ADD COLUMN budget_id UUID REFERENCES budgets(id) ON DELETE SET NULL;

-- 2. Rebuild the budgets table as flat (name + currency identity, one row per month).
--    Drop the header columns and add the period-specific columns.
ALTER TABLE budgets DROP COLUMN IF EXISTS is_active;
ALTER TABLE budgets DROP COLUMN IF EXISTS enable_carry_over;
ALTER TABLE budgets ADD COLUMN year_month      TEXT;
ALTER TABLE budgets ADD COLUMN currency        TEXT NOT NULL DEFAULT 'USD' REFERENCES currencies(code);
ALTER TABLE budgets ADD COLUMN periodic_amount BIGINT;

-- 3. (Optional) Migrate any existing budget_periods rows into flat budgets rows,
--    carrying the parent name. One budgets row per (name, currency, year_month).
--    For the simple case (one period per budget) this is a straight copy; otherwise
--    additional rows are inserted for the extra months.
--    Re-point transactions from their old budget_period_id to the new budget row here.
--    (Skipped when there is no production budget data.)

-- 4. Enforce the new shape.
ALTER TABLE budgets ALTER COLUMN year_month      SET NOT NULL;
ALTER TABLE budgets ALTER COLUMN periodic_amount SET NOT NULL;
ALTER TABLE budgets ADD CONSTRAINT uq_budget_lineage UNIQUE (user_id, name, currency, year_month);
CREATE INDEX IF NOT EXISTS idx_budgets_lineage ON budgets(user_id, name, currency, year_month);

-- 5. Drop the obsolete child table and the old transactions column/index.
DROP INDEX IF EXISTS idx_txn_budget_per;
ALTER TABLE transactions DROP COLUMN IF EXISTS budget_period_id;
DROP TABLE IF EXISTS budget_periods;
CREATE INDEX idx_txn_budget ON transactions(budget_id);

-- 6. RLS: budgets now owns user_id directly (drop the derive-through-parent policy).
DROP POLICY IF EXISTS policy_owner_budget_periods ON budget_periods;
-- budgets already has policy_owner_budgets (user_id = auth.uid()); no change needed.

-- 7. Realtime publication.
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS budget_periods;
ALTER PUBLICATION supabase_realtime ADD TABLE budgets;

-- 8. Replace the budget progress view with the live carry-over version.
--    (Full recursive definition is in the System Design doc / migration file.)
DROP VIEW IF EXISTS v_budget_progress;
-- CREATE OR REPLACE VIEW v_budget_progress AS WITH spent AS (...), base AS (...),
--   chain AS (... recursive ...) SELECT ... FROM chain;  -- see System Design §VIEWS

COMMIT;
```

> Note: `DROP TABLE budget_periods` cascades to the old `transactions.budget_period_id` FK, so step 5's column drop and the table drop must agree on order; the script drops the column first, then the table.

> **Superseded since:** this migration's `currency` column (and its place in the budget identity / lineage) was later dropped by `20260606000001_drop_currency_columns.sql` when the app went single-currency — budget identity is now `(user_id, name, year_month)` and the carry-over chain runs on `(user_id, name)`. `20260613000001_budget_description.sql` then added the optional `description` note and recreated `v_budget_progress` to surface it. The §3.4 DDL reference reflects this current shape.

### 3.9 Forward Migrations — Dashboard

Two later migrations support the month-scoped dashboard (see Web Tech Plan §7.1 and System Design §4.6):

**`20260614000001_account_balances_at.sql` — per-month account balances.** The dashboard Accounts card needs each account's balance *as of the month it is showing*. Balances carry forward across empty months, so that is the latest `account_monthly_balances` row at or before the month. `v_account_current_balance` only answers for the latest month overall; this function is the parameterized version, returning at most one row per account regardless of history depth (the `(account_id, year_month)` PK lets the `DISTINCT ON` run as an index scan). `SECURITY INVOKER` so `account_monthly_balances` RLS still scopes rows to the owner.

```sql
CREATE OR REPLACE FUNCTION fn_account_balances_at(p_year_month TEXT)
RETURNS TABLE (account_id UUID, year_month TEXT, balance BIGINT)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT DISTINCT ON (amb.account_id)
    amb.account_id, amb.year_month, amb.balance
  FROM account_monthly_balances amb
  WHERE amb.year_month <= p_year_month
  ORDER BY amb.account_id, amb.year_month DESC;
$$;
```

**`20260617000001_account_show_on_dashboard.sql` — hide accounts from the dashboard.** Adds a per-account toggle so a user can hide an account (and its balance) from the dashboard Accounts card without archiving it. Defaults to `TRUE` so existing accounts keep showing; `NOT NULL` keeps the flag unambiguous.

```sql
ALTER TABLE accounts
  ADD COLUMN show_on_dashboard BOOLEAN NOT NULL DEFAULT TRUE;
```

### 3.10 Forward Migration — Budget Installments (P1) (`20260618000001_budget_installments.sql`)

Adds the two reservation tables, folds a `reserved` term into `v_budget_progress`, and provides the `create_budget_installment` RPC that persists an expense and its grid atomically. Reservations are **budget-side only** — they never enter `transactions`, so account balances and cash flow are untouched. See System Design §4.11 and Web §7.8.

```sql
-- 20260618000001_budget_installments.sql
BEGIN;

-- 1. Tables ---------------------------------------------------------------
CREATE TABLE budget_installments (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  total_amount          BIGINT NOT NULL CHECK (total_amount > 0),
  description           TEXT,
  start_year_month      TEXT NOT NULL,
  months                SMALLINT NOT NULL CHECK (months > 0),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_budget_installments_user ON budget_installments(user_id);
CREATE INDEX idx_budget_installments_txn  ON budget_installments(source_transaction_id);

CREATE TABLE budget_installment_allocations (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  installment_id UUID NOT NULL REFERENCES budget_installments(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  budget_name    TEXT NOT NULL,
  year_month     TEXT NOT NULL,
  amount         BIGINT NOT NULL CHECK (amount > 0),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (installment_id, budget_name, year_month)
);
CREATE INDEX idx_bia_lookup ON budget_installment_allocations(user_id, budget_name, year_month);

-- 2. RLS (standard owner policy) -----------------------------------------
ALTER TABLE budget_installments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_installment_allocations ENABLE ROW LEVEL SECURITY;
CREATE POLICY policy_owner_budget_installments ON budget_installments
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY policy_owner_bia ON budget_installment_allocations
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 3. Realtime -------------------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE budget_installments;
ALTER PUBLICATION supabase_realtime ADD TABLE budget_installment_allocations;

-- 4. Fold `reserved` into v_budget_progress ------------------------------
--    Adds a `reserved` CTE (SUM of allocations per user_id+name+year_month),
--    LEFT JOINs it into base, and subtracts it inside the recursive remaining:
--      anchor:  remaining = periodic_amount - spent - reserved
--      recurse: remaining = periodic_amount + carry_in - spent - reserved
--    effective_amount stays periodic + carry_in; a `reserved` column is exposed.
--    (Full recursive body in the System Design doc §VIEWS / §4.11.)
DROP VIEW IF EXISTS v_budget_progress;
-- CREATE VIEW v_budget_progress AS WITH RECURSIVE spent AS (...),
--   reserved AS (SELECT user_id, budget_name, year_month, SUM(amount)::BIGINT AS reserved
--                FROM budget_installment_allocations
--                GROUP BY user_id, budget_name, year_month),
--   base AS (... LEFT JOIN reserved r ON r.user_id=b.user_id AND r.budget_name=b.name
--                AND r.year_month=b.year_month, COALESCE(r.reserved,0) ...),
--   chain AS (... recursive, remaining nets out reserved ...)
--   SELECT ..., reserved, periodic_amount + carry_in AS effective_amount,
--          periodic_amount + carry_in - spent - reserved AS remaining FROM chain;
ALTER VIEW v_budget_progress SET (security_invoker = true);

-- 5. RPC: persist an expense + its reservation grid atomically -----------
--    Called by the web client (Web §7.8). p_grid is a JSON array of
--    { budget_name, year_month, amount } objects (non-zero cells only).
CREATE OR REPLACE FUNCTION create_budget_installment(
  p_account_id       UUID,
  p_amount           BIGINT,
  p_date             DATE,
  p_description      TEXT,
  p_start_year_month TEXT,
  p_months           SMALLINT,
  p_grid             JSONB
) RETURNS UUID
LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE
  v_user UUID := auth.uid();
  v_txn  UUID;
  v_inst UUID;
  v_cell RECORD;
  v_sum  BIGINT;
BEGIN
  -- Grid must reconcile to the expense amount.
  SELECT COALESCE(SUM((c->>'amount')::BIGINT), 0) INTO v_sum
  FROM jsonb_array_elements(p_grid) c;
  IF v_sum <> p_amount THEN
    RAISE EXCEPTION 'Allocation grid (%) must equal expense amount (%)', v_sum, p_amount;
  END IF;

  -- 1. The real expense. budget_id stays NULL: the spread accounts for the impact.
  INSERT INTO transactions (user_id, account_id, type, status, amount, description, date)
  VALUES (v_user, p_account_id, 'expense', 'confirmed', p_amount, p_description, p_date)
  RETURNING id INTO v_txn;

  -- 2. Header.
  INSERT INTO budget_installments
    (user_id, source_transaction_id, total_amount, description, start_year_month, months)
  VALUES (v_user, v_txn, p_amount, p_description, p_start_year_month, p_months)
  RETURNING id INTO v_inst;

  -- 3. For each cell: materialize the budget row if missing, then insert the allocation.
  FOR v_cell IN SELECT * FROM jsonb_array_elements(p_grid) AS c LOOP
    INSERT INTO budgets (user_id, name, year_month, periodic_amount)
    VALUES (
      v_user,
      v_cell.value->>'budget_name',
      v_cell.value->>'year_month',
      COALESCE((
        SELECT b.periodic_amount FROM budgets b
        WHERE b.user_id = v_user AND b.name = v_cell.value->>'budget_name'
          AND b.year_month <= v_cell.value->>'year_month'
        ORDER BY b.year_month DESC LIMIT 1
      ), 0)
    )
    ON CONFLICT (user_id, name, year_month) DO NOTHING;

    INSERT INTO budget_installment_allocations
      (installment_id, user_id, budget_name, year_month, amount)
    VALUES (v_inst, v_user, v_cell.value->>'budget_name',
            v_cell.value->>'year_month', (v_cell.value->>'amount')::BIGINT);
  END LOOP;

  RETURN v_inst;
END;
$$;

COMMIT;
```

> Cancelling an installment is a plain `DELETE FROM budget_installments WHERE id = ?` — the `ON DELETE CASCADE` clears its allocations and the budgets recompute. Deleting the source transaction cascades to the installment as well. Materialized `budgets` rows are intentionally left behind as ordinary rows.

---

## 4. Edge Functions

Edge Functions are serverless Deno functions deployed to Supabase's edge network. They handle logic that cannot be expressed as a Postgres trigger or RLS policy.

### 4.1 Auto-Record: Generate Pending Transactions

This function is invoked by `pg_cron` daily. It queries `scheduled_transactions` for items due today (or overdue), inserts a pending transaction for each, and advances `next_due_date`.

```bash
supabase functions new generate-pending-transactions
```

**`supabase/functions/generate-pending-transactions/index.ts`**

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  // Verify this is called by cron or an admin (check Authorization header)
  const authHeader = req.headers.get("Authorization");
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const today = new Date().toISOString().split("T")[0];

  // 1. Fetch due scheduled transactions
  const { data: schedules, error } = await supabase
    .from("scheduled_transactions")
    .select("*")
    .eq("is_active", true)
    .lte("next_due_date", today);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let created = 0;

  for (const sched of schedules ?? []) {
    // 2. Insert pending transaction
    const { error: insertErr } = await supabase.from("transactions").insert({
      user_id: sched.user_id,
      account_id: sched.account_id,
      type: sched.type,
      status: "pending",
      amount: sched.amount,
      currency: sched.currency,
      description: sched.description,
      date: sched.next_due_date,
      scheduled_txn_id: sched.id,
    });

    if (insertErr) continue;

    // 3. Advance next_due_date (monthly for P0)
    const nextDate = new Date(sched.next_due_date);
    nextDate.setMonth(nextDate.getMonth() + 1);

    await supabase
      .from("scheduled_transactions")
      .update({ next_due_date: nextDate.toISOString().split("T")[0] })
      .eq("id", sched.id);

    created++;
  }

  return new Response(JSON.stringify({ created }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

### 4.2 Deploy Edge Functions

```bash
# Deploy to cloud
supabase functions deploy generate-pending-transactions

# Test locally
supabase functions serve generate-pending-transactions
curl -X POST http://127.0.0.1:54321/functions/v1/generate-pending-transactions \
  -H "Authorization: Bearer <service-role-key>"
```

---

## 5. Cron Job Setup (`pg_cron`)

Supabase supports `pg_cron` to schedule recurring SQL or HTTP calls.

### 5.1 Enable pg_cron

In the Supabase Dashboard: **Database → Extensions → Search "pg_cron" → Enable**.

### 5.2 Schedule the Auto-Record Job

Run this SQL in the SQL Editor (or add as a migration):

```sql
-- Run daily at 00:05 UTC
SELECT cron.schedule(
  'generate-pending-transactions',
  '5 0 * * *',
  $$
  SELECT net.http_post(
    url    := current_setting('app.settings.supabase_url') || '/functions/v1/generate-pending-transactions',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body   := '{}'::jsonb
  );
  $$
);
```

Alternatively, if using `pg_net` is not available, you can call the function logic directly in SQL via `pg_cron` without Edge Functions by writing the logic as a PL/pgSQL function.

### 5.3 Direct PL/pgSQL Alternative (No Edge Function Needed)

```sql
CREATE OR REPLACE FUNCTION fn_generate_pending_transactions()
RETURNS void AS $$
DECLARE
  sched RECORD;
  next_date DATE;
BEGIN
  FOR sched IN
    SELECT * FROM scheduled_transactions
    WHERE is_active = TRUE AND next_due_date <= CURRENT_DATE
  LOOP
    INSERT INTO transactions (
      user_id, account_id, type, status, amount, currency,
      description, date, scheduled_txn_id
    ) VALUES (
      sched.user_id, sched.account_id, sched.type, 'pending',
      sched.amount, sched.currency, sched.description,
      sched.next_due_date, sched.id
    );

    next_date := sched.next_due_date + INTERVAL '1 month';
    UPDATE scheduled_transactions
    SET next_due_date = next_date, updated_at = now()
    WHERE id = sched.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule it
SELECT cron.schedule(
  'generate-pending-transactions',
  '5 0 * * *',
  'SELECT fn_generate_pending_transactions()'
);
```

This approach keeps everything inside Postgres and avoids HTTP overhead.

### 5.4 Schedule the Monthly Balance Row Creation

This cron job runs at midnight UTC on the 1st of every month. It creates a new `account_monthly_balances` row for each active account, carrying forward the previous month's balance.

```sql
-- The function is defined in the triggers migration (see System Design doc).
-- Schedule it:
SELECT cron.schedule(
  'create-monthly-balance-rows',
  '0 0 1 * *',
  'SELECT fn_create_monthly_balance_rows()'
);
```

### 5.5 Backfill Migration: Historical Monthly Balances

Migration `20260509000015_backfill_monthly_balances.sql` populates balance rows from **June 2024** through the current month for all existing accounts. It generates the month series, computes the cumulative net confirmed transactions up to each month, and inserts the result.

```sql
-- 20260509000015_backfill_monthly_balances.sql
INSERT INTO account_monthly_balances (account_id, year_month, balance)
SELECT
  a.id,
  m.year_month,
  a.starting_balance + COALESCE(SUM(
    CASE
      WHEN t.type = 'income'   AND t.account_id = a.id          THEN t.amount
      WHEN t.type = 'expense'  AND t.account_id = a.id          THEN -t.amount
      WHEN t.type = 'transfer' AND t.account_id = a.id          THEN -t.amount
      WHEN t.type = 'transfer' AND t.transfer_account_id = a.id THEN  t.amount
      ELSE 0
    END
  ), 0) AS balance
FROM accounts a
CROSS JOIN (
  SELECT to_char(d, 'YYYY-MM') AS year_month
  FROM generate_series('2024-06-01'::date, date_trunc('month', CURRENT_DATE), '1 month') d
) m
LEFT JOIN transactions t
  ON (t.account_id = a.id OR t.transfer_account_id = a.id)
  AND t.status = 'confirmed'
  AND to_char(t.date, 'YYYY-MM') <= m.year_month
GROUP BY a.id, a.starting_balance, m.year_month
ORDER BY a.id, m.year_month
ON CONFLICT (account_id, year_month) DO UPDATE SET
  balance = EXCLUDED.balance,
  updated_at = now();
```

This backfill is idempotent (`ON CONFLICT ... DO UPDATE`) and safe to re-run.

---

## 6. Realtime Configuration

Enable Realtime on tables that clients need to subscribe to for live updates:

```sql
-- In Supabase Dashboard: Database → Replication → or via SQL:
ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE accounts;
ALTER PUBLICATION supabase_realtime ADD TABLE account_monthly_balances;
ALTER PUBLICATION supabase_realtime ADD TABLE budgets;
ALTER PUBLICATION supabase_realtime ADD TABLE fixed_expenses;
ALTER PUBLICATION supabase_realtime ADD TABLE user_settings;
-- P1 — Budget Installments (§3.9): reserved amounts refresh the Budgets page live
ALTER PUBLICATION supabase_realtime ADD TABLE budget_installments;
ALTER PUBLICATION supabase_realtime ADD TABLE budget_installment_allocations;
```

Clients subscribe using the Supabase SDK:

```typescript
// Example (supabase-js)
supabase
  .channel('transactions')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'transactions' }, (payload) => {
    console.log('Change:', payload);
  })
  .subscribe();
```

---

## 7. Environment & Secrets

### 7.1 Environment Variables

| Variable | Where Used | Description |
|---|---|---|
| `SUPABASE_URL` | All clients, Edge Functions | Project API URL |
| `SUPABASE_ANON_KEY` | All clients | Public key for authenticated client requests |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions, cron, admin scripts only | Bypasses RLS — never expose to clients |

### 7.2 Setting Secrets for Edge Functions

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<your-key>
```

### 7.3 Git-Ignored Files

Add to `.gitignore`:

```
.env
.env.local
.env.production
supabase/.temp/
```

---

## 8. Deployment Workflow

### 8.1 Development

```bash
supabase start                     # local Postgres + services
supabase db reset                  # apply all migrations + seed
supabase functions serve           # local Edge Functions with hot reload
```

### 8.2 Staging / Production

```bash
supabase link --project-ref <ref>  # link to cloud project
supabase db push                   # apply pending migrations
supabase functions deploy --all    # deploy all Edge Functions
```

### 8.3 CI/CD (GitHub Actions Example)

```yaml
name: Deploy Supabase
on:
  push:
    branches: [main]
    paths: ['supabase/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: supabase/setup-cli@v1
        with:
          version: latest

      - run: supabase link --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      - run: supabase db push
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      - run: supabase functions deploy --all
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
```

---

## 9. Backup & Recovery

- **Automatic backups**: Supabase Pro plan includes daily backups with point-in-time recovery (PITR).
- **Manual export**: `supabase db dump -f backup.sql` creates a full SQL dump.
- **Restore**: `psql <connection-string> < backup.sql`.

---

## 10. Monitoring & Observability

| What | Tool |
|---|---|
| Query performance | Supabase Dashboard → SQL → Query Performance |
| API logs | Supabase Dashboard → Logs → API |
| Edge Function logs | Supabase Dashboard → Logs → Edge Functions, or `supabase functions logs generate-pending-transactions` |
| Cron job status | `SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 20;` |
| Realtime connections | Supabase Dashboard → Realtime Inspector |
