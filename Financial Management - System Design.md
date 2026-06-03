# Financial Management — System Design & Database Schema

---

## 1. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Clients                                │
│                                                                 │
│   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐       │
│   │  Web / SPA   │   │  iOS App     │   │ Android App  │       │
│   │  (React /    │   │  (Swift /    │   │  (Kotlin /   │       │
│   │   Next.js)   │   │   SwiftUI)   │   │   Compose)   │       │
│   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘       │
│          │                  │                   │               │
│          └──────────────────┼───────────────────┘               │
│                             │                                   │
│                     Supabase Client SDK                         │
│         (supabase-js / supabase-swift / supabase-kt)            │
└─────────────────────────────┬───────────────────────────────────┘
                              │  HTTPS / WebSocket (Realtime)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Supabase Platform                          │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                    Supabase Auth                         │  │
│   │            (single-user, email/password)                 │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                   PostgREST API                          │  │
│   │       (auto-generated REST from Postgres schema)         │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                  Supabase Realtime                        │  │
│   │       (broadcasts row changes to connected clients)      │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │              Supabase Edge Functions                      │  │
│   │  ┌────────────────┐  ┌─────────────────────────────┐     │  │
│   │  │ CRON: generate │  │ P1: Receipt OCR / AI        │     │  │
│   │  │ pending txns   │  │     extraction               │     │  │
│   │  │ from schedules │  │     (calls external API)     │     │  │
│   │  └────────────────┘  └─────────────────────────────┘     │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │              Supabase Storage (P1)                        │  │
│   │           (receipt images / attachments)                  │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                     PostgreSQL                           │  │
│   │          (primary data store — see Section 2)            │  │
│   └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### No Custom Backend Server

This architecture has **no custom backend server** (no Express, FastAPI, etc.). Clients connect **directly to Supabase** via the client SDK over HTTPS/WebSocket. All concerns typically handled by a backend are covered natively:

- **CRUD** → PostgREST auto-generates REST endpoints from the Postgres schema.
- **Auth & Authorization** → Supabase Auth + Row-Level Security at the DB layer.
- **Business logic** (balance updates, validation) → Postgres triggers and constraints.
- **Scheduled jobs** (auto-record transactions) → `pg_cron` + Edge Functions (serverless, not a separate server).
- **Realtime sync** → Supabase Realtime over WebSocket.
- **File storage** (P1) → Supabase Storage.

A custom backend would only be needed if future requirements exceed what Edge Functions can handle (e.g., long-running jobs > 150s, or complex multi-service orchestration). For P0 and P1, this is not the case.

### Key Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Backend** | None — direct FE → Supabase | No middleware needed. PostgREST, Auth, RLS, triggers, Edge Functions, and Realtime cover all P0/P1 requirements. |
| **Cross-platform client** | Native per platform: Next.js (Web), Swift/SwiftUI (iOS), Kotlin/Jetpack Compose (Android) | Each platform uses its native SDK for the best UX and platform integration. Supabase provides first-class SDKs for all three (`supabase-js`, `supabase-swift`, `supabase-kt`). |
| **Sync strategy** | Supabase Realtime subscriptions + optimistic client cache | Clients subscribe to table changes via WebSocket. Offline writes are queued locally and pushed on reconnect. |
| **Auth model** | Supabase Auth, single user | Even though single-user, we still gate every table with RLS (`auth.uid()`) so the schema is secure-by-default and P1-ready for multi-user. |
| **Auto-record engine** | Supabase `pg_cron` + Edge Function | A cron job runs daily (or more frequently), checks `scheduled_transactions` for items due today, and inserts pending transactions. Push notification sent via Edge Function. |
| **Currency** | Stored per transaction; amounts stored as `bigint` in minor units (cents). A `currencies` table holds all supported ISO 4217 codes. A `user_settings` table stores the user's default currency. | Avoids floating-point errors. Centralised currency list prevents hardcoding across platforms. Display layer converts to decimal. |
| **Period handling** | `year_month` column (`TEXT` formatted `YYYY-MM`) | Enables simple equality checks for monthly budgets/fixed expenses. Easy to extend to other period types in P1. |

---

## 2. Database Schema

### 2.1 Entity-Relationship Overview

```
   ┌──────────────────┐
   │   currencies     │  (reference data — no user_id)
   │──────────────────│
   │ code (PK)        │
   │ name             │
   │ symbol           │
   │ decimal_places   │
   └──────────────────┘

                           ┌──────────────┐
                           │    users     │  (Supabase Auth — managed)
                           │──────────────│
                           │ id (uuid)    │
                           └──────┬───────┘
                                  │
                                  ├──────────────────────────┐
                                  ▼ 1                        │
                           ┌────────────────┐                │
                           │ user_settings  │                │
                           │────────────────│                │
                           │ user_id (PK/FK)│                │
                           │ default_currency│               │
                           └────────────────┘                │
                                  │ 1
           ┌──────────────────────┼──────────────────────────┐
           │                      │                          │
           ▼ *                    ▼ *                        ▼ *
   ┌───────────────┐    ┌─────────────────┐        ┌────────────────┐
   │   accounts    │    │    categories   │        │     tags       │
   │───────────────│    │─────────────────│        │────────────────│
   │ id            │    │ id              │        │ id             │
   │ user_id (FK)  │    │ user_id (FK)    │        │ user_id (FK)   │
   │ name          │    │ name            │        │ name           │
   │ type          │    │ icon            │        └────────────────┘
   │ starting_bal  │    │ color           │                │
   │ currency      │    └────────┬────────┘                │
   └───────┬───────┘             │                         │
           │                     │ *                       │ *
           ├──────────────┐      │     ┌──────────────┐    │
           │ 1            │      └─────┤ transaction  │────┘
           │              │ *          │  _categories │  transaction_tags
           │     ┌────────────────┐    └──────┬───────┘
           │     │ account_monthly│            │
           │     │  _balances     │            │
           │     │────────────────│            │
           │     │ account_id(PFK)│            │
           │     │ year_month (PK)│            │
           │     │ balance        │            │
           │     └────────────────┘            │
           │                                   │
           ▼ *                                 │
   ┌───────────────────┐              ┌────────┴──────────┐
   │   transactions    │◄─────────────┤                   │
   │───────────────────│              │                   │
   │ id                │              │                   │
   │ user_id (FK)      │     ┌────────┴────────┐          │
   │ account_id (FK)   │     │ budget_periods  │          │
   │ transfer_acc (FK) │     │─────────────────│          │
   │ type              │     │ id              │          │
   │ amount            │     │ budget_id (FK)  │          │
   │ currency          │     │ year_month      │          │
   │ description       │     │ periodic_amount │          │
   │ date              │     │ carry_over_amt  │          │
   │ budget_period(FK) │     └────────┬────────┘          │
   │ fixed_expense(FK) │              │                   │
   │ status            │              ▼ 1                 │
   │ scheduled_txn(FK) │     ┌─────────────────┐          │
   └───────────────────┘     │    budgets      │          │
                             │─────────────────│          │
           ▲                 │ id              │          │
           │                 │ user_id (FK)    │          │
           │                 │ name            │          │
   ┌───────┴───────────┐    └─────────────────┘          │
   │    scheduled      │                                  │
   │   _transactions   │    ┌─────────────────┐          │
   │───────────────────│    │  fixed_expenses │◄─ ─ ─ ─ ┤ (transactions.fixed_expense_id)
   │ id                │    │─────────────────│          │
   │ user_id (FK)      │    │ id              │          │
   │ account_id (FK)   │    │ user_id (FK)    │          │
   │ type              │    │ name            │          │
   │ amount            │    │ year_month      │          │
   │ description       │    │ amount          │          │
   │ recurrence        │    │ due_day         │          │
   │ next_due_date     │    │ is_active       │          │
   │ is_active         │    └─────────────────┘          │
   └───────────────────┘                                  │
```

### 2.2 Table Definitions (SQL DDL)

All monetary amounts are stored as **`bigint`** in **minor currency units** (e.g., cents for USD). The application layer converts for display.

```sql
-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE account_type AS ENUM (
  'bank_account',
  'credit_card',
  'digital_wallet',
  'cash',
  'other'
);

CREATE TYPE transaction_type AS ENUM (
  'income',
  'expense',
  'transfer'
);

CREATE TYPE transaction_status AS ENUM (
  'confirmed',
  'pending',
  'dismissed'
);

CREATE TYPE recurrence_type AS ENUM (
  'monthly'
  -- P1: 'weekly', 'quarterly', 'yearly', 'custom'
);

-- ============================================================
-- CURRENCIES (reference table — no RLS, readable by all authenticated users)
-- ============================================================
CREATE TABLE currencies (
  code           TEXT PRIMARY KEY,            -- ISO 4217 (e.g. 'USD', 'EUR')
  name           TEXT NOT NULL,               -- e.g. 'US Dollar'
  symbol         TEXT NOT NULL DEFAULT '',     -- e.g. '$', '€'
  decimal_places SMALLINT NOT NULL DEFAULT 2, -- minor unit digits
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- USER SETTINGS
-- ============================================================
CREATE TABLE user_settings (
  user_id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  default_currency TEXT NOT NULL DEFAULT 'USD' REFERENCES currencies(code),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- ACCOUNTS
-- ============================================================
CREATE TABLE accounts (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  type          account_type NOT NULL DEFAULT 'other',
  currency      TEXT NOT NULL DEFAULT 'USD' REFERENCES currencies(code),
  starting_balance BIGINT NOT NULL DEFAULT 0,
  is_archived   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_accounts_user ON accounts(user_id);

-- ============================================================
-- ACCOUNT MONTHLY BALANCES (running balance ledger)
-- ============================================================
-- Each row stores the end-of-month balance for one account in one month.
-- Formula: balance(M) = balance(M-1) + net confirmed transactions in M
--          balance(first month) = starting_balance + net confirmed transactions
-- Rows are created by a monthly cron job on the 1st of each month and
-- recalculated by a trigger whenever transactions change.
CREATE TABLE account_monthly_balances (
  account_id  UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  year_month  TEXT NOT NULL,  -- format: 'YYYY-MM'
  balance     BIGINT NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, year_month)
);

CREATE INDEX idx_amb_account ON account_monthly_balances(account_id);
CREATE INDEX idx_amb_month   ON account_monthly_balances(year_month);

-- ============================================================
-- CATEGORIES
-- ============================================================
CREATE TABLE categories (
  id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name      TEXT NOT NULL,
  icon      TEXT,
  color     TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, name)
);

CREATE INDEX idx_categories_user ON categories(user_id);

-- ============================================================
-- TAGS
-- ============================================================
CREATE TABLE tags (
  id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name      TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, name)
);

CREATE INDEX idx_tags_user ON tags(user_id);

-- ============================================================
-- BUDGETS
-- ============================================================
CREATE TABLE budgets (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  enable_carry_over BOOLEAN NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_budgets_user ON budgets(user_id);

-- Period-specific budget entries: one row per budget per month.
-- Allows the periodic_amount to differ each month and preserves history.
-- carry_over_amount: surplus (positive) or overspend (negative) from the previous period,
-- computed and locked in when this row is created. 0 if carry-over is disabled.
CREATE TABLE budget_periods (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  budget_id         UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
  year_month        TEXT NOT NULL,  -- format: 'YYYY-MM'
  periodic_amount   BIGINT NOT NULL,
  carry_over_amount BIGINT NOT NULL DEFAULT 0,
  currency          TEXT NOT NULL DEFAULT 'USD',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(budget_id, year_month)
);

CREATE INDEX idx_budget_periods_budget ON budget_periods(budget_id);
CREATE INDEX idx_budget_periods_month  ON budget_periods(year_month);

-- ============================================================
-- FIXED EXPENSES
-- ============================================================
-- Each row is a self-contained monthly fixed expense entry.
-- Paid status is derived: an entry is considered paid when at least one
-- transaction references it via transactions.fixed_expense_id.
-- "Copy from Previous Month" creates new rows for the next month.
CREATE TABLE fixed_expenses (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  year_month TEXT NOT NULL,  -- format: 'YYYY-MM'
  amount     BIGINT NOT NULL,
  currency   TEXT NOT NULL DEFAULT 'USD',
  due_day    SMALLINT NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, name, year_month)
);
CREATE INDEX idx_fixed_expenses_user  ON fixed_expenses(user_id);
CREATE INDEX idx_fixed_expenses_month ON fixed_expenses(year_month);

-- ============================================================
-- SCHEDULED TRANSACTIONS (Auto-Record source)
-- ============================================================
CREATE TABLE scheduled_transactions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id    UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  type          transaction_type NOT NULL,
  amount        BIGINT NOT NULL,
  currency      TEXT NOT NULL DEFAULT 'USD',
  description   TEXT,
  recurrence    recurrence_type NOT NULL DEFAULT 'monthly',
  next_due_date DATE NOT NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sched_txn_user ON scheduled_transactions(user_id);
CREATE INDEX idx_sched_txn_due  ON scheduled_transactions(next_due_date)
  WHERE is_active = TRUE;

-- ============================================================
-- TRANSACTIONS
-- ============================================================
CREATE TABLE transactions (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id            UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  transfer_account_id   UUID REFERENCES accounts(id) ON DELETE RESTRICT,
  type                  transaction_type NOT NULL,
  status                transaction_status NOT NULL DEFAULT 'confirmed',
  amount                BIGINT NOT NULL CHECK (amount > 0),
  currency              TEXT NOT NULL DEFAULT 'USD',
  description           TEXT,
  date                  DATE NOT NULL DEFAULT CURRENT_DATE,
  budget_period_id          UUID REFERENCES budget_periods(id) ON DELETE SET NULL,
  scheduled_txn_id          UUID REFERENCES scheduled_transactions(id) ON DELETE SET NULL,
  fixed_expense_id            UUID REFERENCES fixed_expenses(id) ON DELETE SET NULL,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Transfer must reference a second account
  CONSTRAINT chk_transfer_account CHECK (
    (type = 'transfer' AND transfer_account_id IS NOT NULL)
    OR (type != 'transfer' AND transfer_account_id IS NULL)
  )
);

CREATE INDEX idx_txn_user       ON transactions(user_id);
CREATE INDEX idx_txn_account    ON transactions(account_id);
CREATE INDEX idx_txn_date       ON transactions(date);
CREATE INDEX idx_txn_status     ON transactions(status);
CREATE INDEX idx_txn_budget_per ON transactions(budget_period_id);
CREATE INDEX idx_txn_type_date  ON transactions(type, date);
CREATE INDEX idx_txn_fixed_exp  ON transactions(fixed_expense_id)
  WHERE fixed_expense_id IS NOT NULL;

-- ============================================================
-- TRANSACTION ↔ CATEGORY  (many-to-many)
-- ============================================================
CREATE TABLE transaction_categories (
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  category_id    UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (transaction_id, category_id)
);

-- ============================================================
-- TRANSACTION ↔ TAG  (many-to-many)
-- ============================================================
CREATE TABLE transaction_tags (
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  tag_id         UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (transaction_id, tag_id)
);

-- ============================================================
-- ROW-LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE currencies              ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings           ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts                ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories              ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_periods          ENABLE ROW LEVEL SECURITY;
ALTER TABLE fixed_expenses          ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_transactions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions              ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_monthly_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_categories   ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_tags         ENABLE ROW LEVEL SECURITY;

-- currencies: read-only for all authenticated users
CREATE POLICY policy_currencies_read ON currencies FOR SELECT
  USING (auth.role() = 'authenticated');

-- user_settings: owner-only access
CREATE POLICY policy_owner_user_settings ON user_settings FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Uniform policy: owner can do everything on their own rows.
-- (Repeat this pattern for each table; shown generically here.)
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN
    SELECT unnest(ARRAY[
      'accounts','categories','tags','budgets','fixed_expenses',
      'scheduled_transactions','transactions'
    ])
  LOOP
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid())',
      'policy_owner_' || t, t
    );
  END LOOP;
END $$;

-- account_monthly_balances: derive through account.
CREATE POLICY policy_owner_amb ON account_monthly_balances FOR ALL
  USING (
    EXISTS (SELECT 1 FROM accounts a WHERE a.id = account_id AND a.user_id = auth.uid())
  );

-- Junction tables: derive ownership through the transaction's user_id.
CREATE POLICY policy_owner_txn_categories ON transaction_categories FOR ALL
  USING (
    EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND t.user_id = auth.uid())
  );

CREATE POLICY policy_owner_txn_tags ON transaction_tags FOR ALL
  USING (
    EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND t.user_id = auth.uid())
  );

-- budget_periods: derive through budget.
CREATE POLICY policy_owner_budget_periods ON budget_periods FOR ALL
  USING (
    EXISTS (SELECT 1 FROM budgets b WHERE b.id = budget_id AND b.user_id = auth.uid())
  );

-- ============================================================
-- TRIGGERS: recalculate account_monthly_balances
-- ============================================================

-- Core recalculation function: given an account and a starting month,
-- recomputes all balances from that month forward.
-- Formula: balance(M) = balance(M-1) + net_txns(M)
--          balance(first) = starting_balance + net_txns(first)
CREATE OR REPLACE FUNCTION fn_recalc_balances_from(
  p_account_id UUID,
  p_from_month TEXT  -- 'YYYY-MM'
)
RETURNS void AS $$
DECLARE
  prev_balance BIGINT;
  month_row    RECORD;
  net          BIGINT;
BEGIN
  -- Get the balance from the month before p_from_month.
  -- If none exists, fall back to the account's starting_balance.
  SELECT balance INTO prev_balance
  FROM account_monthly_balances
  WHERE account_id = p_account_id AND year_month < p_from_month
  ORDER BY year_month DESC LIMIT 1;

  IF prev_balance IS NULL THEN
    SELECT starting_balance INTO prev_balance
    FROM accounts WHERE id = p_account_id;
  END IF;

  -- Iterate through every month from p_from_month onward and recalculate
  FOR month_row IN
    SELECT year_month
    FROM account_monthly_balances
    WHERE account_id = p_account_id AND year_month >= p_from_month
    ORDER BY year_month
  LOOP
    SELECT COALESCE(SUM(
      CASE
        WHEN type = 'income'   AND account_id = p_account_id          THEN amount
        WHEN type = 'expense'  AND account_id = p_account_id          THEN -amount
        WHEN type = 'transfer' AND account_id = p_account_id          THEN -amount
        WHEN type = 'transfer' AND transfer_account_id = p_account_id THEN  amount
        ELSE 0
      END
    ), 0) INTO net
    FROM transactions
    WHERE (account_id = p_account_id OR transfer_account_id = p_account_id)
      AND status = 'confirmed'
      AND to_char(date, 'YYYY-MM') = month_row.year_month;

    prev_balance := prev_balance + net;

    UPDATE account_monthly_balances
    SET balance = prev_balance, updated_at = now()
    WHERE account_id = p_account_id AND year_month = month_row.year_month;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function: called on INSERT, UPDATE, or DELETE of transactions.
-- Determines which account(s) and month(s) are affected, then cascades.
CREATE OR REPLACE FUNCTION fn_transaction_balance_trigger()
RETURNS TRIGGER AS $$
DECLARE
  affected RECORD;
BEGIN
  -- Collect all (account_id, year_month) pairs that need recalculation.
  -- Use a temp table to deduplicate when UPDATE changes account or date.
  CREATE TEMP TABLE IF NOT EXISTS _affected_balances (
    account_id UUID,
    year_month TEXT
  ) ON COMMIT DROP;

  TRUNCATE _affected_balances;

  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    INSERT INTO _affected_balances VALUES (NEW.account_id, to_char(NEW.date, 'YYYY-MM'));
    IF NEW.transfer_account_id IS NOT NULL THEN
      INSERT INTO _affected_balances VALUES (NEW.transfer_account_id, to_char(NEW.date, 'YYYY-MM'));
    END IF;
  END IF;

  IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
    INSERT INTO _affected_balances VALUES (OLD.account_id, to_char(OLD.date, 'YYYY-MM'));
    IF OLD.transfer_account_id IS NOT NULL THEN
      INSERT INTO _affected_balances VALUES (OLD.transfer_account_id, to_char(OLD.date, 'YYYY-MM'));
    END IF;
  END IF;

  -- For each affected account, recalculate from the earliest affected month
  FOR affected IN
    SELECT account_id, MIN(year_month) AS from_month
    FROM _affected_balances
    GROUP BY account_id
  LOOP
    PERFORM fn_recalc_balances_from(affected.account_id, affected.from_month);
  END LOOP;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_recalc_balances
  AFTER INSERT OR UPDATE OR DELETE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION fn_transaction_balance_trigger();

-- ============================================================
-- CRON: create monthly balance rows on the 1st of each month
-- ============================================================
-- Ensures every active account has a balance row for the new month,
-- initialized to the previous month's balance (no transactions yet).
CREATE OR REPLACE FUNCTION fn_create_monthly_balance_rows()
RETURNS void AS $$
DECLARE
  current_ym TEXT := to_char(CURRENT_DATE, 'YYYY-MM');
  prev_ym    TEXT := to_char(CURRENT_DATE - INTERVAL '1 month', 'YYYY-MM');
BEGIN
  INSERT INTO account_monthly_balances (account_id, year_month, balance)
  SELECT a.id, current_ym, COALESCE(prev.balance, a.starting_balance)
  FROM accounts a
  LEFT JOIN account_monthly_balances prev
    ON prev.account_id = a.id AND prev.year_month = prev_ym
  WHERE a.is_archived = FALSE
  ON CONFLICT (account_id, year_month) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule via pg_cron: midnight UTC on the 1st of every month
-- SELECT cron.schedule('create-monthly-balance-rows', '0 0 1 * *', 'SELECT fn_create_monthly_balance_rows()');

-- ============================================================
-- TRIGGERS: updated_at auto-touch
-- ============================================================
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN
    SELECT unnest(ARRAY[
      'user_settings','accounts','budgets','budget_periods','fixed_expenses',
      'scheduled_transactions','transactions',
      'account_monthly_balances'
    ])
  LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_updated_at_%s BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()',
      t, t
    );
  END LOOP;
END $$;

-- ============================================================
-- VIEWS: dashboard helpers
-- ============================================================

-- Current balance per account (latest month in the ledger)
CREATE OR REPLACE VIEW v_account_current_balance AS
SELECT DISTINCT ON (account_id)
  account_id,
  year_month,
  balance AS current_balance
FROM account_monthly_balances
ORDER BY account_id, year_month DESC;

-- Monthly cash flow for a given month
CREATE OR REPLACE VIEW v_monthly_cashflow AS
SELECT
  user_id,
  to_char(date, 'YYYY-MM') AS year_month,
  SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END) AS total_income,
  SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS total_expense,
  SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END)
    - SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS net
FROM transactions
WHERE status = 'confirmed'
GROUP BY user_id, to_char(date, 'YYYY-MM');

-- Budget progress: spent vs. limit per budget per month (with carry-over)
-- effective_amount = periodic_amount + carry_over_amount
CREATE OR REPLACE VIEW v_budget_progress AS
SELECT
  bp.id AS budget_period_id,
  b.id AS budget_id,
  b.name AS budget_name,
  b.enable_carry_over,
  bp.year_month,
  bp.periodic_amount,
  bp.carry_over_amount,
  bp.periodic_amount + bp.carry_over_amount AS effective_amount,
  bp.currency,
  COALESCE(SUM(t.amount), 0) AS spent,
  (bp.periodic_amount + bp.carry_over_amount) - COALESCE(SUM(t.amount), 0) AS remaining
FROM budget_periods bp
JOIN budgets b ON b.id = bp.budget_id
LEFT JOIN transactions t
  ON t.budget_period_id = bp.id
  AND t.status = 'confirmed'
GROUP BY bp.id, b.id, b.name, b.enable_carry_over,
         bp.year_month, bp.periodic_amount, bp.carry_over_amount, bp.currency;

-- Spending by category for a given month
CREATE OR REPLACE VIEW v_spending_by_category AS
SELECT
  t.user_id,
  to_char(t.date, 'YYYY-MM') AS year_month,
  c.id AS category_id,
  c.name AS category_name,
  c.icon,
  c.color,
  SUM(t.amount) AS total_amount
FROM transactions t
JOIN transaction_categories tc ON tc.transaction_id = t.id
JOIN categories c ON c.id = tc.category_id
WHERE t.type = 'expense' AND t.status = 'confirmed'
GROUP BY t.user_id, to_char(t.date, 'YYYY-MM'), c.id, c.name, c.icon, c.color;
```

---

## 3. Table Summary

| # | Table | Purpose | Key Columns |
|---|---|---|---|
| 1 | `currencies` | Reference table of supported ISO 4217 currency codes | `code` (PK), `name`, `symbol`, `decimal_places` |
| 2 | `user_settings` | Per-user preferences (e.g., default currency) | `user_id` (PK), `default_currency` |
| 3 | `accounts` | Bank accounts, wallets, cash, credit cards | `name`, `type`, `currency`, `starting_balance` |
| 3b | `account_monthly_balances` | End-of-month running balance per account | `account_id` (PK), `year_month` (PK), `balance` |
| 4 | `categories` | Expense/income categories (Food, Salary…) | `name`, `icon`, `color` |
| 5 | `tags` | Free-form labels on transactions | `name` |
| 6 | `budgets` | Named budget definitions | `name`, `is_active`, `enable_carry_over` |
| 7 | `budget_periods` | Monthly snapshot of a budget's limit + carry-over | `budget_id`, `year_month`, `periodic_amount`, `carry_over_amount` |
| 8 | `fixed_expenses` | Monthly fixed expense entries with period-specific amounts | `name`, `year_month`, `amount`, `due_day`, `is_active` (paid = has linked txn) |
| 9 | `scheduled_transactions` | Templates for auto-recorded transactions | `account_id`, `type`, `amount`, `recurrence`, `next_due_date` |
| 10 | `transactions` | All financial movements | `account_id`, `type`, `status`, `amount`, `date`, `budget_period_id`, `fixed_expense_id` |
| 11 | `transaction_categories` | Many-to-many: transaction ↔ category | `transaction_id`, `category_id` |
| 12 | `transaction_tags` | Many-to-many: transaction ↔ tag | `transaction_id`, `tag_id` |

---

## 4. Design Rationale & Key Patterns

### 4.1 Period-Specific Records (Budget & Fixed Expense)

The requirement states that budgets and fixed expenses are **period-specific** — the amount can change between months, and deleting the parent should not erase historical data.

**Budgets** use a **header + period** pattern:

- `budgets` → `budget_periods` (one row per active month)

When the user "removes" a budget in July, we simply stop creating new `budget_periods` rows from July onward. May and June rows remain untouched.

**Fixed expenses** use a **flat, self-contained** pattern: each row in `fixed_expenses` represents one fixed expense for one specific month. The table carries both the identity (`name`, `user_id`) and the period-specific details (`year_month`, `amount`, `currency`, `due_day`). A UNIQUE constraint on `(user_id, name, year_month)` prevents duplicates. To set up a new month, the user copies entries from the previous month (amounts can be adjusted). Historical entries are preserved even if the user stops copying forward.

The app provides a **"Copy from Previous Month"** action: it duplicates all active fixed expense rows from month M-1 into month M, preserving each entry's name, amount, currency, and due day. The user can then edit individual entries as needed.

### 4.2 Budget Carry-Over

Carry-over allows unspent budget (or overspend) to roll into the next month. It is controlled by a per-budget toggle (`enable_carry_over` on `budgets`) and recorded as a snapshot on each period row (`carry_over_amount` on `budget_periods`).

**How it works:**

1. When a new `budget_periods` row is created for month M, the app checks whether `enable_carry_over` is true on the parent budget.
2. If enabled, it looks up the **previous period** (M-1) and computes: `carry_over = previous.periodic_amount + previous.carry_over_amount - previous.spent`.
   - Positive → surplus (user underspent → next month gets more).
   - Negative → deficit (user overspent → next month gets less).
3. This value is stored in `carry_over_amount` on the new row and **never changes retroactively**. Even if the user edits past transactions, the carry-over for subsequent periods remains as it was — consistent with the period-specific snapshot model.
4. The **effective budget** for display and progress bars is: `periodic_amount + carry_over_amount`.

**Example:**

| Month | periodic_amount | carry_over_amount | effective_amount | spent | remaining |
|---|---|---|---|---|---|
| May 2026 | $300 | $0 (first month) | $300 | $290 | $10 |
| Jun 2026 | $400 | +$10 (surplus) | $410 | $430 | -$20 |
| Jul 2026 | $400 | -$20 (overspend) | $380 | $350 | $30 |

If carry-over is disabled, `carry_over_amount` is always 0, and the budget behaves as before.

### 4.3 Account Monthly Balances (Running Balance Ledger)

Instead of storing a single `current_balance` on the `accounts` table, balances are tracked in the `account_monthly_balances` table — one row per account per month, similar to a spreadsheet where each cell's formula references the cell above it.

**Formula:**

```
balance(first month) = starting_balance + net confirmed transactions in that month
balance(M)           = balance(M-1)     + net confirmed transactions in M
```

Where `net confirmed transactions` = `SUM(income) - SUM(expense) ± transfers` for confirmed transactions in that month.

**How it stays up to date:**

1. **Transaction trigger** — Any INSERT, UPDATE, or DELETE on `transactions` fires `fn_transaction_balance_trigger()`. It determines the affected account(s) and earliest affected month, then cascades recalculation forward through all subsequent months via `fn_recalc_balances_from()`.
2. **Monthly cron job** — `fn_create_monthly_balance_rows()` runs on the 1st of each month via `pg_cron`. It creates a new row for every active (non-archived) account, initialized to the previous month's balance. This ensures a balance row always exists for the current month, even if no transactions have been recorded yet.
3. **Account creation** — When a new account is created, the app inserts a balance row for the current month with `balance = starting_balance`.

**Example (Checking account, starting_balance = $5,000):**

| year_month | net_txns | balance | How computed |
|---|---|---|---|
| 2026-01 | +$3,000 income, -$1,200 expense = +$1,800 | $6,800 | $5,000 + $1,800 |
| 2026-02 | -$900 expense | $5,900 | $6,800 + (-$900) |
| 2026-03 | (no transactions) | $5,900 | $5,900 + $0 (cron-created) |
| 2026-04 | +$3,000 income, -$2,100 expense = +$900 | $6,800 | $5,900 + $900 |

If the user edits a January transaction, the trigger recalculates January → February → March → April — exactly like a spreadsheet cascade.

**To get the "current balance" of an account**, clients query the latest row:

```sql
SELECT balance FROM account_monthly_balances
WHERE account_id = ? ORDER BY year_month DESC LIMIT 1;
```

### 4.4 Transfers

A transfer is modeled as a **single transaction row** with both `account_id` (source) and `transfer_account_id` (destination). This avoids the complexity of double-entry bookkeeping while still correctly adjusting both account balances via the trigger.

### 4.5 Auto-Record / Scheduled Transactions

The `scheduled_transactions` table holds the recurring template. A **cron job** (Supabase `pg_cron` or Edge Function) runs daily:

1. Queries `scheduled_transactions WHERE is_active = TRUE AND next_due_date <= today`
2. For each match, inserts a new `transactions` row with `status = 'pending'`
3. Advances `next_due_date` to the next recurrence date
4. Sends a push notification to the user

The user then **confirms**, **edits**, or **dismisses** the pending transaction from the app. Only confirmed transactions affect account balances (enforced by the trigger).

### 4.6 Dashboard Queries

Four **Postgres views** are provided to power the dashboard and account list:

| View | Powers |
|---|---|
| `v_account_current_balance` | Current balance for each account (latest month from ledger) |
| `v_monthly_cashflow` | Monthly Cash Flow (income vs. expense) |
| `v_budget_progress` | Budget Progress bars (spent vs. limit) |
| `v_spending_by_category` | Spending by Category breakdown |

"Recent Transactions" is a simple query: `SELECT * FROM transactions WHERE user_id = ? ORDER BY date DESC, created_at DESC LIMIT 10`.

### 4.7 Currency Handling

- Amounts stored as `bigint` in **minor units** (e.g., 1050 = $10.50).
- A `currencies` reference table stores all supported ISO 4217 codes, names, symbols, and decimal places. All `currency` columns in other tables reference this table via FK.
- A `user_settings` table stores the user's **default currency**. New accounts, transactions, budgets, and fixed expenses default to this currency.
- Each account and each transaction carries its own `currency` code.
- **P1 — Multi-Currency Transactions:** When a transaction's currency differs from the account's currency, the user provides the exchange rate or converted amount. The transaction is recorded in its original currency, and the account balance is adjusted using the converted amount.

### 4.8 Row-Level Security

Every table has RLS enabled. Policies ensure that a user can only read/write rows where `user_id = auth.uid()`. Junction tables (`transaction_categories`, `transaction_tags`) derive ownership through the parent `transactions` row. `budget_periods` derives ownership through its parent `budgets` table. `fixed_expenses` has a direct `user_id` column and uses the standard owner policy.

---

## 5. P1 Extension Points

| Feature | Schema Impact |
|---|---|
| **Receipt Scanning** | Add `receipt_url TEXT` column to `transactions`; store images in Supabase Storage; add an Edge Function that calls an OCR/AI API and pre-fills transaction fields. |
| **Flexible Periods** | Extend `recurrence_type` enum with `'weekly'`, `'quarterly'`, `'yearly'`, `'custom'`. Add `period_type` to `budget_periods`. Adjust cron logic. |
| **Multi-Currency Transactions** | Add `original_amount BIGINT`, `original_currency TEXT`, and `exchange_rate NUMERIC` columns to `transactions`. The existing `amount` holds the converted value in the account's currency. The trigger uses `amount` for balance updates. |
| **Extended Dashboard** | Queries over `fixed_expenses` (upcoming/overdue), `transactions WHERE status = 'pending'`, and `v_monthly_cashflow` grouped over multiple months. No schema changes needed. |
